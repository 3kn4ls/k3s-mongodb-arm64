# Guía de Solución de Problemas

Esta guía cubre los problemas más comunes y sus soluciones.

## Tabla de Contenidos

1. [Problemas de Instalación](#problemas-de-instalación)
2. [Problemas de K3s](#problemas-de-k3s)
3. [Problemas de MongoDB](#problemas-de-mongodb)
4. [Problemas de Red](#problemas-de-red)
5. [Problemas de Almacenamiento](#problemas-de-almacenamiento)
6. [Problemas de Rendimiento](#problemas-de-rendimiento)

## Problemas de Instalación

### K3s no se instala

**Síntoma:** El script de instalación falla

**Diagnóstico:**
```bash
# Verificar arquitectura
uname -m
# Debe ser aarch64 o arm64

# Verificar conectividad
ping -c 3 get.k3s.io

# Ver logs del sistema
sudo journalctl -xe
```

**Solución:**

1. Verificar que tienes Raspberry Pi OS 64-bit:
```bash
getconf LONG_BIT
# Debe mostrar: 64
```

2. Actualizar el sistema:
```bash
sudo apt-get update
sudo apt-get upgrade -y
```

3. Verificar cgroups:
```bash
cat /boot/firmware/cmdline.txt
# Debe contener: cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
```

4. Reiniciar después de configurar cgroups:
```bash
sudo reboot
```

### Pod de MongoDB no inicia

**Síntoma:** Pod permanece en estado `Pending` o `CrashLoopBackOff`

**Diagnóstico:**
```bash
# Ver estado del pod
kubectl get pods -n mongodb

# Ver detalles del pod
kubectl describe pod mongodb-0 -n mongodb

# Ver logs
kubectl logs mongodb-0 -n mongodb

# Ver eventos
kubectl get events -n mongodb --sort-by='.lastTimestamp'
```

**Soluciones comunes:**

1. **Pod en estado Pending:**
```bash
# Verificar PVC
kubectl get pvc -n mongodb

# Si el PVC está en Pending, verificar StorageClass
kubectl get storageclass

# Aplicar StorageClass si no existe
kubectl apply -f k8s/storage/storageclass.yaml
```

2. **CrashLoopBackOff:**
```bash
# Ver logs detallados
kubectl logs mongodb-0 -n mongodb --previous

# Común: Problema con credenciales
# Verificar que el secret existe
kubectl get secret mongodb-secret -n mongodb

# Si no existe, crearlo
cd scripts
./generate-secrets.sh
kubectl apply -f ../k8s/secrets/secret.yaml
```

3. **Recursos insuficientes:**
```bash
# Ver uso de recursos del nodo
kubectl top node

# Si hay problemas de memoria/CPU, reducir los requests en el StatefulSet
nano k8s/mongodb/statefulset.yaml
# Reducir requests.memory y requests.cpu
```

## Problemas de K3s

### K3s no responde

**Síntoma:** `kubectl` no funciona

**Diagnóstico:**
```bash
# Verificar servicio K3s
sudo systemctl status k3s

# Ver logs de K3s
sudo journalctl -u k3s -f
```

**Solución:**

1. Reiniciar K3s:
```bash
sudo systemctl restart k3s

# Esperar un momento
sleep 10

# Verificar
kubectl get nodes
```

2. Si persiste, reinstalar K3s:
```bash
# Desinstalar
/usr/local/bin/k3s-uninstall.sh

# Reinstalar
cd ~/k3s-mongodb-arm64/scripts
./install-k3s.sh
```

### Nodo en estado NotReady

**Diagnóstico:**
```bash
kubectl get nodes
kubectl describe node raspberrypi5
```

**Solución:**

1. Verificar cgroups:
```bash
cat /proc/cgroups
```

2. Verificar memoria:
```bash
free -h
```

3. Limpiar recursos:
```bash
# Limpiar imágenes no usadas
sudo k3s crictl rmi --prune

# Limpiar contenedores parados
sudo k3s crictl rm $(sudo k3s crictl ps -a -q --state=exited)
```

## Problemas de MongoDB

### No puedo conectarme a MongoDB

**Síntoma:** Error de autenticación o timeout

**Diagnóstico:**
```bash
# Verificar que el pod está corriendo
kubectl get pods -n mongodb

# Verificar servicio
kubectl get svc -n mongodb

# Probar desde el pod
kubectl exec -it mongodb-0 -n mongodb -- mongosh --eval "db.adminCommand('ping')"
```

**Soluciones:**

1. **Error de autenticación:**
```bash
# Verificar credenciales
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.username}' | base64 -d
echo
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.password}' | base64 -d
echo

# Reintentar con las credenciales correctas
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p
```

2. **Timeout de conexión:**
```bash
# Verificar que el servicio tiene endpoints
kubectl get endpoints -n mongodb

# Verificar puerto
kubectl get svc mongodb-external -n mongodb -o jsonpath='{.spec.ports[0].nodePort}'

# Probar conectividad al puerto
nc -zv <IP_RASPBERRY_PI> 30017
```

### MongoDB consume mucha memoria

**Diagnóstico:**
```bash
# Ver uso de memoria
kubectl top pod mongodb-0 -n mongodb

# Ver configuración de cache
kubectl exec mongodb-0 -n mongodb -- mongosh -u admin -p --eval "db.serverStatus().wiredTiger.cache"
```

**Solución:**

1. Ajustar cache de WiredTiger:
```bash
nano k8s/mongodb/configmap.yaml
```

Modificar `cacheSizeGB`:
```yaml
wiredTiger:
  engineConfig:
    cacheSizeGB: 0.25  # Reducir según disponibilidad
```

2. Aplicar cambios:
```bash
kubectl apply -f k8s/mongodb/configmap.yaml
kubectl rollout restart statefulset mongodb -n mongodb
```

### Datos perdidos después de reiniciar

**Diagnóstico:**
```bash
# Verificar PVC
kubectl get pvc -n mongodb

# Ver detalles del PV
kubectl get pv
kubectl describe pv <nombre-del-pv>
```

**Solución:**

1. Verificar que el PVC está bound:
```bash
kubectl get pvc -n mongodb
# Status debe ser "Bound"
```

2. Verificar ReclaimPolicy:
```bash
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIMPOLICY:.spec.persistentVolumeReclaimPolicy
# Debe ser "Retain"
```

3. Si los datos se perdieron, restaurar desde backup:
```bash
cd ~/k3s-mongodb-arm64/scripts
ls ~/mongodb-backups/
./restore-mongodb.sh <nombre-del-backup.tar.gz>
```

## Problemas de Red

### No puedo acceder desde fuera del cluster

**Diagnóstico:**
```bash
# Verificar servicio externo
kubectl get svc mongodb-external -n mongodb

# Verificar puerto
kubectl get svc mongodb-external -n mongodb -o jsonpath='{.spec.ports[0].nodePort}'

# Verificar firewall
sudo iptables -L -n | grep 30017
```

**Solución:**

1. Verificar que el servicio es NodePort:
```bash
kubectl get svc mongodb-external -n mongodb -o yaml | grep type
# Debe mostrar: type: NodePort
```

2. Abrir puerto en firewall (si está habilitado):
```bash
sudo ufw allow 30017/tcp
```

3. Verificar desde otra máquina:
```bash
# En tu máquina local
nc -zv <IP_RASPBERRY_PI> 30017

# O con telnet
telnet <IP_RASPBERRY_PI> 30017
```

### Conexión lenta

**Diagnóstico:**
```bash
# Ping al nodo
ping -c 10 <IP_RASPBERRY_PI>

# Ver estadísticas de red
kubectl exec mongodb-0 -n mongodb -- ss -s
```

**Solución:**

1. Usar conexión Ethernet en lugar de WiFi
2. Verificar latencia de red:
```bash
# Desde el pod
kubectl exec mongodb-0 -n mongodb -- ping -c 10 8.8.8.8
```

3. Optimizar buffer de red:
```bash
sudo nano /etc/sysctl.conf
```

Agregar:
```
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
```

Aplicar:
```bash
sudo sysctl -p
```

## Problemas de Almacenamiento

### Espacio en disco lleno

**Diagnóstico:**
```bash
# Ver uso de disco del nodo
df -h

# Ver tamaño de datos de MongoDB
kubectl exec mongodb-0 -n mongodb -- du -sh /data/db

# Ver tamaño del PVC
kubectl get pvc -n mongodb -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.resources.requests.storage
```

**Solución:**

1. Limpiar datos innecesarios del nodo:
```bash
# Limpiar paquetes
sudo apt-get clean
sudo apt-get autoremove -y

# Limpiar journalctl
sudo journalctl --vacuum-time=7d

# Limpiar contenedores de K3s
sudo k3s crictl rmi --prune
```

2. Compactar MongoDB:
```bash
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p

# Dentro de mongosh
use admin
db.runCommand({ compact: 'nombre_coleccion' })
```

3. Expandir PVC (si el StorageClass lo permite):
```bash
# Editar PVC
kubectl edit pvc mongodb-data-mongodb-0 -n mongodb

# Cambiar storage a un valor mayor
# Ejemplo: 20Gi en lugar de 10Gi
```

### PVC no se crea

**Diagnóstico:**
```bash
kubectl get pvc -n mongodb
kubectl describe pvc mongodb-data-mongodb-0 -n mongodb
```

**Solución:**

1. Verificar StorageClass:
```bash
kubectl get storageclass

# Si no existe, crear
kubectl apply -f k8s/storage/storageclass.yaml
```

2. Verificar provisioner de K3s:
```bash
kubectl get pods -n kube-system | grep local-path

# Si no está corriendo, reiniciar K3s
sudo systemctl restart k3s
```

## Problemas de Rendimiento

### MongoDB muy lento

**Diagnóstico:**
```bash
# Ver uso de recursos
kubectl top pod mongodb-0 -n mongodb

# Ver estadísticas de MongoDB
kubectl exec mongodb-0 -n mongodb -- mongosh -u admin -p --eval "db.serverStatus()"

# Ver operaciones lentas
kubectl exec mongodb-0 -n mongodb -- mongosh -u admin -p --eval "db.currentOp({'secs_running': {\$gt: 5}})"
```

**Solución:**

1. Crear índices apropiados:
```bash
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p

use myapp
db.mycollection.createIndex({ campo: 1 })
```

2. Ajustar recursos:
```bash
nano k8s/mongodb/statefulset.yaml

# Aumentar CPU y memoria
resources:
  requests:
    memory: "1Gi"
    cpu: "1000m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

3. Optimizar consultas:
```javascript
// Usar explain para ver qué optimizar
db.mycollection.find({...}).explain("executionStats")
```

4. Usar SSD en lugar de microSD:
- Conectar SSD USB
- Configurar para usar como almacenamiento principal

### Raspberry Pi se sobrecalienta

**Diagnóstico:**
```bash
# Ver temperatura
vcgencmd measure_temp
```

**Solución:**

1. Agregar disipador de calor y/o ventilador
2. Reducir overclock si está configurado
3. Reducir recursos de MongoDB:
```bash
nano k8s/mongodb/statefulset.yaml

# Reducir CPU limits
limits:
  cpu: "1000m"
```

## Comandos de Diagnóstico Útiles

```bash
# Resumen completo del cluster
kubectl cluster-info dump > cluster-dump.txt

# Ver todos los eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Ver todos los logs de MongoDB
kubectl logs mongodb-0 -n mongodb --all-containers=true

# Ver configuración completa del StatefulSet
kubectl get statefulset mongodb -n mongodb -o yaml

# Ejecutar mongosh para diagnóstico
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p

# Backup de diagnóstico
kubectl get all -n mongodb -o yaml > mongodb-resources.yaml
```

## Obtener Ayuda

Si ninguna de estas soluciones funciona:

1. Revisa los logs completos:
```bash
kubectl logs mongodb-0 -n mongodb > mongodb.log
kubectl describe pod mongodb-0 -n mongodb > mongodb-describe.txt
kubectl get events -n mongodb > mongodb-events.txt
```

2. Crea un issue en GitHub con:
   - Descripción del problema
   - Los archivos de logs
   - Salida de `kubectl get nodes` y `kubectl get all -n mongodb`
   - Versión de Raspberry Pi OS y K3s

3. Consulta la documentación oficial:
   - [MongoDB Documentation](https://docs.mongodb.com/)
   - [K3s Documentation](https://docs.k3s.io/)
   - [Kubernetes Documentation](https://kubernetes.io/docs/)

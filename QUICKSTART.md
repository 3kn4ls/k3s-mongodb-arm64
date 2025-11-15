# Guía de Inicio Rápido - MongoDB en K3s

## ⚠️ IMPORTANTE: Cómo ejecutar los scripts

**NO** copies y pegues la salida de los scripts.
**SÍ** ejecuta los scripts directamente desde la terminal.

## Paso a Paso

### 1. Verificar que K3s está funcionando

```bash
kubectl get nodes
```

Deberías ver algo como:
```
NAME     STATUS   ROLES                  AGE   VERSION
rpi5     Ready    control-plane,master   1d    v1.28.x+k3s1
```

Si no ves esto, necesitas instalar K3s primero (ver [docs/INSTALLATION.md](docs/INSTALLATION.md#apéndice-instalación-de-k3s)).

### 2. Navegar al directorio del proyecto

```bash
cd ~/ws/k3s-mongodb-arm64
```

### 3. Verificar permisos de los scripts

```bash
ls -la scripts/
```

Los scripts deben tener permisos de ejecución (x). Si no los tienen:

```bash
chmod +x scripts/*.sh
```

### 4. Generar credenciales de MongoDB

```bash
./scripts/generate-secrets.sh
```

**IMPORTANTE:** Ejecuta el comando EXACTAMENTE como se muestra arriba, incluyendo `./scripts/`

El script te preguntará:
- Usuario de MongoDB (por defecto: admin)
- Si quieres generar una contraseña aleatoria (recomendado: s)

**Guarda la contraseña que se genera** - la necesitarás para conectarte.

### 5. Desplegar MongoDB

```bash
./scripts/deploy-mongodb.sh
```

**IMPORTANTE:** De nuevo, ejecuta EXACTAMENTE como se muestra, con `./scripts/`

El script:
1. Creará el namespace `mongodb`
2. Configurará el almacenamiento
3. Creará los secrets
4. Desplegará MongoDB
5. Esperará a que esté listo (puede tomar varios minutos)

### 6. Verificar el despliegue

```bash
kubectl get pods -n mongodb
```

Deberías ver algo como:
```
NAME        READY   STATUS    RESTARTS   AGE
mongodb-0   1/1     Running   0          2m
```

**Estado esperado:** `Running` con `1/1` en READY

### 7. Monitorear MongoDB

```bash
./scripts/monitor-mongodb.sh
```

Esto mostrará:
- Estado de los pods
- Servicios disponibles
- Uso de recursos
- Información de conexión

## 🔍 Solución de Problemas Comunes

### Error: "command not found"

Si ves errores como:
```
-bash: IMPORTANTE:: command not found
-bash: =========================================: command not found
```

**Problema:** Estás copiando/pegando la salida del script en lugar de ejecutarlo.

**Solución:** Ejecuta el comando completo:
```bash
./scripts/deploy-mongodb.sh
```

**NO hagas:**
- Copiar y pegar líneas individuales del script
- Usar `source` o `.` para ejecutar el script
- Ejecutar desde otro directorio sin `./`

### Error: "Permission denied"

```bash
chmod +x scripts/*.sh
```

### Error: "No such file or directory"

Asegúrate de estar en el directorio correcto:

```bash
pwd
# Debe mostrar: /home/ecanals/ws/k3s-mongodb-arm64 (o similar)

# Si no estás ahí:
cd ~/ws/k3s-mongodb-arm64
```

### Error: "kubectl: command not found"

K3s no está instalado o kubectl no está configurado.

Verificar:
```bash
# Opción 1: Usar k3s kubectl
sudo k3s kubectl get nodes

# Opción 2: Configurar kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

### Pod en estado "Pending" o "ImagePullBackOff"

```bash
# Ver detalles del error
kubectl describe pod mongodb-0 -n mongodb

# Ver logs
kubectl logs mongodb-0 -n mongodb
```

Causas comunes:
- Falta de recursos (RAM/CPU)
- Problema descargando la imagen (verificar conectividad)
- StorageClass no configurado correctamente

## 📋 Comandos de Referencia Rápida

```bash
# Ver estado de MongoDB
kubectl get all -n mongodb

# Ver logs en tiempo real
kubectl logs -f mongodb-0 -n mongodb

# Conectar a MongoDB desde el pod
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p

# Obtener la contraseña
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.password}' | base64 -d && echo

# Obtener la IP del nodo para conexión externa
kubectl get nodes -o wide

# Ver información de conexión
./scripts/monitor-mongodb.sh

# Hacer backup
./scripts/backup-mongodb.sh

# Desinstalar (¡CUIDADO! Borra los datos)
./scripts/uninstall-mongodb.sh
```

## 🔌 Conectarse a MongoDB

### Desde dentro del cluster

```javascript
mongodb://admin:TU_PASSWORD@mongodb-service.mongodb.svc.cluster.local:27017
```

### Desde fuera del cluster

```javascript
mongodb://admin:TU_PASSWORD@IP_DEL_NODO:30017
```

Para obtener la IP del nodo:
```bash
kubectl get nodes -o wide | awk 'NR==2 {print $6}'
```

### Usando mongosh (desde tu PC)

```bash
# Instalar mongosh si no lo tienes
# En tu PC local (no en la Raspberry Pi)

# Ubuntu/Debian:
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-mongosh

# Conectar (reemplazar IP_DEL_NODO y PASSWORD)
mongosh "mongodb://admin:PASSWORD@IP_DEL_NODO:30017"
```

## 🎯 Próximos Pasos

1. ✅ MongoDB está corriendo
2. 📖 Lee la [Guía de Configuración Avanzada](docs/CONFIGURATION.md)
3. 💾 Configura backups automáticos: `./scripts/setup-cronjob-backup.sh`
4. 🔒 Cambia las credenciales por defecto si las usaste
5. 🔌 Conecta tu aplicación a MongoDB
6. 📊 Configura monitoreo continuo: `./scripts/monitor-mongodb.sh --watch`

## 📚 Documentación Adicional

- [Guía de Instalación Completa](docs/INSTALLATION.md)
- [Configuración Avanzada](docs/CONFIGURATION.md)
- [Solución de Problemas](docs/TROUBLESHOOTING.md)
- [Guía de Backups](docs/BACKUP.md)
- [Ejemplos de Clientes](examples/README.md)

# Guía de Instalación Detallada

Esta guía cubre el proceso de despliegue de MongoDB en un cluster K3s existente sobre Raspberry Pi 5.

## Tabla de Contenidos

1. [Verificar Prerrequisitos](#verificar-prerrequisitos)
2. [Configuración de MongoDB](#configuración-de-mongodb)
3. [Despliegue](#despliegue)
4. [Verificación](#verificación)
5. [Post-instalación](#post-instalación)
6. [Apéndice: Instalación de K3s](#apéndice-instalación-de-k3s) (si no lo tienes instalado)

## Verificar Prerrequisitos

### 1. Cluster K3s Instalado

**IMPORTANTE:** Este proyecto asume que ya tienes un cluster K3s funcionando.

Verifica que K3s está corriendo:

```bash
# Verificar que kubectl está disponible
kubectl version --client

# Verificar el cluster
kubectl cluster-info

# Verificar nodos
kubectl get nodes
```

Deberías ver algo como:

```
NAME            STATUS   ROLES                  AGE   VERSION
raspberrypi5    Ready    control-plane,master   1d    v1.28.x+k3s1
```

**Si NO tienes K3s instalado**, ve al [Apéndice: Instalación de K3s](#apéndice-instalación-de-k3s) al final de este documento.

### 2. Requisitos del Sistema

- **Raspberry Pi 5** con arquitectura ARM64
- **RAM:** Mínimo 4GB disponible (8GB recomendado)
- **Almacenamiento:** Mínimo 20GB libres para datos de MongoDB
- **Arquitectura:** ARM64 (aarch64)

Verificar arquitectura:

```bash
uname -m
# Debe mostrar: aarch64 o arm64
```

### 3. Clonar el Repositorio

```bash
cd ~
git clone https://github.com/tu-usuario/k3s-mongodb-arm64.git
cd k3s-mongodb-arm64
```


## Configuración de MongoDB

### 1. Generar credenciales

#### Opción A: Usando el script (recomendado)

```bash
cd scripts
./generate-secrets.sh
```

El script te guiará para:
- Establecer el usuario (por defecto: admin)
- Generar una contraseña segura automáticamente o ingresar una personalizada

#### Opción B: Manualmente

```bash
# Copiar plantilla
cp k8s/secrets/secret.yaml.example k8s/secrets/secret.yaml

# Editar credenciales
nano k8s/secrets/secret.yaml
```

Cambiar los valores de `username` y `password`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
  namespace: mongodb
type: Opaque
stringData:
  username: admin
  password: tu-contraseña-segura-aqui
  connection-string: mongodb://admin:tu-contraseña-segura-aqui@mongodb-service.mongodb.svc.cluster.local:27017
```

### 2. Ajustar recursos (opcional)

Si tu Raspberry Pi tiene limitaciones de recursos, edita el StatefulSet:

```bash
nano k8s/mongodb/statefulset.yaml
```

Ajustar la sección de recursos:

```yaml
resources:
  requests:
    memory: "256Mi"  # Reducir si es necesario
    cpu: "250m"
  limits:
    memory: "1Gi"    # Ajustar según RAM disponible
    cpu: "1000m"
```

Ajustar tamaño del volumen:

```yaml
volumeClaimTemplates:
  - metadata:
      name: mongodb-data
    spec:
      resources:
        requests:
          storage: 5Gi  # Ajustar según espacio disponible
```

## Despliegue

### 1. Usando el script automatizado

```bash
cd scripts
./deploy-mongodb.sh
```

El script desplegará automáticamente:
1. Namespace
2. StorageClass
3. Secret
4. ConfigMap
5. Services
6. StatefulSet

### 2. Despliegue manual (alternativa)

```bash
# 1. Crear namespace
kubectl apply -f k8s/mongodb/namespace.yaml

# 2. Crear StorageClass
kubectl apply -f k8s/storage/storageclass.yaml

# 3. Crear Secret
kubectl apply -f k8s/secrets/secret.yaml

# 4. Crear ConfigMap
kubectl apply -f k8s/mongodb/configmap.yaml

# 5. Crear Services
kubectl apply -f k8s/mongodb/service.yaml

# 6. Crear StatefulSet
kubectl apply -f k8s/mongodb/statefulset.yaml
```

### 3. Esperar a que esté listo

```bash
# Ver progreso
kubectl get pods -n mongodb -w

# Esperar hasta que el estado sea "Running" y "1/1" en READY
```

Esto puede tomar varios minutos, especialmente la primera vez que descarga la imagen.

## Verificación

### 1. Verificar recursos

```bash
# Ver todos los recursos
kubectl get all -n mongodb

# Ver detalles del pod
kubectl describe pod mongodb-0 -n mongodb

# Ver logs
kubectl logs mongodb-0 -n mongodb
```

### 2. Probar conexión

```bash
# Desde el pod
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p

# Ingresar la contraseña cuando se solicite
```

Dentro de mongosh, ejecutar:

```javascript
// Ver bases de datos
show dbs

// Usar una base de datos
use test

// Insertar un documento
db.test.insertOne({ mensaje: "¡MongoDB funciona!" })

// Leer el documento
db.test.find()

// Salir
exit
```

### 3. Probar conectividad externa

Desde tu máquina local (no la Raspberry Pi):

```bash
# Obtener IP de la Raspberry Pi
# Supongamos que es 192.168.1.100

# Instalar mongosh en tu máquina local
# Para Ubuntu/Debian:
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-mongosh

# Conectar
mongosh "mongodb://admin:PASSWORD@192.168.1.100:30017"
```

### 4. Usar el script de monitoreo

```bash
cd scripts
./monitor-mongodb.sh
```

Esto mostrará:
- Estado de recursos K8s
- Uso de CPU/RAM
- Estadísticas de MongoDB
- Logs recientes
- Información de conexión

## Post-instalación

### 1. Configurar backups automáticos

```bash
cd scripts
./setup-cronjob-backup.sh
```

Esto configurará un cron job para hacer backups diarios a las 2:00 AM.

### 2. Crear usuario de aplicación

Es recomendable crear un usuario específico para tu aplicación:

```bash
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p
```

Dentro de mongosh:

```javascript
// Cambiar a la base de datos de tu aplicación
use myapp

// Crear usuario de aplicación
db.createUser({
  user: "myappuser",
  pwd: "secure-password-here",
  roles: [
    { role: "readWrite", db: "myapp" }
  ]
})

// Verificar
db.getUsers()
```

### 3. Configurar monitoreo (opcional)

Si deseas monitoreo continuo:

```bash
# En una sesión separada o tmux
cd scripts
./monitor-mongodb.sh --watch
```

### 4. Optimización del rendimiento

#### Configurar ulimits

```bash
sudo nano /etc/security/limits.conf
```

Agregar:

```
mongodb soft nofile 64000
mongodb hard nofile 64000
mongodb soft nproc 64000
mongodb hard nproc 64000
```

#### Deshabilitar Transparent Huge Pages

```bash
sudo nano /etc/rc.local
```

Agregar antes de `exit 0`:

```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

### 5. Documentar tu instalación

Guardar información importante:

```bash
# Crear archivo de información
cat > ~/mongodb-info.txt << EOF
MongoDB en K3s - Información de Instalación
=========================================

Fecha de instalación: $(date)
Versión de K3s: $(kubectl version --short 2>/dev/null | grep Server)
Versión de MongoDB: $(kubectl exec mongodb-0 -n mongodb -- mongosh --version 2>/dev/null | head -1)

IP del nodo: $(hostname -I | awk '{print $1}')
Puerto externo: 30017

Conexión interna: mongodb://admin:PASSWORD@mongodb-service.mongodb.svc.cluster.local:27017
Conexión externa: mongodb://admin:PASSWORD@$(hostname -I | awk '{print $1}'):30017

Usuario: admin
Contraseña: [Guardada en k8s/secrets/secret.yaml]

Directorio de backups: ~/mongodb-backups/
Cron job de backup: $(crontab -l 2>/dev/null | grep backup-mongodb.sh || echo "No configurado")

Comandos útiles:
- Monitorear: cd ~/k3s-mongodb-arm64/scripts && ./monitor-mongodb.sh
- Backup: cd ~/k3s-mongodb-arm64/scripts && ./backup-mongodb.sh
- Logs: kubectl logs -f mongodb-0 -n mongodb
EOF

cat ~/mongodb-info.txt
```

## Próximos pasos

1. Lee la [Guía de Configuración Avanzada](CONFIGURATION.md)
2. Configura tu aplicación para conectarse a MongoDB
3. Establece una rutina de backups
4. Configura alertas de monitoreo
5. Lee la [Guía de Solución de Problemas](TROUBLESHOOTING.md)

## Desinstalación

Si necesitas desinstalar MongoDB:

```bash
cd ~/k3s-mongodb-arm64/scripts
./uninstall-mongodb.sh
```

**IMPORTANTE:** Haz un backup antes de desinstalar si tienes datos importantes.

---

## Apéndice: Instalación de K3s

**NOTA:** Esta sección es solo si NO tienes K3s instalado. Si ya tienes K3s funcionando, puedes saltar esta sección.

### Requisitos Previos para K3s

- Raspberry Pi OS (64-bit)
- Al menos 4GB de RAM
- Conexión a Internet

### Opción 1: Instalación Automatizada (Recomendado)

Usa el script proporcionado:

```bash
cd ~/k3s-mongodb-arm64/scripts
chmod +x install-k3s.sh
./install-k3s.sh
```

El script realizará:
1. Verificación del sistema
2. Configuración de cgroups
3. Instalación de K3s
4. Configuración de kubectl
5. Creación de alias útiles

**Después de ejecutar el script, es probable que necesites reiniciar:**

```bash
sudo reboot
```

### Opción 2: Instalación Manual

#### Paso 1: Configurar cgroups

```bash
sudo nano /boot/firmware/cmdline.txt
```

Agregar al final de la línea existente (sin crear nueva línea):

```
cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
```

Guardar y reiniciar:

```bash
sudo reboot
```

#### Paso 2: Instalar K3s

```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --node-name raspberrypi5
```

#### Paso 3: Configurar kubectl para usuario no-root

```bash
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
chmod 600 $HOME/.kube/config
```

#### Paso 4: Verificar instalación

```bash
kubectl get nodes
kubectl get pods -A
```

Deberías ver:
- Nodo en estado "Ready"
- Varios pods del sistema corriendo en namespaces kube-system

#### Paso 5: Configuración adicional (Opcional)

Agregar alias útiles:

```bash
cat >> ~/.bashrc << 'ALIASES'
# Kubernetes aliases
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
ALIASES

source ~/.bashrc
```

Habilitar autocompletado:

```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
```

### Verificar que K3s está funcionando correctamente

```bash
# Ver versión de K3s
k3s --version

# Ver cluster info
kubectl cluster-info

# Ver nodos
kubectl get nodes -o wide

# Ver componentes del sistema
kubectl get pods -n kube-system
```

### Optimizaciones para Raspberry Pi (Opcional)

#### Reducir uso de memoria

Editar `/etc/rancher/k3s/config.yaml`:

```yaml
kubelet-arg:
  - "kube-api-qps=20"
  - "kube-api-burst=40"
  - "max-pods=50"
```

Reiniciar K3s:

```bash
sudo systemctl restart k3s
```

#### Configurar IP estática

Editar `/etc/dhcpcd.conf`:

```bash
sudo nano /etc/dhcpcd.conf
```

Agregar al final:

```
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8
```

Aplicar cambios:

```bash
sudo systemctl restart dhcpcd
```

### Solución de Problemas de K3s

#### K3s no inicia

Ver logs:

```bash
sudo journalctl -u k3s -f
```

#### Reiniciar K3s

```bash
sudo systemctl restart k3s
```

#### Desinstalar K3s (si necesitas empezar de cero)

```bash
/usr/local/bin/k3s-uninstall.sh
```

### Una vez K3s esté funcionando...

Regresa a la [Configuración de MongoDB](#configuración-de-mongodb) para continuar con el despliegue de MongoDB.

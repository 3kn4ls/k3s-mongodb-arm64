# Guía de Instalación Detallada

Esta guía cubre el proceso completo de instalación de MongoDB en K3s sobre Raspberry Pi 5.

## Tabla de Contenidos

1. [Preparación del Sistema](#preparación-del-sistema)
2. [Instalación de K3s](#instalación-de-k3s)
3. [Configuración de MongoDB](#configuración-de-mongodb)
4. [Despliegue](#despliegue)
5. [Verificación](#verificación)
6. [Post-instalación](#post-instalación)

## Preparación del Sistema

### 1. Requisitos de Hardware

- **Raspberry Pi 5** (recomendado) o Raspberry Pi 4
- **RAM:** Mínimo 4GB, recomendado 8GB
- **Almacenamiento:** Mínimo 32GB microSD (recomendado SSD USB)
- **Red:** Conexión Ethernet (recomendado) o WiFi

### 2. Sistema Operativo

Instalar **Raspberry Pi OS (64-bit)**:

```bash
# Verificar arquitectura
uname -m
# Debe mostrar: aarch64 o arm64

# Actualizar el sistema
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
```

### 3. Configuración del Sistema

#### Expandir el sistema de archivos

```bash
sudo raspi-config
# Navegar a: Advanced Options > Expand Filesystem
```

#### Configurar memoria (opcional pero recomendado)

Editar `/boot/firmware/config.txt`:

```bash
sudo nano /boot/firmware/config.txt
```

Agregar al final:

```
# Aumentar memoria GPU (reducir para dar más a sistema)
gpu_mem=16

# Overclock (opcional, ajustar según tu modelo)
over_voltage=6
arm_freq=2400
```

#### Configurar swap (para sistemas con 4GB RAM)

```bash
# Aumentar swap a 2GB
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# Cambiar CONF_SWAPSIZE=2048
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

#### Deshabilitar servicios innecesarios

```bash
# Deshabilitar Bluetooth (si no se usa)
sudo systemctl disable bluetooth
sudo systemctl stop bluetooth

# Deshabilitar servicios gráficos (si es servidor headless)
sudo systemctl set-default multi-user.target
```

### 4. Configurar IP estática (recomendado)

Editar `/etc/dhcpcd.conf`:

```bash
sudo nano /etc/dhcpcd.conf
```

Agregar al final (ajustar según tu red):

```
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8
```

Reiniciar:

```bash
sudo reboot
```

## Instalación de K3s

### 1. Usando el script automatizado

```bash
cd k3s-mongodb-arm64/scripts
chmod +x install-k3s.sh
./install-k3s.sh
```

### 2. Instalación manual (alternativa)

#### Configurar cgroups

```bash
sudo nano /boot/firmware/cmdline.txt
```

Agregar al final de la línea (sin saltos de línea):

```
cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
```

Reiniciar:

```bash
sudo reboot
```

#### Instalar K3s

```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --node-name raspberrypi5
```

#### Configurar kubectl

```bash
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
chmod 600 $HOME/.kube/config
```

#### Verificar instalación

```bash
kubectl get nodes
kubectl get pods -A
```

Deberías ver el nodo en estado "Ready" y varios pods del sistema corriendo.

### 3. Configuración adicional de K3s

#### Alias útiles

```bash
echo "alias k=kubectl" >> ~/.bashrc
echo "alias kgp='kubectl get pods'" >> ~/.bashrc
echo "alias kgs='kubectl get svc'" >> ~/.bashrc
echo "alias kgn='kubectl get nodes'" >> ~/.bashrc
source ~/.bashrc
```

#### Habilitar autocompletado

```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
```

## Configuración de MongoDB

### 1. Clonar el repositorio

```bash
cd ~
git clone https://github.com/tu-usuario/k3s-mongodb-arm64.git
cd k3s-mongodb-arm64
```

### 2. Generar credenciales

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

### 3. Ajustar recursos (opcional)

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

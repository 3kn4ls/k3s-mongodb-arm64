# Guía de Backups y Restauración

Guía completa para realizar backups y restauración de MongoDB.

## Tabla de Contenidos

1. [Estrategia de Backup](#estrategia-de-backup)
2. [Backup Manual](#backup-manual)
3. [Backup Automático](#backup-automático)
4. [Restauración](#restauración)
5. [Backup a Storage Remoto](#backup-a-storage-remoto)
6. [Verificación de Backups](#verificación-de-backups)

## Estrategia de Backup

### Tipos de Backup

1. **Backup Completo (Full):** Copia de todas las bases de datos
2. **Backup Incremental:** Solo cambios desde último backup
3. **Snapshot del Volumen:** Copia del volumen de almacenamiento

### Frecuencia Recomendada

| Entorno | Frecuencia | Retención |
|---------|-----------|-----------|
| Desarrollo | Semanal | 2 semanas |
| Testing | Diario | 1 mes |
| Producción | Diario + Continuo | 3 meses |

### Regla 3-2-1

Para producción, seguir la regla 3-2-1:
- **3** copias de tus datos
- **2** tipos diferentes de storage
- **1** copia off-site (remota)

## Backup Manual

### Usando el Script

```bash
cd ~/k3s-mongodb-arm64/scripts
./backup-mongodb.sh
```

El script:
1. Crea un dump de todas las bases de datos
2. Comprime el backup
3. Lo guarda en `~/mongodb-backups/`
4. Limpia backups antiguos (>7 días por defecto)

### Personalizar el Directorio

```bash
# Cambiar directorio de backups
export BACKUP_DIR=/mnt/external-drive/mongodb-backups
./backup-mongodb.sh

# Cambiar retención (días)
export RETENTION_DAYS=30
./backup-mongodb.sh
```

### Backup Manual con mongodump

```bash
# Obtener credenciales
MONGO_USER=$(kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.username}' | base64 -d)
MONGO_PASS=$(kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.password}' | base64 -d)

# Crear backup
kubectl exec mongodb-0 -n mongodb -- mongodump \
  --username="$MONGO_USER" \
  --password="$MONGO_PASS" \
  --authenticationDatabase=admin \
  --out=/tmp/backup

# Copiar a local
kubectl cp mongodb/mongodb-0:/tmp/backup ./mongodb-backup-$(date +%Y%m%d)

# Limpiar en el pod
kubectl exec mongodb-0 -n mongodb -- rm -rf /tmp/backup
```

### Backup de una Base de Datos Específica

```bash
kubectl exec mongodb-0 -n mongodb -- mongodump \
  --username="$MONGO_USER" \
  --password="$MONGO_PASS" \
  --authenticationDatabase=admin \
  --db=myapp \
  --out=/tmp/backup
```

### Backup de una Colección Específica

```bash
kubectl exec mongodb-0 -n mongodb -- mongodump \
  --username="$MONGO_USER" \
  --password="$MONGO_PASS" \
  --authenticationDatabase=admin \
  --db=myapp \
  --collection=users \
  --out=/tmp/backup
```

## Backup Automático

### Configurar Cron Job

```bash
cd ~/k3s-mongodb-arm64/scripts
./setup-cronjob-backup.sh
```

Esto configura un cron job que ejecuta backups diarios a las 2:00 AM.

### Ver Crontab

```bash
crontab -l
```

### Ver Logs de Backup

```bash
tail -f /var/log/mongodb-backup.log
```

### Personalizar Horario

```bash
# Editar crontab
crontab -e

# Ejemplos de horarios:
# Cada 6 horas: 0 */6 * * *
# Cada domingo a las 3 AM: 0 3 * * 0
# Cada día a las 2 AM: 0 2 * * *
# Cada hora: 0 * * * *
```

### CronJob de Kubernetes (Alternativa)

Crear un CronJob que corre dentro del cluster:

```yaml
# k8s/mongodb/backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-backup
  namespace: mongodb
spec:
  schedule: "0 2 * * *"  # Diario a las 2 AM
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: mongodb-backup
            image: mongo:7.0
            command:
            - /bin/bash
            - -c
            - |
              TIMESTAMP=$(date +%Y%m%d_%H%M%S)
              mongodump \
                --uri="mongodb://${MONGO_USER}:${MONGO_PASS}@mongodb-service:27017" \
                --authenticationDatabase=admin \
                --out=/backup/mongodb_${TIMESTAMP}
              tar -czf /backup/mongodb_${TIMESTAMP}.tar.gz /backup/mongodb_${TIMESTAMP}
              rm -rf /backup/mongodb_${TIMESTAMP}
              # Limpiar backups antiguos (>7 días)
              find /backup -name "mongodb_*.tar.gz" -mtime +7 -delete
            env:
            - name: MONGO_USER
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: username
            - name: MONGO_PASS
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: password
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: mongodb-backup-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-backup-pvc
  namespace: mongodb
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: mongodb-storage
  resources:
    requests:
      storage: 20Gi
```

Aplicar:

```bash
kubectl apply -f k8s/mongodb/backup-cronjob.yaml

# Ver CronJobs
kubectl get cronjob -n mongodb

# Ver ejecuciones
kubectl get jobs -n mongodb

# Trigger manual
kubectl create job --from=cronjob/mongodb-backup mongodb-backup-manual -n mongodb
```

## Restauración

### Usando el Script

```bash
cd ~/k3s-mongodb-arm64/scripts

# Listar backups disponibles
ls -lh ~/mongodb-backups/

# Restaurar
./restore-mongodb.sh mongodb_backup_20240115_020000.tar.gz
```

**ADVERTENCIA:** Esto sobrescribirá todos los datos actuales.

### Restauración Manual

```bash
# Descomprimir backup
cd ~/mongodb-backups
tar -xzf mongodb_backup_20240115_020000.tar.gz

# Copiar al pod
kubectl cp mongodb_backup_20240115_020000 mongodb/mongodb-0:/tmp/restore

# Restaurar
MONGO_USER=$(kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.username}' | base64 -d)
MONGO_PASS=$(kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.password}' | base64 -d)

kubectl exec mongodb-0 -n mongodb -- mongorestore \
  --username="$MONGO_USER" \
  --password="$MONGO_PASS" \
  --authenticationDatabase=admin \
  --drop \
  /tmp/restore

# Limpiar
kubectl exec mongodb-0 -n mongodb -- rm -rf /tmp/restore
```

### Restaurar Solo una Base de Datos

```bash
kubectl exec mongodb-0 -n mongodb -- mongorestore \
  --username="$MONGO_USER" \
  --password="$MONGO_PASS" \
  --authenticationDatabase=admin \
  --db=myapp \
  --drop \
  /tmp/restore/myapp
```

### Restaurar a un Nombre Diferente

```bash
# Restaurar 'myapp' como 'myapp_backup'
kubectl exec mongodb-0 -n mongodb -- mongorestore \
  --username="$MONGO_USER" \
  --password="$MONGO_PASS" \
  --authenticationDatabase=admin \
  --db=myapp_backup \
  /tmp/restore/myapp
```

### Restaurar Solo una Colección

```bash
kubectl exec mongodb-0 -n mongodb -- mongorestore \
  --username="$MONGO_USER" \
  --password="$MONGO_PASS" \
  --authenticationDatabase=admin \
  --db=myapp \
  --collection=users \
  /tmp/restore/myapp/users.bson
```

## Backup a Storage Remoto

### Backup a NFS

#### 1. Montar NFS

```bash
# Instalar cliente NFS
sudo apt-get install -y nfs-common

# Crear punto de montaje
sudo mkdir -p /mnt/nfs-backup

# Montar NFS
sudo mount -t nfs 192.168.1.50:/backup /mnt/nfs-backup

# Hacer permanente
echo "192.168.1.50:/backup /mnt/nfs-backup nfs defaults 0 0" | sudo tee -a /etc/fstab
```

#### 2. Configurar backup a NFS

```bash
export BACKUP_DIR=/mnt/nfs-backup/mongodb
./scripts/backup-mongodb.sh
```

### Backup a S3 / MinIO

#### 1. Instalar s3cmd

```bash
sudo apt-get install -y s3cmd
s3cmd --configure
```

#### 2. Script de backup a S3

```bash
#!/bin/bash
# backup-to-s3.sh

# Crear backup local
cd ~/k3s-mongodb-arm64/scripts
./backup-mongodb.sh

# Obtener último backup
LATEST_BACKUP=$(ls -t ~/mongodb-backups/*.tar.gz | head -1)

# Subir a S3
s3cmd put $LATEST_BACKUP s3://my-bucket/mongodb-backups/

# Opcional: Limpiar backup local después de subir
# rm $LATEST_BACKUP
```

#### 3. Automatizar

```bash
chmod +x backup-to-s3.sh

# Agregar a crontab
crontab -e
# 0 3 * * * /home/pi/backup-to-s3.sh >> /var/log/mongodb-s3-backup.log 2>&1
```

### Backup a Rsync

```bash
#!/bin/bash
# backup-to-remote.sh

# Crear backup local
cd ~/k3s-mongodb-arm64/scripts
./backup-mongodb.sh

# Sincronizar con servidor remoto
rsync -avz --progress \
  ~/mongodb-backups/ \
  user@remote-server:/backups/mongodb/
```

## Verificación de Backups

### Verificar Integridad

```bash
# Verificar que el archivo no está corrupto
tar -tzf ~/mongodb-backups/mongodb_backup_20240115_020000.tar.gz > /dev/null
echo $?  # Debe ser 0

# Ver contenido
tar -tzf ~/mongodb-backups/mongodb_backup_20240115_020000.tar.gz | head -20
```

### Test de Restauración

Es crítico probar que los backups funcionan:

```bash
# 1. Crear namespace de prueba
kubectl create namespace mongodb-test

# 2. Desplegar MongoDB de prueba
# (usar los mismos manifiestos pero en namespace mongodb-test)

# 3. Restaurar backup
./scripts/restore-mongodb.sh mongodb_backup_20240115_020000.tar.gz

# 4. Verificar datos
kubectl exec -it mongodb-0 -n mongodb-test -- mongosh -u admin -p
# Verificar que los datos están correctos

# 5. Limpiar
kubectl delete namespace mongodb-test
```

### Automatizar Verificación

```bash
#!/bin/bash
# verify-backup.sh

BACKUP_FILE=$1

# Descomprimir
TEMP_DIR=$(mktemp -d)
tar -xzf $BACKUP_FILE -C $TEMP_DIR

# Verificar estructura
if [ -d "$TEMP_DIR/admin" ] && [ -d "$TEMP_DIR/myapp" ]; then
  echo "✓ Estructura correcta"
else
  echo "✗ Estructura inválida"
  exit 1
fi

# Contar archivos
FILE_COUNT=$(find $TEMP_DIR -name "*.bson" | wc -l)
echo "Archivos BSON encontrados: $FILE_COUNT"

# Limpiar
rm -rf $TEMP_DIR

echo "Verificación completada"
```

## Mejores Prácticas

### 1. Automatización

- Siempre tener backups automáticos configurados
- No confiar solo en backups manuales

### 2. Múltiples Copias

```bash
# Backup local + remoto
./backup-mongodb.sh
rsync -az ~/mongodb-backups/ user@remote:/backups/
```

### 3. Encriptación

```bash
# Encriptar backup antes de subir
gpg --symmetric --cipher-algo AES256 mongodb_backup.tar.gz

# Desencriptar
gpg --decrypt mongodb_backup.tar.gz.gpg > mongodb_backup.tar.gz
```

### 4. Monitoreo

```bash
# Script para verificar que los backups se están creando
#!/bin/bash
LATEST=$(find ~/mongodb-backups -name "*.tar.gz" -mtime -1 | wc -l)
if [ $LATEST -eq 0 ]; then
  echo "ALERTA: No hay backups recientes"
  # Enviar notificación
fi
```

### 5. Documentación

Mantener registro de:
- Qué se respalda
- Cuándo se hace el backup
- Dónde se almacena
- Cómo restaurar
- Última restauración exitosa

### 6. Retención

Configurar política de retención apropiada:

```bash
# Ejemplo de política escalonada
# Mantener:
# - Diarios: últimos 7 días
# - Semanales: últimas 4 semanas
# - Mensuales: últimos 12 meses

# Script de limpieza (retention.sh)
BACKUP_DIR=~/mongodb-backups

# Limpiar backups diarios >7 días
find $BACKUP_DIR -name "mongodb_backup_*.tar.gz" -mtime +7 -delete

# Los backups semanales y mensuales se manejan por separado
# (mover a subdirectorios weekly/ y monthly/)
```

## Recuperación ante Desastres

### Escenario: Pérdida Total

1. **Reinstalar K3s y MongoDB**
```bash
cd ~/k3s-mongodb-arm64/scripts
./install-k3s.sh
./deploy-mongodb.sh
```

2. **Restaurar último backup**
```bash
# Copiar backup desde storage remoto
rsync -az user@remote:/backups/mongodb/ ~/mongodb-backups/

# Restaurar
./restore-mongodb.sh $(ls -t ~/mongodb-backups/*.tar.gz | head -1)
```

3. **Verificar datos**
```bash
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p
show dbs
# Verificar que todo está en orden
```

### Escenario: Corrupción de Datos

1. **Detener aplicaciones que escriben a MongoDB**
```bash
kubectl scale deployment myapp --replicas=0 -n myapp
```

2. **Identificar último backup bueno**
```bash
ls -lht ~/mongodb-backups/
```

3. **Restaurar**
```bash
./restore-mongodb.sh mongodb_backup_BUENO.tar.gz
```

4. **Reiniciar aplicaciones**
```bash
kubectl scale deployment myapp --replicas=3 -n myapp
```

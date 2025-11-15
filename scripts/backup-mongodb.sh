#!/bin/bash

###############################################################################
# Script de backup de MongoDB
# Crea un backup completo de todas las bases de datos
###############################################################################

set -e

echo "========================================="
echo "Backup de MongoDB"
echo "========================================="

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuración
BACKUP_DIR="${BACKUP_DIR:-/home/$(whoami)/mongodb-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mongodb_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
NAMESPACE="mongodb"
POD_NAME="mongodb-0"

# Número de backups a retener
RETENTION_DAYS=${RETENTION_DAYS:-7}

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}Iniciando backup de MongoDB...${NC}"
echo "Directorio de backup: $BACKUP_PATH"

# Verificar que el pod existe y está corriendo
if ! kubectl get pod $POD_NAME -n $NAMESPACE &> /dev/null; then
    echo -e "${RED}Error: Pod $POD_NAME no encontrado en namespace $NAMESPACE${NC}"
    exit 1
fi

# Obtener credenciales
MONGO_USER=$(kubectl get secret mongodb-secret -n $NAMESPACE -o jsonpath='{.data.username}' | base64 -d)
MONGO_PASS=$(kubectl get secret mongodb-secret -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d)

# Crear backup usando mongodump
echo -e "\n${YELLOW}Ejecutando mongodump...${NC}"
kubectl exec $POD_NAME -n $NAMESPACE -- mongodump \
    --username="$MONGO_USER" \
    --password="$MONGO_PASS" \
    --authenticationDatabase=admin \
    --out=/tmp/backup_${TIMESTAMP}

# Copiar backup del pod a local
echo -e "\n${YELLOW}Copiando backup del pod...${NC}"
kubectl cp $NAMESPACE/$POD_NAME:/tmp/backup_${TIMESTAMP} "$BACKUP_PATH"

# Limpiar backup temporal en el pod
kubectl exec $POD_NAME -n $NAMESPACE -- rm -rf /tmp/backup_${TIMESTAMP}

# Comprimir backup
echo -e "\n${YELLOW}Comprimiendo backup...${NC}"
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)

# Limpiar backups antiguos
echo -e "\n${YELLOW}Limpiando backups antiguos (mayores a $RETENTION_DAYS días)...${NC}"
find "$BACKUP_DIR" -name "mongodb_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete

# Contar backups restantes
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "mongodb_backup_*.tar.gz" -type f | wc -l)

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Backup completado exitosamente${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\nArchivo: ${BACKUP_NAME}.tar.gz"
echo -e "Tamaño: $BACKUP_SIZE"
echo -e "Ubicación: $BACKUP_DIR"
echo -e "Backups totales: $BACKUP_COUNT"

echo -e "\n${YELLOW}Para restaurar este backup, ejecute:${NC}"
echo "./restore-mongodb.sh ${BACKUP_NAME}.tar.gz"

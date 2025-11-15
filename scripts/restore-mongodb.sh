#!/bin/bash

###############################################################################
# Script de restauración de MongoDB
# Restaura un backup de MongoDB
###############################################################################

set -e

echo "========================================="
echo "Restauración de MongoDB"
echo "========================================="

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuración
BACKUP_DIR="${BACKUP_DIR:-/home/$(whoami)/mongodb-backups}"
NAMESPACE="mongodb"
POD_NAME="mongodb-0"

# Verificar argumento
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: Debe especificar el archivo de backup${NC}"
    echo "Uso: $0 <archivo_backup.tar.gz>"
    echo ""
    echo "Backups disponibles:"
    ls -lh "$BACKUP_DIR"/mongodb_backup_*.tar.gz 2>/dev/null || echo "No hay backups disponibles"
    exit 1
fi

BACKUP_FILE="$1"

# Si no es una ruta completa, buscar en BACKUP_DIR
if [[ ! "$BACKUP_FILE" = /* ]]; then
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
fi

# Verificar que el archivo existe
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Archivo de backup no encontrado: $BACKUP_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}Archivo de backup: $BACKUP_FILE${NC}"

# Advertencia
echo -e "\n${RED}ADVERTENCIA: Esta operación sobrescribirá los datos actuales de MongoDB${NC}"
read -p "¿Está seguro de que desea continuar? (escriba 'SI' para confirmar): " CONFIRM

if [ "$CONFIRM" != "SI" ]; then
    echo "Operación cancelada"
    exit 0
fi

# Verificar que el pod existe
if ! kubectl get pod $POD_NAME -n $NAMESPACE &> /dev/null; then
    echo -e "${RED}Error: Pod $POD_NAME no encontrado en namespace $NAMESPACE${NC}"
    exit 1
fi

# Obtener credenciales
MONGO_USER=$(kubectl get secret mongodb-secret -n $NAMESPACE -o jsonpath='{.data.username}' | base64 -d)
MONGO_PASS=$(kubectl get secret mongodb-secret -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d)

# Crear directorio temporal
TEMP_DIR=$(mktemp -d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "\n${YELLOW}Descomprimiendo backup...${NC}"
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Encontrar el directorio del backup
BACKUP_EXTRACT_DIR=$(find "$TEMP_DIR" -type d -name "mongodb_backup_*" | head -1)

if [ -z "$BACKUP_EXTRACT_DIR" ]; then
    echo -e "${RED}Error: No se pudo encontrar el directorio del backup${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "\n${YELLOW}Copiando backup al pod...${NC}"
kubectl cp "$BACKUP_EXTRACT_DIR" $NAMESPACE/$POD_NAME:/tmp/restore_${TIMESTAMP}

echo -e "\n${YELLOW}Restaurando backup con mongorestore...${NC}"
kubectl exec $POD_NAME -n $NAMESPACE -- mongorestore \
    --username="$MONGO_USER" \
    --password="$MONGO_PASS" \
    --authenticationDatabase=admin \
    --drop \
    /tmp/restore_${TIMESTAMP}

# Limpiar archivos temporales
echo -e "\n${YELLOW}Limpiando archivos temporales...${NC}"
kubectl exec $POD_NAME -n $NAMESPACE -- rm -rf /tmp/restore_${TIMESTAMP}
rm -rf "$TEMP_DIR"

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Restauración completada exitosamente${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${YELLOW}Verificando estado de MongoDB...${NC}"
kubectl exec $POD_NAME -n $NAMESPACE -- mongosh \
    --username="$MONGO_USER" \
    --password="$MONGO_PASS" \
    --authenticationDatabase=admin \
    --eval "db.adminCommand({ listDatabases: 1 })"

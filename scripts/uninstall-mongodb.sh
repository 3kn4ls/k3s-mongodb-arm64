#!/bin/bash

###############################################################################
# Script para desinstalar MongoDB de K3s
###############################################################################

set -e

echo "========================================="
echo "Desinstalación de MongoDB"
echo "========================================="

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Advertencia
echo -e "${RED}ADVERTENCIA: Esta acción eliminará todos los datos de MongoDB${NC}"
read -p "¿Está seguro de que desea continuar? (escriba 'SI' para confirmar): " CONFIRM

if [ "$CONFIRM" != "SI" ]; then
    echo "Operación cancelada"
    exit 0
fi

echo -e "\n${YELLOW}Eliminando recursos de MongoDB...${NC}"

# Eliminar StatefulSet
echo "Eliminando StatefulSet..."
kubectl delete statefulset mongodb -n mongodb --ignore-not-found=true

# Eliminar Services
echo "Eliminando Services..."
kubectl delete svc mongodb-service mongodb-external -n mongodb --ignore-not-found=true

# Eliminar ConfigMap
echo "Eliminando ConfigMap..."
kubectl delete configmap mongodb-config -n mongodb --ignore-not-found=true

# Eliminar Secret
echo "Eliminando Secret..."
kubectl delete secret mongodb-secret -n mongodb --ignore-not-found=true

# Preguntar si eliminar PVCs (datos)
read -p "¿Desea eliminar los PersistentVolumeClaims (datos)? (s/n): " DELETE_PVC
if [[ $DELETE_PVC =~ ^[Ss]$ ]]; then
    echo "Eliminando PVCs..."
    kubectl delete pvc -l app=mongodb -n mongodb --ignore-not-found=true
    echo -e "${RED}Datos eliminados${NC}"
else
    echo -e "${YELLOW}PVCs preservados. Los datos se mantendrán.${NC}"
fi

# Preguntar si eliminar namespace
read -p "¿Desea eliminar el namespace 'mongodb'? (s/n): " DELETE_NS
if [[ $DELETE_NS =~ ^[Ss]$ ]]; then
    echo "Eliminando namespace..."
    kubectl delete namespace mongodb --ignore-not-found=true
    echo -e "${GREEN}Namespace eliminado${NC}"
else
    echo -e "${YELLOW}Namespace preservado${NC}"
fi

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Desinstalación completada${NC}"
echo -e "${GREEN}=========================================${NC}"

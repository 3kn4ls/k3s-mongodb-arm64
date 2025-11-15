#!/bin/bash

###############################################################################
# Script de despliegue de MongoDB en K3s
# Para Raspberry Pi 5 (ARM64)
###############################################################################

set -e

echo "========================================="
echo "Despliegue de MongoDB en K3s"
echo "========================================="

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directorio base del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_DIR/k8s"

# Verificar que kubectl está disponible
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl no está instalado${NC}"
    exit 1
fi

# Verificar que el cluster está disponible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: No se puede conectar al cluster de Kubernetes${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Cluster de Kubernetes disponible${NC}"

# Paso 1: Crear namespace
echo -e "\n${BLUE}[1/6] Creando namespace...${NC}"
kubectl apply -f "$K8S_DIR/mongodb/namespace.yaml"
echo -e "${GREEN}✓ Namespace creado${NC}"

# Paso 2: Crear StorageClass
echo -e "\n${BLUE}[2/6] Creando StorageClass...${NC}"
kubectl apply -f "$K8S_DIR/storage/storageclass.yaml"
echo -e "${GREEN}✓ StorageClass creado${NC}"

# Paso 3: Crear Secret
echo -e "\n${BLUE}[3/6] Creando Secret...${NC}"
if [ -f "$K8S_DIR/secrets/secret.yaml" ]; then
    kubectl apply -f "$K8S_DIR/secrets/secret.yaml"
    echo -e "${GREEN}✓ Secret creado desde archivo${NC}"
else
    echo -e "${YELLOW}No se encontró secret.yaml, creando secret con valores por defecto${NC}"
    echo -e "${RED}ADVERTENCIA: Usar credenciales por defecto no es seguro en producción${NC}"

    kubectl create secret generic mongodb-secret \
        --from-literal=username=admin \
        --from-literal=password=changeme \
        --from-literal=connection-string=mongodb://admin:changeme@mongodb-service.mongodb.svc.cluster.local:27017 \
        --namespace=mongodb \
        --dry-run=client -o yaml | kubectl apply -f -

    echo -e "${YELLOW}Secret creado con credenciales por defecto${NC}"
    echo -e "${YELLOW}Usuario: admin, Contraseña: changeme${NC}"
fi

# Paso 4: Crear ConfigMap
echo -e "\n${BLUE}[4/6] Creando ConfigMap...${NC}"
kubectl apply -f "$K8S_DIR/mongodb/configmap.yaml"
echo -e "${GREEN}✓ ConfigMap creado${NC}"

# Paso 5: Crear Services
echo -e "\n${BLUE}[5/6] Creando Services...${NC}"
kubectl apply -f "$K8S_DIR/mongodb/service.yaml"
echo -e "${GREEN}✓ Services creados${NC}"

# Paso 6: Crear StatefulSet
echo -e "\n${BLUE}[6/6] Creando StatefulSet de MongoDB...${NC}"
kubectl apply -f "$K8S_DIR/mongodb/statefulset.yaml"
echo -e "${GREEN}✓ StatefulSet creado${NC}"

# Esperar a que el pod esté listo
echo -e "\n${YELLOW}Esperando a que MongoDB esté listo...${NC}"
echo "Esto puede tomar varios minutos..."

kubectl wait --for=condition=ready pod \
    -l app=mongodb \
    -n mongodb \
    --timeout=300s || true

# Verificar el estado
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Despliegue completado${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${BLUE}Estado de los recursos:${NC}"
echo -e "\n${YELLOW}Pods:${NC}"
kubectl get pods -n mongodb

echo -e "\n${YELLOW}Services:${NC}"
kubectl get svc -n mongodb

echo -e "\n${YELLOW}PersistentVolumeClaims:${NC}"
kubectl get pvc -n mongodb

echo -e "\n${YELLOW}StatefulSets:${NC}"
kubectl get statefulset -n mongodb

# Obtener información de conexión
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Información de conexión${NC}"
echo -e "${GREEN}=========================================${NC}"

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NODE_PORT=$(kubectl get svc mongodb-external -n mongodb -o jsonpath='{.spec.ports[0].nodePort}')

echo -e "\n${YELLOW}Conexión interna (desde el cluster):${NC}"
echo "mongodb://admin:PASSWORD@mongodb-service.mongodb.svc.cluster.local:27017"

echo -e "\n${YELLOW}Conexión externa (desde fuera del cluster):${NC}"
echo "mongodb://admin:PASSWORD@${NODE_IP}:${NODE_PORT}"

echo -e "\n${YELLOW}Para obtener la contraseña:${NC}"
echo "kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.password}' | base64 -d"

echo -e "\n${YELLOW}Comandos útiles:${NC}"
echo "# Ver logs de MongoDB:"
echo "kubectl logs -f mongodb-0 -n mongodb"
echo ""
echo "# Conectar a MongoDB:"
echo "kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p"
echo ""
echo "# Verificar estado:"
echo "kubectl get all -n mongodb"

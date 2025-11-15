#!/bin/bash

###############################################################################
# Script de monitoreo de MongoDB
# Muestra estadísticas y estado del despliegue
###############################################################################

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="mongodb"
POD_NAME="mongodb-0"

clear
echo "========================================="
echo "Monitor de MongoDB en K3s"
echo "========================================="

# Función para mostrar estado de recursos
show_resources() {
    echo -e "\n${BLUE}=== Estado de Recursos K8s ===${NC}"

    echo -e "\n${YELLOW}Pods:${NC}"
    kubectl get pods -n $NAMESPACE -o wide

    echo -e "\n${YELLOW}Services:${NC}"
    kubectl get svc -n $NAMESPACE

    echo -e "\n${YELLOW}PersistentVolumeClaims:${NC}"
    kubectl get pvc -n $NAMESPACE

    echo -e "\n${YELLOW}StatefulSet:${NC}"
    kubectl get statefulset -n $NAMESPACE
}

# Función para mostrar uso de recursos
show_resource_usage() {
    echo -e "\n${BLUE}=== Uso de Recursos del Pod ===${NC}"

    if kubectl get pod $POD_NAME -n $NAMESPACE &> /dev/null; then
        kubectl top pod $POD_NAME -n $NAMESPACE 2>/dev/null || echo "Metrics server no disponible"
    else
        echo -e "${RED}Pod no encontrado${NC}"
    fi
}

# Función para mostrar estadísticas de MongoDB
show_mongo_stats() {
    echo -e "\n${BLUE}=== Estadísticas de MongoDB ===${NC}"

    if ! kubectl get pod $POD_NAME -n $NAMESPACE &> /dev/null; then
        echo -e "${RED}Pod no encontrado${NC}"
        return
    fi

    # Obtener credenciales
    MONGO_USER=$(kubectl get secret mongodb-secret -n $NAMESPACE -o jsonpath='{.data.username}' | base64 -d 2>/dev/null)
    MONGO_PASS=$(kubectl get secret mongodb-secret -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d 2>/dev/null)

    if [ -z "$MONGO_USER" ] || [ -z "$MONGO_PASS" ]; then
        echo -e "${RED}No se pudieron obtener las credenciales${NC}"
        return
    fi

    echo -e "\n${YELLOW}Bases de datos:${NC}"
    kubectl exec $POD_NAME -n $NAMESPACE -- mongosh \
        --username="$MONGO_USER" \
        --password="$MONGO_PASS" \
        --authenticationDatabase=admin \
        --quiet \
        --eval "db.adminCommand({ listDatabases: 1 }).databases.forEach(function(db) { print(db.name + ': ' + (db.sizeOnDisk / 1024 / 1024).toFixed(2) + ' MB'); })" \
        2>/dev/null || echo "Error al obtener bases de datos"

    echo -e "\n${YELLOW}Conexiones activas:${NC}"
    kubectl exec $POD_NAME -n $NAMESPACE -- mongosh \
        --username="$MONGO_USER" \
        --password="$MONGO_PASS" \
        --authenticationDatabase=admin \
        --quiet \
        --eval "db.serverStatus().connections" \
        2>/dev/null || echo "Error al obtener conexiones"

    echo -e "\n${YELLOW}Estado del servidor:${NC}"
    kubectl exec $POD_NAME -n $NAMESPACE -- mongosh \
        --username="$MONGO_USER" \
        --password="$MONGO_PASS" \
        --authenticationDatabase=admin \
        --quiet \
        --eval "db.serverStatus().uptime" \
        2>/dev/null | awk '{printf "Uptime: %.0f segundos (%.2f horas)\n", $0, $0/3600}' || echo "Error al obtener uptime"
}

# Función para mostrar logs recientes
show_recent_logs() {
    echo -e "\n${BLUE}=== Logs Recientes ===${NC}"

    if kubectl get pod $POD_NAME -n $NAMESPACE &> /dev/null; then
        kubectl logs --tail=10 $POD_NAME -n $NAMESPACE
    else
        echo -e "${RED}Pod no encontrado${NC}"
    fi
}

# Función para mostrar información de conexión
show_connection_info() {
    echo -e "\n${BLUE}=== Información de Conexión ===${NC}"

    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    NODE_PORT=$(kubectl get svc mongodb-external -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

    echo -e "\n${YELLOW}Conexión interna (desde el cluster):${NC}"
    echo "mongodb://USER:PASSWORD@mongodb-service.mongodb.svc.cluster.local:27017"

    echo -e "\n${YELLOW}Conexión externa (desde fuera del cluster):${NC}"
    echo "mongodb://USER:PASSWORD@${NODE_IP}:${NODE_PORT}"

    echo -e "\n${YELLOW}Para obtener las credenciales:${NC}"
    echo "Usuario: kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.username}' | base64 -d"
    echo "Password: kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.password}' | base64 -d"
}

# Modo interactivo
if [ "$1" == "--watch" ]; then
    while true; do
        clear
        echo "========================================="
        echo "Monitor de MongoDB en K3s (Auto-refresh)"
        echo "========================================="
        show_resources
        show_resource_usage
        show_mongo_stats
        echo -e "\n${YELLOW}Actualizando en 5 segundos... (Ctrl+C para salir)${NC}"
        sleep 5
    done
else
    show_resources
    show_resource_usage
    show_mongo_stats
    show_recent_logs
    show_connection_info

    echo -e "\n${YELLOW}Comandos útiles:${NC}"
    echo "# Monitoreo continuo:"
    echo "$0 --watch"
    echo ""
    echo "# Ver logs en tiempo real:"
    echo "kubectl logs -f $POD_NAME -n $NAMESPACE"
    echo ""
    echo "# Conectar a MongoDB:"
    echo "kubectl exec -it $POD_NAME -n $NAMESPACE -- mongosh -u admin -p"
fi

#!/bin/bash

###############################################################################
# Script para generar secrets de MongoDB
###############################################################################

set -e

echo "========================================="
echo "Generador de Secrets para MongoDB"
echo "========================================="

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Generar contraseña aleatoria segura
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Solicitar información al usuario
echo -e "\n${YELLOW}Ingrese los datos para el secret de MongoDB:${NC}"

# Usuario
read -p "Usuario de MongoDB [admin]: " MONGO_USER
MONGO_USER=${MONGO_USER:-admin}

# Contraseña
read -p "¿Desea generar una contraseña aleatoria? (s/n) [s]: " GEN_PASS
GEN_PASS=${GEN_PASS:-s}

if [[ $GEN_PASS =~ ^[Ss]$ ]]; then
    MONGO_PASSWORD=$(generate_password)
    echo -e "${GREEN}Contraseña generada: $MONGO_PASSWORD${NC}"
    echo -e "${YELLOW}IMPORTANTE: Guarde esta contraseña en un lugar seguro${NC}"
else
    read -sp "Contraseña de MongoDB: " MONGO_PASSWORD
    echo
    read -sp "Confirmar contraseña: " MONGO_PASSWORD_CONFIRM
    echo

    if [ "$MONGO_PASSWORD" != "$MONGO_PASSWORD_CONFIRM" ]; then
        echo "Error: Las contraseñas no coinciden"
        exit 1
    fi
fi

# Generar connection string
CONN_STRING="mongodb://${MONGO_USER}:${MONGO_PASSWORD}@mongodb-service.mongodb.svc.cluster.local:27017"

# Crear archivo de secret
SECRET_FILE="../k8s/secrets/secret.yaml"

cat > $SECRET_FILE << EOF
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
  namespace: mongodb
type: Opaque
stringData:
  username: ${MONGO_USER}
  password: ${MONGO_PASSWORD}
  connection-string: ${CONN_STRING}
EOF

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Secret creado correctamente${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\nArchivo: ${SECRET_FILE}"
echo -e "\nPara aplicar el secret, ejecute:"
echo -e "${YELLOW}kubectl apply -f ${SECRET_FILE}${NC}"
echo -e "\n${YELLOW}IMPORTANTE: No versionar este archivo en git${NC}"

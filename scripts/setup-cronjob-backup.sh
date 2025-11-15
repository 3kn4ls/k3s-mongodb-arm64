#!/bin/bash

###############################################################################
# Script para configurar backups automáticos con CronJob
###############################################################################

set -e

echo "========================================="
echo "Configuración de Backups Automáticos"
echo "========================================="

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\n${YELLOW}Configurando crontab para backups automáticos...${NC}"

# Crear entrada de crontab
CRON_CMD="0 2 * * * $SCRIPT_DIR/backup-mongodb.sh >> /var/log/mongodb-backup.log 2>&1"

# Verificar si ya existe
if crontab -l 2>/dev/null | grep -q "backup-mongodb.sh"; then
    echo -e "${YELLOW}Ya existe una tarea de backup configurada${NC}"
    read -p "¿Desea reemplazarla? (s/n): " REPLACE
    if [[ ! $REPLACE =~ ^[Ss]$ ]]; then
        echo "Operación cancelada"
        exit 0
    fi
    # Eliminar entrada existente
    crontab -l 2>/dev/null | grep -v "backup-mongodb.sh" | crontab -
fi

# Agregar nueva entrada
(crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -

echo -e "${GREEN}✓ Crontab configurado${NC}"
echo -e "\nLos backups se ejecutarán diariamente a las 2:00 AM"
echo -e "\nPara ver el crontab:"
echo "crontab -l"
echo -e "\nPara ver logs de backup:"
echo "tail -f /var/log/mongodb-backup.log"

# Crear directorio de logs
sudo touch /var/log/mongodb-backup.log
sudo chmod 666 /var/log/mongodb-backup.log

echo -e "\n${GREEN}Configuración completada${NC}"

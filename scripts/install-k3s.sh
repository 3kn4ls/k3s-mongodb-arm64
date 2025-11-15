#!/bin/bash

###############################################################################
# Script de instalación de K3s en Raspberry Pi 5
# Optimizado para ARM64
###############################################################################

set -e

echo "========================================="
echo "Instalación de K3s en Raspberry Pi 5"
echo "========================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que se está ejecutando en Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo -e "${YELLOW}Advertencia: Este sistema no parece ser una Raspberry Pi${NC}"
    read -p "¿Desea continuar de todos modos? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Verificar arquitectura ARM64
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    echo -e "${RED}Error: Este script requiere arquitectura ARM64${NC}"
    echo "Arquitectura detectada: $ARCH"
    exit 1
fi

echo -e "${GREEN}✓ Arquitectura ARM64 detectada${NC}"

# Actualizar el sistema
echo -e "\n${YELLOW}Actualizando el sistema...${NC}"
sudo apt-get update
sudo apt-get upgrade -y

# Instalar dependencias necesarias
echo -e "\n${YELLOW}Instalando dependencias...${NC}"
sudo apt-get install -y \
    curl \
    wget \
    git \
    htop \
    iotop \
    ca-certificates \
    gnupg \
    lsb-release

# Configurar cgroups (necesario para Kubernetes)
echo -e "\n${YELLOW}Configurando cgroups...${NC}"
if ! grep -q "cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" /boot/firmware/cmdline.txt; then
    sudo sed -i '$ s/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt
    echo -e "${GREEN}✓ Cgroups configurados (requiere reinicio)${NC}"
    REQUIRES_REBOOT=true
else
    echo -e "${GREEN}✓ Cgroups ya configurados${NC}"
fi

# Descargar e instalar K3s
echo -e "\n${YELLOW}Descargando e instalando K3s...${NC}"

# Variables de configuración
export INSTALL_K3S_EXEC="--disable traefik --disable servicelb --write-kubeconfig-mode 644"

# Instalar K3s
curl -sfL https://get.k3s.io | sh -s - server \
    --disable traefik \
    --disable servicelb \
    --write-kubeconfig-mode 644 \
    --node-name raspberrypi5

# Esperar a que K3s esté listo
echo -e "\n${YELLOW}Esperando a que K3s esté listo...${NC}"
sleep 10

# Verificar instalación
if sudo k3s kubectl get nodes; then
    echo -e "${GREEN}✓ K3s instalado correctamente${NC}"
else
    echo -e "${RED}✗ Error en la instalación de K3s${NC}"
    exit 1
fi

# Configurar kubectl para usuario actual
echo -e "\n${YELLOW}Configurando kubectl...${NC}"
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
chmod 600 $HOME/.kube/config

# Agregar alias útiles
if ! grep -q "alias k=kubectl" ~/.bashrc; then
    echo "alias k=kubectl" >> ~/.bashrc
    echo "alias kgp='kubectl get pods'" >> ~/.bashrc
    echo "alias kgs='kubectl get svc'" >> ~/.bashrc
    echo "alias kgn='kubectl get nodes'" >> ~/.bashrc
    echo -e "${GREEN}✓ Alias de kubectl agregados a ~/.bashrc${NC}"
fi

# Verificar que kubectl funciona sin sudo
if kubectl get nodes; then
    echo -e "${GREEN}✓ kubectl configurado correctamente${NC}"
else
    echo -e "${RED}✗ Error en la configuración de kubectl${NC}"
    exit 1
fi

# Mostrar información del cluster
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}K3s instalado correctamente${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\nInformación del cluster:"
kubectl get nodes -o wide

echo -e "\n${YELLOW}Versión de K3s:${NC}"
k3s --version

if [ "$REQUIRES_REBOOT" = true ]; then
    echo -e "\n${RED}=========================================${NC}"
    echo -e "${RED}IMPORTANTE: Se requiere reiniciar el sistema${NC}"
    echo -e "${RED}para aplicar la configuración de cgroups${NC}"
    echo -e "${RED}=========================================${NC}"
    echo -e "\nEjecuta: ${YELLOW}sudo reboot${NC}"
fi

echo -e "\n${GREEN}Siguientes pasos:${NC}"
echo "1. Si se requiere reiniciar, ejecuta: sudo reboot"
echo "2. Después del reinicio, ejecuta: ./deploy-mongodb.sh"
echo "3. Para verificar el cluster: kubectl get nodes"

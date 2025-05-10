#!/bin/bash
# Script para destruir la infraestructura de la Fase 2

set -e

# Colores para la salida
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directorio base
BASE_DIR="infra/phase2"

echo -e "${YELLOW}Iniciando destrucción de la infraestructura de la Fase 2${NC}"

# Verificar que Terraform está instalado
if ! command -v terraform &> /dev/null
then
    echo -e "${RED}Terraform no está instalado. Por favor instálelo primero.${NC}"
    exit 1
fi

# Ir al directorio de la fase 2
cd "$BASE_DIR" || exit 1

# Confirmar la destrucción
echo -e "${RED}¡ADVERTENCIA! Esta acción eliminará toda la infraestructura de la Fase 2.${NC}"
echo -e "${RED}Esto incluye el Auto Scaling Group, Load Balancer, RDS, EFS y todos los recursos asociados.${NC}"
echo -e "${RED}Los datos almacenados en RDS y EFS se perderán.${NC}"
echo -e "${YELLOW}¿Está seguro de que desea continuar? (s/n)${NC}"
read -r confirmation
if [[ "$confirmation" != "s" ]]
then
    echo -e "${GREEN}Destrucción cancelada.${NC}"
    exit 0
fi

# Destruir la infraestructura
echo -e "${YELLOW}Destruyendo la infraestructura...${NC}"
terraform destroy -auto-approve

echo -e "${GREEN}¡Infraestructura de la Fase 2 destruida correctamente!${NC}"

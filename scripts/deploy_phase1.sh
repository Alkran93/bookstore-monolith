#!/bin/bash

# Variables de configuración
STACK_NAME="bookstore-monolith-phase1"
TEMPLATE_FILE="infra/phase1.yaml"
KEY_NAME="bookstore-key"
REGION="us-east-1"

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Comenzando despliegue de BookStore - Fase 1${NC}"

# Verificar que el archivo de template existe
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}Error: No se encuentra el archivo de template CloudFormation ($TEMPLATE_FILE)${NC}"
    exit 1
fi

# Crear el stack de CloudFormation
echo -e "${YELLOW}Creando stack de CloudFormation: $STACK_NAME${NC}"
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters ParameterKey=KeyName,ParameterValue=$KEY_NAME \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Esperar a que el stack se complete
echo -e "${YELLOW}Esperando a que el stack se complete...${NC}"
aws cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME \
    --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Stack creado exitosamente!${NC}"
    
    # Obtener outputs del stack
    INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" --output text --region $REGION)
    PUBLIC_DNS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PublicDNS'].OutputValue" --output text --region $REGION)
    PUBLIC_IP=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" --output text --region $REGION)
    
    echo -e "${GREEN}Información de la instancia:${NC}"
    echo -e "Instance ID: ${YELLOW}$INSTANCE_ID${NC}"
    echo -e "Public DNS: ${YELLOW}$PUBLIC_DNS${NC}"
    echo -e "Public IP: ${YELLOW}$PUBLIC_IP${NC}"
    
    echo -e "\n${YELLOW}Próximos pasos:${NC}"
    echo -e "1. Actualiza los registros DNS en Hostinger para apuntar a la IP: ${YELLOW}$PUBLIC_IP${NC}"
    echo -e "2. Espera unos minutos para que la instancia complete su configuración"
    echo -e "3. Conéctate a la instancia y configura el certificado SSL con: ${YELLOW}sudo certbot --nginx -d proyecto2.shop -d www.proyecto2.shop${NC}"
    echo -e "4. Verifica el despliegue con: ${YELLOW}curl -vk https://proyecto2.shop${NC}"
else
    echo -e "${RED}Error al crear el stack. Revise la consola de AWS para más detalles.${NC}"
    exit 1
fi

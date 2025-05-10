#!/bin/bash
# Script para desplegar la Fase 2 (Escalado del monolito)

set -e

# Colores para la salida
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directorio base
BASE_DIR="infra/phase2"

echo -e "${YELLOW}Iniciando despliegue de la Fase 2: Escalado del monolito${NC}"

# Verificar que Terraform está instalado
if ! command -v terraform &> /dev/null
then
    echo -e "${RED}Terraform no está instalado. Por favor instálelo primero.${NC}"
    exit 1
fi

# Verificar que AWS CLI está instalado
if ! command -v aws &> /dev/null
then
    echo -e "${RED}AWS CLI no está instalado. Por favor instálelo primero.${NC}"
    exit 1
fi

# Verificar que la variable AWS_PROFILE está configurada o que hay credenciales por defecto
if [ -z "$AWS_PROFILE" ] && [ -z "$AWS_ACCESS_KEY_ID" ]
then
    echo -e "${YELLOW}AWS_PROFILE o credenciales por defecto no detectadas. Asegúrese de tener configurado el acceso a AWS.${NC}"
    echo -e "${YELLOW}Continuar? (s/n)${NC}"
    read -r response
    if [[ "$response" != "s" ]]
    then
        exit 1
    fi
fi

# Ir al directorio de la fase 2
cd "$BASE_DIR" || exit 1

# Solicitar valores para las variables de Terraform
echo -e "${YELLOW}Por favor, proporcione los siguientes valores (presione Enter para usar el valor por defecto):${NC}"

read -p "VPC ID: " vpc_id
# Ya no necesitamos el certificado ARN
read -p "Nombre del Key Pair SSH: " ssh_key_name
read -p "Contraseña para la base de datos: " db_password

# Actualizar terraform.tfvars con los valores proporcionados
if [ -n "$vpc_id" ]; then
    sed -i "s/vpc_id *= *\"vpc-xxxxxxxx\"/vpc_id = \"$vpc_id\"/" terraform.tfvars
fi

# Ya no necesitamos modificar el certificado ARN

if [ -n "$ssh_key_name" ]; then
    sed -i "s/ssh_key_name *= *\"bookstore-key\"/ssh_key_name = \"$ssh_key_name\"/" terraform.tfvars
fi

if [ -n "$db_password" ]; then
    sed -i "s/db_password *= *\"YourStrongPassword123!\"/db_password = \"$db_password\"/" terraform.tfvars
fi

# Inicializar Terraform
echo -e "${YELLOW}Inicializando Terraform...${NC}"
terraform init

# Validar configuración
echo -e "${YELLOW}Validando configuración de Terraform...${NC}"
terraform validate

# Plan de Terraform
echo -e "${YELLOW}Generando plan de Terraform...${NC}"
terraform plan -out=tfplan

# Confirmar el despliegue
echo -e "${YELLOW}¿Desea proceder con el despliegue? (s/n)${NC}"
read -r confirmation
if [[ "$confirmation" != "s" ]]
then
    echo -e "${RED}Despliegue cancelado.${NC}"
    exit 0
fi

# Aplicar el plan
echo -e "${YELLOW}Aplicando la infraestructura...${NC}"
terraform apply tfplan

# Mostrar salidas
echo -e "${GREEN}Infraestructura desplegada correctamente.${NC}"
echo -e "${GREEN}Outputs:${NC}"
terraform output

# Instrucciones para validar el despliegue
echo -e "\n${GREEN}=== Instrucciones para validar el despliegue ===${NC}"
echo -e "1. Verificar el estado del Auto Scaling Group y las instancias EC2:"
echo -e "   ${YELLOW}aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name \$(terraform output -raw autoscaling_group_name)${NC}"
echo -e "2. Verificar que el Application Load Balancer esté funcionando:"
echo -e "   ${YELLOW}curl -k https://\$(terraform output -raw alb_dns_name)${NC}"
echo -e "3. Verificar la configuración de DNS (si ya configuró el dominio):"
echo -e "   ${YELLOW}curl -k https://\$(terraform output -raw website_url)${NC}"
echo -e "4. Para probar el Auto Scaling, puede generar carga en las instancias:"
echo -e "   ${YELLOW}# Ejemplo usando ab (Apache Benchmark) o herramientas similares${NC}"
echo -e "   ${YELLOW}ab -n 1000 -c 100 https://\$(terraform output -raw alb_dns_name)/${NC}"
echo -e "5. Verificar las métricas de CloudWatch para el Auto Scaling Group:"
echo -e "   ${YELLOW}aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization \
--dimensions Name=AutoScalingGroupName,Value=\$(terraform output -raw autoscaling_group_name) \
--start-time \$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%S) --end-time \$(date -u +%Y-%m-%dT%H:%M:%S) \
--period 300 --statistics Average${NC}"

echo -e "\n${GREEN}¡Despliegue de la Fase 2 completado!${NC}"

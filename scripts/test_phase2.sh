#!/bin/bash
# Script para probar la infraestructura de la Fase 2

set -e

# Colores para la salida
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directorio base
BASE_DIR="infra/phase2"

echo -e "${YELLOW}Iniciando pruebas de la infraestructura de la Fase 2${NC}"

# Verificar que AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI no está instalado. Por favor instálelo primero.${NC}"
    exit 1
fi

# Ir al directorio de la fase 2
cd "$BASE_DIR" || exit 1

# Obtener outputs de Terraform
echo -e "${YELLOW}Obteniendo información de la infraestructura desplegada...${NC}"
alb_dns_name=$(terraform output -raw alb_dns_name)
autoscaling_group_name=$(terraform output -raw autoscaling_group_name)

# Verificar el estado del Auto Scaling Group
echo -e "${YELLOW}Verificando el Auto Scaling Group...${NC}"
asg_info=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name "$autoscaling_group_name")
instance_count=$(echo "$asg_info" | jq '.AutoScalingGroups[0].Instances | length')

echo -e "${GREEN}Auto Scaling Group: $autoscaling_group_name${NC}"
echo -e "${GREEN}Instancias en ejecución: $instance_count${NC}"

# Verificar las instancias EC2
echo -e "${YELLOW}Verificando instancias EC2...${NC}"
instances=$(echo "$asg_info" | jq -r '.AutoScalingGroups[0].Instances[].InstanceId')

for instance_id in $instances; do
    instance_info=$(aws ec2 describe-instances --instance-ids "$instance_id")
    instance_state=$(echo "$instance_info" | jq -r '.Reservations[0].Instances[0].State.Name')
    instance_ip=$(echo "$instance_info" | jq -r '.Reservations[0].Instances[0].PublicIpAddress')
    
    echo -e "${GREEN}Instancia ID: $instance_id, Estado: $instance_state, IP: $instance_ip${NC}"
done

# Verificar el estado del Application Load Balancer
echo -e "${YELLOW}Verificando el Application Load Balancer...${NC}"
echo -e "${GREEN}ALB DNS: $alb_dns_name${NC}"

# Probar la accesibilidad del sitio web
echo -e "${YELLOW}Probando accesibilidad del sitio web...${NC}"
http_status=$(curl -s -o /dev/null -w "%{http_code}" "http://$alb_dns_name")

if [ "$http_status" -eq 200 ] || [ "$http_status" -eq 302 ]; then
    echo -e "${GREEN}¡El sitio web está accesible! (Código HTTP: $http_status)${NC}"
else
    echo -e "${RED}¡Error! El sitio web no está accesible. (Código HTTP: $http_status)${NC}"
    echo -e "${YELLOW}Verifique los logs de las instancias EC2 para detectar posibles problemas.${NC}"
fi

# Verificar las métricas del Auto Scaling Group
echo -e "${YELLOW}Obteniendo métricas de CloudWatch para el Auto Scaling Group...${NC}"
start_time=$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%S)
end_time=$(date -u +%Y-%m-%dT%H:%M:%S)

metrics=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=AutoScalingGroupName,Value="$autoscaling_group_name" \
    --start-time "$start_time" \
    --end-time "$end_time" \
    --period 300 \
    --statistics Average)

datapoints_count=$(echo "$metrics" | jq '.Datapoints | length')

if [ "$datapoints_count" -gt 0 ]; then
    echo -e "${GREEN}Métricas de CPU disponibles:${NC}"
    echo "$metrics" | jq '.Datapoints[] | {Timestamp, Average}'
else
    echo -e "${YELLOW}No hay métricas de CPU disponibles aún. Espere unos minutos e intente nuevamente.${NC}"
fi

# Prueba de carga básica (requiere apache2-utils o httpd-tools)
echo -e "${YELLOW}¿Desea realizar una prueba de carga básica? (s/n)${NC}"
read -r loadtest_confirmation

if [[ "$loadtest_confirmation" == "s" ]]; then
    if ! command -v ab &> /dev/null; then
        echo -e "${YELLOW}Apache Benchmark (ab) no está instalado. Instalando...${NC}"
        if command -v yum &> /dev/null; then
            sudo yum install -y httpd-tools
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y apache2-utils
        else
            echo -e "${RED}No se pudo instalar ab automáticamente. Instálelo manualmente según su sistema operativo.${NC}"
            exit 1
        fi
    fi

    echo -e "${YELLOW}Realizando prueba de carga...${NC}"
    echo -e "${YELLOW}Enviando 1000 solicitudes, 50 concurrentes a http://$alb_dns_name/${NC}"
    
    ab -n 1000 -c 50 "http://$alb_dns_name/"
    
    echo -e "${GREEN}Prueba de carga completada.${NC}"
    echo -e "${YELLOW}Verifique las alarmas de Auto Scaling en la consola AWS para ver si se activaron.${NC}"
fi

echo -e "\n${GREEN}¡Pruebas de la Fase 2 completadas!${NC}"
echo -e "${GREEN}La aplicación está desplegada y accesible en: http://$alb_dns_name${NC}"


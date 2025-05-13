#!/bin/bash
set -e

# Este script debe ejecutarse después de que la infraestructura de la fase 2 esté desplegada
echo "Migrando datos desde la instancia MySQL local a RDS..."

# Obtener información de RDS
cd infra/phase2
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
RDS_HOST=$(echo $RDS_ENDPOINT | cut -d':' -f1)
DB_USER=$(grep -A1 "db_username" variables.tf | grep default | sed 's/.*"\(.*\)".*/\1/')
DB_PASSWORD=$(grep -A1 "db_password" variables.tf | grep default | sed 's/.*"\(.*\)".*/\1/')
cd ../..

# Obtener información de la instancia EC2 actual
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=BookStore-Monolith" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text)
EC2_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)
KEY_FILE="/home/cloudshell-user/bookstore-monolith/bookstore-key.pem"

echo "RDS Host: $RDS_HOST"
echo "EC2 IP: $EC2_IP"

# Instrucciones para la migración manualmente
echo "Ejecuta los siguientes comandos para migrar los datos:"
echo "1. Conéctate a tu instancia EC2:"
echo "   ssh -i $KEY_FILE ec2-user@$EC2_IP"
echo ""
echo "2. Exporta la base de datos desde el contenedor MySQL:"
echo "   sudo docker exec -i mysql mysqldump -uroot -pexample bookstore > /tmp/bookstore_dump.sql"
echo ""
echo "3. Descarga el dump a tu máquina local:"
echo "   scp -i $KEY_FILE ec2-user@$EC2_IP:/tmp/bookstore_dump.sql /tmp/bookstore_dump.sql"
echo ""
echo "4. Importa el dump a RDS:"
echo "   mysql -h $RDS_HOST -u $DB_USER -p$DB_PASSWORD bookstore < /tmp/bookstore_dump.sql"
echo ""
echo "También puedes instalar el cliente MySQL en las instancias del ASG e importar directamente desde ellas."

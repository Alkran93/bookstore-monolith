#!/bin/bash
# Script para obtener información de AWS necesaria para la configuración de Terraform

set -e

# Colores para la salida
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Obteniendo información de AWS para la configuración de Terraform...${NC}"

# Verificar que AWS CLI está instalado
if ! command -v aws &> /dev/null
then
    echo -e "${RED}AWS CLI no está instalado. Por favor instálelo primero.${NC}"
    exit 1
fi

# Verificar que jq está instalado (para parsear la salida JSON)
if ! command -v jq &> /dev/null
then
    echo -e "${YELLOW}jq no está instalado. Instalando...${NC}"
    sudo apt-get update && sudo apt-get install -y jq
fi

# Obtener VPCs disponibles
echo -e "${YELLOW}Obteniendo VPCs disponibles...${NC}"
vpcs=$(aws ec2 describe-vpcs)
vpc_count=$(echo "$vpcs" | jq '.Vpcs | length')

echo -e "${GREEN}Se encontraron $vpc_count VPCs:${NC}"
for i in $(seq 0 $(($vpc_count - 1))); do
    vpc_id=$(echo "$vpcs" | jq -r ".Vpcs[$i].VpcId")
    cidr=$(echo "$vpcs" | jq -r ".Vpcs[$i].CidrBlock")
    is_default=$(echo "$vpcs" | jq -r ".Vpcs[$i].IsDefault")
    
    echo -e "  ${GREEN}VPC ID:${NC} $vpc_id, ${GREEN}CIDR:${NC} $cidr, ${GREEN}Default:${NC} $is_default"
done

# Seleccionar VPC (por defecto, el primero)
default_vpc_id=$(echo "$vpcs" | jq -r '.Vpcs[0].VpcId')
echo -e "${YELLOW}Seleccione el VPC ID a utilizar [default: $default_vpc_id]:${NC}"
read -r selected_vpc_id
selected_vpc_id=${selected_vpc_id:-$default_vpc_id}

# Obtener subnets públicas para el VPC seleccionado
echo -e "${YELLOW}Obteniendo subnets para el VPC $selected_vpc_id...${NC}"
subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$selected_vpc_id")
subnet_count=$(echo "$subnets" | jq '.Subnets | length')

echo -e "${GREEN}Se encontraron $subnet_count subnets:${NC}"
public_subnets=()
for i in $(seq 0 $(($subnet_count - 1))); do
    subnet_id=$(echo "$subnets" | jq -r ".Subnets[$i].SubnetId")
    cidr=$(echo "$subnets" | jq -r ".Subnets[$i].CidrBlock")
    az=$(echo "$subnets" | jq -r ".Subnets[$i].AvailabilityZone")
    map_public_ip=$(echo "$subnets" | jq -r ".Subnets[$i].MapPublicIpOnLaunch")
    
    if [ "$map_public_ip" = "true" ]; then
        public_subnets+=("$subnet_id")
        public_status="SÍ"
    else
        public_status="NO"
    fi
    
    echo -e "  ${GREEN}Subnet ID:${NC} $subnet_id, ${GREEN}CIDR:${NC} $cidr, ${GREEN}AZ:${NC} $az, ${GREEN}Pública:${NC} $public_status"
done

# Verificar que tenemos al menos 2 subnets públicas para HA
if [ ${#public_subnets[@]} -lt 2 ]; then
    echo -e "${RED}¡Advertencia! Se requieren al menos 2 subnets públicas para alta disponibilidad.${NC}"
    if [ ${#public_subnets[@]} -eq 0 ]; then
        echo -e "${RED}No se encontraron subnets públicas. Por favor revise la configuración de su VPC.${NC}"
        exit 1
    fi
fi

# Obtener pares de claves disponibles
echo -e "${YELLOW}Obteniendo pares de claves disponibles...${NC}"
key_pairs=$(aws ec2 describe-key-pairs)
key_pair_count=$(echo "$key_pairs" | jq '.KeyPairs | length')

echo -e "${GREEN}Se encontraron $key_pair_count pares de claves:${NC}"
if [ "$key_pair_count" -gt 0 ]; then
    for i in $(seq 0 $(($key_pair_count - 1))); do
        key_name=$(echo "$key_pairs" | jq -r ".KeyPairs[$i].KeyName")
        echo -e "  ${GREEN}Key Name:${NC} $key_name"
    done
    
    # Seleccionar key pair (por defecto, el primero)
    default_key_name=$(echo "$key_pairs" | jq -r '.KeyPairs[0].KeyName')
    echo -e "${YELLOW}Seleccione el nombre del par de claves a utilizar [default: $default_key_name]:${NC}"
    read -r selected_key_name
    selected_key_name=${selected_key_name:-$default_key_name}
else
    echo -e "${RED}No se encontraron pares de claves. Se creará uno nuevo.${NC}"
    echo -e "${YELLOW}Ingrese el nombre para el nuevo par de claves:${NC}"
    read -r selected_key_name
    selected_key_name=${selected_key_name:-"bookstore-key"}
    
    # Crear par de claves
    echo -e "${YELLOW}Creando par de claves $selected_key_name...${NC}"
    key_file="$selected_key_name.pem"
    aws ec2 create-key-pair --key-name "$selected_key_name" --query 'KeyMaterial' --output text > "$key_file"
    chmod 400 "$key_file"
    echo -e "${GREEN}Par de claves $selected_key_name creado y guardado en $key_file${NC}"
fi

# Generar archivo tfvars
echo -e "${YELLOW}Generando archivo terraform.tfvars...${NC}"
cat > infra/phase2/terraform.tfvars <<EOL
aws_region        = "us-east-1"
project_name      = "bookstore"
environment       = "dev"
vpc_id            = "$selected_vpc_id"
use_ssl           = false
ssh_key_name      = "$selected_key_name"
instance_type     = "t2.micro"
db_instance_class = "db.t3.micro"
db_name           = "bookstore"
db_username       = "admin"
db_password       = "BookStore1234!" # Cambiar por una contraseña segura
min_size          = 2
max_size          = 4
desired_capacity  = 2
EOL

echo -e "${GREEN}Archivo terraform.tfvars generado en infra/phase2/terraform.tfvars${NC}"
echo -e "${YELLOW}Por favor, revise y actualice cualquier valor adicional según sea necesario.${NC}"
echo -e "${YELLOW}Especialmente considere cambiar la contraseña de la base de datos por motivos de seguridad.${NC}"

# Mostrar resumen
echo -e "\n${GREEN}=== Resumen de la configuración ===${NC}"
echo -e "${GREEN}VPC ID:${NC} $selected_vpc_id"
echo -e "${GREEN}Subnets públicas:${NC} ${public_subnets[*]}"
echo -e "${GREEN}Par de claves:${NC} $selected_key_name"
echo -e "\n${GREEN}¡Listo para continuar con el despliegue!${NC}"
echo -e "${YELLOW}Ejecute ./deploy_phase2.sh para iniciar el despliegue.${NC}"

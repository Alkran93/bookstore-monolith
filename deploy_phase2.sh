#!/bin/bash
set -e

echo "Desplegando la fase 2 del proyecto BookStore..."

# Verificar que los archivos de Terraform existen
if [ ! -d "infra/phase2" ]; then
    echo "El directorio infra/phase2 no existe. Por favor, verifica la estructura del proyecto."
    exit 1
fi

# Verificar si estás utilizando AWS Academy
echo "Verificando entorno AWS..."
if aws sts get-caller-identity | grep -q "lab-account"; then
    echo "Detectado entorno AWS Academy. Configurando tiempo de expiración..."
    # Configurar variables para AWS Lab
    export AWS_SESSION_TOKEN_EXPIRATION=$(date -d "+8 hours" +%s)
fi

# Guardar información sobre la AMI y el Key Pair
echo "Obteniendo la última AMI de Amazon Linux 2023..."
AMI_ID=$(aws ec2 describe-images     --owners amazon     --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available"     --query "sort_by(Images, &CreationDate)[-1].ImageId"     --output text)

echo "AMI ID seleccionada: $AMI_ID"

# Actualizar el valor de AMI_ID en variables.tf
cd infra/phase2
sed -i "s/default     = \"ami-.*\"/default     = \"$AMI_ID\"/" variables.tf

# Configurar tu key pair
KEY_NAME=$(aws ec2 describe-key-pairs --query "KeyPairs[0].KeyName" --output text)
echo "Key pair seleccionado: $KEY_NAME"
sed -i "s/default     = \"vockey\"/default     = \"$KEY_NAME\"/" variables.tf

# Inicializar Terraform
echo "Inicializando Terraform..."
terraform init

# Planificar el despliegue
echo "Planificando el despliegue..."
terraform plan -out=tfplan

# Aplicar los cambios
echo "Aplicando cambios. Esto puede tardar varios minutos..."
terraform apply tfplan

# Mostrar las salidas
echo "Despliegue completado. Información de la infraestructura:"
terraform output

# Instrucciones para la validación
echo ""
echo "Para validar que el despliegue funciona correctamente, puedes ejecutar los siguientes comandos:"
echo "curl -v https://$(terraform output -raw load_balancer_dns)"
echo ""
echo "Para monitorear el Auto Scaling Group, puedes visitar la consola de AWS o ejecutar:"
echo "aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $(terraform output -raw autoscaling_group_name)"
echo ""


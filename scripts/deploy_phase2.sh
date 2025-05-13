#!/bin/bash
set -e

echo "Desplegando la fase 2 del proyecto BookStore..."

# Verificar que existan los archivos de Terraform
if [ ! -d "infra/phase2" ]; then
    echo "El directorio infra/phase2 no existe. Por favor, verifica la estructura del proyecto."
    exit 1
fi

# Inicializar Terraform
cd infra/phase2
terraform init

# Planificar el despliegue
terraform plan -out=tfplan

# Desplegar
echo "Aplicando cambios. Esto puede tardar varios minutos..."
terraform apply tfplan

# Mostrar las salidas
echo "Despliegue completado. Información de la infraestructura:"
terraform output

# Instrucciones para la validación
echo ""
echo "Para validar que el despliegue funciona correctamente, puedes ejecutar los siguientes comandos:"
echo "curl -v https://$(terraform output -raw dns_name)"
echo ""
echo "Para monitorear el Auto Scaling Group, puedes visitar la consola de AWS o ejecutar:"
echo "aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $(terraform output -raw autoscaling_group_name)"
echo ""

cd ../..

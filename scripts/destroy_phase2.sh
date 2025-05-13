cat > destroy_phase2.sh << EOF
#!/bin/bash
set -e

echo "Eliminando la infraestructura de la fase 2 del proyecto BookStore..."

# Verificar que los archivos de Terraform existen
if [ ! -d "infra/phase2" ]; then
    echo "El directorio infra/phase2 no existe. Por favor, verifica la estructura del proyecto."
    exit 1
fi

# Inicializar Terraform
cd infra/phase2
terraform init

# Destruir la infraestructura
echo "Destruyendo recursos. Esto puede tardar varios minutos..."
terraform destroy -auto-approve

echo "Infraestructura eliminada con éxito."
cd ../..
EOF

chmod +x destroy_phase2.sh

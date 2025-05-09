#!/bin/bash
# Este script debe ejecutarse en la instancia EC2 para configurar NGINX con SSL
set -e

# Colored output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Configurando NGINX con SSL${NC}"
echo "----------------------------------------"

# Create self-signed certificate for development
echo -e "${YELLOW}Creando certificado SSL autofirmado...${NC}"
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx.key \
  -out /etc/nginx/ssl/nginx.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Configure NGINX with SSL
echo -e "${YELLOW}Configurando NGINX para SSL...${NC}"
sudo bash -c 'cat > /etc/nginx/sites-available/bookstore << EOF
server {
    listen 80;
    server_name _;
    
    # Redirect all HTTP requests to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name _;
    
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
    # Add HSTS header
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF'

# Enable the site and test configuration
echo -e "${YELLOW}Habilitando sitio y comprobando configuración...${NC}"
sudo ln -sf /etc/nginx/sites-available/bookstore /etc/nginx/sites-enabled/
sudo nginx -t

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Configuración de NGINX válida.${NC}"
    sudo systemctl restart nginx
    echo -e "${GREEN}NGINX reiniciado con configuración SSL.${NC}"
    
    echo -e "${YELLOW}Comprobando conexión HTTPS:${NC}"
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    HTTPS_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" https://$PUBLIC_IP)
    echo -e "Estado HTTP: ${GREEN}$HTTPS_STATUS${NC}"
    
    echo -e "\n${GREEN}HTTPS ahora está configurado con un certificado autofirmado.${NC}"
    echo "Puedes acceder a tu aplicación en: https://$PUBLIC_IP"
    echo "Nota: Tu navegador mostrará una advertencia de seguridad porque el certificado es autofirmado."
else
    echo -e "${RED}¡Prueba de configuración de NGINX fallida!${NC}"
    exit 1
fi

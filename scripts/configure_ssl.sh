#!/bin/bash

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Configuración de certificado SSL para BookStore${NC}"

# Verificar si se está ejecutando como root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Este script debe ejecutarse como root (sudo)${NC}"
  exit 1
fi

# Instalación de Certbot si no está instalado
if ! command -v certbot &> /dev/null; then
    echo -e "${YELLOW}Certbot no encontrado. Instalando...${NC}"
    dnf install -y certbot python3-certbot-nginx
fi

# Verificar el estado de NGINX
echo -e "${YELLOW}Verificando el estado de NGINX...${NC}"
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}NGINX está en ejecución${NC}"
else
    echo -e "${YELLOW}NGINX no está en ejecución. Iniciando...${NC}"
    systemctl start nginx
    
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}NGINX iniciado correctamente${NC}"
    else
        echo -e "${RED}Error al iniciar NGINX. Verifique los logs: journalctl -u nginx${NC}"
        exit 1
    fi
fi

# Obtener certificado SSL con Certbot
echo -e "${YELLOW}Obteniendo certificado SSL con Certbot...${NC}"
certbot --nginx -d proyecto2.shop -d www.proyecto2.shop

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Certificado SSL obtenido y configurado correctamente${NC}"
    
    # Reiniciar NGINX para aplicar cambios
    echo -e "${YELLOW}Reiniciando NGINX...${NC}"
    systemctl restart nginx
    
    echo -e "${GREEN}Configuración completada. Ahora puedes acceder a tu aplicación en:${NC}"
    echo -e "https://proyecto2.shop"
    echo -e "https://www.proyecto2.shop"
    
    # Verificar que la aplicación está accesible
    echo -e "${YELLOW}Verificando acceso a la aplicación...${NC}"
    if curl -s --head https://proyecto2.shop | grep "200 OK" > /dev/null; then
        echo -e "${GREEN}La aplicación está correctamente accesible vía HTTPS${NC}"
    else
        echo -e "${YELLOW}La aplicación no parece estar accesible. Verifica que:${NC}"
        echo -e "1. Los registros DNS estén correctamente configurados"
        echo -e "2. La aplicación Docker esté en ejecución (docker ps)"
        echo -e "3. NGINX esté correctamente configurado (nginx -t)"
    fi
else
    echo -e "${RED}Error al obtener el certificado SSL. Revise los mensajes de error.${NC}"
    exit 1
fi

# Verificar el estado de la aplicación Docker
echo -e "${YELLOW}Verificando el estado de la aplicación Docker...${NC}"
if docker ps | grep -q "bookstore"; then
    echo -e "${GREEN}La aplicación BookStore está en ejecución${NC}"
else
    echo -e "${YELLOW}La aplicación BookStore no parece estar en ejecución. Iniciándola...${NC}"
    cd /app
    docker-compose up -d
    
    sleep 5
    
    if docker ps | grep -q "bookstore"; then
        echo -e "${GREEN}La aplicación BookStore ahora está en ejecución${NC}"
    else
        echo -e "${RED}Error al iniciar la aplicación. Verifique los logs: docker-compose logs${NC}"
    fi
fi

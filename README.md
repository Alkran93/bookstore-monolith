# Proyecto 2 - BookStore Monolítico y Microservicios

## Fase 1: Despliegue de BookStore Monolítico en AWS

Este documento detalla el proceso de despliegue de la aplicación BookStore Monolítica en una Máquina Virtual en AWS, con dominio propio, certificado SSL y Proxy inverso en NGINX.

## Tabla de Contenidos

- [Requisitos Previos](#requisitos-previos)
- [Arquitectura](#arquitectura)
- [Paso 1: Preparación del entorno](#paso-1-preparación-del-entorno)
- [Paso 2: Despliegue de la infraestructura](#paso-2-despliegue-de-la-infraestructura)
- [Paso 3: Configuración de DNS](#paso-3-configuración-de-dns)
- [Paso 4: Configuración del certificado SSL](#paso-4-configuración-del-certificado-ssl)
- [Paso 5: Verificación del despliegue](#paso-5-verificación-del-despliegue)
- [Troubleshooting](#troubleshooting)
- [Próximos pasos](#próximos-pasos)

## Requisitos Previos

- Cuenta de AWS Academy
- Par de claves EC2 generado
- Dominio registrado (proyecto2.shop en Hostinger)
- AWS CLI configurado

## Arquitectura

La arquitectura para la Fase 1 consiste en:

- Una instancia EC2 Amazon Linux 2023
- Puerto 80 y 443 expuestos para tráfico web
- Puerto 5000 para la aplicación BookStore
- NGINX como proxy inverso
- Certificado SSL/TLS gestionado por Certbot
- Docker y Docker-Compose para la ejecución de la aplicación

## Paso 1: Preparación del entorno

Clone el repositorio y prepare el entorno:

```bash
# Actualizar el sistema
sudo yum update -y

# Instalar herramientas necesarias
sudo yum install -y git jq aws-cli

# Clonar el repositorio
git clone https://github.com/Alkran93/bookstore-monolith.git
cd bookstore-monolith

# Crear directorios para el proyecto
mkdir -p infra
```

## Paso 2: Despliegue de la infraestructura

### Personalización de la plantilla CloudFormation

La plantilla `infra/phase1.yaml` debe modificarse para incluir:
- Tu par de claves EC2
- El tipo de instancia deseado (t2.micro es suficiente)

### Despliegue con CloudFormation

```bash
# Dar permisos de ejecución al script
chmod +x deploy_phase1.sh

# Editar el script para configurar tu KEY_NAME
nano deploy_phase1.sh

# Ejecutar el script de despliegue
./deploy_phase1.sh
```

El script realizará:
1. Creación de un grupo de seguridad con puertos 22, 80, 443 y 5000 abiertos
2. Lanzamiento de una instancia EC2 con Amazon Linux 2023
3. Instalación y configuración de Docker, Docker-Compose y NGINX
4. Clonación del repositorio y preparación de la aplicación
5. Configuración inicial de NGINX como proxy inverso

Al finalizar, el script mostrará:
- ID de la instancia
- DNS público
- IP pública

## Paso 3: Configuración de DNS

Configurar los registros DNS en Hostinger:

1. Accede a tu panel de control de Hostinger
2. Ve a la sección de DNS del dominio proyecto2.shop
3. Crea o actualiza los siguientes registros:

| Tipo  | Nombre | Valor           | TTL    |
|-------|--------|-----------------|--------|
| A     | @      | [IP pública]    | 300    |
| A     | www    | [IP pública]    | 300    |

Donde [IP pública] es la dirección IP mostrada por el script de despliegue.

## Paso 4: Configuración del certificado SSL

Conéctate a la instancia EC2:

```bash
ssh -i tu-clave.pem ec2-user@[IP pública]
```

Ejecuta el script de configuración SSL:

```bash
# Dar permisos de ejecución
sudo chmod +x configure_ssl.sh

# Ejecutar el script
sudo ./configure_ssl.sh
```

El script:
1. Verifica la instalación de Certbot
2. Comprueba que NGINX esté en funcionamiento
3. Obtiene y configura un certificado SSL para proyecto2.shop y www.proyecto2.shop
4. Verifica el estado de la aplicación Docker

## Paso 5: Verificación del despliegue

Para verificar que todo funciona correctamente:

```bash
# Verificar que la aplicación responde por HTTPS
curl -vk https://proyecto2.shop

# Verificar el estado de Docker
docker ps

# Verificar los logs de la aplicación
docker-compose logs
```

También puedes acceder directamente desde tu navegador a:
- https://proyecto2.shop
- https://www.proyecto2.shop

## Troubleshooting

### Problemas comunes:

1. **La aplicación no responde en el puerto 5000**
   ```bash
   # Verificar que el contenedor está en ejecución
   docker ps
   
   # Si no está en ejecución, iniciar docker-compose
   cd /app
   docker-compose up -d
   
   # Verificar logs
   docker-compose logs
   ```

2. **NGINX no redirige correctamente a la aplicación**
   ```bash
   # Verificar la configuración de NGINX
   sudo nginx -t
   
   # Ver logs de NGINX
   sudo cat /var/log/nginx/error.log
   ```

3. **Error al obtener certificado SSL**
   ```bash
   # Verificar que los registros DNS están propagados
   nslookup proyecto2.shop
   
   # Intentar nuevamente la obtención del certificado
   sudo certbot --nginx -d proyecto2.shop -d www.proyecto2.shop
   ```

4. **Problemas de conectividad**
   ```bash
   # Verificar grupo de seguridad en AWS
   aws ec2 describe-security-groups --group-ids [ID_GRUPO_SEGURIDAD]
   
   # Verificar que los puertos necesarios están abiertos
   sudo netstat -tulpn
   ```

---

© 2025 - Universidad EAFIT - ST0263: Tópicos Especiales en Telemática
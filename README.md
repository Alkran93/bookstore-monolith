# Project 2 - Monolithic and Microservices BookStore

## Phase 1: Deployment of the Monolithic BookStore on AWS

This document details the process of deploying the Monolithic BookStore application on a Virtual Machine on AWS, with a custom domain, SSL certificate, and Reverse Proxy using NGINX.

## Table of Contents

- [Prerequisites](#requisitos-previos)
- [Architecture](#arquitectura)
- [Step 1: Environment Preparation](#paso-1-preparación-del-entorno)
- [Step 2: Infrastructure Deployment](#paso-2-despliegue-de-la-infraestructura)
- [Step 3: DNS Configuration](#paso-3-configuración-de-dns)
- [Step 4: SSL Certificate Configuration](#paso-4-configuración-del-certificado-ssl)
- [Step 5: Deployment Verification](#paso-5-verificación-del-despliegue)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#próximos-pasos)

## Prerequisites

- AWS Academy Account
- EC2 key pair generated
- Registered domain (proyecto2.shop on Hostinger)
- Configured AWS CLI

## Architecture

The architecture for Phase 1 consists of:

- An Amazon Linux 2023 EC2 instance
- Ports 80 and 443 exposed for web traffic
- Port 5000 for the BookStore application
- NGINX as a reverse proxy
- SSL/TLS certificate managed by Certbot
- Docker and Docker-Compose for application execution

##  Step 1: Environment Preparation

Clone the repository and prepare the environment:

```bash
# Update the system
sudo yum update -y

# Install necessary tools
sudo yum install -y git jq aws-cli

# Clone the repository
git clone https://github.com/Alkran93/bookstore-monolith.git
cd bookstore-monolith

# Create directories for the project
mkdir -p infra
```

## Step 2: Infrastructure Deployment

### Customizing the CloudFormation template

The template infra/phase1.yaml must be modified to include:
- Your EC2 key pair
- The desired instance type (t2.micro is sufficient)

### Deployment with CloudFormation

```bash
# Grant execution permissions to the script
chmod +x deploy_phase1.sh

# Edit the script to configure your KEY_NAME
nano deploy_phase1.sh

# Run the deployment script
./deploy_phase1.sh
```

The script will:
1. Create a security group with ports 22, 80, 443, and 5000 open
2. Launch an EC2 instance with Amazon Linux 2023
3. Install and configure Docker, Docker-Compose, and NGINX
4. Clone the repository and prepare the application
5. Configure NGINX as a reverse proxy

Upon completion, the script will show:

- Instance ID
- Public DNS
- Public IP

## Step 3: DNS Configuration

Configure the DNS records in Hostinger:

1. Access your Hostinger control panel
2. Go to the DNS section of the domain proyecto2.shop
3. Create or update the following records::

| Type  | Name   | Value           | TTL    |
|-------|--------|-----------------|--------|
| A     | @      | [Public IP]    | 300    |
| A     | www    | [Public IP]    | 300    |

Where [Public IP] is the IP address displayed by the deployment script.

## Step 4: SSL Certificate Configuration

Connect to the EC2 instance:

```bash
ssh -i your-key.pem ec2-user@[Public IP]
```

Run the SSL configuration script:

```bash
# Grant execution permissions
sudo chmod +x configure_ssl.sh

# Run the script
sudo ./configure_ssl.sh
```

The script will:
1. Verify Certbot installation
2. Check that NGINX is running
3. Obtain and configure an SSL certificate for proyecto2.shop and www.proyecto2.shop
4. Verify the Docker application status

## Step 5: Deployment Verification

To verify everything is working correctly:

```bash
# Verify the application responds via HTTPS
curl -vk https://proyecto2.shop

# Check Docker status
docker ps

# Check application logs
docker-compose logs
```

You can also access directly via your browser:
- https://proyecto2.shop
- https://www.proyecto2.shop

## Troubleshooting

### Common Issues:

1. **The application is not responding on port 5000**
   ```bash
   # Verify that the container is running
   docker ps

   # If not running, start docker-compose
   cd /app
   docker-compose up -d

   # Check logs
   docker-compose logs
   ```

2. **NGINX is not redirecting correctly to the application
   ```bash
   # Verify NGINX configuration
   sudo nginx -t

   # Check NGINX logs
   sudo cat /var/log/nginx/error.log
   ```

3. **Error obtaining SSL certificate

   ```bash
   # Verify DNS records are propagated
   nslookup proyecto2.shop

   # Try obtaining the certificate again
   sudo certbot --nginx -d proyecto2.shop -d www.proyecto2.shop
   ```

4. **Connectivity issues**
   ```bash
   # Verify security group in AWS
   aws ec2 describe-security-groups --group-ids [SECURITY_GROUP_ID]
   
   # Verify required ports are open
   sudo netstat -tulpn
   ```

---

© 2025 - Universidad EAFIT - ST0263: Special Topics in Telematics

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

# Project 2 - AWS Scaled BookStore
## Phase 2: Scaling the Monolith on AWS

This document details the process of scaling the monolithic BookStore application using Auto Scaling Group, Application Load Balancer, RDS Multi-AZ, and EFS.

### Table of Contents
* Architecture
* Prerequisites
* Step 1: Environment Preparation
* Step 2: AMI Creation
* Step 3: Infrastructure Deployment
    * Main Components
    * Service Configuration
* Step 4: Data Migration
* Step 5: Deployment Verification
* Monitoring and Scaling
* Load Testing
* Troubleshooting

### Architecture

The architecture for Phase 2 consists of:

* Auto Scaling Group with a minimum of 2 EC2 instances
* Application Load Balancer (ALB) with HTTPS
* RDS MySQL in Multi-AZ configuration
* EFS for shared storage
* CloudWatch for monitoring and auto-scaling
* Route 53 for DNS

### Prerequisites

* Phase 1 successfully completed
* AWS CLI configured
* Terraform installed
* SSL/TLS certificate already issued
* Domain configured in Route 53 or an external provider

### Step 1: Environment Preparation

Clone the repository and prepare the environment:

bash
# Update the system
sudo yum update -y

# Install necessary tools
sudo yum install -y git jq aws-cli

# If terraform is not available via yum, install it manually
if ! command -v terraform &> /dev/null; then
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo [https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo](https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo)
    sudo yum -y install terraform
fi

# Create directory for phase 2
mkdir -p infra/phase2
cd infra/phase2


### Step 2: AMI Creation

Create an AMI based on the existing EC2 instance:

bash
# Get the ID of the current EC2 instance
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=BookStore-Phase1" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text)

# Create an AMI
AMI_ID=$(aws ec2 create-image \
    --instance-id $INSTANCE_ID \
    --name "BookStore-AMI-$(date +%Y%m%d)" \
    --description "AMI for BookStore with Docker and NGINX" \
    --no-reboot \
    --query "ImageId" \
    --output text)

echo "AMI ID: $AMI_ID"


### Step 3: Infrastructure Deployment

#### Main Components

The infrastructure consists of the following main components:

* **Security Groups:**
    * ALB Security Group: Allows HTTP/HTTPS traffic from the Internet
    * EC2 Security Group: Allows traffic from ALB and SSH access
    * RDS Security Group: Allows MySQL traffic from EC2 instances
    * EFS Security Group: Allows NFS traffic from EC2 instances
* **Application Load Balancer:**
    * HTTP listener that redirects to HTTPS
    * HTTPS listener with SSL certificate
    * Target Group pointing to port 5000 of the EC2 instances
* **Auto Scaling Group:**
    * Launch Template using the AMI created in step 2
    * Configured to maintain a minimum of 2 and a maximum of 4 instances
    * Scaling policies based on CPU usage
* **RDS MySQL:**
    * Multi-AZ configuration for high availability
    * Private subnet
    * 20GB of storage
* **EFS File System:**
    * Mounted on all EC2 instances
    * Configured for data persistence

#### Service Configuration

To deploy the infrastructure, we have created several Terraform files:

* `variables.tf`: Defines all variables used in the configuration
* `main.tf`: Main configuration and AWS provider
* `networking.tf`: Security Groups for all services
* `loadbalancer.tf`: ALB and Target Groups configuration
* `database.tf`: RDS MySQL Multi-AZ configuration
* `storage.tf`: EFS configuration
* `autoscaling.tf`: ASG, Launch Template, and scaling policies configuration
* `dns.tf`: Route 53 records configuration
* `outputs.tf`: Defines the outputs that will be displayed after deployment

Execute the deployment script:

bash
./deploy_phase2.sh


This script will perform:

1.  Terraform initialization
2.  Deployment planning
3.  Applying the changes
4.  It will display relevant information upon completion

### Step 4: Data Migration

To migrate data from the local MySQL database in Docker to RDS:

bash
./migrate_data.sh


This script:

1.  Connects to the original EC2 instance
2.  Exports the database from the MySQL container
3.  Imports the data into RDS

### Step 5: Deployment Verification

To verify that the deployment works correctly:

bash
# Check that the ALB responds
curl -v [https://proyecto2.shop](https://proyecto2.shop)

# Verify that the instances are registered in the Target Group
aws elbv2 describe-target-health \
  --target-group-arn $(cd infra/phase2 && terraform output -raw bookstore_tg_arn)


You can also access it directly from your browser at:

* `https://proyecto2.shop`
* `https://www.proyecto2.shop`

### Monitoring and Scaling

The Auto Scaling Group is configured to scale based on CPU utilization:

* If the average CPU exceeds 70% for 2 periods of 120 seconds, an instance will be added.
* If the average CPU is below 30% for 2 periods of 120 seconds, an instance will be removed.

To monitor the ASG:

bash
# View ASG status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name $(cd infra/phase2 && terraform output -raw autoscaling_group_name)

# View CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=$(cd infra/phase2 && terraform output -raw autoscaling_group_name) \
  --start-time $(date -u -d "1 hour ago" "+%Y-%m-%dT%H:%M:%SZ") \
  --end-time $(date -u "+%Y-%m-%dT%H:%M:%SZ") \
  --period 300 \
  --statistics Average


### Load Testing

To validate auto-scaling, you can perform load tests:

bash
# Install k6 (load testing tool)
# On another machine, not the production instances
sudo apt-get update
sudo apt-get install -y k6

# Create test script
cat > load-test.js << EOF
import http from 'k6/http';
import { sleep } from 'k6';

export default function() {
  http.get('[https://proyecto2.shop/](https://proyecto2.shop/)');
  sleep(0.5);
}

export const options = {
  vus: 100,
  duration: '10m',
};
EOF

# Run load test
k6 run load-test.js


You can also use Apache Benchmark from an EC2 instance:

bash
# Install ab
sudo yum install -y httpd-tools

# Run test
ab -n 10000 -c 100 [https://proyecto2.shop/](https://proyecto2.shop/)


### Troubleshooting

Common problems:

* **EC2 instances do not join the Target Group**
    bash
    # Check instance logs
    aws ec2 get-console-output --instance-id [INSTANCE_ID]

    # Verify health check status
    aws elbv2 describe-target-health \
      --target-group-arn $(cd infra/phase2 && terraform output -raw bookstore_tg_arn)
    
* **Problems mounting EFS**
    bash
    # Verify the security group allows NFS (port 2049)
    aws ec2 describe-security-groups \
      --group-ids $(cd infra/phase2 && terraform output -raw ec2_sg_id)

    # On the EC2 instance, check the mount status
    df -h
    mount | grep efs
    
* **The application cannot connect to RDS**
    bash
    # Verify the connection from the instance
    mysql -h $(cd infra/phase2 && terraform output -raw rds_endpoint | cut -d':' -f1) \
      -u bookstore_user -p bookstore

    # Check application logs
    docker logs bookstore-app
    
* **Problems with SSL/TLS certificates**
    bash
    # Check certificate status
    aws acm describe-certificate \
      --certificate-arn $(cd infra/phase2 && terraform output -raw certificate_arn)

    # Test SSL connection
    openssl s_client -connect proyecto2.shop:443
    
---
© 2025 - Universidad EAFIT - ST0263: Tópicos Especiales en Telemática

© 2025 - Universidad EAFIT - ST0263: Special Topics in Telematics

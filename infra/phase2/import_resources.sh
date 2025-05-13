#!/bin/bash
# Script para importar recursos existentes de AWS a Terraform

# Asegúrate de estar en el directorio correcto
cd infra/phase2

# Obtener el ID de VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
echo "ID de VPC por defecto: $VPC_ID"

# 1. Importar grupo de seguridad ALB
SG_ALB_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=BookStore-ALB-SG" --query "SecurityGroups[0].GroupId" --output text)
echo "Importando grupo de seguridad ALB: $SG_ALB_ID"
terraform import aws_security_group.alb_sg $SG_ALB_ID

# 2. Importar grupo de seguridad EC2
SG_EC2_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=BookStore-EC2-SG" --query "SecurityGroups[0].GroupId" --output text)
echo "Importando grupo de seguridad EC2: $SG_EC2_ID"
terraform import aws_security_group.ec2_sg $SG_EC2_ID

# 3. Importar grupo de seguridad RDS
SG_RDS_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=BookStore-RDS-SG" --query "SecurityGroups[0].GroupId" --output text)
echo "Importando grupo de seguridad RDS: $SG_RDS_ID"
terraform import aws_security_group.rds_sg $SG_RDS_ID

# 4. Importar grupo de seguridad EFS
SG_EFS_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=BookStore-EFS-SG" --query "SecurityGroups[0].GroupId" --output text)
echo "Importando grupo de seguridad EFS: $SG_EFS_ID"
terraform import aws_security_group.efs_sg $SG_EFS_ID

# 5. Importar DB subnet group
echo "Importando grupo de subredes DB: bookstore-db-subnet"
terraform import aws_db_subnet_group.bookstore_db_subnet bookstore-db-subnet

# 6. Importar target group
TG_ARN=$(aws elbv2 describe-target-groups --names BookStore-TG --query "TargetGroups[0].TargetGroupArn" --output text)
echo "Importando target group: $TG_ARN"
terraform import aws_lb_target_group.bookstore_tg $TG_ARN

# 7. Importar EFS
EFS_ID=$(aws efs describe-file-systems --creation-token BookStore-EFS --query "FileSystems[0].FileSystemId" --output text)
echo "Importando EFS: $EFS_ID"
terraform import aws_efs_file_system.bookstore_efs $EFS_ID

# 8. Importar ALB (si existe)
ALB_ARN=$(aws elbv2 describe-load-balancers --names BookStore-ALB --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)
if [ "$ALB_ARN" != "None" ] && [ ! -z "$ALB_ARN" ]; then
  echo "Importando ALB: $ALB_ARN"
  terraform import aws_lb.bookstore_alb $ALB_ARN
else
  echo "No se encontró ALB existente con nombre BookStore-ALB"
fi

# 9. Importar instancia RDS (si existe)
RDS_IDENTIFIER=$(aws rds describe-db-instances --query "DBInstances[?DBName=='bookstore'].DBInstanceIdentifier" --output text)
if [ ! -z "$RDS_IDENTIFIER" ]; then
  echo "Importando instancia RDS: $RDS_IDENTIFIER"
  terraform import aws_db_instance.bookstore_db $RDS_IDENTIFIER
else
  echo "No se encontró instancia RDS para la base de datos 'bookstore'"
fi

# 10. Importar Auto Scaling Group (si existe)
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'BookStore')].AutoScalingGroupName" --output text)
if [ ! -z "$ASG_NAME" ]; then
  echo "Importando Auto Scaling Group: $ASG_NAME"
  terraform import aws_autoscaling_group.bookstore_asg $ASG_NAME
else
  echo "No se encontró Auto Scaling Group que contenga 'BookStore' en el nombre"
fi

echo "Importación completada. Ejecuta 'terraform plan' para verificar el estado."

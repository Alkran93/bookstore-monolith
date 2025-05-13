#!/bin/bash
# Script para eliminar recursos existentes para permitir que Terraform los recree

# Advertencia de seguridad
echo "¡ADVERTENCIA! Este script eliminará recursos existentes en AWS."
echo "Si estos recursos contienen datos importantes, podría perderlos."
echo "Se recomienda hacer una copia de seguridad antes de continuar."
echo ""
read -p "¿Estás seguro de que deseas continuar? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
  echo "Operación cancelada."
  exit 1
fi

# 1. Eliminar Auto Scaling Group
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'BookStore')].AutoScalingGroupName" --output text)
if [ ! -z "$ASG_NAME" ]; then
  echo "Eliminando Auto Scaling Group: $ASG_NAME"
  aws autoscaling update-auto-scaling-group --auto-scaling-group-name $ASG_NAME --min-size 0 --max-size 0 --desired-capacity 0
  echo "Esperando a que las instancias terminen..."
  sleep 60  # Dar tiempo para que las instancias se terminen
  aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $ASG_NAME --force-delete
else
  echo "No se encontró Auto Scaling Group"
fi

# 2. Eliminar Load Balancer
ALB_ARN=$(aws elbv2 describe-load-balancers --names BookStore-ALB --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)
if [ "$ALB_ARN" != "None" ] && [ ! -z "$ALB_ARN" ]; then
  echo "Eliminando ALB: $ALB_ARN"
  
  # Primero eliminar los listeners
  LISTENERS=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query "Listeners[*].ListenerArn" --output text)
  for listener in $LISTENERS; do
    echo "Eliminando listener: $listener"
    aws elbv2 delete-listener --listener-arn $listener
  done
  
  # Luego eliminar el ALB
  aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
  echo "Esperando a que el ALB sea eliminado..."
  sleep 60  # Los ALB pueden tardar en eliminarse
else
  echo "No se encontró ALB"
fi

# 3. Eliminar Target Group
TG_ARN=$(aws elbv2 describe-target-groups --names BookStore-TG --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
if [ "$TG_ARN" != "None" ] && [ ! -z "$TG_ARN" ]; then
  echo "Eliminando Target Group: $TG_ARN"
  aws elbv2 delete-target-group --target-group-arn $TG_ARN
else
  echo "No se encontró Target Group"
fi

# 4. Eliminar RDS
RDS_IDENTIFIER=$(aws rds describe-db-instances --query "DBInstances[?DBName=='bookstore'].DBInstanceIdentifier" --output text)
if [ ! -z "$RDS_IDENTIFIER" ]; then
  echo "Eliminando instancia RDS: $RDS_IDENTIFIER"
  aws rds delete-db-instance --db-instance-identifier $RDS_IDENTIFIER --skip-final-snapshot
  echo "Esperando a que RDS se elimine..."
  aws rds wait db-instance-deleted --db-instance-identifier $RDS_IDENTIFIER
else
  echo "No se encontró instancia RDS"
fi

# 5. Eliminar EFS y mount targets
EFS_ID=$(aws efs describe-file-systems --creation-token BookStore-EFS --query "FileSystems[0].FileSystemId" --output text 2>/dev/null)
if [ ! -z "$EFS_ID" ]; then
  echo "Encontrado EFS: $EFS_ID"
  
  # Primero eliminar los mount targets
  MOUNT_TARGETS=$(aws efs describe-mount-targets --file-system-id $EFS_ID --query "MountTargets[*].MountTargetId" --output text)
  for mt in $MOUNT_TARGETS; do
    echo "Eliminando mount target: $mt"
    aws efs delete-mount-target --mount-target-id $mt
  done
  
  # Esperar a que los mount targets sean eliminados
  echo "Esperando a que los mount targets sean eliminados..."
  sleep 60
  
  # Luego eliminar el EFS
  echo "Eliminando EFS: $EFS_ID"
  aws efs delete-file-system --file-system-id $EFS_ID
else
  echo "No se encontró EFS"
fi

# 6. Eliminar DB Subnet Group
echo "Eliminando DB Subnet Group: bookstore-db-subnet"
aws rds delete-db-subnet-group --db-subnet-group-name bookstore-db-subnet 2>/dev/null || echo "No se pudo eliminar el DB Subnet Group o no existe"

# 7. Eliminar Security Groups
# Primero obtener los IDs
SG_ALB_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=BookStore-ALB-SG" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
SG_EC2_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=BookStore-EC2-SG" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
SG_RDS_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=BookStore-RDS-SG" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
SG_EFS_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=BookStore-EFS-SG" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

# Esperar a que los recursos que dependen de los security groups sean eliminados
echo "Esperando un poco más para asegurarse que los recursos se eliminaron..."
sleep 60

# Eliminar los security groups en orden inverso (debido a dependencias)
if [ ! -z "$SG_EFS_ID" ] && [ "$SG_EFS_ID" != "None" ]; then
  echo "Eliminando security group EFS: $SG_EFS_ID"
  aws ec2 delete-security-group --group-id $SG_EFS_ID || echo "No se pudo eliminar SG EFS (puede tener dependencias)"
fi

if [ ! -z "$SG_RDS_ID" ] && [ "$SG_RDS_ID" != "None" ]; then
  echo "Eliminando security group RDS: $SG_RDS_ID"
  aws ec2 delete-security-group --group-id $SG_RDS_ID || echo "No se pudo eliminar SG RDS (puede tener dependencias)"
fi

if [ ! -z "$SG_EC2_ID" ] && [ "$SG_EC2_ID" != "None" ]; then
  echo "Eliminando security group EC2: $SG_EC2_ID"
  aws ec2 delete-security-group --group-id $SG_EC2_ID || echo "No se pudo eliminar SG EC2 (puede tener dependencias)"
fi

if [ ! -z "$SG_ALB_ID" ] && [ "$SG_ALB_ID" != "None" ]; then
  echo "Eliminando security group ALB: $SG_ALB_ID"
  aws ec2 delete-security-group --group-id $SG_ALB_ID || echo "No se pudo eliminar SG ALB (puede tener dependencias)"
fi

echo "Operación completada. Puedes ejecutar 'terraform apply' para crear recursos nuevamente."
echo "Nota: Es posible que algunos recursos todavía estén en proceso de eliminación."

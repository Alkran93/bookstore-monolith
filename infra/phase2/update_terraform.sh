cat > update_terraform.sh << 'EOF'
#!/bin/bash
set -e

echo "Actualizando configuración de Terraform para la fase 2..."

# Asegurarnos de estar en el directorio correcto
cd infra/phase2

# Inicializar Terraform
terraform init

# Crear plan solo para obtener información
terraform plan -out=tfplan >/dev/null 2>&1 || true

# Si el plan falla, es posible que necesitemos crear recursos primero
EFS_ID=$(terraform output -raw efs_dns_name 2>/dev/null || echo "TO_BE_REPLACED")
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "TO_BE_REPLACED")
DB_USERNAME=$(grep db_username variables.tf | grep default | awk -F'"' '{print $2}')
DB_PASSWORD=$(grep db_password variables.tf | grep default | awk -F'"' '{print $2}')

# Crear user_data actualizado
cp ../../user_data.sh user_data_temp.sh
sed -i "s/EFS_ID/$EFS_ID/g" user_data_temp.sh
sed -i "s/RDS_ENDPOINT/$RDS_ENDPOINT/g" user_data_temp.sh
sed -i "s/DB_USERNAME/$DB_USERNAME/g" user_data_temp.sh
sed -i "s/DB_PASSWORD/$DB_PASSWORD/g" user_data_temp.sh

# Actualizar el launch template
ENCODED_USER_DATA=$(base64 -w0 user_data_temp.sh)

cat > autoscaling_updated.tf << 'AUTOSCALING'
# Launch Template for EC2 Instances
resource "aws_launch_template" "bookstore_lt" {
  name_prefix   = "${var.project_name}-LT-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = "ENCODED_USER_DATA_PLACEHOLDER"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-Instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "bookstore_asg" {
  name                = "${var.project_name}-ASG"
  vpc_zone_identifier = data.aws_subnets.default.ids
  min_size            = var.min_instances
  max_size            = var.max_instances
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.bookstore_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.bookstore_tg.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ASG-Instance"
    propagate_at_launch = true
  }

  depends_on = [
    aws_lb_target_group.bookstore_tg
  ]
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-ASG-ScaleUp"
  autoscaling_group_name = aws_autoscaling_group.bookstore_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-ASG-ScaleDown"
  autoscaling_group_name = aws_autoscaling_group.bookstore_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-HighCPUAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.bookstore_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-LowCPUAlarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.bookstore_asg.name
  }
}
AUTOSCALING

sed -i "s|ENCODED_USER_DATA_PLACEHOLDER|\"$ENCODED_USER_DATA\"|g" autoscaling_updated.tf

# Reemplazar el archivo autoscaling.tf
mv autoscaling_updated.tf autoscaling.tf

# Limpiar archivos temporales
rm user_data_temp.sh

echo "Configuración de Terraform actualizada con éxito."
cd ../../
EOF

chmod +x update_terraform.sh

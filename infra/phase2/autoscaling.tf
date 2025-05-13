# Launch Template for EC2 Instances
resource "aws_launch_template" "bookstore_lt" {
  name_prefix   = "${var.project_name}-LT-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Montar EFS
    sudo mkdir -p /mnt/efs
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.bookstore_efs.dns_name}:/ /mnt/efs
    
    # Añadir entrada a /etc/fstab para que se monte automáticamente al reiniciar
    echo "${aws_efs_file_system.bookstore_efs.dns_name}:/ /mnt/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" | sudo tee -a /etc/fstab
    
    # Iniciar la aplicación con la nueva configuración de base de datos
    cd /app
    
    # Reemplazar la configuración de la base de datos MySQL
    sed -i "s/MYSQL_HOST=mysql/MYSQL_HOST=${aws_db_instance.bookstore_db.address}/g" .env
    sed -i "s/MYSQL_USER=root/MYSQL_USER=${var.db_username}/g" .env
    sed -i "s/MYSQL_PASSWORD=example/MYSQL_PASSWORD=${var.db_password}/g" .env
    
    # Actualizar configuración de NGINX para apuntar a puerto 5000
    cat > /etc/nginx/conf.d/default.conf << 'NGINXCONF'
    server {
        listen 80;
        server_name proyecto2.shop www.proyecto2.shop;
        
        location / {
            proxy_pass http://localhost:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
    NGINXCONF
    
    # Reiniciar NGINX
    sudo systemctl restart nginx
    
    # Reiniciar la aplicación
    docker-compose down
    docker-compose up -d
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-Instance"
    }
  }

  depends_on = [
    aws_efs_mount_target.bookstore_efs_mt,
    aws_db_instance.bookstore_db
  ]
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

# Obtener información de los subnets disponibles si no se especifican
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "instance_sg" {
  name        = "${var.project_name}-instance-sg"
  description = "Security group for EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-instance-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for RDS MySQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.instance_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-db-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "${var.project_name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.instance_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-efs-sg"
    Environment = var.environment
  }
}

# EFS File System
resource "aws_efs_file_system" "bookstore_efs" {
  creation_token = "${var.project_name}-efs"
  
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name        = "${var.project_name}-efs"
    Environment = var.environment
  }
}

# EFS Mount Targets (one per subnet for high availability)
resource "aws_efs_mount_target" "efs_mount" {
  count           = length(data.aws_subnets.private.ids) > 0 ? length(data.aws_subnets.private.ids) : length(data.aws_subnets.public.ids)
  file_system_id  = aws_efs_file_system.bookstore_efs.id
  subnet_id       = length(data.aws_subnets.private.ids) > 0 ? data.aws_subnets.private.ids[count.index] : data.aws_subnets.public.ids[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}

# RDS MySQL (Multi-AZ)
resource "aws_db_subnet_group" "bookstore_db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = length(data.aws_subnets.private.ids) >= 2 ? slice(data.aws_subnets.private.ids, 0, 2) : slice(data.aws_subnets.public.ids, 0, 2)

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "bookstore_db" {
  identifier             = "${var.project_name}-db"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.bookstore_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  multi_az               = true
  skip_final_snapshot    = true

  tags = {
    Name        = "${var.project_name}-db"
    Environment = var.environment
  }
}

# Application Load Balancer
resource "aws_lb" "bookstore_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = slice(data.aws_subnets.public.ids, 0, 2)

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "bookstore_tg" {
  name     = "${var.project_name}-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200-299"
  }

  tags = {
    Name        = "${var.project_name}-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.bookstore_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bookstore_tg.arn
  }
}

# User data script for EC2 instances
data "template_file" "user_data" {
  template = <<-EOF
    #!/bin/bash
    # Actualizar paquetes
    apt-get update
    apt-get upgrade -y
    
    # Instalar dependencias
    apt-get install -y git amazon-efs-utils nfs-common docker.io docker-compose

    # Habilitar y arrancar Docker
    systemctl enable docker
    systemctl start docker
    
    # Crear directorio y montar EFS
    mkdir -p /mnt/efs
    mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.bookstore_efs.dns_name}:/ /mnt/efs
    
    # Asegurar que EFS se monte después de reinicios
    echo "${aws_efs_file_system.bookstore_efs.dns_name}:/ /mnt/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" >> /etc/fstab
    
    # Clonar repositorio
    git clone https://github.com/Alkran93/bookstore-monolith.git /home/ubuntu/bookstore-monolith
    chown -R ubuntu:ubuntu /home/ubuntu/bookstore-monolith
    
    # Crear directorio para almacenar imágenes y otros archivos compartidos
    mkdir -p /mnt/efs/uploads
    chmod 777 /mnt/efs/uploads
    
    # Configurar variables de entorno para la aplicación
    cat > /home/ubuntu/bookstore-monolith/.env <<EOL
    MYSQL_ROOT_PASSWORD=${var.db_password}
    MYSQL_DATABASE=${var.db_name}
    MYSQL_USER=${var.db_username}
    MYSQL_PASSWORD=${var.db_password}
    MYSQL_HOST=${aws_db_instance.bookstore_db.address}
    MYSQL_PORT=3306
    UPLOADS_FOLDER=/mnt/efs/uploads
    EOL
    
    # Modificar docker-compose.yml para usar RDS en lugar de MySQL local
    cd /home/ubuntu/bookstore-monolith
    sed -i 's/- db/#- db/g' docker-compose.yml  # Comentar la dependencia de db
    sed -i '/db:/,/volumes:/d' docker-compose.yml  # Eliminar sección de servicio db
    
    # Iniciar la aplicación
    docker-compose up -d
  EOF
}

# Launch Template
resource "aws_launch_template" "bookstore_lt" {
  name          = "${var.project_name}-lt"
  image_id      = "ami-0c7217cdde317cfec"  # Ubuntu Server 22.04 LTS en us-east-1, cambiar según la región
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = base64encode(data.template_file.user_data.rendered)

  tag_specifications {
    resource_type = "instance"
    
    tags = {
      Name        = "${var.project_name}-instance"
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-lt"
    Environment = var.environment
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "bookstore_asg" {
  name                = "${var.project_name}-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = slice(data.aws_subnets.public.ids, 0, 2)
  target_group_arns   = [aws_lb_target_group.bookstore_tg.arn]
  
  launch_template {
    id      = aws_launch_template.bookstore_lt.id
    version = "$Latest"
  }
  
  health_check_type         = "ELB"
  health_check_grace_period = 300
  
  tag {
    key                 = "Name"
    value               = "${var.project_name}-instance"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  
  depends_on = [aws_db_instance.bookstore_db, aws_efs_mount_target.efs_mount]
}

# Políticas de escalado
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.bookstore_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.bookstore_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# CloudWatch Alarms para Auto Scaling
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Este alarma se activa cuando el CPU supera el 70%"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.bookstore_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-low-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Este alarma se activa cuando el CPU es menor al 30%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.bookstore_asg.name
  }
}

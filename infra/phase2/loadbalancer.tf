# Application Load Balancer
resource "aws_lb" "bookstore_alb" {
  name               = "${var.project_name}-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-ALB"
  }
}

# Target Group
resource "aws_lb_target_group" "bookstore_tg" {
  name     = "${var.project_name}-TG"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "5000"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-TG"
  }
}

# HTTP Listener (simplificado para usar solo HTTP)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.bookstore_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bookstore_tg.arn
  }
}

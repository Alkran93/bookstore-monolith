output "load_balancer_dns" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.bookstore_alb.dns_name
}

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.bookstore_db.endpoint
}

output "efs_dns_name" {
  description = "The DNS name of the EFS file system"
  value       = aws_efs_file_system.bookstore_efs.dns_name
}

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.bookstore_asg.name
}

output "dns_name" {
  description = "The DNS name for the application"
  value       = var.domain_name
}

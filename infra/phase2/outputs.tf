output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.bookstore_alb.dns_name
}

output "rds_endpoint" {
  description = "Endpoint of the RDS database"
  value       = aws_db_instance.bookstore_db.endpoint
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.bookstore_efs.dns_name
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.bookstore_asg.name
}

output "website_url" {
  description = "URL of the website"
  value       = "http://${aws_lb.bookstore_alb.dns_name}"
}

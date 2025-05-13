variable "aws_region" {
  description = "AWS Region to deploy to"
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name to use for resource naming"
  default     = "BookStore"
}

variable "domain_name" {
  description = "Domain name for the application"
  default     = "proyecto2.shop"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instances"
  default     = "ami-065a3271750f821cd"  # Reemplaza con tu AMI ID
}

variable "instance_type" {
  description = "Instance type for EC2 instances"
  default     = "t2.micro"
}

variable "key_name" {
  description = "Key pair name for EC2 instances"
  default     = "bookstore-key"  # Reemplaza con tu key name
}

variable "db_username" {
  description = "Username for RDS database"
  default     = "bookstore_user"
}

variable "db_password" {
  description = "Password for RDS database"
  default     = "123456789*"  # Cambiar en producción
  sensitive   = true
}

variable "min_instances" {
  description = "Minimum number of instances in ASG"
  default     = 2
}

variable "max_instances" {
  description = "Maximum number of instances in ASG"
  default     = 4
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  default     = 2
}

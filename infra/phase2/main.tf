provider "aws" {
  region = var.aws_region
}

# Datos existentes (VPC, Subnets, etc.)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

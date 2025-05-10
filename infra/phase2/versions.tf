terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Si estás usando AWS Academy, es posible que necesites estos ajustes
  # Para evitar errores de permisos, pueden ser necesarios ajustes adicionales en función de las limitaciones de AWS Academy
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
}

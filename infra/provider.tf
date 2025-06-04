terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7.1"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
  # Configure suas credenciais AWS via variáveis de ambiente,
  # perfis AWS, ou roles IAM.
}
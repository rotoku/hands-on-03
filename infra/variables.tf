variable "aws_region" {
  description = "Região AWS para criar os recursos"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome base para os recursos"
  type        = string
  default     = "sqs-lambda-processor"
}

variable "lambda_runtime" {
  description = "Runtime da função Lambda"
  type        = string
  default     = "python3.11"
}

variable "lambda_handler_name" {
  description = "Nome do handler da função Lambda"
  type        = string
  default     = "lambda_function.handler"
}

variable "datadog_api_key_secret_arn" {
  description = "ARN do AWS Secrets Manager para a Datadog API Key (usado pela Datadog Forwarder Lambda, se aplicável, ou para a extensão se não configurada globalmente)"
  type        = string
  default     = "" # Opcional: pode ser configurado diretamente na Lambda ou via extensão
}

variable "datadog_site" {
  description = "Site do Datadog (ex: datadoghq.com, datadoghq.eu)"
  type        = string
  default     = "datadoghq.com"
}

variable "dd_env" {
  description = "Ambiente para Datadog (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "dd_service" {
  description = "Nome do serviço no Datadog"
  type        = string
  default     = "sqs-processor-service"
}

variable "dd_version" {
  description = "Versão do serviço no Datadog"
  type        = string
  default     = "1.0.0"
}

variable "datadog_lambda_layer_arn" {
  description = "ARN da Layer da Datadog Lambda Extension para a região e arquitetura apropriadas. Ex: arn:aws:lambda:<AWS_REGION>:464622532012:layer:Datadog-Extension:<VERSION>"
  type        = string
  # Encontre o ARN mais recente aqui: https://docs.datadoghq.com/serverless/installation/python/?tab= ரசிக
  # Exemplo para us-east-1, Python 3.11 (verifique a versão mais recente e arquitetura)
  default     = "arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Extension-Python3-11:latest" # Ajuste conforme necessário
}

variable "datadog_forwarder_arn" {
  description = "ARN da Lambda Datadog Forwarder para encaminhar logs, caso não esteja usando a extensão ou queira logs de outros serviços."
  type        = string
  default     = "" # Deixe em branco se usar a extensão para logs da Lambda
}
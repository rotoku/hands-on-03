# --- SQS Queue ---
resource "aws_sqs_queue" "main_queue" {
  name                       = "${var.project_name}-queue"
  delay_seconds              = 0
  max_message_size           = 262144 # 256 KiB
  message_retention_seconds  = 345600 # 4 dias
  receive_wait_time_seconds  = 10     # Long polling

  # Opcional: Dead Letter Queue (DLQ)
  # redrive_policy = jsonencode({
  #   deadLetterTargetArn = aws_sqs_queue.dlq.arn
  #   maxReceiveCount     = 5
  # })

  tags = {
    Environment = var.dd_env
    Project     = var.project_name
    Terraform   = "true"
  }
}

# Opcional: Dead Letter Queue (DLQ)
# resource "aws_sqs_queue" "dlq" {
#   name = "${var.project_name}-dlq"
#   tags = {
#     Environment = var.dd_env
#     Project     = var.project_name
#     Terraform   = "true"
#   }
# }

# --- IAM Role for Lambda ---
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json

  tags = {
    Environment = var.dd_env
    Project     = var.project_name
    Terraform   = "true"
  }
}

# Política para logs da Lambda no CloudWatch
data "aws_iam_policy_document" "lambda_logging_policy_doc" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"] # Pode ser mais restritivo
  }
}

resource "aws_iam_policy" "lambda_logging_policy" {
  name        = "${var.project_name}-lambda-logging-policy"
  description = "IAM policy for Lambda logging to CloudWatch"
  policy      = data.aws_iam_policy_document.lambda_logging_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_logging_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

# Política para acesso ao SQS
data "aws_iam_policy_document" "lambda_sqs_policy_doc" {
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.main_queue.arn]
  }
}

resource "aws_iam_policy" "lambda_sqs_policy" {
  name        = "${var.project_name}-lambda-sqs-policy"
  description = "IAM policy for Lambda to access SQS queue"
  policy      = data.aws_iam_policy_document.lambda_sqs_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}

# Política para X-Ray (necessário para tracing com Datadog)
resource "aws_iam_policy" "xray_policy" {
  name        = "${var.project_name}-lambda-xray-policy"
  description = "Policy for AWS X-Ray"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Effect   = "Allow",
        Resource = "*" # Pode ser mais restritivo
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_xray_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.xray_policy.arn
}

# Política para acesso ao Secrets Manager (se a API Key do Datadog estiver lá)
# Descomente se estiver usando var.datadog_api_key_secret_arn
# data "aws_iam_policy_document" "lambda_secrets_manager_policy_doc" {
#   statement {
#     actions   = ["secretsmanager:GetSecretValue"]
#     resources = [var.datadog_api_key_secret_arn]
#     condition {
#       test     = "StringEquals"
#       variable = "secretsmanager:VersionStage"
#       values   = ["AWSCURRENT"]
#     }
#   }
# }

# resource "aws_iam_policy" "lambda_secrets_manager_policy" {
#   name        = "${var.project_name}-lambda-secrets-policy"
#   description = "IAM policy for Lambda to access Datadog API key from Secrets Manager"
#   policy      = data.aws_iam_policy_document.lambda_secrets_manager_policy_doc.json
# }

# resource "aws_iam_role_policy_attachment" "lambda_secrets_manager_attach" {
#   role       = aws_iam_role.lambda_execution_role.name
#   policy_arn = aws_iam_policy.lambda_secrets_manager_policy.arn
# }

# --- Lambda Function ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../src/" # Caminho para a pasta com o código da Lambda e requirements.txt
  output_path = "${path.module}/lambda_package.zip"
}

resource "aws_lambda_function" "sqs_processor_lambda" {
  function_name    = "${var.project_name}-function"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = var.lambda_handler_name
  runtime          = var.lambda_runtime
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30 # Segundos
  memory_size      = 256 # MB

  environment {
    variables = {
      DD_SITE          = var.datadog_site
      DD_FLUSH_TO_LOG  = "true" # Recomendado quando usa a extensão para enviar traces e métricas via logs
      DD_LOG_LEVEL     = "INFO"
      DD_ENV           = var.dd_env
      DD_SERVICE       = var.dd_service
      DD_VERSION       = var.dd_version
      # DD_API_KEY_SECRET_ARN = var.datadog_api_key_secret_arn # Se estiver buscando a chave do Secrets Manager
      # DD_SERVERLESS_LOGS_ENABLED = "true" # A extensão lida com isso
      PYTHONPATH       = "/opt/python/lib/python3.11/site-packages:/var/runtime:/var/task" # Ajuste se necessário
    }
  }

  # Configuração para X-Ray Tracing (Integrado com Datadog APM)
  tracing_config {
    mode = "Active"
  }

  # Adiciona a Layer da Datadog Lambda Extension
  layers = [var.datadog_lambda_layer_arn]

  tags = {
    Environment = var.dd_env
    Project     = var.project_name
    Terraform   = "true"
  }

  # Permite que a Lambda seja acionada pelo SQS
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logging_attach,
    aws_iam_role_policy_attachment.lambda_sqs_attach,
    aws_iam_role_policy_attachment.lambda_xray_attach,
    # aws_iam_role_policy_attachment.lambda_secrets_manager_attach # Descomente se usar
    aws_sqs_queue.main_queue,
  ]
}

# --- SQS Event Source Mapping for Lambda ---
resource "aws_lambda_event_source_mapping" "sqs_mapping" {
  event_source_arn = aws_sqs_queue.main_queue.arn
  function_name    = aws_lambda_function.sqs_processor_lambda.arn
  batch_size       = 10 # Número de mensagens a serem buscadas por vez
  enabled          = true

  # Opcional: define a janela de tempo para o processamento em lote
  # maximum_batching_window_in_seconds = 5
}

# --- Datadog Integration (CloudWatch Logs Forwarding - Opcional se a extensão já envia logs) ---
# Se você estiver usando a Datadog Lambda Extension, ela pode encaminhar os logs diretamente.
# Se preferir usar a Datadog Forwarder Lambda para logs do CloudWatch:
# 1. Deploy a Datadog Forwarder Lambda (geralmente via CloudFormation ou Serverless Application Repository).
# 2. Configure a subscrição do CloudWatch Log Group da sua Lambda para a Forwarder.

# Exemplo de subscrição de log para a Datadog Forwarder (se var.datadog_forwarder_arn estiver definido)
resource "aws_cloudwatch_log_subscription_filter" "datadog_log_forwarder_subscription" {
  count = var.datadog_forwarder_arn != "" ? 1 : 0

  name            = "${var.project_name}-datadog-subscription"
  log_group_name  = "/aws/lambda/${aws_lambda_function.sqs_processor_lambda.function_name}"
  filter_pattern  = "" # Enviar todos os logs
  destination_arn = var.datadog_forwarder_arn

  # A role para a CloudWatch Logs invocar a Lambda Forwarder precisa ser configurada
  # separadamente ou como parte do deploy da Forwarder.
  # role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_FOR_CW_TO_FORWARDER>"

  depends_on = [aws_lambda_function.sqs_processor_lambda]
}
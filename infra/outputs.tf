output "sqs_queue_arn" {
  description = "ARN da fila SQS criada"
  value       = aws_sqs_queue.main_queue.arn
}

output "sqs_queue_url" {
  description = "URL da fila SQS criada"
  value       = aws_sqs_queue.main_queue.id # .id retorna a URL da fila
}

output "lambda_function_name" {
  description = "Nome da função Lambda criada"
  value       = aws_lambda_function.sqs_processor_lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN da função Lambda criada"
  value       = aws_lambda_function.sqs_processor_lambda.arn
}

output "lambda_iam_role_name" {
  description = "Nome da IAM Role da Lambda"
  value       = aws_iam_role.lambda_execution_role.name
}
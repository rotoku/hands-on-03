import json
import os

# Importações para Datadog (assumindo que a Datadog Lambda Extension ou Forwarder está configurada)
from datadog_lambda.metric import lambda_metric
from datadog_lambda.handler import datadog_lambda_handler
from aws_xray_sdk.core import patch_all # Para traces distribuídos com X-Ray (integrado com Datadog)

# Patch de bibliotecas para tracing automático (opcional, mas recomendado)
patch_all()

# Variáveis de ambiente para Datadog (configuradas na Lambda)
# DD_API_KEY (se não usar a extensão)
# DD_SITE (ex: "datadoghq.com")
# DD_ENV (ex: "dev", "prod")
# DD_SERVICE (ex: "sqs-processor-lambda")
# DD_VERSION (ex: "1.0")

@datadog_lambda_handler
def handler(event, context):
    """
    Processa mensagens da fila SQS.
    """
    print(f"Evento recebido: {event}")

    for record in event.get('Records', []):
        try:
            message_body = record.get('body')
            if message_body:
                # Simula o processamento da mensagem
                print(f"Processando mensagem: {message_body}")
                data = json.loads(message_body)

                # Exemplo de métrica customizada para o Datadog
                lambda_metric(
                    "my_app.sqs_messages_processed",  # Nome da métrica
                    1,                                # Valor
                    tags=[
                        f"message_id:{record.get('messageId', 'unknown')}",
                        f"environment:{os.environ.get('DD_ENV', 'undefined')}"
                    ]
                )

                # Seu código de processamento aqui...
                print(f"Dados da mensagem processados: {data}")

            else:
                print("Corpo da mensagem vazio.")

        except json.JSONDecodeError as e:
            print(f"Erro ao decodificar JSON da mensagem: {e}")
            # Adicionar tratamento de erro, como enviar para uma Dead Letter Queue (DLQ)
            # ou registrar um erro no Datadog
            # datadog_lambda_handler irá capturar exceções automaticamente como traces de erro.
            raise  # Re-lança a exceção para que a Lambda a marque como falha e o Datadog capture
        except Exception as e:
            print(f"Erro inesperado ao processar mensagem: {e}")
            raise

    return {
        'statusCode': 200,
        'body': json.dumps('Mensagens processadas com sucesso!')
    }

if __name__ == "__main__":
    # Exemplo de evento SQS para teste local (simplificado)
    sample_event = {
        "Records": [
            {
                "messageId": "19dd0b57-b21e-4ac1-bd88-01bbb068cb78",
                "receiptHandle": "MessageReceiptHandle",
                "body": "{\"key\":\"value\", \"number\": 123}",
                "attributes": {
                    "ApproximateReceiveCount": "1",
                    "SentTimestamp": "1523232000000",
                    "SenderId": "123456789012",
                    "ApproximateFirstReceiveTimestamp": "1523232000001"
                },
                "messageAttributes": {},
                "md5OfBody": "7b270e59b47ff90a553787216d55d91d",
                "eventSource": "aws:sqs",
                "eventSourceARN": "arn:aws:sqs:us-east-1:123456789012:MyQueue",
                "awsRegion": "us-east-1"
            }
        ]
    }
    handler(sample_event, None)
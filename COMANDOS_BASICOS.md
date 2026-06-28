# Comandos Básicos - LocalStack AWS

Todos los comandos usan `docker-compose run --rm aws-cli` para ejecutar AWS CLI dentro del contenedor.

**Endpoint**: `http://floci:4566`

## S3 - Almacenamiento

### Listar buckets
```bash
docker-compose run --rm aws-cli s3api list-buckets --endpoint-url=http://floci:4566
```

### Listar contenido de un bucket
```bash
docker-compose run --rm aws-cli s3 ls s3://s3-demo-sds-dh-dev/ --endpoint-url=http://floci:4566
```

### Listar carpetas dentro de un bucket
```bash
docker-compose run --rm aws-cli s3 ls s3://s3-demo-sds-dh-dev/share/ --endpoint-url=http://floci:4566
```

## Lambda - Funciones

### Listar todas las funciones Lambda
```bash
docker-compose run --rm aws-cli lambda list-functions --endpoint-url=http://floci:4566
```

### Ver detalles de una función específica
```bash
docker-compose run --rm aws-cli lambda get-function --function-name generateThumbnailsFromImage-dev --endpoint-url=http://floci:4566
```

### Guardar detalles en archivo
```bash
docker-compose run --rm aws-cli lambda get-function --function-name generateThumbnailsFromImage-dev --endpoint-url=http://floci:4566 > lambda-details.txt
```

### Actualizar código de Lambda (Python/ZIP)
```bash
docker-compose run --rm aws-cli lambda update-function-code \
  --function-name generateThumbnailsFromImage-dev \
  --zip-file fileb:///workspace/function.zip \
  --endpoint-url=http://floci:4566
```

### Actualizar código de Lambda (Docker)
```bash
docker-compose run --rm aws-cli lambda update-function-code \
  --function-name SET-dev-Doodle-ConvertMsDocToPdf \
  --image-uri pdf-converter-dev/document.conversion.office:latest \
  --endpoint-url=http://floci:4566
```

### Invocar una función Lambda
```bash
docker-compose run --rm aws-cli lambda invoke \
  --function-name SET-dev-Doodle-ConvertMsDocToPdf \
  --payload "{\"test\": \"data\"}" \
  --endpoint-url=http://floci:4566 \
  response.json
```

## CloudWatch Logs

### Ver logs de una función Lambda (seguimiento en vivo)
```bash
docker-compose run --rm aws-cli logs tail /aws/lambda/generateThumbnailsFromImage-dev \
  --endpoint-url=http://floci:4566 \
  --follow
```

### Ver logs desde el contenedor de Floci directamente
```bash
docker-compose exec floci cat /tmp/lambda/logs/generateThumbnailsFromImage-dev/latest.log
```

## ECR - Registro de imágenes Docker

### Listar repositorios ECR
```bash
docker-compose run --rm aws-cli ecr describe-repositories --endpoint-url=http://floci:4566
```

### Describir repositorio específico
```bash
docker-compose run --rm aws-cli ecr describe-repositories \
  --repository-names pdf-converter-dev \
  --endpoint-url=http://floci:4566
```

## SQS - Colas de mensajes

### Listar colas SQS
```bash
docker-compose run --rm aws-cli sqs list-queues --endpoint-url=http://floci:4566
```

### Enviar mensaje a cola
```bash
docker-compose run --rm aws-cli sqs send-message \
  --queue-url http://floci:4566/queue/my-queue \
  --message-body "Mensaje de prueba" \
  --endpoint-url=http://floci:4566
```

### Recibir mensajes de cola
```bash
docker-compose run --rm aws-cli sqs receive-message \
  --queue-url http://floci:4566/queue/my-queue \
  --endpoint-url=http://floci:4566
```

## Tips

- Todos los comandos deben ejecutarse desde la raíz del proyecto (donde está `docker-compose.yml`)
- El endpoint `http://floci:4566` es donde LocalStack escucha
- Para ver más opciones de cualquier comando: `docker-compose run --rm aws-cli <service> help`
- Los logs de Floci se guardan en `/tmp/lambda/logs/` dentro del contenedor

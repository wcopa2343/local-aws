# Manual — Floci Dev Environment

## Requisitos
- Docker Desktop corriendo
- Archivo `.env` configurado (copiar de `.env.example`)

---

## Primera vez (o después de un `docker-compose down`)

LocalStack no persiste infraestructura entre reinicios. Cada vez que levantes el entorno debes correr el `apply`. Terraform es idempotente — si el recurso ya existe no lo recrea, solo verifica.

### Paso 1 — Levantar los contenedores

```bash
# Modo Floci (devs)
docker-compose --profile floci up

# Modo AWS real (staging/prod)
docker-compose up -d
```

Espera a que Floci esté healthy antes de continuar:
```bash
docker-compose logs -f floci
# Espera ver que el healthcheck pasa
```

### Paso 2 — Crear la infraestructura con Terraform

```bash
# LocalStack
docker-compose exec terraform sh -c "terraform init && terraform apply -auto-approve -var-file=environments/dev/terraform.tfvars"

# AWS staging
docker-compose exec terraform sh -c "terraform init && terraform apply -auto-approve -var-file=environments/staging/terraform.tfvars"

# AWS prod
docker-compose exec terraform sh -c "terraform init && terraform apply -auto-approve -var-file=environments/prod/terraform.tfvars"
```

---

## Uso diario (contenedores ya corriendo)

Si los contenedores ya están levantados y la infraestructura ya fue creada, solo necesitas levantar Floci:

```bash
docker-compose --profile floci up
```

No es necesario volver a correr `terraform apply` a menos que hayas bajado los contenedores con `docker-compose down` o hayas cambiado código Terraform.

---

## Destruir la infraestructura

```bash
# Floci
docker-compose exec terraform sh -c "terraform destroy -auto-approve -var-file=environments/dev/terraform.tfvars"

# Bajar los contenedores
docker-compose --profile floci down
```

---

## Usar los recursos creados

Todos los comandos de aws-cli apuntan automáticamente a LocalStack via `AWS_ENDPOINT_URL`.

### S3 — bucket: `s3-demo-sds-dh-dev`

```bash
# Listar buckets
docker-compose run --rm aws-cli s3 ls

# Subir un archivo
docker-compose run --rm aws-cli s3 cp /ruta/archivo.pdf s3://s3-demo-sds-dh-dev/

# Listar contenido del bucket
docker-compose run --rm aws-cli s3 ls s3://s3-demo-sds-dh-dev/

# Descargar un archivo
docker-compose run --rm aws-cli s3 cp s3://s3-demo-sds-dh-dev/archivo.pdf /ruta/destino/
```

---

### SQS — enviar mensajes a las colas

```bash
# Obtener URL de una cola
docker-compose run --rm aws-cli sqs get-queue-url \
  --queue-name doodle-dev-generateThumbnailsFromImage

# Enviar mensaje a la cola de thumbnails desde imagen
docker-compose run --rm aws-cli sqs send-message \
  --queue-url http://floci:4566/000000000000/doodle-dev-generateThumbnailsFromImage \
  --message-body '{"key": "imagen.jpg", "bucket": "s3-demo-sds-dh-dev"}'

# Enviar mensaje a la cola de thumbnails desde pdf
docker-compose run --rm aws-cli sqs send-message \
  --queue-url http://floci:4566/000000000000/doodle-dev-generateThumbnailsFromPdf \
  --message-body '{"key": "documento.pdf", "bucket": "s3-demo-sds-dh-dev"}'

# Enviar mensaje a la cola de conversión HTML
docker-compose run --rm aws-cli sqs send-message \
  --queue-url http://floci:4566/000000000000/pdf-converter-dev-html-conversion-queue \
  --message-body '{"key": "pagina.html", "bucket": "s3-demo-sds-dh-dev"}'

# Enviar mensaje a la cola de conversión Office
docker-compose run --rm aws-cli sqs send-message \
  --queue-url http://floci:4566/000000000000/pdf-converter-dev-office-conversion-queue \
  --message-body '{"key": "documento.docx", "bucket": "s3-demo-sds-dh-dev"}'

# Ver mensajes en una cola (sin consumirlos)
docker-compose run --rm aws-cli sqs receive-message \
  --queue-url http://floci:4566/000000000000/doodle-dev-generateThumbnailsFromImage
```

---

### Lambda — invocar funciones

```bash
# Invocar lambda Python A
docker-compose run --rm aws-cli lambda invoke \
  --function-name generateThumbnailsFromImage-dev \
  --payload '{"key": "imagen.jpg"}' \
  /tmp/response.json

# Invocar lambda Python B
docker-compose run --rm aws-cli lambda invoke \
  --function-name generateThumbnailsFromPdf-dev \
  --payload '{"key": "documento.pdf"}' \
  /tmp/response.json

# Invocar lambda Docker C
docker-compose run --rm aws-cli lambda invoke \
  --function-name SET-dev-Doodle-ConvertHtmlToPdf \
  --payload '{"key": "pagina.html"}' \
  /tmp/response.json

# Invocar lambda Docker D
docker-compose run --rm aws-cli lambda invoke \
  --function-name SET-dev-Doodle-ConvertMsDocToPdf \
  --payload '{"key": "documento.docx"}' \
  /tmp/response.json

# Ver logs de una lambda
docker-compose run --rm aws-cli logs filter-log-events \
  --log-group-name /aws/lambda/generateThumbnailsFromImage-dev
```

---

### ECR — repositorios de imágenes Docker

```bash
# Listar repositorios
docker-compose run --rm aws-cli ecr describe-repositories

# Login al registry de Floci
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  000000000000.dkr.ecr.us-east-1.localhost.floci.cloud:4566

# Tag y push de imagen al repo html
docker tag mi-imagen:latest \
  000000000000.dkr.ecr.us-east-1.localhost.floci.cloud:4566/pdf-converter-dev/document.conversion.html:latest

docker push \
  000000000000.dkr.ecr.us-east-1.localhost.floci.cloud:4566/pdf-converter-dev/document.conversion.html:latest

# Tag y push de imagen al repo office
docker tag mi-imagen:latest \
  000000000000.dkr.ecr.us-east-1.localhost.floci.cloud:4566/pdf-converter-dev/document.conversion.office:latest

docker push \
  000000000000.dkr.ecr.us-east-1.localhost.floci.cloud:4566/pdf-converter-dev/document.conversion.office:latest

# Actualizar image_uri de lambda Docker C después del push (paso Jenkins)
docker-compose run --rm aws-cli lambda update-function-code \
  --function-name SET-dev-Doodle-ConvertHtmlToPdf \
  --image-uri 000000000000.dkr.ecr.us-east-1.localhost.floci.cloud:4566/pdf-converter-dev/document.conversion.html:latest

# Actualizar image_uri de lambda Docker D después del push (paso Jenkins)
docker-compose run --rm aws-cli lambda update-function-code \
  --function-name SET-dev-Doodle-ConvertMsDocToPdf \
  --image-uri 000000000000.dkr.ecr.us-east-1.localhost.floci.cloud:4566/pdf-converter-dev/document.conversion.office:latest
```

---

## Verificar estado de Floci

```bash
# Health check
curl http://localhost:4566/health

# Ver todos los recursos creados
docker-compose run --rm aws-cli resourcegroupstaggingapi get-resources
```

---

## Actualizar código de Lambdas Python (A y B) — via contenedor aws-cli

Esto aplica tanto para LocalStack como para AWS real.

### Paso 1 — Empaquetar tu código en ZIP

```bash
zip -r function.zip index.py
```

### Paso 2 — Actualizar la lambda

```bash
# Lambda A — generateThumbnailsFromImage
docker-compose run --rm \
  -v $(pwd)/function.zip:/tmp/function.zip \
  aws-cli lambda update-function-code \
  --function-name generateThumbnailsFromImage-dev \
  --zip-file fileb:///tmp/function.zip

# Lambda B — generateThumbnailsFromPdf
docker-compose run --rm \
  -v $(pwd)/function.zip:/tmp/function.zip \
  aws-cli lambda update-function-code \
  --function-name generateThumbnailsFromPdf-dev \
  --zip-file fileb:///tmp/function.zip
```

### Paso 3 — Verificar

```bash
docker-compose run --rm aws-cli lambda invoke \
  --function-name generateThumbnailsFromImage-dev \
  --payload '{"test": "ok"}' \
  /tmp/response.json
```

---

## Actualizar image_uri de Lambdas Docker (C y D) — solo AWS real

Aplica únicamente cuando `TARGET_ENV=aws`.

El flujo es: `docker build` + `docker push` al ECR, luego actualizar el `image_uri` via aws-cli.

### Lambda C — ConvertHtmlToPdf

```bash
# Login al ECR
docker-compose run --rm aws-cli ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  {account_id}.dkr.ecr.us-east-1.amazonaws.com

# Build y push
docker build -t {account_id}.dkr.ecr.us-east-1.amazonaws.com/pdf-converter-staging/document.conversion.html:latest .
docker push {account_id}.dkr.ecr.us-east-1.amazonaws.com/pdf-converter-staging/document.conversion.html:latest

# Actualizar image_uri
docker-compose run --rm aws-cli lambda update-function-code \
  --function-name SET-staging-Doodle-ConvertHtmlToPdf \
  --image-uri {account_id}.dkr.ecr.us-east-1.amazonaws.com/pdf-converter-staging/document.conversion.html:latest
```

### Lambda D — ConvertMsDocToPdf

```bash
# Build y push
docker build -t {account_id}.dkr.ecr.us-east-1.amazonaws.com/pdf-converter-staging/document.conversion.office:latest .
docker push {account_id}.dkr.ecr.us-east-1.amazonaws.com/pdf-converter-staging/document.conversion.office:latest

# Actualizar image_uri
docker-compose run --rm aws-cli lambda update-function-code \
  --function-name SET-staging-Doodle-ConvertMsDocToPdf \
  --image-uri {account_id}.dkr.ecr.us-east-1.amazonaws.com/pdf-converter-staging/document.conversion.office:latest
```

> Reemplaza `{account_id}` con tu AWS Account ID y `staging` con el environment correspondiente.
> Terraform no revertirá estos cambios gracias al `lifecycle { ignore_changes = [image_uri] }`.

# LocalStack + AWS CLI + Terraform — Dev Environment

## El problema que resuelve

Los devs no siempre tienen cuenta AWS. Tú sí. La idea es que:
- **Devs** → setean `LOCALSTACK_AUTH_TOKEN` y hacen `docker-compose up` → todo corre en LocalStack
- **Tú / CI** → seteas credenciales AWS reales → el mismo stack apunta a AWS real

Un solo flujo, dos destinos.

---

## Estructura propuesta

```
localStack-aws/
├── docker-compose.yml              ← orquesta todo
├── .env.example                    ← variables que el dev debe copiar y setear
├── .env                            ← ignorado en git (credenciales reales)
├── infrastructure-dh/              ← código Terraform del proyecto
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── scripts/
│   ├── apply.sh                    ← Mac/Linux
│   ├── apply.bat                   ← Windows
│   ├── destroy.sh
│   └── destroy.bat
└── .aws/
    ├── config
    └── credentials                 ← solo para modo AWS real, ignorado en git
```

---

## Cómo funciona el switch LocalStack ↔ AWS

La clave está en `TARGET_ENV` dentro del `.env`:

| Variable | Modo dev (LocalStack) | Modo real (AWS) |
|---|---|---|
| `TARGET_ENV` | `localstack` | `aws` |
| `LOCALSTACK_AUTH_TOKEN` | tu token Pro | no se usa |
| `AWS_ACCESS_KEY_ID` | `test` | tu key real |
| `AWS_SECRET_ACCESS_KEY` | `test` | tu secret real |
| `AWS_DEFAULT_REGION` | `us-east-1` | la que uses |

---

## ¿Por qué LocalStack tiene `profiles` y Terraform depende de él?

**LocalStack solo levanta en modo `localstack`.**
Usando `profiles` en docker-compose, el servicio `localstack` no existe cuando haces un `docker-compose up` normal. Solo levanta si el profile `localstack` está activo — y el script `apply` lo activa automáticamente según `TARGET_ENV`.

**Terraform depende de LocalStack porque en modo dev apunta a `http://localstack:4566`.**
Si LocalStack no está corriendo, Terraform no puede conectar. El `depends_on` + healthcheck garantiza que Terraform no intente correr hasta que LocalStack esté listo y respondiendo.

Cuando `TARGET_ENV=aws`, Terraform usa endpoints normales de AWS — LocalStack nunca levanta, no hay dependencia.

---

## docker-compose.yml

```yaml
services:

  localstack:
    image: localstack/localstack-pro:4
    ports:
      - "4566:4566"
      - "4510-4559:4510-4559"  # port range for ECR and other services
    environment:
      - LOCALSTACK_AUTH_TOKEN=${LOCALSTACK_AUTH_TOKEN:-}
      - SERVICES=s3,sqs,lambda,ecr,iam
      - LAMBDA_EXECUTOR=docker            # run lambdas in real Docker containers
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - localstack-data:/var/lib/localstack
      - /var/run/docker.sock:/var/run/docker.sock  # needed for lambda docker executor and ECR
    profiles:
      - localstack
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4566/_localstack/health"]
      interval: 5s
      timeout: 5s
      retries: 10

  terraform:
    image: hashicorp/terraform:1.6
    working_dir: /workspace
    volumes:
      - ./infrastructure-dh:/workspace
      - ./.aws:/root/.aws:ro
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}
      - AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
      - TARGET_ENV=${TARGET_ENV:-localstack}
      - TF_ENDPOINT=${TF_ENDPOINT:-http://localstack:4566}
    depends_on:
      localstack:
        condition: service_healthy
    entrypoint: ["/bin/sh"]
    command: ["-c", "while true; do sleep 30; done"]

  aws-cli:
    image: amazon/aws-cli:latest
    working_dir: /workspace
    volumes:
      - ./infrastructure-dh:/workspace
      - ./.aws:/root/.aws:ro
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-test}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-test}
      - AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
      - AWS_ENDPOINT_URL=${TF_ENDPOINT:-http://localstack:4566}
    entrypoint: ["aws"]

volumes:
  localstack-data:
```

> **Nota:** el `depends_on` con `condition: service_healthy` solo aplica cuando el profile `localstack` está activo. En modo `aws`, el servicio `localstack` no existe y `terraform` levanta sin dependencias.

> **Windows:** el socket `/var/run/docker.sock` lo expone Docker Desktop automáticamente. No requiere configuración extra.

---

## Terraform provider condicional (infrastructure-dh/main.tf)

```hcl
variable "target_env" {
  default = "localstack"
}

variable "tf_endpoint" {
  default = "http://localstack:4566"
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = var.target_env == "localstack" ? "test" : null
  secret_key                  = var.target_env == "localstack" ? "test" : null
  skip_credentials_validation = var.target_env == "localstack"
  skip_metadata_api_check     = var.target_env == "localstack"
  skip_requesting_account_id  = var.target_env == "localstack"

  dynamic "endpoints" {
    for_each = var.target_env == "localstack" ? [1] : []
    content {
      s3      = var.tf_endpoint
      sqs     = var.tf_endpoint
      iam     = var.tf_endpoint
      lambda  = var.tf_endpoint
      ecr     = var.tf_endpoint
    }
  }
}
```

---

## .env.example

```bash
# --- LocalStack mode (devs) ---
TARGET_ENV=localstack
LOCALSTACK_AUTH_TOKEN=your_token_here
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
TF_ENDPOINT=http://localstack:4566

# --- AWS real mode (uncomment and fill) ---
# TARGET_ENV=aws
# AWS_ACCESS_KEY_ID=AKIA...
# AWS_SECRET_ACCESS_KEY=...
# AWS_DEFAULT_REGION=us-east-1
# TF_ENDPOINT=
```

---

## Scripts de apply

### scripts/apply.sh (Mac / Linux)

```bash
#!/bin/bash
set -e

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

# Load .env
if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi
export $(grep -v '^#' .env | xargs)

TARGET_ENV=${TARGET_ENV:-localstack}
PROFILES=""

if [ "$TARGET_ENV" = "localstack" ]; then
  PROFILES="--profile localstack"
  echo ">> Mode: LocalStack"
else
  echo ">> Mode: AWS real"
fi

echo ">> Starting services..."
docker-compose $PROFILES up -d

echo ">> Running Terraform..."
docker-compose exec terraform sh -c "
  terraform init &&
  terraform apply -auto-approve \
    -var='target_env=${TARGET_ENV}' \
    -var='tf_endpoint=${TF_ENDPOINT:-}'
"
```

### scripts/apply.bat (Windows)

```bat
@echo off
setlocal

REM Check Docker is running
docker info > nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running. Please start Docker Desktop and try again.
    exit /b 1
)

REM Check .env exists
if not exist .env (
    echo ERROR: .env file not found. Copy .env.example to .env and fill in your values.
    exit /b 1
)

REM Load .env variables
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    if not "%%A"=="" if not "%%A:~0,1%"=="#" set %%A=%%B
)

set PROFILES=
if "%TARGET_ENV%"=="localstack" (
    set PROFILES=--profile localstack
    echo ^>^> Mode: LocalStack
) else (
    echo ^>^> Mode: AWS real
)

echo ^>^> Starting services...
docker-compose %PROFILES% up -d

echo ^>^> Running Terraform...
docker-compose exec terraform sh -c "terraform init && terraform apply -auto-approve -var='target_env=%TARGET_ENV%' -var='tf_endpoint=%TF_ENDPOINT%'"
```

---

## Flujo completo del dev

```bash
# 1. Una sola vez — copiar y setear el token
cp .env.example .env
# editar .env: poner LOCALSTACK_AUTH_TOKEN

# 2. Mac/Linux
./scripts/apply.sh

# 2. Windows
scripts\apply.bat
```

Eso es todo. Docker levanta LocalStack, espera el healthcheck, levanta Terraform y aplica la IaC.

---

## Servicios incluidos y sus capacidades en LocalStack Pro

| Servicio | Soportado | Triggers | Notas |
|---|---|---|---|
| S3 | ✅ | S3 → Lambda event notification | igual que AWS |
| SQS | ✅ | SQS → Lambda trigger (`event_source_mapping`) | igual que AWS |
| Lambda | ✅ | desde S3, SQS, EventBridge | corre en contenedor Docker real |
| Lambda Layers | ✅ | — | `aws_lambda_layer_version` funciona igual |
| ECR | ✅ | — | registry local, push/pull de imágenes para Lambda container |
| IAM | ✅ | — | roles y policies para los recursos |

### Lambda con Docker en LocalStack

Con `LAMBDA_EXECUTOR=docker`, LocalStack levanta cada invocación de Lambda en un contenedor Docker real en tu máquina. Esto significa:
- El runtime es idéntico al de AWS (usa las mismas imágenes base de AWS)
- Puedes usar Lambda container images (ECR) o zip deployments
- Requiere el socket `/var/run/docker.sock` montado en LocalStack

### ECR en LocalStack

El registry local tiene esta URL:
```
000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566
```
Puedes hacer `docker build`, `docker tag` y `docker push` a ese registry igual que en AWS real.

---

## Pendiente definir

- Estructura de `infrastructure-dh/`: ¿un módulo por servicio o todo en root?

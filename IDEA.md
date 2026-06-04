# Floci + AWS CLI + Terraform — Dev Environment

## El problema que resuelve

Los devs no siempre tienen cuenta AWS. La idea es que:
- **Devs** → usan [Floci](https://floci.io/aws/) y hacen `docker-compose up` → todo corre localmente
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

## Cómo funciona el switch Floci ↔ AWS

La clave está en `TARGET_ENV` dentro del `.env`:

| Variable | Modo dev (Floci) | Modo real (AWS) |
|---|---|---|
| `TARGET_ENV` | `floci` | `aws` |
| `AWS_ACCESS_KEY_ID` | `test` | tu key real |
| `AWS_SECRET_ACCESS_KEY` | `test` | tu secret real |
| `AWS_DEFAULT_REGION` | `us-east-1` | la que uses |

---

## ¿Por qué Floci tiene `profiles` y Terraform depende de él?

**Floci solo levanta en modo `floci`.**
Usando `profiles` en docker-compose, el servicio `floci` no existe cuando haces un `docker-compose up` normal. Solo levanta si el profile `floci` está activo — y el script `apply` lo activa automáticamente según `TARGET_ENV`.

**Terraform depende de Floci porque en modo dev apunta a `http://floci:4566`.**
Si Floci no está corriendo, Terraform no puede conectar. El `depends_on` + healthcheck garantiza que Terraform no intente correr hasta que Floci esté listo y respondiendo.

Cuando `TARGET_ENV=aws`, Terraform usa endpoints normales de AWS — Floci nunca levanta, no hay dependencia.

---

## docker-compose.yml

```yaml
services:

  floci:
    image: floci/aws:latest
    ports:
      - "4566:4566"
    environment:
      - SERVICES=s3,sqs,lambda,ecr,iam
    volumes:
      - floci-data:/var/lib/floci
    profiles:
      - floci
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4566/health"]
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
      - TARGET_ENV=${TARGET_ENV:-floci}
      - TF_ENDPOINT=${TF_ENDPOINT:-http://floci:4566}
    depends_on:
      floci:
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
      - AWS_ENDPOINT_URL=${TF_ENDPOINT:-http://floci:4566}
    entrypoint: ["aws"]

volumes:
  floci-data:
```

> **Nota:** el `depends_on` con `condition: service_healthy` solo aplica cuando el profile `floci` está activo. En modo `aws`, el servicio `floci` no existe y `terraform` levanta sin dependencias.

> **Windows:** el socket de Docker lo expone Docker Desktop automáticamente. No requiere configuración extra.

---

## Terraform provider condicional (infrastructure-dh/main.tf)

```hcl
variable "target_env" {
  default = "floci"
}

variable "tf_endpoint" {
  default = "http://floci:4566"
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = var.target_env != "aws" ? "test" : null
  secret_key                  = var.target_env != "aws" ? "test" : null
  skip_credentials_validation = var.target_env != "aws"
  skip_metadata_api_check     = var.target_env != "aws"
  skip_requesting_account_id  = var.target_env != "aws"

  dynamic "endpoints" {
    for_each = var.target_env != "aws" ? [1] : []
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
# --- Floci mode (devs) ---
TARGET_ENV=floci
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
TF_ENDPOINT=http://floci:4566

# --- AWS real mode (uncomment and fill) ---
# TARGET_ENV=aws
# AWS_ACCESS_KEY_ID=AKIA...
# AWS_SECRET_ACCESS_KEY=...
# AWS_DEFAULT_REGION=us-east-1
# TF_ENDPOINT=
```

---

## Flujo completo del dev

```bash
# 1. Una sola vez
cp .env.example .env

# 2. Mac/Linux
./scripts/apply.sh

# 2. Windows
scripts\apply.bat
```

Docker levanta Floci, espera el healthcheck, levanta Terraform y aplica la IaC.

---

## Servicios incluidos

| Servicio | Floci | Notas |
|---|---|---|
| S3 | ✅ | S3 → Lambda event notification |
| SQS | ✅ | SQS → Lambda trigger (`event_source_mapping`) |
| Lambda | ✅ | desde S3, SQS |
| Lambda Layers | ✅ | `aws_lambda_layer_version` funciona igual |
| ECR | ✅ | registry local para Lambda container images |
| IAM | ✅ | roles y policies |

---

## Pendiente definir

- Estructura de `infrastructure-dh/`: ¿un módulo por servicio o todo en root?

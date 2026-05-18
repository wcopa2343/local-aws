# LocalStack AWS Dev Environment

Entorno local de desarrollo AWS usando LocalStack, Terraform y AWS CLI orquestados con Docker Compose.

## Cómo funciona

El switch entre LocalStack y AWS real se controla con `TARGET_ENV` en el `.env`:

| `TARGET_ENV` | Descripción |
|---|---|
| `localstack` | Levanta LocalStack, Terraform apunta a `http://localstack:4566` |
| `staging` / `prod` | No levanta LocalStack, Terraform apunta a AWS real |

## Estructura

```
localStack-aws/
├── docker-compose.yml        ← orquesta LocalStack, Terraform y AWS CLI
├── .env.example              ← copia esto a .env y llena tus valores
├── .aws/                     ← credenciales AWS real (solo modo aws)
├── infrastructure-dh/        ← código Terraform
│   ├── environments/         ← tfvars por ambiente (dev, staging, prod)
│   ├── modules/              ← storage, messaging, registry, compute, security
│   └── externalResource/     ← layer ZIP y terraform-policy.json
└── readme/                   ← documentación
```

## Inicio rápido

```bash
# 1. Configurar el entorno
cp .env.example .env
# editar .env: poner LOCALSTACK_AUTH_TOKEN

# 2. Levantar contenedores
docker-compose --profile localstack up -d

# 3. Crear infraestructura
docker-compose exec terraform sh -c "terraform init && terraform apply -auto-approve -var-file=environments/dev/terraform.tfvars"
```

## Documentación

- [IDEA.md](IDEA.md) — arquitectura y decisiones de diseño
- [readme/INFRASTRUCTURE_DH.md](readme/INFRASTRUCTURE_DH.md) — detalle de recursos Terraform
- [readme/MANUAL.md](readme/MANUAL.md) — comandos para usar S3, SQS, Lambda y ECR
- [readme/SPRINGBOOT_AND_LAMBDA.md](readme/SPRINGBOOT_AND_LAMBDA.md) — integración con Spring Boot

# Floci AWS Dev Environment

Entorno local de desarrollo AWS usando [Floci](https://floci.io/aws/), Terraform y AWS CLI orquestados con Docker Compose.

## Cómo funciona

El switch entre Floci y AWS real se controla con `TARGET_ENV` en el `.env`:

| `TARGET_ENV` | Descripción |
|---|---|
| `floci` | Levanta Floci, Terraform apunta a `http://floci:4566` |
| `staging` / `prod` | No levanta Floci, Terraform apunta a AWS real |

## Estructura

```
localStack-aws/
├── docker-compose.yml        ← orquesta Floci, Terraform y AWS CLI
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

# 2. Levantar contenedores
docker-compose --profile floci up -d

# 3. Crear infraestructura
docker-compose exec terraform sh -c "terraform init && terraform apply -auto-approve -var-file=environments/dev/terraform.tfvars"
```

## Documentación

- [IDEA.md](IDEA.md) — arquitectura y decisiones de diseño
- [readme/INFRASTRUCTURE_DH.md](readme/INFRASTRUCTURE_DH.md) — detalle de recursos Terraform
- [readme/MANUAL.md](readme/MANUAL.md) — comandos para usar S3, SQS, Lambda y ECR
- [readme/SPRINGBOOT_AND_LAMBDA.md](readme/SPRINGBOOT_AND_LAMBDA.md) — integración con Spring Boot

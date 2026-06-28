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

# 4. Desplegar Lambdas
cd deploy-dh
deploy-menu.bat
```

## Deploy de Lambdas

La carpeta `deploy-dh/` contiene scripts para desplegar las funciones Lambda:

### Usando el menú interactivo
```bash
cd deploy-dh
deploy-menu.bat
```

Opciones disponibles:
- **1** — Desplegar TODO (Lambdas Python + Docker)
- **2** — Solo Lambdas Python (thumbnail-from-img, thumbnail-from-pdf, split-pdf)
- **3** — Solo Lambdas Docker (ms-to-pdf, html-to-pdf)
- **0** — Salir

### Scripts disponibles
- `deploy-menu.bat` — Menú interactivo para elegir qué desplegar
- `deploy.bat` — Desplega todo (Python + Docker)
- `deploy-python-lambdas.bat` — Solo Lambdas Python
- `deploy-docker-lambdas.bat` — Solo Lambdas Docker

## Documentación

- [COMANDOS_BASICOS.md](readme/COMANDOS_BASICOS.md) — comandos útiles para S3, Lambda, ECR, SQS y logs

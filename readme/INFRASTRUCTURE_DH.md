# Infrastructure DH — Requerimiento Terraform

## Estructura de módulos

```
infrastructure-dh/
├── environments/
│   ├── dev/
│   │   └── terraform.tfvars
│   ├── staging/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
├── modules/
│   ├── storage/          ← S3
│   ├── messaging/        ← SQS x4
│   ├── registry/         ← ECR x2
│   ├── compute/          ← Lambdas x4 + Layer
│   └── security/         ← Rol IAM + Policy Terraform
├── externalResource/
│   ├── layer_thumbnail.zip        ← layer ya listo
│   └── terraform-policy.json      ← permisos para el user de Terraform
├── main.tf
├── variables.tf
├── outputs.tf
└── providers.tf
```

---

## Convención de nombres

| Recurso | Patrón |
|---|---|
| Lambda Python | `{name}-{env}` |
| Lambda Docker | `SET-{env}-Doodle-{name}` |
| SQS | `{prefix}-{env}-{name}` |
| ECR | `{prefix}-{env}/{name}` |
| IAM Role | `role-dh-lambda-{env}` |
| Layer | `layer-thumbnail-{env}` |
| S3 | `s3-demo-sds-dh-{env}` |

---

## Recursos a crear

### Layer
| Campo | Valor |
|---|---|
| Nombre | `layer-thumbnail-{env}` |
| Runtime compatible | Python 3.10 |
| Fuente | `externalResource/layer_thumbnail.zip` |
| Gestionado por | Terraform (`aws_lambda_layer_version`) — sube el ZIP directamente |
| Usado por | Lambdas A y B |

---

### S3 Bucket
| Campo | Valor |
|---|---|
| Nombre | `s3-demo-sds-dh-{env}` |
| Lifecycle rule | Expiración + Delete a los 7 días |

---

### SQS Queues (x4)
| Nombre | Trigger de |
|---|---|
| `doodle-{env}-generateThumbnailsFromImage` | Lambda A |
| `doodle-{env}-generateThumbnailsFromPdf` | Lambda B |
| `pdf-converter-{env}-html-conversion-queue` | Lambda C |
| `pdf-converter-{env}-office-conversion-queue` | Lambda D |

---

### ECR Repositories (x2)
| Nombre | Usado por |
|---|---|
| `pdf-converter-{env}/document.conversion.html` | Lambda C |
| `pdf-converter-{env}/document.conversion.office` | Lambda D |

> Terraform crea los repositorios. El `docker push` de las imágenes lo hace el pipeline CI/CD (Jenkins), no Terraform.

**Estrategia de deploy: Placeholder (Estrategia 1)**

Flujo:
```
1. terraform apply  → crea ECR + Lambda con imagen placeholder
2. Jenkins          → docker build + push al ECR
3. Jenkins          → aws lambda update-function-code (apunta a imagen real)
```

Las Lambdas C y D se crean con `image_uri = "public.ecr.aws/lambda/python:3.10"` (imagen oficial base de AWS Lambda). Con `lifecycle { ignore_changes = [image_uri] }`, Terraform nunca revierte la imagen que Jenkins pusheó en futuros `apply`.

El `destroy` elimina todo limpio — `ignore_changes` no protege el recurso de ser destruido, solo evita que Terraform sobreescriba el campo `image_uri` durante un `apply`.

---

### Lambdas

#### A — generateThumbnailsFromImage
| Campo | Valor |
|---|---|
| Nombre | `generateThumbnailsFromImage-{env}` |
| Runtime | Python 3.10 |
| Layer | `layer-thumbnail-{env}` |
| Trigger SQS | `doodle-{env}-generateThumbnailsFromImage` |
| Rol | `role-dh-lambda-{env}` |
| Código inicial | placeholder con `print("Hello from Terraform")` |

#### B — generateThumbnailsFromPdf
| Campo | Valor |
|---|---|
| Nombre | `generateThumbnailsFromPdf-{env}` |
| Runtime | Python 3.10 |
| Layer | `layer-thumbnail-{env}` |
| Trigger SQS | `doodle-{env}-generateThumbnailsFromPdf` |
| Rol | `role-dh-lambda-{env}` |
| Código inicial | placeholder con `print("Hello from Terraform")` |

#### C — SET-{env}-Doodle-ConvertHtmlToPdf
| Campo | Valor |
|---|---|
| Nombre | `SET-{env}-Doodle-ConvertHtmlToPdf` |
| Runtime | Docker (`package_type = "Image"`) |
| Image URI inicial | `public.ecr.aws/lambda/python:3.10` (placeholder) |
| Image URI real | `{account}.dkr.ecr.{region}.amazonaws.com/pdf-converter-{env}/document.conversion.html:latest` |
| Trigger SQS | `pdf-converter-{env}-html-conversion-queue` |
| Rol | `role-dh-lambda-{env}` |

#### D — SET-{env}-Doodle-ConvertMsDocToPdf
| Campo | Valor |
|---|---|
| Nombre | `SET-{env}-Doodle-ConvertMsDocToPdf` |
| Runtime | Docker (`package_type = "Image"`) |
| Image URI inicial | `public.ecr.aws/lambda/python:3.10` (placeholder) |
| Image URI real | `{account}.dkr.ecr.{region}.amazonaws.com/pdf-converter-{env}/document.conversion.office:latest` |
| Trigger SQS | `pdf-converter-{env}-office-conversion-queue` |
| Rol | `role-dh-lambda-{env}` |

---

### IAM

#### Rol único: role-dh-lambda-{env}
Las 4 lambdas son del mismo proyecto y team, comparten un solo rol con política scoped al proyecto.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Access",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::s3-demo-sds-dh-{env}",
        "arn:aws:s3:::s3-demo-sds-dh-{env}/*"
      ]
    },
    {
      "Sid": "SQSAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
      ],
      "Resource": [
        "arn:aws:sqs:{region}:*:doodle-{env}-*",
        "arn:aws:sqs:{region}:*:pdf-converter-{env}-*"
      ]
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/lambda/*"
    }
  ]
}
```

#### terraform-policy.json — Permisos del usuario Terraform
Archivo: `externalResource/terraform-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LambdaScoped",
      "Effect": "Allow",
      "Action": ["lambda:*"],
      "Resource": [
        "arn:aws:lambda:*:*:function:generateThumbnails*",
        "arn:aws:lambda:*:*:function:SET-*-Doodle-*",
        "arn:aws:lambda:*:*:layer:layer-thumbnail-*"
      ]
    },
    {
      "Sid": "LambdaEventSourceMapping",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateEventSourceMapping",
        "lambda:DeleteEventSourceMapping",
        "lambda:GetEventSourceMapping",
        "lambda:ListEventSourceMappings",
        "lambda:UpdateEventSourceMapping"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3Scoped",
      "Effect": "Allow",
      "Action": ["s3:*"],
      "Resource": [
        "arn:aws:s3:::s3-demo-sds-dh-*",
        "arn:aws:s3:::s3-demo-sds-dh-*/*"
      ]
    },
    {
      "Sid": "SQSScoped",
      "Effect": "Allow",
      "Action": ["sqs:*"],
      "Resource": [
        "arn:aws:sqs:*:*:doodle-*",
        "arn:aws:sqs:*:*:pdf-converter-*"
      ]
    },
    {
      "Sid": "ECRScoped",
      "Effect": "Allow",
      "Action": ["ecr:*"],
      "Resource": "arn:aws:ecr:*:*:repository/pdf-converter-*"
    },
    {
      "Sid": "ECRAuthToken",
      "Effect": "Allow",
      "Action": ["ecr:GetAuthorizationToken"],
      "Resource": "*"
    },
    {
      "Sid": "IAMScoped",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:TagRole"
      ],
      "Resource": "arn:aws:iam::*:role/role-dh-lambda-*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:ListTagsLogGroup",
        "logs:PutRetentionPolicy"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/lambda/*"
    },
    {
      "Sid": "STSCallerIdentity",
      "Effect": "Allow",
      "Action": ["sts:GetCallerIdentity"],
      "Resource": "*"
    }
  ]
}
```

---

## Orden de creación
Terraform lo resuelve automáticamente por el grafo de dependencias — no hay que especificar orden en `main.tf`. Para referencia:

```
1. S3
2. SQS x4
3. ECR x2
4. Layer (Terraform sube el ZIP)
5. IAM Role
6. Lambdas x4
7. Event Source Mappings x4 (SQS → Lambda)
```

---

## Preguntas resueltas
_(para borrar una vez confirmadas)_

- **¿Terraform sube el Layer ZIP?** Sí, `aws_lambda_layer_version` lo sube directo. No necesitas Jenkins.
- **¿Hay que especificar orden en main.tf?** No. Terraform infiere el orden por las referencias entre recursos (`aws_sqs_queue.x.arn` referenciado en el `event_source_mapping` ya le dice a Terraform que el SQS va primero).
- **¿Un rol o dos?** Un solo rol `role-dh-lambda-{env}` para las 4 lambdas — mismo proyecto, mismo team.
- **¿Las lambdas Docker necesitan imagen pusheada antes de crearse?** Sí, AWS/LocalStack rechaza la lambda si el ECR está vacío. Solución: imagen placeholder pública en la creación inicial + `lifecycle { ignore_changes = [image_uri] }` para que el pipeline actualice sin que Terraform lo pise.
- **¿El S3 lleva {env} en el nombre?** Sí, todos los recursos llevan `{env}`.

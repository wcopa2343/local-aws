#!/bin/bash
set -e

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

# Check .env exists
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

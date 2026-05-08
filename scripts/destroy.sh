#!/bin/bash
set -e

if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

export $(grep -v '^#' .env | xargs)

TARGET_ENV=${TARGET_ENV:-localstack}

echo ">> Mode: ${TARGET_ENV}"
echo ">> Running Terraform destroy..."
docker-compose exec terraform sh -c "
  terraform destroy -auto-approve \
    -var='target_env=${TARGET_ENV}' \
    -var='tf_endpoint=${TF_ENDPOINT:-}'
"

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

REM Load .env variables (skip comments and empty lines)
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    set "line=%%A"
    if not "!line:~0,1!"=="#" if not "%%A"=="" set %%A=%%B
)

echo ^>^> Mode: %TARGET_ENV%
echo ^>^> Running Terraform destroy...
docker-compose exec terraform sh -c "terraform destroy -auto-approve -var='target_env=%TARGET_ENV%' -var='tf_endpoint=%TF_ENDPOINT%'"

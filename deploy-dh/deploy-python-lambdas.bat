@echo off
setlocal
cd ..
set ENDPOINT=http://floci:4566
set VERSION=0.0.0.SNAPSHOT

echo ===== Deploy Python Lambdas =====

echo [1/3] thumbnail-from-img...
cd lambdas-code-dh\thumbnail-from-img
if not exist function.zip powershell Compress-Archive -Force -Path index.py -DestinationPath function.zip
cd ..\..
docker-compose run --rm aws-cli lambda update-function-code ^
  --function-name generateThumbnailsFromImage-dev ^
  --zip-file fileb:///workspace/lambdas-code-dh/thumbnail-from-img/function.zip ^
  --endpoint-url=%ENDPOINT% ^
  --query FunctionArn ^
  --output text

echo [2/3] thumbnail-from-pdf...
cd lambdas-code-dh\thumbnail-from-pdf
if not exist function.zip powershell Compress-Archive -Force -Path index.py -DestinationPath function.zip
cd ..\..
docker-compose run --rm aws-cli lambda update-function-code ^
  --function-name generateThumbnailsFromPdf-dev ^
  --zip-file fileb:///workspace/lambdas-code-dh/thumbnail-from-pdf/function.zip ^
  --endpoint-url=%ENDPOINT% ^
  --query FunctionArn ^
  --output text

echo [3/3] split-pdf...
cd lambdas-code-dh\split-pdf
if not exist function.zip powershell Compress-Archive -Force -Path index.py -DestinationPath function.zip
cd ..\..
docker-compose run --rm aws-cli lambda update-function-code ^
  --function-name SET-dev-splitPdfToImages ^
  --zip-file fileb:///workspace/lambdas-code-dh/split-pdf/function.zip ^
  --endpoint-url=%ENDPOINT% ^
  --query FunctionArn ^
  --output text

echo.
echo ===== Done =====
endlocal


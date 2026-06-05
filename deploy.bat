@echo off
setlocal
set ENDPOINT=http://floci:4566
set VERSION=0.0.0.SNAPSHOT

echo ===== Deploy Python Lambdas =====

echo [1/3] Zipping thumbnail-from-img...
cd lambdas-code-dh\thumbnail-from-img
powershell Compress-Archive -Force -Path index.py -DestinationPath function.zip
cd ..\..
docker-compose run --rm aws-cli lambda update-function-code ^
  --function-name generateThumbnailsFromImage-dev ^
  --zip-file fileb:///workspace/lambdas-code-dh/thumbnail-from-img/function.zip ^
  --endpoint-url=%ENDPOINT%

echo [2/3] Zipping thumbnail-from-pdf...
cd lambdas-code-dh\thumbnail-from-pdf
powershell Compress-Archive -Force -Path index.py -DestinationPath function.zip
cd ..\..
docker-compose run --rm aws-cli lambda update-function-code ^
  --function-name generateThumbnailsFromPdf-dev ^
  --zip-file fileb:///workspace/lambdas-code-dh/thumbnail-from-pdf/function.zip ^
  --endpoint-url=%ENDPOINT%

echo [3/3] Zipping split-pdf...
cd lambdas-code-dh\split-pdf
powershell Compress-Archive -Force -Path index.py -DestinationPath function.zip
cd ..\..
docker-compose run --rm aws-cli lambda update-function-code ^
  --function-name splitFromPdf-dev ^
  --zip-file fileb:///workspace/lambdas-code-dh/split-pdf/function.zip ^
  --endpoint-url=%ENDPOINT%

echo.
echo ===== Deploy Docker Lambdas =====

echo [1/2] Building document-conversion-office...
cd lambdas-code-dh\ms-to-pdf
docker build -t document-conversion-office:%VERSION% .
docker tag document-conversion-office:%VERSION% document-conversion-office:latest
docker tag document-conversion-office:latest pdf-converter-dev/document.conversion.office:latest
cd ..\..
docker-compose run --rm aws-cli lambda update-function-code ^
  --function-name SET-dev-Doodle-ConvertMsDocToPdf ^
  --image-uri pdf-converter-dev/document.conversion.office:latest ^
  --endpoint-url=%ENDPOINT%
docker-compose run --rm aws-cli lambda get-function ^
  --function-name SET-dev-Doodle-ConvertMsDocToPdf ^
  --endpoint-url=%ENDPOINT%

echo [2/2] Building document-conversion-html...
cd lambdas-code-dh\html-to-pdf
docker build -t document-conversion-html:%VERSION% .
docker tag document-conversion-html:%VERSION% document-conversion-html:latest
docker tag document-conversion-html:latest pdf-converter-dev/document.conversion.html:latest
cd ..\..
docker-compose run --rm aws-cli lambda update-function-code ^
  --function-name SET-dev-Doodle-ConvertHtmlToPdf ^
  --image-uri pdf-converter-dev/document.conversion.html:latest ^
  --endpoint-url=%ENDPOINT%
docker-compose run --rm aws-cli lambda get-function ^
  --function-name SET-dev-Doodle-ConvertHtmlToPdf ^
  --endpoint-url=%ENDPOINT%

echo.
echo ===== Done =====
endlocal

@echo off
setlocal enabledelayedexpansion

:menu
cls
echo.
echo =====================================
echo     DEPLOY LAMBDAS - MENU
echo =====================================
echo.
echo 1) Desplegar TODO (Python + Docker)
echo 2) Solo Lambdas Python
echo 3) Solo Lambdas Docker
echo 0) Salir
echo.
echo =====================================
set /p option="Selecciona una opcion (0-3): "

if "%option%"=="1" (
    call deploy.bat
    endlocal
    exit /b %errorlevel%
) else if "%option%"=="2" (
    call deploy-python-lambdas.bat
    endlocal
    exit /b %errorlevel%
) else if "%option%"=="3" (
    call deploy-docker-lambdas.bat
    endlocal
    exit /b %errorlevel%
) else if "%option%"=="0" (
    endlocal
    exit /b
) else (
    echo.
    echo ERROR: Opcion invalida. Intenta de nuevo.
    timeout /t 2 /nobreak
    goto menu
)

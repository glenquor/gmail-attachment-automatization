@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ===================================================================================
echo  Verificando librerias requeridas...
echo ===================================================================================

set "NEED_SETUP=0"
if not exist "%~dp0libs\MailKit.dll" set "NEED_SETUP=1"
if not exist "%~dp0libs\MimeKit.dll" set "NEED_SETUP=1"

if "%NEED_SETUP%"=="1" (
    echo [!] Librerias faltantes. Ejecutando setup-libraries.ps1...
    echo.
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-libraries.ps1"
    
    if errorlevel 1 (
        echo.
        echo [ERROR] La instalacion de librerias fallo. Abortando proceso.
        goto :FIN
    )
    echo.
    echo [OK] Librerias instaladas correctamente. Continuando con la descarga...
    echo.
) else (
    echo [OK] Librerias ya instaladas. Saltando setup...
    echo.
)

pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0descargar_facturas_gmail.ps1"

:FIN
echo.
echo Presiona cualquier tecla para cerrar esta ventana.
pause >nul
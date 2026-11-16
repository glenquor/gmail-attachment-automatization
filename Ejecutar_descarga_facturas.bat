@echo off
chcp 65001 >nul
cd /d "%~dp0"

:: Limpiar cualquier archivo temporal previo por seguridad
set "TEMP_PATH_FILE=%TEMP%\ultima_ruta_facturas.txt"
if exist "%TEMP_PATH_FILE%" del /f /q "%TEMP_PATH_FILE%"

echo ===================================================================================
echo  Verificando librerias requeridas...
echo ===================================================================================

set "NEED_SETUP=0"
if not exist "%~dp0scripts\libs\MailKit.dll" set "NEED_SETUP=1"
if not exist "%~dp0scripts\libs\MimeKit.dll" set "NEED_SETUP=1"

if "%NEED_SETUP%"=="1" (
    echo [!] Librerias faltantes. Ejecutando setup-libraries.ps1...
    echo.
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-libraries.ps1"
    
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

pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\descargar_facturas_gmail.ps1"

:FIN
echo.
echo Presiona cualquier tecla para cerrar esta ventana.
pause >nul

:: Leer la ruta que dejo PowerShell y abrir la carpeta si el proceso termino bien
if exist "%TEMP_PATH_FILE%" (
    set /p TARGET_FOLDER=<"%TEMP_PATH_FILE%"
    del /f /q "%TEMP_PATH_FILE%"
)

if defined TARGET_FOLDER (
    if exist "%TARGET_FOLDER%" (
        start "" "%TARGET_FOLDER%"
    )
)
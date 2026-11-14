@echo off
cd /d "%~dp0"

pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-libraries.ps1"

echo Presiona cualquier tecla para cerrar esta ventana.
pause >nul
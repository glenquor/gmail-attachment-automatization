@echo off
cd /d "%~dp0"

pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0descargar_facturas_gmail.ps1"

echo Presiona cualquier tecla para cerrar esta ventana.
pause >nul
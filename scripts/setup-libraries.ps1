# ============================================================================
# setup-libraries.ps1
#
# Run this ONCE to download the required MailKit/MimeKit libraries.
#
# This script downloads only the explicitly specified NuGet packages from
# nuget.org and extracts the required DLLs into .\libs.
# ============================================================================

$ErrorActionPreference = "Stop"

$projectPath = $PSScriptRoot
$libPath     = Join-Path $projectPath "libs"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Fixed versions
$packages = @(
    @{
        Name    = "MailKit"
        Version = "4.18.2"
    },
    @{
        Name    = "MimeKit"
        Version = "4.18.2"
    }
)

# ---------------------------------------------------------------------------
# Prepare directory
# ---------------------------------------------------------------------------

if (-not (Test-Path $libPath)) {
    New-Item -ItemType Directory -Path $libPath -Force | Out-Null
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Setup de librerías MailKit/MimeKit" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

foreach ($package in $packages) {

    $name    = $package.Name
    $version = $package.Version

    $zipFile       = Join-Path $libPath "$name-$version.zip"
    $extractPath   = Join-Path $libPath "_$name-$version"
    $downloadUrl   = "https://www.nuget.org/api/v2/package/$name/$version"

    Write-Host "Paquete: $name $version" -ForegroundColor Yellow
    Write-Host "URL:     $downloadUrl"

    try {
        Write-Host "Descargando..." -ForegroundColor Cyan

        Invoke-WebRequest `
            -Uri $downloadUrl `
            -OutFile $zipFile `
            -UseBasicParsing

        Write-Host "Descargado exitosamente." -ForegroundColor Green

        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
        }

        Expand-Archive `
            -Path $zipFile `
            -DestinationPath $extractPath `
            -Force

        # Prefer a modern .NET Standard build.
        $dll = Get-ChildItem `
            -Path (Join-Path $extractPath "lib") `
            -Recurse `
            -Filter "$name.dll" |
            Where-Object {
                $_.DirectoryName -match "netstandard2\.0|netstandard2\.1|net6\.0|net7\.0|net8\.0|net9\.0"
            } |
            Select-Object -First 1

        if (-not $dll) {
            throw "Could not find $name.dll in the downloaded NuGet package."
        }

        Copy-Item `
            -Path $dll.FullName `
            -Destination $libPath `
            -Force

        Write-Host "Instalado: $($dll.FullName)" -ForegroundColor Green

        # Clean up
        Remove-Item $zipFile -Force
        Remove-Item $extractPath -Recurse -Force

        Write-Host ""
    }
    catch {
        Write-Host ""
        Write-Host "ERROR instalando $name $version" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        if (Test-Path $zipFile) {
            Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        exit 1
    }
}

Write-Host "============================================================" -ForegroundColor Green
Write-Host " Las librarías se instalaron correctamente." -ForegroundColor Green
Write-Host " Este archivo no debe ejecutarse nuevamente." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Get-ChildItem $libPath -Filter "*.dll" |
    Select-Object Name, Length |
    Format-Table -AutoSize

Write-Host ""
Write-Host "La automatización de descarga de correos no descargará estas librerías de nuevo." -ForegroundColor Cyan
Write-Host ""
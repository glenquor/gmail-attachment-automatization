
# ============================================================================
# setup-libraries.ps1
#
# Resolves and downloads MailKit, MimeKit and all transitive dependencies.
# Requires PowerShell 7.4+ and the .NET 8 SDK or later.
# ============================================================================

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Validate PowerShell
# ---------------------------------------------------------------------------

if ($PSVersionTable.PSVersion -lt [version]"7.4") {
    throw "PowerShell 7.4 or later is required."
}

# ---------------------------------------------------------------------------
# Validate .NET SDK
# ---------------------------------------------------------------------------

$dotnet = Get-Command "dotnet" -ErrorAction SilentlyContinue

if (-not $dotnet) {
    throw "The .NET SDK is required. Install it from https://dotnet.microsoft.com/download"
}

$sdks = & dotnet --list-sdks

if ($LASTEXITCODE -ne 0 -or -not $sdks) {
    throw "No .NET SDK was found. Install the .NET 8 SDK or later."
}

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

$projectPath = $PSScriptRoot
$libPath = Join-Path $projectPath "libs"

$tempPath = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ([guid]::NewGuid().ToString())

$publishPath = Join-Path $tempPath "publish"

$packageVersion = "4.18.2"

# ---------------------------------------------------------------------------
# Prepare temporary project
# ---------------------------------------------------------------------------

try {

    New-Item -ItemType Directory -Path $tempPath -Force |
        Out-Null

    $projectFile = Join-Path $tempPath "DependencyBootstrap.csproj"
    $programFile = Join-Path $tempPath "Program.cs"

    $projectContent = @"
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="MailKit" Version="$packageVersion" />
    <PackageReference Include="MimeKit" Version="$packageVersion" />
  </ItemGroup>

</Project>
"@

    Set-Content -Path $projectFile -Value $projectContent -Encoding utf8

    Set-Content `
        -Path $programFile `
        -Value 'Console.WriteLine("Dependencies restored.");' `
        -Encoding utf8

    # -----------------------------------------------------------------------
    # Restore and publish
    # -----------------------------------------------------------------------

    Write-Host ""
    Write-Host "Resolviendo dependencias NuGet..." -ForegroundColor Cyan

    & dotnet publish $projectFile `
        --configuration Release `
        --framework net8.0 `
        --output $publishPath `
        --verbosity minimal

    if ($LASTEXITCODE -ne 0) {
        throw "NuGet restore or publishing failed."
    }

    # -----------------------------------------------------------------------
    # Validate published assemblies
    # -----------------------------------------------------------------------

    $requiredDlls = @(
        "MailKit.dll",
        "MimeKit.dll"
    )

    foreach ($dllName in $requiredDlls) {

        $dllPath = Join-Path $publishPath $dllName

        if (-not (Test-Path $dllPath -PathType Leaf)) {
            throw "Required assembly not found: $dllName"
        }
    }

    # -----------------------------------------------------------------------
    # Copy dependencies
    # -----------------------------------------------------------------------

    $dllFiles = Get-ChildItem `
        -Path $publishPath `
        -Filter "*.dll" `
        -File |
        Where-Object {
            $_.Name -ne "DependencyBootstrap.dll"
        }

    if (-not (Test-Path $libPath)) {
        New-Item -ItemType Directory -Path $libPath -Force |
            Out-Null
    }

    # Remove previous DLLs only after successful publishing.
    Get-ChildItem -Path $libPath -Filter "*.dll" -File |
        Remove-Item -Force

    foreach ($dll in $dllFiles) {

        Copy-Item `
            -Path $dll.FullName `
            -Destination $libPath `
            -Force
    }

    Write-Host ""
    Write-Host "Libraries installed successfully." -ForegroundColor Green

    Get-ChildItem $libPath -Filter "*.dll" |
        Select-Object Name, Length |
        Format-Table -AutoSize

}
catch {

    Write-Host ""
    Write-Host "ERROR installing libraries:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1

}
finally {

    if (Test-Path $tempPath) {
        Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# gmail-download.ps1
#
# Downloads PDF/XML attachments from specific Gmail labels for a selected
# month and year.
#
# IMPORTANT:
# - This script does NOT download libraries.
# - This script does NOT execute email attachments.
# - Gmail is accessed using IMAP over TLS.
# - Gmail folders are opened read-only.
# - Only .pdf and .xml attachments are saved.
# ============================================================================

# ============================================================================
# To run this script is recommended to use PowerShell 7 or later.
#
# To install it run the following steps in an elevated PowerShell prompt:
#
# 1. winget install --id Microsoft.PowerShell --source winget
# 2. Close the current PowerShell window and open a new one.
# 3. Run this command to check the version: $PSVersionTable
#
# If WinGet isn't available, download the installer from: 
# https://github.com/PowerShell/PowerShell/releases/tag/v7.7.0
# ============================================================================

$ErrorActionPreference = "Stop"

# ============================================================================
# Configuration
# ============================================================================

$projectPath = $PSScriptRoot

$credPath = Join-Path $projectPath "gmail_cred.xml"
$libPath  = Join-Path $projectPath "libs"

# Where the downloaded invoices will be stored.
$outputRoot = $env:SystemDrive

# Gmail labels to process.
$clients = @(
    "Daniel Rivera",
    "Sofia Martinez",
    "Lucas Thompson",
    "Emma Johnson",
    "Mateo Gonzalez",
    "Olivia Brown",
    "Noah Wilson",
    "Isabella Lopez",
    "Ethan Clark",
    "Camila Morales",
    "Glen"
)

$months = @{
    1  = "Enero"
    2  = "Febrero"
    3  = "Marzo"
    4  = "Abril"
    5  = "Mayo"
    6  = "Junio"
    7  = "Julio"
    8  = "Agosto"
    9  = "Septiembre"
    10 = "Octubre"
    11 = "Noviembre"
    12 = "Diciembre"
}

# ============================================================================
# Helper: validated integer input
# ============================================================================

function Get-ValidInteger {
    param (
        [string]$PromptMessage,
        [int]$Min,
        [int]$Max,
        [string]$RangeHint
    )

    [int]$parsedValue = 0

    do {
        $rawInput = Read-Host $PromptMessage
        if (
            [int]::TryParse($rawInput, [ref]$parsedValue) -and
            $parsedValue -ge $Min -and
            $parsedValue -le $Max
        ) {
            return $parsedValue
        }

        Write-Host ""
        Write-Host "=> Error: '$rawInput' no es un valor válido." -ForegroundColor Red
        Write-Host "   Por favor ingrese un número entero $RangeHint"
        Write-Host ""
    }
    while ($true)
}

# ============================================================================
# Helper: create folder
# ============================================================================

function Ensure-Folder {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path -PathType Container)) {
        New-Item `
            -ItemType Directory `
            -Path $Path `
            -Force |
            Out-Null
    }
}

# ============================================================================
# Header
# ============================================================================

# Cleans the console
clear

Write-Host ""
Write-Host "-----------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " Automatización de descarga de facturas desde Gmail" -ForegroundColor Cyan
Write-Host "-----------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Ask for year/month
# ============================================================================

# First check the PowerShell version to ensure compatibility with the script.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "ERROR: Version incompatible de PowerShell." -ForegroundColor Red
    Write-Host "Version actual: PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "Version requerida: PowerShell 7 o mayor." -ForegroundColor Yellow
    Write-Host "Por favor ejecuta este script usando: 'pwsh'." -ForegroundColor Yellow
    Write-Host "Si el error continua, instala la version de PowerShell 7 o mayor.`n" -ForegroundColor Yellow
    exit 1
}

$year = Get-ValidInteger `
    -PromptMessage "Ingrese el año" `
    -Min 2000 `
    -Max 2050 `
    -RangeHint "que esté en el rango que va desde 2000 a 2050"

$month = Get-ValidInteger `
    -PromptMessage "Ingrese el número del mes" `
    -Min 1 `
    -Max 12 `
    -RangeHint "que represente un mes entre 1 y 12"

$monthName = $months[$month]

# ============================================================================
# Calculate exact date range
# ============================================================================

$startDate = Get-Date `
    -Year $year `
    -Month $month `
    -Day 1 `
    -Hour 0 `
    -Minute 0 `
    -Second 0 `
    -Millisecond 0

$endDate = $startDate.AddMonths(1)

Write-Host ""
Write-Host "Procesando: $monthName $year" -ForegroundColor Cyan
Write-Host "Desde:      $($startDate.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Hasta:      $($endDate.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host ""

# ============================================================================
# Validate credential file
# ============================================================================

if (-not (Test-Path $credPath -PathType Leaf)) {
    Write-Host "ERROR: No se encontró el archivo de credenciales:" -ForegroundColor Red
    Write-Host $credPath -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Créalo una sola vez con:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Get-Credential | Export-Clixml -Path '$credPath'"
    Write-Host ""

    exit 1
}

# ============================================================================
# Validate libraries
# ============================================================================

$mailKitDll = Join-Path $libPath "MailKit.dll"
$mimeKitDll = Join-Path $libPath "MimeKit.dll"

if (-not (Test-Path $mailKitDll -PathType Leaf)) {
    Write-Host "ERROR: No se encontró la libraría MailKit.dll:" -ForegroundColor Red
    Write-Host $mailKitDll -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Ejecute primero el archivo 'setup-libraries.ps1'." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if (-not (Test-Path $mimeKitDll -PathType Leaf)) {
    Write-Host "ERROR: No se encontró la libraría MimeKit.dll:" -ForegroundColor Red
    Write-Host $mimeKitDll -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Ejecute primero el archivo 'setup-libraries.ps1'." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# ============================================================================
# Load libraries
# ============================================================================

Write-Host "Cargando librerías..." -ForegroundColor Cyan

try {
    # Load all DLLs from the local libs directory.
    #
    # IMPORTANT:
    # These DLLs were installed separately by setup-libraries.ps1.
    # Nothing is downloaded here.

    Get-ChildItem `
        -Path $libPath `
        -Filter "*.dll" |
        Sort-Object Name |
        ForEach-Object {

            Write-Host "  Loading $($_.Name)..."

            Add-Type `
                -Path $_.FullName `
                -ErrorAction Stop
        }

}
catch {
    Write-Host ""
    Write-Host "ERROR: No se pudieron cargar las librerías." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "Librerías cargadas correctamente." -ForegroundColor Green
Write-Host ""

# ============================================================================
# Import credentials
# ============================================================================

try {
    $credential = Import-Clixml -Path $credPath

    $emailUser = $credential.UserName

    $appPassword = $credential.GetNetworkCredential().Password

    # Remove spaces in case the password was entered with spaces.
    $appPassword = $appPassword -replace '\s', ''
}
catch {
    Write-Host "ERROR: No se pudieron leer las credenciales." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    exit 1
}

# ============================================================================
# Prepare output directories
# ============================================================================

$parentFolderName = "111. Contas Yuli $year"
$parentFolderPath = Join-Path $outputRoot $parentFolderName

Ensure-Folder -Path $parentFolderPath

# ============================================================================
# Create Gmail IMAP client
# ============================================================================

$imapClient = [MailKit.Net.Imap.ImapClient]::new()

try {

    # ------------------------------------------------------------------------
    # Connect
    # ------------------------------------------------------------------------

    Write-Host "Conectando a Gmail ($emailUser)..." -ForegroundColor Yellow

    # Port 993 + SSL/TLS.
    $imapClient.Connect(
        "imap.gmail.com",
        993,
        [MailKit.Security.SecureSocketOptions]::SslOnConnect
    )

    Write-Host "Conexión TLS establecida." -ForegroundColor Green

    # ------------------------------------------------------------------------
    # Authenticate
    # ------------------------------------------------------------------------

    $imapClient.Authenticate(
        $emailUser,
        $appPassword
    )

    Write-Host "Autenticación exitosa." -ForegroundColor Green
    Write-Host ""

    # =========================================================================
    # Process each client
    # =========================================================================

    for ($i = 0; $i -lt $clients.Count; $i++) {

        $clientName = $clients[$i]

        Write-Host "[$($i + 1)/$($clients.Count)] => $clientName" `
            -ForegroundColor Cyan

        # ---------------------------------------------------------------------
        # Local output folders
        # ---------------------------------------------------------------------

        $clientFolderPath = Join-Path `
            $parentFolderPath `
            $clientName

        $monthFolderName = "$month. $monthName"

        $monthFolderPath = Join-Path `
            $clientFolderPath `
            $monthFolderName

        Ensure-Folder -Path $monthFolderPath

        # ---------------------------------------------------------------------
        # Gmail label
        # ---------------------------------------------------------------------

        $gmailLabel = "Facturas/$clientName"

        Write-Host "   Gmail label: $gmailLabel"

        # ---------------------------------------------------------------------
        # Find Gmail folder
        # ---------------------------------------------------------------------

        try {

            $gmailFolder = $imapClient.GetFolder($gmailLabel)

        }
        catch {

            Write-Host `
                "   [!] No se encontró la etiqueta '$gmailLabel'. Saltando..." `
                -ForegroundColor DarkYellow

            Write-Host ""
            continue
        }

        # ---------------------------------------------------------------------
        # Open folder read-only
        # ---------------------------------------------------------------------

        try {

            $gmailFolder.Open(
                [MailKit.FolderAccess]::ReadOnly
            )

        }
        catch {

            Write-Host `
                "   [!] No se pudo abrir '$gmailLabel' en modo lectura." `
                -ForegroundColor Red

            Write-Host "   $($_.Exception.Message)" `
                -ForegroundColor Red

            Write-Host ""
            continue
        }

        # ---------------------------------------------------------------------
        # Search messages
        # ---------------------------------------------------------------------
        #
        # DeliveredAfter/Before are used only to reduce the amount of mail
        # retrieved from Gmail.
        #
        # We perform a second exact Date check below because the IMAP search
        # criteria and the message Date can differ around boundaries/time zones.
        # ---------------------------------------------------------------------

        $searchQuery = `
            [MailKit.Search.SearchQuery]::DeliveredAfter(
                $startDate.AddDays(-1)
            ).And(
                [MailKit.Search.SearchQuery]::DeliveredBefore(
                    $endDate
                )
            )

        try {
            $messageUids = $gmailFolder.Search($searchQuery)
        }
        catch {
            Write-Host `
                "   [!] Error buscando mensajes." `
                -ForegroundColor Red

            Write-Host "   $($_.Exception.Message)" `
                -ForegroundColor Red

            $gmailFolder.Close($false)

            Write-Host ""
            continue
        }

        Write-Host "   Correos encontrados: $($messageUids.Count)"

        $filesSaved = 0

        # =====================================================================
        # Process messages
        # =====================================================================

        foreach ($uid in $messageUids) {
            try {
                $message = $gmailFolder.GetMessage($uid)
            }
            catch {
                Write-Host `
                    "   [!] No se pudo leer un mensaje. Saltando..." `
                    -ForegroundColor DarkYellow

                continue
            }

            # -----------------------------------------------------------------
            # Exact year/month validation
            # -----------------------------------------------------------------

            if (
                $message.Date.Year -ne $year -or
                $message.Date.Month -ne $month
            ) {
                continue
            }

            $datePrefix = $message.Date.ToString("yyyy-MM-dd")

            # -----------------------------------------------------------------
            # Process attachments
            # -----------------------------------------------------------------

            foreach ($attachment in $message.Attachments) {

                # Only process actual MIME parts.
                if ($attachment -isnot [MimeKit.MimePart]) {
                    continue
                }

                $originalFileName = $attachment.FileName

                if ([string]::IsNullOrWhiteSpace($originalFileName)) {
                    continue
                }

                # -------------------------------------------------------------
                # ONLY PDF and XML
                # -------------------------------------------------------------

                if (
                    $originalFileName -notmatch `
                    '(?i)\.(pdf|xml)$'
                ) {
                    continue
                }

                # -------------------------------------------------------------
                # Sanitize filename
                # -------------------------------------------------------------

                $safeFileName = $originalFileName -replace `
                    '[\\/:*?"<>|]', '_'

                # Prevent strange path-related names.
                $safeFileName = $safeFileName.Trim()

                if ([string]::IsNullOrWhiteSpace($safeFileName)) {
                    continue
                }

                # -------------------------------------------------------------
                # Final destination
                # -------------------------------------------------------------

                $destinationFileName = "${datePrefix}_${safeFileName}"

                $destinationPath = Join-Path `
                    $monthFolderPath `
                    $destinationFileName

                # -------------------------------------------------------------
                # Do not overwrite existing files
                # -------------------------------------------------------------

                if (Test-Path $destinationPath -PathType Leaf) {

                    Write-Host `
                        "      [=] Ya existe: $destinationFileName" `
                        -ForegroundColor DarkGray

                    continue
                }

                # -------------------------------------------------------------
                # Save attachment
                # -------------------------------------------------------------

                $fileStream = $null

                try {
                    $fileStream = [System.IO.File]::Create(
                        $destinationPath
                    )

                    $attachment.Content.DecodeTo(
                        $fileStream
                    )

                    $filesSaved++

                    Write-Host `
                        "      [+] $destinationFileName" `
                        -ForegroundColor Green
                }
                catch {
                    Write-Host `
                        "      [!] Error guardando '$safeFileName'" `
                        -ForegroundColor Red

                    Write-Host `
                        "          $($_.Exception.Message)" `
                        -ForegroundColor Red

                    # Remove partially-created files.
                    if (Test-Path $destinationPath -PathType Leaf) {
                        Remove-Item `
                            $destinationPath `
                            -Force `
                            -ErrorAction SilentlyContinue
                    }
                }
                finally {
                    if ($null -ne $fileStream) {
                        $fileStream.Dispose()
                    }
                }
            }
        }

        # ---------------------------------------------------------------------
        # Close folder
        # ---------------------------------------------------------------------

        try {
            $gmailFolder.Close($false)
        }
        catch {
            # Nothing critical here; the main connection will be closed later.
        }

        Write-Host `
            "   [+] $filesSaved archivos descargados." `
            -ForegroundColor Green

        Write-Host ""
    }

}
catch {

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Red

    Write-Host "ERROR durante el proceso:" `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    Write-Host "============================================================" `
        -ForegroundColor Red

}
finally {

    # =========================================================================
    # Always disconnect from Gmail
    # =========================================================================

    if ($null -ne $imapClient) {
        if ($imapClient.IsConnected) {
            try {
                $imapClient.Disconnect($true)
            }
            catch {
                # Ignore disconnect errors.
            }
        }
        $imapClient.Dispose()
    }
}

Write-Host ""
Write-Host "-----------------------------------------------------------------------------------"
Write-Host "¡Proceso finalizado!"
Write-Host "-----------------------------------------------------------------------------------"
Write-Host ""
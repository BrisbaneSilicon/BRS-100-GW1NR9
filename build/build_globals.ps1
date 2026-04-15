# ---- REPO ROOT DETECTION ----
$RepoRoot = (git rev-parse --show-toplevel 2>$null) -replace '/', '\'
if (-not $RepoRoot -or $RepoRoot.Trim() -eq '') {
    Write-Host "ERROR: Could not determine repo root from Git."
    Write-Host "Make sure Git is installed and you are running this script from inside the repository."
    exit 1
}

# ---- GOWIN INSTALL PATH DETECTION ----
$GowinInstallDir = $null

# define common paths for GOWIN v1.9.12 and later
$commonPaths = @(
    "C:\Gowin\Gowin_V1.9.12_x64",
    "C:\Gowin\Gowin_V1.9.12",
    "C:\Program Files\Gowin\Gowin_V1.9.12_x64",
    "C:\Program Files\Gowin\Gowin_V1.9.12"
)

# check environment variable
if ($env:GOWIN_INSTALL_DIR) {
    if (Test-Path "$env:GOWIN_INSTALL_DIR\IDE\bin\gw_sh.exe") {
        $GowinInstallDir = $env:GOWIN_INSTALL_DIR
        Write-Host "GOWIN location from environment variable: $GowinInstallDir"
    } else {
        Write-Host "WARNING: GOWIN_INSTALL_DIR is set but gw_sh.exe not found at:"
        Write-Host "  $env:GOWIN_INSTALL_DIR\IDE\bin\gw_sh.exe"
        Write-Host "Falling back to common path search..."
    }
}

# check common install locations
if (-not $GowinInstallDir) {
    foreach ($path in $commonPaths) {
        if (Test-Path "$path\IDE\bin\gw_sh.exe") {
            $GowinInstallDir = $path
            break
        }
    }
}

# cannot locate in common location and path
if (-not $GowinInstallDir) {
    Write-Host ""
    Write-Host "ERROR: Could not find GOWIN EDA installation."
    Write-Host ""
    Write-Host "Searched the following locations:"
    foreach ($path in $commonPaths) {
        Write-Host "  $path"
    }
    Write-Host ""
    Write-Host "To fix this, either:"
    Write-Host "  1. Install GOWIN EDA V1.9.12 to one of the above locations."
    Write-Host "     Download: https://www.gowinsemi.com/en/support/download_eda/"
    Write-Host ""
    Write-Host "  2. Set the GOWIN_INSTALL_DIR environment variable to your install path:"
    Write-Host "     (Run this once in PowerShell, then reopen PowerShell)"
    Write-Host "     [System.Environment]::SetEnvironmentVariable('GOWIN_INSTALL_DIR', 'C:\your\gowin\path', 'User')"
    Write-Host ""
    Write-Host "  NOTE: Only GOWIN EDA V1.9.12 is tested and verified for this script. "
    Write-Host "        Older versions may have compatibility issues. Please install V1.9.12."
    Write-Host ""
    exit 1
}

# ---- GOWIN VERSION COMPATIBILITY CHECK ----
$installFolderName = Split-Path $GowinInstallDir -Leaf
Write-Host "Found GOWIN EDA at: $GowinInstallDir"

# Extract version number from folder name (e.g., "Gowin_V1.9.12_x64" -> "1.9.12")
if ($installFolderName -match 'V(\d+\.\d+\.\d+(?:\.\d+)?)') {
    $versionNumber = $matches[1]
} else {
    $versionNumber = $installFolderName
}

if ($versionNumber -like "1.9.12*" -and $versionNumber -notlike "1.9.12.01*") {
    Write-Host "GOWIN version: $installFolderName (verified compatible)"

} elseif ($versionNumber -like "1.9.12.01*") {
    Write-Host ""
    Write-Host "ERROR: GOWIN EDA V1.9.12.01 has a fatal bug and is not supported by this script."
    Write-Host "Please install V1.9.12 from:"
    Write-Host "https://www.gowinsemi.com/en/support/download_eda/"
    exit 1

} elseif ($versionNumber -like "*1.9.11.01*") {
    Write-Host ""
    Write-Host "ERROR: GOWIN EDA V1.9.11.01 is a known broken release."
    Write-Host "Please install V1.9.12 from:"
    Write-Host "https://www.gowinsemi.com/en/support/download_eda/"
    exit 1

} elseif ($versionNumber -like "*1.9.8*"  -or
          $versionNumber -like "*1.9.9*"  -or
          $versionNumber -like "*1.9.10*" -or
          $versionNumber -like "*1.9.11*") {
    Write-Host ""
    Write-Host "WARNING: GOWIN EDA $installFolderName has not been tested with this script."
    Write-Host "         This script was developed and verified with V1.9.12."
    Write-Host "         Some TCL commands used in build.tcl may not be supported."
    Write-Host "         Recommended version: V1.9.12"
    Write-Host "         Continuing anyway..."
    Write-Host ""

} elseif ($versionNumber -notlike "*1.9.*") {
    Write-Host ""
    Write-Host "WARNING: Unrecognised GOWIN EDA version: $installFolderName"
    Write-Host "         This script was developed and verified with V1.9.12."
    Write-Host "         Continuing anyway..."
    Write-Host ""

} else {
    Write-Host ""
    Write-Host "WARNING: GOWIN EDA $installFolderName has not been tested with this script."
    Write-Host "         This script was developed and verified with V1.9.12."
    Write-Host "         Continuing anyway..."
    Write-Host ""
}

# note: user.sv file is specified by build.tcl
# ---- PATHS ----
$GwSh               = "$GowinInstallDir\IDE\bin\gw_sh.exe"
$PlatformsDir       = "$RepoRoot\build\platforms"
$FreqCsvPath        = "$RepoRoot\build\platforms\gowin\gowin_supported_system_clock_frequencies.csv"
$DevicesCsvPath     = "$RepoRoot\build\platforms\gowin\gowin_supported_devices_information.csv"
$WindowsOutputDir   = "$PSScriptRoot\output"
$Platform           = "gowin"

# ---- IS_SUPPORTED_PLATFORM ----
if (-not (Test-SupportedPlatform $Platform)) {
    Write-Host ""
    Write-Host "ERROR: Platform '$Platform' is not supported."
    Write-Host "Supported platforms:"
    Get-ChildItem -Directory $PlatformsDir |
        Select-Object -ExpandProperty Name |
        ForEach-Object { Write-Host "  $_" }
    exit 1
}

# ---- PROJECT NAME ----
$ProjectName        = "BRS-100-GW1NR9"

# ---- CHIP SETTINGS FROM CSV ----
if (-not (Test-Path $DevicesCsvPath)) {
    Write-Host "ERROR: Cannot find devices CSV at: $DevicesCsvPath"
    exit 1
}
$devices = Import-Csv $DevicesCsvPath

# check if CSV loaded any devices
if ($devices.Count -eq 0) {
    Write-Host "ERROR: No devices found in CSV at: $DevicesCsvPath"
    exit 1
}

$device = $devices | Where-Object { $_.'Build Target'.Trim() -eq $ProjectName }

if (-not $device) {
    Write-Host "ERROR: Could not find '$ProjectName' in devices CSV at: $DevicesCsvPath"
    exit 1
}

$PartNumber    = $device.'Part Number'.Trim()
$DeviceVersion = $device.'Device Version'.Trim()
$SpeedGrade    = $device.'Speed Grade'.Trim()
$DeviceId      = $device.'Device'.Trim()

Write-Host "Device settings loaded from CSV:"
Write-Host "  Part Number    : $PartNumber"
Write-Host "  Device Version : $DeviceVersion"
Write-Host "  Speed Grade    : $SpeedGrade"
Write-Host "  Device ID      : $DeviceId"

# ---- DERIVE PATHS FROM CSV VALUES ----
# construct paths according to detected environment
$BuildTcl  = "$RepoRoot\build\platforms\gowin\devices\$DeviceId\build.tcl"
$OutputDir = "$RepoRoot\build\platforms\gowin\devices\$DeviceId\$SpeedGrade\output"
$ArtifactsDir = "$OutputDir\.artifacts"

# ---- LOAD SUPPORTED CLOCK FREQUENCIES FROM CSV ----
if (-not (Test-Path $FreqCsvPath)) {
    Write-Host "ERROR: Cannot find clock frequencies CSV at: $FreqCsvPath"
    exit 1
}
$freqData = Import-Csv $FreqCsvPath

# check if CSV loaded any frequencies at all
if ($freqData.Count -eq 0) {
    Write-Host "ERROR: No frequencies found in CSV at: $FreqCsvPath"
    exit 1
}

$supportedFreqs = $freqData | ForEach-Object { [int]($_.Frequency.Trim()) }

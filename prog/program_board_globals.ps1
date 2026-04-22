# ---- REPO ROOT DETECTION ----
$RepoRoot = (git rev-parse --show-toplevel 2>$null) -replace '/', '\'
if (-not $RepoRoot) {
    Write-Host "ERROR: Could not determine repo root from Git."
    Write-Host "Make sure Git is installed and you are running this script from inside the repository."
    exit 1
}

# ---- GOWIN INSTALL PATH DETECTION ----
# checks for programmer_cli.exe specifically - different from build script
# which checks for gw_sh.exe
$GowinInstallDir = $null

$commonPaths = @(
    "C:\Gowin\Gowin_V1.9.12_x64",
    "C:\Gowin\Gowin_V1.9.12",
    "C:\Program Files\Gowin\Gowin_V1.9.12_x64",
    "C:\Program Files\Gowin\Gowin_V1.9.12"
)

# check environment variable
if ($env:GOWIN_INSTALL_DIR) {
    if (Test-Path "$env:GOWIN_INSTALL_DIR\Programmer\bin\programmer_cli.exe") {
        $GowinInstallDir = $env:GOWIN_INSTALL_DIR
        Write-Host "GOWIN location from environment variable: $GowinInstallDir"
    } else {
        Write-Host "WARNING: GOWIN_INSTALL_DIR is set but programmer_cli.exe not found at:"
        Write-Host "  $env:GOWIN_INSTALL_DIR\Programmer\bin\programmer_cli.exe"
        Write-Host "Falling back to common path search..."
    }
}

# check common install locations
if (-not $GowinInstallDir) {
    foreach ($path in $commonPaths) {
        if (Test-Path "$path\Programmer\bin\programmer_cli.exe") {
            $GowinInstallDir = $path
            break
        }
    }
}

# if still not found - fail with clear instructions
if (-not $GowinInstallDir) {
    Write-Host ""
    Write-Host "ERROR: Could not find GOWIN programmer_cli.exe."
    Write-Host ""
    Write-Host "Searched the following locations:"
    foreach ($path in $commonPaths) {
        Write-Host "  $path\Programmer\bin\programmer_cli.exe"
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
    Write-Host "  NOTE: Only GOWIN EDA V1.9.12 is tested and verified for this script."
    Write-Host "        Older versions may have compatibility issues. Please install V1.9.12."
    Write-Host ""
    exit 1
}

# ---- GOWIN VERSION COMPATIBILITY CHECK ----
$installFolderName = Split-Path $GowinInstallDir -Leaf
Write-Host "Found GOWIN programmer at: $GowinInstallDir"

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

} else {
    Write-Host ""
    Write-Host "WARNING: GOWIN EDA $installFolderName has not been tested with this script."
    Write-Host "         Verified version: V1.9.12"
    Write-Host "         Continuing anyway..."
    Write-Host ""
}

# ---- PATHS ----
$ProgrammerCli  = "$GowinInstallDir\Programmer\bin\programmer_cli.exe"
$ProgrammerGui  = "$GowinInstallDir\Programmer\bin\programmer.exe"
$BuildScript    = "$RepoRoot\build\build.ps1"
$DevicesCsvPath = "$RepoRoot\build\platforms\gowin\gowin_supported_devices_information.csv"
$BoardsCsvPath  = "$RepoRoot\prog\supported_boards.csv"

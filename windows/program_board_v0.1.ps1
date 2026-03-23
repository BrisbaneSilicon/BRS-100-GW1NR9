# =============================================================
# program_win_v0.1.ps1
# Minimal Windows programming script for BRS-100-GW1NR9
# version 0.1 - minimal functionality:
#               find programmer_cli.exe
#               find .fs file at default location
#               auto-trigger build if .fs not found
#               program board via programmer_cli.exe
# =============================================================

# ---- AUTO-DERIVE REPO ROOT FROM GIT ----
$RepoRoot = (git rev-parse --show-toplevel 2>$null) -replace '/', '\'
if (-not $RepoRoot -or $RepoRoot.Trim() -eq '') {
    Write-Host "ERROR: Could not determine repo root from Git."
    Write-Host "Make sure Git is installed and you are running this script from inside the repository."
    exit 1
}

# ---- AUTO-DETECT GOWIN INSTALL PATH ----
# checks for programmer_cli.exe specifically - different from build script
# which checks for gw_sh.exe
$GowinInstallDir = $null

$commonPaths = @(
    "C:\Gowin\Gowin_V1.9.12.01_x64",
    "C:\Gowin\Gowin_V1.9.12.01",
    "C:\Gowin\Gowin_V1.9.12_x64",
    "C:\Gowin\Gowin_V1.9.12",
    "C:\Program Files\Gowin\Gowin_V1.9.12.01_x64",
    "C:\Program Files\Gowin\Gowin_V1.9.12.01",
    "$env:LOCALAPPDATA\Gowin\Gowin_V1.9.12.01_x64",
    "$env:LOCALAPPDATA\Gowin\Gowin_V1.9.12.01"
)

# first check environment variable
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

# then check common install locations
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
    Write-Host "  1. Install GOWIN EDA V1.9.12.01 to one of the above locations."
    Write-Host "     Download: https://www.gowinsemi.com/en/support/download_eda/"
    Write-Host ""
    Write-Host "  2. Set the GOWIN_INSTALL_DIR environment variable to your install path:"
    Write-Host "     (Run this once in PowerShell, then reopen PowerShell)"
    Write-Host "     [System.Environment]::SetEnvironmentVariable('GOWIN_INSTALL_DIR', 'C:\your\gowin\path', 'User')"
    Write-Host ""
    exit 1
}

# ---- PATHS ----
$ProgrammerCli  = "$GowinInstallDir\Programmer\bin\programmer_cli.exe"
$BuildScript    = "$RepoRoot\windows\build_v0.7.ps1"
$DevicesCsvPath = "$RepoRoot\build\platforms\gowin\gowin_supported_devices_information.csv"
$BoardsCsvPath  = "$RepoRoot\prog\supported_boards.csv"

# ---- PROJECT SETTINGS ----
$ProjectName    = "BRS-100-GW1NR9"

# ---- LOAD SUPPORTED BOARDS FROM CSV ----
# confirms this board is supported and gets bitstream extension
if (-not (Test-Path $BoardsCsvPath)) {
    Write-Host "ERROR: Cannot find supported boards CSV at: $BoardsCsvPath"
    exit 1
}
$boards = Import-Csv $BoardsCsvPath
if ($boards.Count -eq 0) {
    Write-Host "ERROR: No boards found in CSV at: $BoardsCsvPath"
    exit 1
}

$board = $boards | Where-Object { $_.Board.Trim() -eq $ProjectName }
if (-not $board) {
    Write-Host "ERROR: Board '$ProjectName' not found in supported boards CSV."
    Write-Host "Supported boards:"
    $boards | ForEach-Object { Write-Host "  $($_.Board.Trim())" }
    exit 1
}

$BitstreamExt  = $board.BitstreamExt.Trim()    # fs
$BoardPlatform = $board.Platform.Trim()         # gowin

# ---- CHIP SETTINGS FROM DEVICES CSV ----
if (-not (Test-Path $DevicesCsvPath)) {
    Write-Host "ERROR: Cannot find devices CSV at: $DevicesCsvPath"
    exit 1
}
$devices = Import-Csv $DevicesCsvPath
if ($devices.Count -eq 0) {
    Write-Host "ERROR: No devices found in CSV at: $DevicesCsvPath"
    exit 1
}

$device = $devices | Where-Object { $_.'Build Target'.Trim() -eq $ProjectName }
if (-not $device) {
    Write-Host "ERROR: Could not find '$ProjectName' in devices CSV."
    exit 1
}

$DeviceId   = $device.'Device'.Trim()        # GW1NR-9
$SpeedGrade = $device.'Speed Grade'.Trim()   # C7I6

# ---- DERIVE .FS FILE PATH FROM CSV VALUES ----
$ArtifactsDir = "$RepoRoot\build\platforms\gowin\devices\$DeviceId\$SpeedGrade\output\.artifacts"
$FsFile       = "$ArtifactsDir\$ProjectName.$BitstreamExt"

# ---- BUILD DEVICE ARGUMENT FOR PROGRAMMER ----
# matches Linux: speed_grade_category=${speed_grade:0:1}
# "C7I6" -> "C", combined with "GW1NR-9" -> "GW1NR-9C"
$SpeedGradeCategory = $SpeedGrade.Substring(0, 1)
$DeviceArg          = "$DeviceId$SpeedGradeCategory"

Write-Host "Found GOWIN programmer at: $ProgrammerCli"
Write-Host "Board    : $ProjectName ($BoardPlatform)"
Write-Host "Device   : $DeviceArg"
Write-Host "Bitstream: $FsFile"

# ---- CHECK IF FIRMWARE IS BUILT ----
# if .fs not found, auto-trigger build first - matches Linux behaviour
if (-not (Test-Path $FsFile)) {
    Write-Host ""
    Write-Host "Detected firmware not built - triggering build..."
    Write-Host ""

    if (-not (Test-Path $BuildScript)) {
        Write-Host "ERROR: Cannot find build script at: $BuildScript"
        Write-Host "Please check the build script exists at that location."
        exit 1
    }

    & $BuildScript

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Build failed - cannot program board."
        exit 1
    }

    # check again after build
    if (-not (Test-Path $FsFile)) {
        Write-Host "ERROR: Build completed but .fs file not found at: $FsFile"
        exit 1
    }

} else {
    Write-Host ""
    Write-Host "Detected firmware already built - reusing."
}

# ---- PROGRAM THE BOARD ----
Write-Host ""
Write-Host "====================================="
Write-Host " BRS-100-GW1NR9 Windows Programmer"
Write-Host "====================================="
Write-Host "Device     : $DeviceArg"
Write-Host "Bitstream  : $FsFile"
Write-Host "Programmer : $ProgrammerCli"
Write-Host "====================================="
Write-Host ""
Write-Host "NOTE: Make sure the board is plugged in via USB-C before continuing."
Write-Host ""

& $ProgrammerCli --device $DeviceArg --operation_index 5 -f $FsFile

# ---- RESULT ----
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " PROGRAMMING SUCCESS"
    Write-Host "====================================="
    Write-Host "Board programmed successfully."
    Write-Host "The design will auto-load on every power-on."

} else {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " PROGRAMMING FAILED (exit code: $LASTEXITCODE)"
    Write-Host "====================================="
    Write-Host ""
    Write-Host "Common causes:"
    Write-Host "  1. Board not plugged in via USB-C"
    Write-Host "  2. Wrong USB cable (must support data, not just power)"
    Write-Host "  3. GOWIN Programmer GUI is open - close it and try again"
    Write-Host "  4. Driver issue - try unplugging and replugging the board"
    Write-Host "  5. License issue - check GOWIN license via IDE: Help > Manage License"
    exit 1
}
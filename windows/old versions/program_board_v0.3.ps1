# =============================================================
# program_board_v0.3.ps1
# Windows programming script for BRS-100-GW1NR9
# version 0.1 - minimal functionality:
#               find programmer_cli.exe
#               scan for JTAG cable and verify board connected
#               find .fs file at default location
#               auto-trigger build if .fs not found
#               program board via programmer_cli.exe
# version 0.2 - fix programming command:
#               use --cable-index 4 (USB Debugger A) to select
#                 ftd2xx driver path instead of default FT2CH
#               use --location to target the correct USB device
#               use --frequency 0.5MHz for reliable JTAG comms
#               use --operation_index 5 (embFlash Erase,Program)
#                 to match Linux build.sh behaviour
#               use --scan-cables F (ftd2xx) for cable detection
#               fix: actually execute programmer_cli with args
# version 0.3 - implement command-line arguments:
#               -h / --help               show usage and exit
#               -b / --check_if_built     print firmware built status and exit
#               -c / --clean              clean build before programming
#               -m / --custom_bitfile     program a custom .fs file
# =============================================================

param(
    [switch]$h,
    [switch]$help,
    [switch]$b,
    [switch]$check_if_built,
    [switch]$c,
    [switch]$clean,
    [string]$m,
    [string]$custom_bitfile
)

# ---- NORMALISE ALIASES ----
$ShowHelp       = $h -or $help
$CheckIfBuilt   = $b -or $check_if_built
$CleanBuild     = $c -or $clean
$CustomBitfile  = if ($m) { $m } elseif ($custom_bitfile) { $custom_bitfile } else { $null }

# ---- HELP ----
function Show-Help {
    Write-Host ""
    Write-Host "PROGRAM_BOARD"
    Write-Host ""
    Write-Host "NAME"
    Write-Host "    program_board - program the BRS-100-GW1NR9 board with FPGA firmware"
    Write-Host ""
    Write-Host "SYNOPSIS"
    Write-Host "    .\program_board_v0.3.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "DESCRIPTION"
    Write-Host "    Program the BRS-100-GW1NR9 board via JTAG using programmer_cli.exe."
    Write-Host "    If firmware is not yet built, automatically triggers a build first."
    Write-Host ""
    Write-Host "OPTIONS"
    Write-Host "    -h, --help"
    Write-Host "        Display this help and exit."
    Write-Host ""
    Write-Host "    -b, --check_if_built"
    Write-Host "        Print whether the firmware is built and exit without programming."
    Write-Host ""
    Write-Host "    -c, --clean"
    Write-Host "        Clean the build output before building and programming."
    Write-Host ""
    Write-Host "    -m, --custom_bitfile  <PATH>"
    Write-Host "        Program the board with a custom .fs file instead of the default"
    Write-Host "        build output. Path must be the full path to a .fs file."
    Write-Host ""
    Write-Host "EXAMPLES"
    Write-Host "    .\program_board_v0.3.ps1"
    Write-Host "        Build (if needed) and program the board."
    Write-Host ""
    Write-Host "    .\program_board_v0.3.ps1 -c"
    Write-Host "        Clean, rebuild, and program the board."
    Write-Host ""
    Write-Host "    .\program_board_v0.3.ps1 -b"
    Write-Host "        Check whether firmware is built without programming."
    Write-Host ""
    Write-Host "    .\program_board_v0.3.ps1 -m C:\path\to\custom.fs"
    Write-Host "        Program the board with a custom bitstream file."
    Write-Host ""
}

if ($ShowHelp) {
    Show-Help
    exit 0
}

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
    "C:\Gowin\Gowin_V1.9.12.02_x64",
    "C:\Gowin\Gowin_V1.9.12.01",
    "C:\Gowin\Gowin_V1.9.12.02",
    "C:\Gowin\Gowin_V1.9.12_x64",
    "C:\Gowin\Gowin_V1.9.12",
    "C:\Program Files\Gowin\Gowin_V1.9.12.01_x64",
    "C:\Program Files\Gowin\Gowin_V1.9.12.02_x64",
    "C:\Program Files\Gowin\Gowin_V1.9.12.01",
    "C:\Program Files\Gowin\Gowin_V1.9.12.02",
    "$env:LOCALAPPDATA\Gowin\Gowin_V1.9.12.01_x64",
    "$env:LOCALAPPDATA\Gowin\Gowin_V1.9.12.02_x64",
    "$env:LOCALAPPDATA\Gowin\Gowin_V1.9.12.01",
    "$env:LOCALAPPDATA\Gowin\Gowin_V1.9.12.02"
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
    Write-Host "  1. Install GOWIN EDA V1.9.12.01 or V1.9.12.02 to one of the above locations."
    Write-Host "     Download: https://www.gowinsemi.com/en/support/download_eda/"
    Write-Host ""
    Write-Host "  2. Set the GOWIN_INSTALL_DIR environment variable to your install path:"
    Write-Host "     (Run this once in PowerShell, then reopen PowerShell)"
    Write-Host "     [System.Environment]::SetEnvironmentVariable('GOWIN_INSTALL_DIR', 'C:\your\gowin\path', 'User')"
    Write-Host ""
    exit 1
}

# ---- GOWIN VERSION COMPATIBILITY CHECK ----
$installFolderName = Split-Path $GowinInstallDir -Leaf
Write-Host "Found GOWIN programmer at: $GowinInstallDir"

if ($installFolderName -like "*1.9.12.01*" -or
    $installFolderName -like "*1.9.12.02*") {
    Write-Host "GOWIN version: $installFolderName (verified compatible)"

} elseif ($installFolderName -like "*1.9.12*") {
    Write-Host ""
    Write-Host "WARNING: GOWIN $installFolderName has not been verified with this script."
    Write-Host "         Verified versions: V1.9.12.01, V1.9.12.02"
    Write-Host "         Continuing anyway..."
    Write-Host ""

} elseif ($installFolderName -like "*1.9.11.01*") {
    Write-Host ""
    Write-Host "ERROR: GOWIN EDA V1.9.11.01 is a known broken release."
    Write-Host "Please install V1.9.12.01 or V1.9.12.02 from:"
    Write-Host "https://www.gowinsemi.com/en/support/download_eda/"
    exit 1

} elseif ($installFolderName -like "*1.9.8*"  -or
          $installFolderName -like "*1.9.9*"  -or
          $installFolderName -like "*1.9.10*" -or
          $installFolderName -like "*1.9.11*") {
    Write-Host ""
    Write-Host "WARNING: GOWIN EDA $installFolderName has not been tested with this script."
    Write-Host "         Verified versions: V1.9.12.01, V1.9.12.02"
    Write-Host "         Continuing anyway..."
    Write-Host ""

} elseif ($installFolderName -notlike "*1.9.*") {
    Write-Host ""
    Write-Host "WARNING: Unrecognised GOWIN EDA version: $installFolderName"
    Write-Host "         Verified versions: V1.9.12.01, V1.9.12.02"
    Write-Host "         Continuing anyway..."
    Write-Host ""

} else {
    Write-Host ""
    Write-Host "WARNING: GOWIN EDA $installFolderName has not been tested with this script."
    Write-Host "         Verified versions: V1.9.12.01, V1.9.12.02"
    Write-Host "         Continuing anyway..."
    Write-Host ""
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
$DefaultFsFile = "$ArtifactsDir\$ProjectName.$BitstreamExt"

# ---- BUILD DEVICE ARGUMENT FOR PROGRAMMER ----
# matches Linux: speed_grade_category=${speed_grade:0:1}
# "C7I6" -> "C", combined with "GW1NR-9" -> "GW1NR-9C"
$SpeedGradeCategory = $SpeedGrade.Substring(0, 1)
$DeviceArg          = "$DeviceId$SpeedGradeCategory"

Write-Host "Board    : $ProjectName ($BoardPlatform)"
Write-Host "Device   : $DeviceArg"

# ---- VALIDATE CUSTOM BITFILE ----
if ($CustomBitfile) {
    if (-not (Test-Path $CustomBitfile)) {
        Write-Host ""
        Write-Host "ERROR: Custom bitfile not found: $CustomBitfile"
        exit 1
    }
    if ([System.IO.Path]::GetExtension($CustomBitfile) -ne ".$BitstreamExt") {
        Write-Host ""
        Write-Host "ERROR: Custom bitfile must have .$BitstreamExt extension: $CustomBitfile"
        exit 1
    }
    $FsFile = $CustomBitfile
    Write-Host "Bitstream: $FsFile (custom)"
} else {
    $FsFile = $DefaultFsFile
    Write-Host "Bitstream: $FsFile"
}

# ---- CHECK IF BUILT (-b flag) ----
if ($CheckIfBuilt) {
    if (Test-Path $DefaultFsFile) {
        Write-Host ""
        Write-Host "Firmware built status: true"
        Write-Host "  $DefaultFsFile"
    } else {
        Write-Host ""
        Write-Host "Firmware built status: false"
        Write-Host "  $DefaultFsFile not found"
    }
    exit 0
}

# ---- SCAN FOR JTAG CABLE ----
# scan using ftd2xx driver (F flag) - this matches the GUI's "Using ftd2xx driver"
# checkbox which must be checked for this board to work.
# board shows up as two USB Debugger A interfaces:
#   index 0 - JTAG  - used for programming
#   index 1 - UART  - used for serial communication
Write-Host ""
Write-Host "Scanning for connected cables (ftd2xx)..."
$scanOutput = & $ProgrammerCli --scan-cables F 2>&1
Write-Host $scanOutput

# extract JTAG cable location from scan output
# scan output format: "USB Debugger A/0/529/null (USB location:529)"
$locationMatch = ($scanOutput | Out-String)
$regexMatch    = [regex]::Match($locationMatch, "USB Debugger A/0/(\d+)/null")

if (-not $regexMatch.Success) {
    Write-Host ""
    Write-Host "ERROR: Could not find JTAG interface (USB Debugger A, index 0)."
    Write-Host ""
    Write-Host "Common causes:"
    Write-Host "  1. Board not plugged in via USB-C"
    Write-Host "  2. Wrong USB cable (must support data, not just power)"
    Write-Host "  3. Driver issue - try unplugging and replugging the board"
    exit 1
}

$cableLocation = $regexMatch.Groups[1].Value
Write-Host "JTAG interface found at USB location: $cableLocation - proceeding."

# ---- BUILD IF NEEDED (skipped when -m custom bitfile is provided) ----
if (-not $CustomBitfile) {
    if (-not (Test-Path $FsFile) -or $CleanBuild) {
        if ($CleanBuild) {
            Write-Host ""
            Write-Host "Clean build requested - triggering build with -c flag..."
        } else {
            Write-Host ""
            Write-Host "Detected firmware not built - triggering build..."
        }
        Write-Host ""

        if (-not (Test-Path $BuildScript)) {
            Write-Host "ERROR: Cannot find build script at: $BuildScript"
            Write-Host "Please check the build script exists at that location."
            exit 1
        }

        if ($CleanBuild) {
            & $BuildScript -c
        } else {
            & $BuildScript
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "ERROR: Build failed - cannot program board."
            exit 1
        }

        if (-not (Test-Path $FsFile)) {
            Write-Host "ERROR: Build completed but .fs file not found at: $FsFile"
            exit 1
        }

    } else {
        Write-Host ""
        Write-Host "Detected firmware already built - reusing."
    }
}

# ---- PROGRAM THE BOARD ----
# on Windows, programmer_cli.exe defaults to the FT2CH cable type which does not
# work with the BRS-100-GW1NR9's USB Debugger A interface. three arguments are
# required together to force the correct ftd2xx driver path:
#   --cable-index 4  : selects "USB Debugger A" cable type (ftd2xx driver)
#   --location <loc> : targets the specific USB device (from --scan-cables F)
#   --frequency 0.5MHz : reliable JTAG clock speed for this board
# without all three, programmer_cli falls back to FT2CH and fails with CRC errors.
# operation_index 5 = embFlash Erase,Program (matches Linux build.sh behaviour)
Write-Host ""
Write-Host "====================================="
Write-Host " BRS-100-GW1NR9 Windows Programmer"
Write-Host "====================================="
Write-Host "Device    : $DeviceArg"
Write-Host "Cable     : USB Debugger A (cable-index 4, location $cableLocation - JTAG)"
Write-Host "Frequency : 0.5MHz"
Write-Host "Operation : embFlash Erase, Program (index 5)"
Write-Host "Bitstream : $FsFile"
Write-Host "Programmer: $ProgrammerCli"
Write-Host "====================================="
Write-Host "Programming board..."
Write-Host ""

& $ProgrammerCli --device $DeviceArg --cable-index 4 --location $cableLocation --frequency 0.5MHz --operation_index 5 --fsFile $FsFile

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

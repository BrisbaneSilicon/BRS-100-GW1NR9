param (
    # ---- CORE BUILD FLAGS ----
    [Alias('board_demonstration')]
    [switch]$b,

    [Alias('clock_frequency')]
    [int]$k             = 51,

    [Alias('uart_baud')]
    [int]$u             = 115200,

    [Alias('disable_pushbutton_reset')]
    [switch]$r,

    [Alias('help')]
    [switch]$h,

    # ---- IMPLEMENTED FLAGS ----
    [Alias('proj_only')]
    [switch]$p,

    [Alias('synth_only')]
    [switch]$s,

    [Alias('clean_all_platforms')]
    [switch]$a,

    # ---- NOT YET IMPLEMENTED ----
    [Alias('custom_target')]
    [string]$t          = "",

    [Alias('platform')]
    [string]$f          = "",

    [Alias('clean')]
    [switch]$c,

    [Alias('clean_platform')]
    [switch]$m,

    [Alias('list_default_target')]
    [switch]$d,

    [Alias('list_supported_platforms')]
    [switch]$i,

    [Alias('list_supported_targets')]
    [switch]$l,

    [Alias('list_supported_system_clock_frequencies')]
    [switch]$y
)

# version 0.1 - minimal functionality, hardcoded paths
# version 0.2 - added command line options and generate_top_wrapper
# version 0.3 - implemented -p, -s, -a flags, added /output copy, y/n prompt for -a
# version 0.4 - auto-derive RepoRoot from Git, auto-detect GOWIN install path,
#               version compatibility check

# ---- HELP ---- runs before any detection so -h works without GOWIN installed
if ($h) {
    Write-Host ""
    Write-Host "Usage: .\build.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "  Core Build Options:"
    Write-Host "  -b, -board_demonstration            Board demonstration mode (default: LED blink)"
    Write-Host "  -k, -clock_frequency <MHz>          System clock frequency in MHz (default: 51)"
    Write-Host "  -u, -uart_baud <baud>               UART baud rate (default: 115200)"
    Write-Host "  -r, -disable_pushbutton_reset       Disable pushbutton 1 as reset (default: enabled)"
    Write-Host "  -p, -proj_only                      Generate project file only, then exit"
    Write-Host "  -s, -synth_only                     Stop after synthesis, then exit"
    Write-Host "  -a, -clean_all_platforms            Delete all build output and exit"
    Write-Host "  -h, -help                           Show this help and exit"
    Write-Host ""
    Write-Host "  Not Yet Implemented:"
    Write-Host "  -t, -custom_target <TARGET>         Target a different board"
    Write-Host "  -f, -platform <PLATFORM>            Specify platform explicitly"
    Write-Host "  -c, -clean                          Clean target build and exit"
    Write-Host "  -m, -clean_platform                 Clean all devices for platform and exit"
    Write-Host "  -d, -list_default_target            Print default target and exit"
    Write-Host "  -i, -list_supported_platforms       List supported platforms and exit"
    Write-Host "  -l, -list_supported_targets         List supported targets and exit"
    Write-Host "  -y, -list_supported_system_clock_frequencies   List valid clock frequencies and exit"
    Write-Host ""
    Write-Host "  Examples:"
    Write-Host "  .\build.ps1                         Default LED blink build"
    Write-Host "  .\build.ps1 -b                      Board demonstration build"
    Write-Host "  .\build.ps1 -k 66                   LED blink at 66 MHz"
    Write-Host "  .\build.ps1 -b -k 66                Board demo at 66 MHz"
    Write-Host "  .\build.ps1 -u 9600                 LED blink with 9600 baud UART"
    Write-Host "  .\build.ps1 -r                      Disable pushbutton reset"
    Write-Host "  .\build.ps1 -p                      Generate project file only"
    Write-Host "  .\build.ps1 -s                      Run synthesis only"
    Write-Host "  .\build.ps1 -a                      Clean all build output"
    Write-Host ""
    exit 0
}

# ---- PROCESS CORE PARAMETERS INTO CLEAN VARIABLES ----
$BoardDemonstration = if ($b) { 1 } else { 0 }
$ClockMhz           = $k
$UartBaud           = $u
$PushbuttonReset    = if ($r) { 0 } else { 1 }
$DoProjectGenOnly   = if ($p) { "true" } else { "false" }
$DoSynthOnly        = if ($s) { "true" } else { "false" }

# ---- AUTO-DERIVE REPO ROOT FROM GIT ----
# no longer hardcoded - works on any PC regardless of where repo is cloned
$RepoRoot = (git rev-parse --show-toplevel) -replace '/', '\'
if (-not $RepoRoot) {
    Write-Host "ERROR: Could not determine repo root from Git."
    Write-Host "Make sure Git is installed and you are running this script from inside the repository."
    exit 1
}

# ---- AUTO-DETECT GOWIN INSTALL PATH ----
$GowinInstallDir = $null

# define common paths up front — used for both search and error message
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

# first check environment variable — allows user to override without editing script
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

# then check common install locations
if (-not $GowinInstallDir) {
    foreach ($path in $commonPaths) {
        if (Test-Path "$path\IDE\bin\gw_sh.exe") {
            $GowinInstallDir = $path
            break
        }
    }
}

# if still not found — fail with clear instructions
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
    Write-Host "  1. Install GOWIN EDA V1.9.12.01 to one of the above locations."
    Write-Host "     Download: https://www.gowinsemi.com/en/support/download_eda/"
    Write-Host ""
    Write-Host "  2. Set the GOWIN_INSTALL_DIR environment variable to your install path:"
    Write-Host "     (Run this once in PowerShell, then reopen PowerShell)"
    Write-Host "     [System.Environment]::SetEnvironmentVariable('GOWIN_INSTALL_DIR', 'C:\your\gowin\path', 'User')"
    Write-Host ""
    exit 1
}


# ---- GOWIN VERSION COMPATIBILITY CHECK ----
# note: more specific version checks must come before general ones
$installFolderName = Split-Path $GowinInstallDir -Leaf
Write-Host "Found GOWIN EDA at: $GowinInstallDir"

if ($installFolderName -like "*1.9.12*") {
    Write-Host "GOWIN version: $installFolderName (verified compatible) ✓"

} elseif ($installFolderName -like "*1.9.11.01*") {
    # must be checked BEFORE *1.9.11* otherwise this case is never reached
    Write-Host ""
    Write-Host "ERROR: GOWIN EDA V1.9.11.01 is a known broken release."
    Write-Host "Please install V1.9.12.01 from:"
    Write-Host "https://www.gowinsemi.com/en/support/download_eda/"
    exit 1

} elseif ($installFolderName -like "*1.9.8*"  -or
          $installFolderName -like "*1.9.9*"  -or
          $installFolderName -like "*1.9.10*" -or
          $installFolderName -like "*1.9.11*") {
    Write-Host ""
    Write-Host "WARNING: GOWIN EDA $installFolderName has not been tested with this script."
    Write-Host "         This script was developed and verified with V1.9.12.01."
    Write-Host "         Some TCL commands used in build.tcl may not be supported."
    Write-Host "         Recommended version: V1.9.12.01"
    Write-Host "         Continuing anyway..."
    Write-Host ""

} elseif ($installFolderName -notlike "*1.9.*") {
    Write-Host ""
    Write-Host "WARNING: Unrecognised GOWIN EDA version: $installFolderName"
    Write-Host "         This script was developed and verified with V1.9.12.01."
    Write-Host "         Continuing anyway..."
    Write-Host ""

} else {
    Write-Host ""
    Write-Host "WARNING: GOWIN EDA $installFolderName has not been tested with this script."
    Write-Host "         This script was developed and verified with V1.9.12.01."
    Write-Host "         Continuing anyway..."
    Write-Host ""
}

# note: user.sv file is specified by build.tcl
# ---- PATHS ----
$GwSh               = "$GowinInstallDir\IDE\bin\gw_sh.exe"
$BuildTcl           = "$RepoRoot\build\platforms\gowin\devices\GW1NR-9\build.tcl"
$OutputDir          = "$RepoRoot\build\platforms\gowin\devices\GW1NR-9\C7I6\output"
$WindowsOutputDir   = "$PSScriptRoot\output"

# ---- CHIP SETTINGS FROM CSV ----
$ProjectName        = "BRS-100-GW1NR9"
$PartNumber         = "GW1NR-LV9QN88PC7/I6"
$DeviceVersion      = "C"
$SpeedGrade         = "C7I6"

# ---- CLEAN ALL PLATFORMS ---- runs before preflight checks
if ($a) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " CLEAN ALL BUILD OUTPUT"
    Write-Host "====================================="
    Write-Host ""
    Write-Host "WARNING: The following folders will be permanently deleted."
    Write-Host "There is no way to restore them without rebuilding."
    Write-Host ""

    if (Test-Path $OutputDir) {
        Write-Host "  $OutputDir"
    } else {
        Write-Host "  $OutputDir (does not exist, nothing to clean)"
    }
    if (Test-Path $WindowsOutputDir) {
        Write-Host "  $WindowsOutputDir"
    } else {
        Write-Host "  $WindowsOutputDir (does not exist, nothing to clean)"
    }

    Write-Host ""
    $confirm = Read-Host "Are you sure you want to delete these folders? (y/n)"

    if ($confirm -ne "y") {
        Write-Host "Clean cancelled."
        exit 0
    }

    Write-Host ""

    if (Test-Path $OutputDir) {
        Remove-Item -Recurse -Force $OutputDir
        Write-Host "Cleaned: $OutputDir"
    } else {
        Write-Host "Nothing to clean at: $OutputDir"
    }

    if (Test-Path $WindowsOutputDir) {
        Remove-Item -Recurse -Force $WindowsOutputDir
        Write-Host "Cleaned: $WindowsOutputDir"
    } else {
        Write-Host "Nothing to clean at: $WindowsOutputDir"
    }

    Write-Host ""
    Write-Host "====================================="
    Write-Host " CLEAN COMPLETE"
    Write-Host "====================================="
    exit 0
}

# ---- DUMMY HANDLERS FOR NOT YET IMPLEMENTED FLAGS ----
if ($t) { Write-Host "NOTE: -t / -custom_target is not yet implemented. Using default target." }
if ($f) { Write-Host "NOTE: -f / -platform is not yet implemented. Using default platform." }
if ($c) { Write-Host "NOTE: -c / -clean is not yet implemented."; exit 0 }
if ($m) { Write-Host "NOTE: -m / -clean_platform is not yet implemented."; exit 0 }
if ($d) { Write-Host "NOTE: -d / -list_default_target is not yet implemented."; exit 0 }
if ($i) { Write-Host "NOTE: -i / -list_supported_platforms is not yet implemented."; exit 0 }
if ($l) { Write-Host "NOTE: -l / -list_supported_targets is not yet implemented."; exit 0 }
if ($y) { Write-Host "NOTE: -y / -list_supported_system_clock_frequencies is not yet implemented."; exit 0 }

# ---- PRE-FLIGHT CHECKS ----

## build.tcl
if (-not (Test-Path $BuildTcl)) {
    Write-Host "ERROR: Cannot find build.tcl at: $BuildTcl"
    Write-Host "Please check RepoRoot was correctly derived from Git."
    exit 1
}

## create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    Write-Host "Creating output directory: $OutputDir"
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

## generate autogen_top_wrapper.sv
Write-Host "Generating autogen_top_wrapper.sv..."
& "$PSScriptRoot\generate_top_wrapper.ps1" `
    -BuildArtifactsDirectory "$OutputDir\.artifacts" `
    -TopWrapperFilename      "autogen_top_wrapper.sv" `
    -ClockFrequencyMhz       $ClockMhz `
    -UartBaud                $UartBaud `
    -PushbuttonReset         $PushbuttonReset `
    -BoardDemonstration      $BoardDemonstration

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to generate autogen_top_wrapper.sv"
    exit 1
}

# ---- RUN THE BUILD ----
Write-Host ""
Write-Host "====================================="
Write-Host " BRS-100-GW1NR9 Windows Build"
Write-Host "====================================="
Write-Host "Repo    : $RepoRoot"
Write-Host "Output  : $OutputDir"
Write-Host "Device  : $PartNumber (v$DeviceVersion, $SpeedGrade)"
Write-Host "Clock   : $ClockMhz MHz"
Write-Host "UART    : $UartBaud baud"
Write-Host "Reset   : $(if ($PushbuttonReset -eq 1) { 'enabled' } else { 'disabled' })"
Write-Host "Mode    : $(if ($BoardDemonstration -eq 1) { 'board demonstration' } else { 'LED blink (user.sv)' })"
Write-Host "Build   : $(if ($p) { 'project only' } elseif ($s) { 'synthesis only' } else { 'full build' })"
Write-Host "GOWIN   : $installFolderName"
Write-Host "====================================="
Write-Host "Starting build..."
Write-Host ""

& $GwSh $BuildTcl $ProjectName $RepoRoot $OutputDir $PartNumber $DeviceVersion $SpeedGrade $ClockMhz $DoProjectGenOnly $DoSynthOnly

# ---- RESULT ----
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "====================================="

    if ($p) {
        # ---- PROJECT ONLY RESULT ----
        Write-Host " PROJECT GENERATION COMPLETE"
        Write-Host "====================================="

        $projSource = "$OutputDir\$ProjectName"
        $projDest   = "$WindowsOutputDir\$ProjectName"

        Write-Host "Project files at: $projSource"

        if (-not (Test-Path $WindowsOutputDir)) {
            New-Item -ItemType Directory -Path $WindowsOutputDir -Force | Out-Null
        }
        Copy-Item $projSource $projDest -Recurse -Force
        Write-Host "Project copied to: $projDest"
        Write-Host ""
        Write-Host "Open GOWIN IDE and load the project from: $projDest"

    } elseif ($s) {
        # ---- SYNTHESIS ONLY RESULT ----
        Write-Host " SYNTHESIS COMPLETE"
        Write-Host "====================================="

        $rptSource = "$OutputDir\$ProjectName\impl\gwsynthesis\$ProjectName`_syn.rpt.html"
        $rptDest   = "$WindowsOutputDir\$ProjectName`_syn.rpt.html"

        Write-Host "Synthesis report at: $rptSource"

        if (Test-Path $rptSource) {
            if (-not (Test-Path $WindowsOutputDir)) {
                New-Item -ItemType Directory -Path $WindowsOutputDir -Force | Out-Null
            }
            Copy-Item $rptSource $rptDest -Force
            Write-Host "Report copied to: $rptDest"
        } else {
            Write-Host "WARNING: Synthesis report not found at expected location."
        }

    } else {
        # ---- FULL BUILD RESULT ----
        Write-Host " BUILD SUCCESS"
        Write-Host "====================================="

        $fsSource = "$OutputDir\.artifacts\BRS-100-GW1NR9.fs"
        $fsDest   = "$WindowsOutputDir\BRS-100-GW1NR9.fs"

        if (Test-Path $fsSource) {
            Write-Host ".fs file ready at: $fsSource"

            if (-not (Test-Path $WindowsOutputDir)) {
                New-Item -ItemType Directory -Path $WindowsOutputDir -Force | Out-Null
            }
            Copy-Item $fsSource $fsDest -Force
            Write-Host ".fs file copied to: $fsDest"

        } else {
            Write-Host "WARNING: .fs not found at expected location."
            Write-Host "Searching output folder for .fs files..."
            Get-ChildItem -Recurse -Filter "*.fs" -Path $OutputDir
        }
    }

} else {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " BUILD FAILED (exit code: $LASTEXITCODE)"
    Write-Host "====================================="
    exit 1
}
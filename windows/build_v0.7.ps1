# =============================================================
# build_v0.7.ps1
# Windows build script for BRS-100-GW1NR9
#
# Author:    Bruce Mao
# Based on build.sh, originally authored by Craig Haywood
# Copyright: (C) Brisbane Silicon, Pty Ltd. All rights reserved.
#
# The source code contained herein is provided on an "as is" basis.
# Brisbane Silicon, Pty Ltd. disclaims any and all warranties,
# whether express, implied, or statutory, including any implied
# warranties of merchantability or of fitness for a particular
# purpose. In no event shall Brisbane Silicon, Pty Ltd. be liable
# for any incidental, punitive, or consequential damages of any
# kind whatsoever arising from the use of this source code.
#
# This disclaimer of warranty extends to the user of this source
# code and user's customers, employees, agents, transferees,
# successors and assigns.
#
# This is not a grant of patent rights.
#
# =============================================================
# version 0.1 - minimal functionality, hardcoded paths
# version 0.2 - added command line options and generate_top_wrapper
# version 0.3 - implemented -p, -s, -a flags, added /output copy, y/n prompt for -a
# version 0.4 - auto-derive RepoRoot from Git, auto-detect GOWIN install path,
#               version compatibility check
# version 0.5 - validate -k against CSV, implement -y, add build timing
# version 0.6 - read chip settings from CSV, nothing hardcoded
#               implemented -d, -i, -l, -c flags
#               derive OutputDir and BuildTcl from CSV values
#               added empty CSV checks matching Linux return code pattern
#               added generate_top_wrapper.ps1 existence check
#               improved RepoRoot empty string handling
# version 0.7 - implemented setup_build_output_directory — clean before build
#               implemented is_supported_platform — validate platform exists
#               note: xilinx not yet implemented. This script is currently only for GOWIN builds.
# =============================================================

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

    [Alias('list_supported_system_clock_frequencies')]
    [switch]$y,

    [Alias('list_default_target')]
    [switch]$d,

    [Alias('list_supported_platforms')]
    [switch]$i,

    [Alias('list_supported_targets')]
    [switch]$l,

    [Alias('clean')]
    [switch]$c,

    # ---- NOT YET IMPLEMENTED, NOT IMPORTANT FOR CURRENT BOARD----
    [Alias('custom_target')]
    [string]$t          = "",

    [Alias('platform')]
    [string]$f          = "",

    [Alias('clean_platform')]
    [switch]$m
)


# ---- HELP ---- 
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
    Write-Host "  -c, -clean                          Delete current target build output and exit"
    Write-Host "  -y, -list_supported_system_clock_frequencies   List valid clock frequencies and exit"
    Write-Host "  -d, -list_default_target            Print default target and exit"
    Write-Host "  -i, -list_supported_platforms       List supported platforms and exit"
    Write-Host "  -l, -list_supported_targets         List supported targets and exit"
    Write-Host "  -h, -help                           Show this help and exit"
    Write-Host ""
    Write-Host "  Not Yet Implemented:"
    Write-Host "  -t, -custom_target <TARGET>         Target a different board"
    Write-Host "  -f, -platform <PLATFORM>            Specify platform explicitly"
    Write-Host "  -m, -clean_platform                 Clean all devices for platform and exit"
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
    Write-Host "  .\build.ps1 -c                      Clean current target build output"
    Write-Host "  .\build.ps1 -y                      List supported clock frequencies"
    Write-Host "  .\build.ps1 -d                      Print default target"
    Write-Host "  .\build.ps1 -i                      List supported platforms"
    Write-Host "  .\build.ps1 -l                      List supported targets"
    Write-Host ""
    Write-Host "AUTHOR"
    Write-Host "    Written by Bruce Mao"
    Write-Host ""
    Write-Host "COPYRIGHT"
    Write-Host "    (C) Brisbane Silicon, Pty Ltd. All rights reserved."
    Write-Host ""
    Write-Host "    The source code contained herein is provided on an `"as is`" basis. Brisbane Silicon, Pty Ltd."
    Write-Host "    disclaims any and all warranties, whether express, implied, or statutory, including any implied"
    Write-Host "    warranties of merchantability or of fitness for a particular purpose. In no event shall Brisbane"
    Write-Host "    Silicon, Pty Ltd. be liable for any incidental, punitive, or consequential damages of any kind"
    Write-Host "    whatsoever arising from the use of this source code."
    Write-Host ""
    Write-Host "    This disclaimer of warranty extends to the user of this source code and user's customers,"
    Write-Host "    employees, agents, transferees, successors and assigns."
    Write-Host ""
    Write-Host "    This is not a grant of patent rights."
    Write-Host ""

    exit 0
}

# ---- CORE PARAMS ----
$BoardDemonstration = if ($b) { 1 } else { 0 }
$ClockMhz           = $k
$UartBaud           = $u
$PushbuttonReset    = if ($r) { 0 } else { 1 }
$DoProjectGenOnly   = if ($p) { "true" } else { "false" }
$DoSynthOnly        = if ($s) { "true" } else { "false" }

# ---- REPO ROOT DETECTION ----
$RepoRoot = (git rev-parse --show-toplevel 2>$null) -replace '/', '\'
if (-not $RepoRoot -or $RepoRoot.Trim() -eq '') {
    Write-Host "ERROR: Could not determine repo root from Git."
    Write-Host "Make sure Git is installed and you are running this script from inside the repository."
    exit 1
}

# ---- GOWIN INSTALL PATH DETECTION ----
$GowinInstallDir = $null

# define common paths for GOWIN v1.9.12.01 and v1.9.12.01
$commonPaths = @(
    "C:\Gowin\Gowin_V1.9.12.01_x64",
    "C:\Gowin\Gowin_V1.9.12.01",
    "C:\Gowin\Gowin_V1.9.12_x64",
    "C:\Gowin\Gowin_V1.9.12",
    "C:\Program Files\Gowin\Gowin_V1.9.12.01_x64",
    "C:\Program Files\Gowin\Gowin_V1.9.12.01",
    "$env:LOCALAPPDATA\Gowin\Gowin_V1.9.12.01_x64",
    "$env:LOCALAPPDATA\Gowin\Gowin_V1.9.12.01"
    "C:\Gowin\Gowin_V1.9.12.02_x64",
    "C:\Gowin\Gowin_V1.9.12.02",
    "C:\Program Files\Gowin\Gowin_V1.9.12.02_x64",
    "C:\Program Files\Gowin\Gowin_V1.9.12.02",
    "$env:LOCALAPPDATA\Gowin\Gowin_V1.9.12.02_x64",
    "$env:LOCALAPPDATA\Gowin\Gowin_V1.9.12.02"
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
$installFolderName = Split-Path $GowinInstallDir -Leaf
Write-Host "Found GOWIN EDA at: $GowinInstallDir"

if ($installFolderName -like "*1.9.12*") {
    Write-Host "GOWIN version: $installFolderName (verified compatible)"

} elseif ($installFolderName -like "*1.9.11.01*") {
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
$PlatformsDir       = "$RepoRoot\build\platforms"
$FreqCsvPath        = "$RepoRoot\build\platforms\gowin\gowin_supported_system_clock_frequencies.csv"
$DevicesCsvPath     = "$RepoRoot\build\platforms\gowin\gowin_supported_devices_information.csv"
$WindowsOutputDir   = "$PSScriptRoot\output"
$Platform           = "gowin"

# ---- IS_SUPPORTED_PLATFORM ----
# checks platform folder exists before proceeding with any platform-specific operations
function Test-SupportedPlatform {
    param([string]$PlatformName)
    $platformPath = "$PlatformsDir\$PlatformName"
    if (Test-Path $platformPath) {
        return $true
    }
    return $false
}

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

# ---- IMPLEMENT -d / list_default_target ----
if ($d) {
    Write-Host ""
    Write-Host "Default target: $ProjectName"
    exit 0
}

# ---- IMPLEMENT -i / list_supported_platforms ----
if ($i) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " Supported Platforms"
    Write-Host "====================================="
    if (Test-Path $PlatformsDir) {
        Get-ChildItem -Directory $PlatformsDir |
            Select-Object -ExpandProperty Name |
            ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "ERROR: Platforms directory not found at: $PlatformsDir"
    }
    Write-Host "====================================="
    exit 0
}

# ---- IMPLEMENT -l / list_supported_targets ----
if ($l) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " Supported Targets"
    Write-Host "====================================="
    $devices | ForEach-Object {
        Write-Host "  $($_.'Build Target'.Trim())"
    }
    Write-Host "====================================="
    exit 0
}

# ---- IMPLEMENT -y / list_supported_system_clock_frequencies ----
if ($y) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " Supported System Clock Frequencies"
    Write-Host "====================================="
    Write-Host "Platform : $Platform"
    Write-Host "Target   : $ProjectName"
    Write-Host -NoNewline "Freq MHz : "
    Write-Host ($supportedFreqs -join ", ")
    Write-Host "====================================="
    exit 0
}

# ---- VALIDATE -k CLOCK FREQUENCY AGAINST CSV ----
if ($PSBoundParameters.ContainsKey('k')) {
    if ($supportedFreqs -notcontains $ClockMhz) {
        Write-Host ""
        Write-Host "ERROR: Clock frequency $ClockMhz MHz is not supported."
        Write-Host ""
        Write-Host "Supported frequencies (MHz): $($supportedFreqs -join ', ')"
        Write-Host "Use .\build.ps1 -y to list supported frequencies."
        Write-Host ""
        exit 1
    }
}

# ---- IMPLEMENT -c / clean ----
# deletes current target build output only
if ($c) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " CLEAN TARGET BUILD OUTPUT"
    Write-Host "====================================="

    if (Test-Path $OutputDir) {
        Remove-Item -Recurse -Force $OutputDir
        Write-Host "Cleaned: $OutputDir"
    } else {
        Write-Host "Nothing to clean at: $OutputDir"
    }

    Write-Host "====================================="
    Write-Host " CLEAN COMPLETE"
    Write-Host "====================================="
    exit 0
}

# ---- CLEAN ALL PLATFORMS ----
# note: added a (y/n) prompt, which linux version doesn't have. 
# delete user prompt if needed
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

# ---- PARTIALLY IMPLEMENTED FLAGS ----
if ($t) {
    # check if the target exists in the CSV
    $customDevice = $devices | Where-Object { $_.'Build Target'.Trim() -eq $t }
    if (-not $customDevice) {
        Write-Host ""
        Write-Host "ERROR: Build target '$t' is not supported."
        Write-Host ""
        Write-Host "Supported targets:"
        $devices | ForEach-Object { Write-Host "  $($_.'Build Target'.Trim())" }
        Write-Host ""
        Write-Host "Note: -t / -custom_target is not yet fully implemented."
        Write-Host "      Only the default target '$ProjectName' is currently supported."
        exit 1
    }
    Write-Host "NOTE: -t / -custom_target is not yet fully implemented."
    Write-Host "      Continuing with default target: $ProjectName"
}

# ---- DUMMY HANDLERS FOR NOT YET IMPLEMENTED FLAGS ----


if ($f) { Write-Host "NOTE: -f / -platform is not yet implemented. Using default platform." }
if ($m) { Write-Host "NOTE: -m / -clean_platform is not yet implemented."; exit 0 }

# ---- PRE-FLIGHT CHECKS ----

## checks generate_top_wrapper.ps1
if (-not (Test-Path "$PSScriptRoot\generate_top_wrapper.ps1")) {
    Write-Host "ERROR: generate_top_wrapper.ps1 not found at: $PSScriptRoot"
    Write-Host "Make sure generate_top_wrapper.ps1 is in the same folder as this script."
    exit 1
}

## checks build.tcl
if (-not (Test-Path $BuildTcl)) {
    Write-Host "ERROR: Cannot find build.tcl at: $BuildTcl"
    Write-Host "Please check RepoRoot was correctly derived from Git."
    exit 1
}

# ---- SETUP_BUILD_OUTPUT_DIRECTORY ----
# matches Linux setup_build_output_directory() —
# clean old output first, then create fresh artifacts folder
# ensures every build starts completely clean with no leftover files
Write-Host "Setting up build output directory..."

if (Test-Path $OutputDir) {
    Remove-Item -Recurse -Force $OutputDir
    Write-Host "  Cleaned old output: $OutputDir"
}

New-Item -ItemType Directory -Path $ArtifactsDir -Force | Out-Null
Write-Host "  Created artifacts dir: $ArtifactsDir"

## generate autogen_top_wrapper.sv
Write-Host "Generating autogen_top_wrapper.sv..."
& "$PSScriptRoot\generate_top_wrapper.ps1" `
    -BuildArtifactsDirectory $ArtifactsDir `
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
Write-Host "Repo     : $RepoRoot"
Write-Host "Platform : $Platform"
Write-Host "Output   : $OutputDir"
Write-Host "Device   : $PartNumber (v$DeviceVersion, $SpeedGrade)"
Write-Host "Clock    : $ClockMhz MHz"
Write-Host "UART     : $UartBaud baud"
Write-Host "Reset    : $(if ($PushbuttonReset -eq 1) { 'enabled' } else { 'disabled' })"
Write-Host "Mode     : $(if ($BoardDemonstration -eq 1) { 'board demonstration' } else { 'LED blink (user.sv)' })"
Write-Host "Build    : $(if ($p) { 'project only' } elseif ($s) { 'synthesis only' } else { 'full build' })"
Write-Host "GOWIN    : $installFolderName"
Write-Host "====================================="
Write-Host "Starting build..."
Write-Host ""

# ---- START TIMER ----
$startTime = Get-Date

& $GwSh $BuildTcl $ProjectName $RepoRoot $OutputDir $PartNumber $DeviceVersion $SpeedGrade $ClockMhz $DoProjectGenOnly $DoSynthOnly

# ---- STOP TIMER ----
$elapsed = (Get-Date) - $startTime

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

        $fsSource = "$ArtifactsDir\BRS-100-GW1NR9.fs"
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

    # ---- BUILD TIMING ----
    Write-Host ""
    if ($elapsed.Hours -gt 0) {
        Write-Host "Build time: $($elapsed.Hours)h $($elapsed.Minutes)m $($elapsed.Seconds)s"
    } else {
        Write-Host "Build time: $($elapsed.Minutes)m $($elapsed.Seconds)s"
    }

} else {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " BUILD FAILED (exit code: $LASTEXITCODE)"
    Write-Host "====================================="

    if ($elapsed.Hours -gt 0) {
        Write-Host "Failed after: $($elapsed.Hours)h $($elapsed.Minutes)m $($elapsed.Seconds)s"
    } else {
        Write-Host "Failed after: $($elapsed.Minutes)m $($elapsed.Seconds)s"
    }

    exit 1
}
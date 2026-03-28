# =============================================================
# program_board_v0.6.ps1
# Windows programming script for BRS-100-GW1NR9
#
# Author:    Bruce Mao
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
# version 0.4 - detect programmer.exe GUI running (exclusive cable lock)
#               -k / --clock_frequency    pass clock frequency to build script
#               -f / --jtag_frequency     override JTAG programming frequency
#               warn if programmer.exe is running before cable scan
# version 0.4.1 - fix intermittent hang during embFlash erase:
#               programmer_cli.exe occasionally hangs because the ftd2xx driver
#               doesn't fully release the USB handle between invocations. the
#               FTDI chip's state machine accumulates stale state until it locks.
#               fix: call FT_CyclePort via ftd2xx.dll P/Invoke before programming
#               to force the FTDI chip to USB re-enumerate, clearing stale handles.
#               this is equivalent to a physical USB unplug/replug.
# version 0.5.1 - align flags with Linux program_board.sh:
#               -d / --list_default_target        print default target and exit
#               -l / --list_supported_targets     list all supported boards and exit
#               -s / --check_if_target_supported  print whether this board is supported and exit
#               -b / --check_if_target_built      renamed from --check_if_built to match Linux
#               -c / --clean_target_prior         renamed from --clean to match Linux
#               -f / --update_flash_only          dummy flag (Xilinx only, not implemented)
#               -t / --custom_target              dummy flag (single target, not implemented)
#               --jtag_frequency                  renamed from -f (no short flag, avoids -f collision)
# version 0.6 - add author and copyright statement
#               update help text references to v0.6
# =============================================================

param(
    [switch]$h,
    [switch]$help,
    [switch]$d,
    [switch]$list_default_target,
    [switch]$c,
    [switch]$clean_target_prior,
    [switch]$l,
    [switch]$list_supported_targets,
    [switch]$s,
    [switch]$check_if_target_supported,
    [switch]$b,
    [switch]$check_if_target_built,
    [string]$m,
    [string]$custom_bitfile,
    [string]$t,
    [string]$custom_target,
    [string]$f,
    [string]$update_flash_only,

    [Alias('clock_frequency')]
    [int]$k = 0,

    [string]$jtag_frequency
)

# ---- NORMALISE ALIASES ----
$ShowHelp                  = $h -or $help
$ListDefaultTarget         = $d -or $list_default_target
$CleanBuild                = $c -or $clean_target_prior
$ListSupportedTargets      = $l -or $list_supported_targets
$CheckIfTargetSupported    = $s -or $check_if_target_supported
$CheckIfTargetBuilt        = $b -or $check_if_target_built
$CustomBitfile             = if ($m) { $m } elseif ($custom_bitfile) { $custom_bitfile } else { $null }
$CustomTarget              = if ($t) { $t } elseif ($custom_target) { $custom_target } else { $null }
$UpdateFlashOnly           = if ($f) { $f } elseif ($update_flash_only) { $update_flash_only } else { $null }
$ClockMhz                  = $k
$JtagFrequency             = $jtag_frequency

# ---- CONSTANTS ----
$DefaultJtagFrequency = "0.02MHz"
$ValidJtagFrequencies = @(
    "2.5MHz", "2MHz", "15MHz", "10MHz", "1.5MHz", "1.1MHz",
    "0.9MHz", "0.75MHz", "0.5MHz", "0.3MHz", "0.4MHz", "0.1MHz", "0.02MHz"
)

# ---- HELP ----
function Show-Help {
    Write-Host ""
    Write-Host "PROGRAM_BOARD"
    Write-Host ""
    Write-Host "NAME"
    Write-Host "    program_board - program the BRS-100-GW1NR9 board with FPGA firmware"
    Write-Host ""
    Write-Host "SYNOPSIS"
    Write-Host "    .\program_board_v0.6.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "DESCRIPTION"
    Write-Host "    Program the BRS-100-GW1NR9 board via JTAG using programmer_cli.exe."
    Write-Host "    If firmware is not yet built, automatically triggers a build first."
    Write-Host ""
    Write-Host "OPTIONS"
    Write-Host "    -h, --help"
    Write-Host "        Display this help and exit."
    Write-Host ""
    Write-Host "    -d, --list_default_target"
    Write-Host "        Print the default target board name and exit."
    Write-Host ""
    Write-Host "    -c, --clean_target_prior"
    Write-Host "        Clean the build output before building and programming."
    Write-Host ""
    Write-Host "    -f, --update_flash_only  <MCS_FILE_PATH>"
    Write-Host "        [NOT IMPLEMENTED] Update flash with provided MCS file."
    Write-Host "        This flag exists for compatibility with the Linux script."
    Write-Host "        Flash update is only supported on Xilinx boards (ARTYS7-25/50)."
    Write-Host ""
    Write-Host "    -m, --custom_bitfile  <PATH>"
    Write-Host "        Program the board with a custom .fs file instead of the default"
    Write-Host "        build output. Path must be the full path to a .fs file."
    Write-Host ""
    Write-Host "    -l, --list_supported_targets"
    Write-Host "        List all supported target boards and exit."
    Write-Host ""
    Write-Host "    -s, --check_if_target_supported"
    Write-Host "        Print whether the current target board is supported and exit."
    Write-Host ""
    Write-Host "    -b, --check_if_target_built"
    Write-Host "        Print firmware built status of the target board and exit."
    Write-Host ""
    Write-Host "    -t, --custom_target  <TARGET>"
    Write-Host "        [NOT IMPLEMENTED] Instead of the default target, target CUSTOM_TARGET."
    Write-Host "        This flag exists for compatibility with the Linux script."
    Write-Host "        Currently only one target (BRS-100-GW1NR9) is supported."
    Write-Host ""
    Write-Host "    -k, --clock_frequency  <MHz>"
    Write-Host "        System clock frequency in MHz passed to the build script when"
    Write-Host "        auto-triggering a build. Ignored when using -m (custom bitfile)."
    Write-Host "        Valid values: 51, 66, 75, 81, 87 (default: 51)"
    Write-Host ""
    Write-Host "    --jtag_frequency  <freq>"
    Write-Host "        Override the JTAG programming clock frequency (default: 0.5MHz)."
    Write-Host "        Valid values: $($ValidJtagFrequencies -join ', ')"
    Write-Host "        (Windows-only flag, no short form to avoid collision with -f)"
    Write-Host ""
    Write-Host "EXAMPLES"
    Write-Host "    .\program_board_v0.6.ps1"
    Write-Host "        Build (if needed) and program the board."
    Write-Host ""
    Write-Host "    .\program_board_v0.6.ps1 -c"
    Write-Host "        Clean, rebuild, and program the board."
    Write-Host ""
    Write-Host "    .\program_board_v0.6.ps1 -b"
    Write-Host "        Check whether firmware is built without programming."
    Write-Host ""
    Write-Host "    .\program_board_v0.6.ps1 -m C:\path\to\custom.fs"
    Write-Host "        Program the board with a custom bitstream file."
    Write-Host ""
    Write-Host "    .\program_board_v0.6.ps1 -k 66"
    Write-Host "        Build at 66 MHz and program the board."
    Write-Host ""
    Write-Host "    .\program_board_v0.6.ps1 -c -k 75"
    Write-Host "        Clean, rebuild at 75 MHz, and program the board."
    Write-Host ""
    Write-Host "    .\program_board_v0.6.ps1 --jtag_frequency 2.5MHz"
    Write-Host "        Program at 2.5MHz JTAG speed (faster, less reliable)."
    Write-Host ""
    Write-Host "IMPORTANT NOTICE"
    Write-Host "    The Windows ftd2xx driver may cause the script to freeze during programming."
    Write-Host "    If the script freezes at the following line:"
    Write-Host ""
    Write-Host "        Operation `"embFlash Erase,Program`" for device#1..."
    Write-Host ""
    Write-Host "    Manually kill programmer_cli.exe in Task Manager and disconnect the USB-C"
    Write-Host "    cable for 3-5 seconds before reconnecting. See detailed troubleshooting"
    Write-Host "    steps in windows\TROUBLESHOOTING.txt."
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
}

if ($ShowHelp) {
    Show-Help
    exit 0
}

# ---- DUMMY FLAGS (not implemented for Gowin / single-target) ----
if ($UpdateFlashOnly) {
    Write-Host "ERROR: -f / --update_flash_only is not implemented on Windows."
    Write-Host "       Flash update is only supported on Xilinx boards (ARTYS7-25/50)"
    Write-Host "       via the Linux program_board.sh script."
    exit 1
}

if ($CustomTarget) {
    if ($CustomTarget -eq "BRS-100-GW1NR9") {
        Write-Host "Target '$CustomTarget' is already the default target - continuing."
    } else {
        Write-Host "ERROR: Target '$CustomTarget' is not supported."
        Write-Host "       Only 'BRS-100-GW1NR9' is supported in this version."
        exit 1
    }
}

# ---- VALIDATE JTAG FREQUENCY ----
if ($JtagFrequency) {
    if ($ValidJtagFrequencies -notcontains $JtagFrequency) {
        Write-Host "ERROR: Invalid JTAG frequency '$JtagFrequency'."
        Write-Host "Valid values: $($ValidJtagFrequencies -join ', ')"
        exit 1
    }
} else {
    $JtagFrequency = $DefaultJtagFrequency
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
$ProgrammerGui  = "$GowinInstallDir\Programmer\bin\programmer.exe"
$BuildScript    = "$RepoRoot\windows\build_v0.7.ps1"
$DevicesCsvPath = "$RepoRoot\build\platforms\gowin\gowin_supported_devices_information.csv"
$BoardsCsvPath  = "$RepoRoot\prog\supported_boards.csv"

# ---- FTDI USB RESET VIA ftd2xx.dll ----
# programmer_cli.exe occasionally hangs because the ftd2xx driver doesn't fully
# release the USB handle between invocations. calling FT_CyclePort forces the
# FTDI chip to USB re-enumerate (equivalent to physical unplug/replug), clearing
# any stale driver state that would cause the next programmer_cli call to deadlock.
#
# ftd2xx API reference: https://ftdichip.com/wp-content/uploads/2024/09/D2XX_Programmers_Guide.pdf
# FT_STATUS values: FT_OK=0, FT_INVALID_HANDLE=1, FT_DEVICE_NOT_FOUND=2, etc.
$Ftd2xxDll = "$GowinInstallDir\Programmer\bin\ftd2xx.dll"

if (Test-Path $Ftd2xxDll) {
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Ftd2xx {
    // FT_Open: open device by index number
    // returns FT_STATUS (0 = FT_OK)
    [DllImport("ftd2xx.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint FT_Open(uint deviceNumber, out IntPtr ftHandle);

    // FT_Close: close an open device handle
    [DllImport("ftd2xx.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint FT_Close(IntPtr ftHandle);

    // FT_CyclePort: causes the USB device to be re-enumerated by the host.
    // equivalent to unplugging and replugging the USB cable.
    // the handle is invalid after this call - must close and re-open.
    [DllImport("ftd2xx.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint FT_CyclePort(IntPtr ftHandle);

    // FT_ResetDevice: sends a reset command to the FTDI device
    [DllImport("ftd2xx.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint FT_ResetDevice(IntPtr ftHandle);

    // FT_CreateDeviceInfoList: returns number of FTDI devices connected
    [DllImport("ftd2xx.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint FT_CreateDeviceInfoList(out uint numDevs);
}
"@

        # must set DLL search path so P/Invoke finds ftd2xx.dll in Gowin's bin dir
        $env:PATH = "$GowinInstallDir\Programmer\bin;$env:PATH"

        $script:Ftd2xxLoaded = $true
    } catch {
        Write-Host "WARNING: Could not load ftd2xx.dll for USB reset: $_"
        Write-Host "         Continuing without USB reset (may hang on rapid re-runs)."
        $script:Ftd2xxLoaded = $false
    }
} else {
    Write-Host "WARNING: ftd2xx.dll not found at: $Ftd2xxDll"
    Write-Host "         Continuing without USB reset (may hang on rapid re-runs)."
    $script:Ftd2xxLoaded = $false
}

function Reset-FtdiDevice {
    <#
    .SYNOPSIS
        Reset all FTDI devices via FT_CyclePort to clear stale USB handle state.
        This forces a USB re-enumeration equivalent to physical unplug/replug.
    #>
    if (-not $script:Ftd2xxLoaded) {
        return $false
    }

    try {
        # enumerate how many FTDI devices are connected
        [uint32]$numDevs = 0
        $status = [Ftd2xx]::FT_CreateDeviceInfoList([ref]$numDevs)
        if ($status -ne 0) {
            Write-Host "WARNING: FT_CreateDeviceInfoList failed (status=$status)"
            return $false
        }

        if ($numDevs -eq 0) {
            Write-Host "WARNING: No FTDI devices found for reset."
            return $false
        }

        Write-Host "Resetting $numDevs FTDI device(s) to clear stale USB state..."

        # cycle port on device index 0 (JTAG interface)
        # this resets the entire FT2232H chip (both channels)
        [IntPtr]$handle = [IntPtr]::Zero
        $status = [Ftd2xx]::FT_Open(0, [ref]$handle)
        if ($status -ne 0) {
            Write-Host "WARNING: FT_Open failed (status=$status) - device may be in use."
            return $false
        }

        # reset the device first (clears internal buffers)
        $status = [Ftd2xx]::FT_ResetDevice($handle)
        if ($status -ne 0) {
            Write-Host "WARNING: FT_ResetDevice failed (status=$status)"
            [void][Ftd2xx]::FT_Close($handle)
            return $false
        }

        # cycle port forces full USB re-enumeration
        $status = [Ftd2xx]::FT_CyclePort($handle)
        if ($status -ne 0) {
            Write-Host "WARNING: FT_CyclePort failed (status=$status)"
            [void][Ftd2xx]::FT_Close($handle)
            return $false
        }

        # handle is invalid after CyclePort but close anyway for cleanup
        [void][Ftd2xx]::FT_Close($handle)

        # wait for Windows to complete USB re-enumeration
        # FT_CyclePort triggers a disconnect+reconnect cycle at the USB level
        Write-Host "Waiting for USB re-enumeration..."
        Start-Sleep -Seconds 3

        return $true
    } catch {
        Write-Host "WARNING: FTDI reset failed: $_"
        return $false
    }
}

# ---- PROJECT SETTINGS ----
$ProjectName    = "BRS-100-GW1NR9"

# ---- -d / --list_default_target ----
# print the default target board name and exit.
# matches Linux: echo "$target_board"
if ($ListDefaultTarget) {
    Write-Host $ProjectName
    exit 0
}

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

# ---- -l / --list_supported_targets ----
# list all unique board names from the CSV, comma-separated, and exit.
# matches Linux: list_supported_targets()
if ($ListSupportedTargets) {
    $uniqueBoards = $boards | ForEach-Object { $_.Board.Trim() } | Select-Object -Unique
    Write-Host ($uniqueBoards -join ", ")
    exit 0
}

$board = $boards | Where-Object { $_.Board.Trim() -eq $ProjectName }
if (-not $board) {
    Write-Host "ERROR: Board '$ProjectName' not found in supported boards CSV."
    Write-Host "Supported boards:"
    $boards | ForEach-Object { Write-Host "  $($_.Board.Trim())" }
    exit 1
}

# ---- -s / --check_if_target_supported ----
# print whether the current target board is in the supported_boards.csv and exit.
# matches Linux: check_if_target_supported flag
if ($CheckIfTargetSupported) {
    Write-Host "Target '$ProjectName' is supported."
    exit 0
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
# matches Linux format: "Target 'BRS-100-GW1NR9' firmware built status: true/false"
if ($CheckIfTargetBuilt) {
    if (Test-Path $DefaultFsFile) {
        Write-Host "Target '$ProjectName' firmware built status: true"
    } else {
        Write-Host "Target '$ProjectName' firmware built status: false"
    }
    exit 0
}

# ---- DETECT PROGRAMMER GUI RUNNING ----
# programmer.exe holds an exclusive lock on the USB cable — if it's running,
# programmer_cli.exe will fail to open the cable. detect this early and warn
# the user instead of letting them wait for a cryptic cable-open failure.
$programmerGuiName = [System.IO.Path]::GetFileNameWithoutExtension($ProgrammerGui)
$guiProcesses = Get-Process -Name $programmerGuiName -ErrorAction SilentlyContinue
if ($guiProcesses) {
    Write-Host ""
    Write-Host "ERROR: GOWIN Programmer GUI (programmer.exe) is currently running."
    Write-Host "       The GUI holds an exclusive lock on the USB cable and will"
    Write-Host "       prevent programmer_cli.exe from accessing the board."
    Write-Host ""
    Write-Host "Please close the Programmer GUI and try again."
    exit 1
}

# ---- RESET FTDI USB DEVICE ----
# clear any stale ftd2xx handle state from previous programmer_cli invocations.
# without this, rapid back-to-back programming can hang during embFlash erase
# because the FTDI chip's state machine never fully released the previous handle.
Write-Host ""
$resetResult = Reset-FtdiDevice
if ($resetResult) {
    Write-Host "FTDI USB reset complete."
} else {
    Write-Host "FTDI USB reset skipped - proceeding anyway."
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

        # build the argument list for the build script
        $buildArgs = @()
        if ($CleanBuild) {
            $buildArgs += "-c"
        }
        if ($ClockMhz -gt 0) {
            $buildArgs += "-k"
            $buildArgs += $ClockMhz
        }

        & $BuildScript @buildArgs

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
#   --frequency      : JTAG clock speed (default 0.5MHz, configurable via --jtag_frequency)
# without all three, programmer_cli falls back to FT2CH and fails with CRC errors.
# operation_index 5 = embFlash Erase,Program (matches Linux build.sh behaviour)
Write-Host ""
Write-Host "====================================="
Write-Host " BRS-100-GW1NR9 Windows Programmer"
Write-Host "====================================="
Write-Host "Device    : $DeviceArg"
Write-Host "Cable     : USB Debugger A (cable-index 4, location $cableLocation - JTAG)"
Write-Host "Frequency : $JtagFrequency"
Write-Host "Operation : embFlash Erase, Program (index 5)"
Write-Host "Bitstream : $FsFile"
Write-Host "Programmer: $ProgrammerCli"
Write-Host "====================================="
Write-Host ""
Write-Host "  [i] NOTE"
Write-Host "  If the script freezes below, kill programmer_cli.exe in Task Manager"
Write-Host "  and replug USB. See TROUBLESHOOTING.txt for details."
Write-Host ""

# echo exact command line before executing (matches Linux behaviour)
Write-Host "Program command line: '$ProgrammerCli --device $DeviceArg --cable-index 4 --location $cableLocation --frequency $JtagFrequency --operation_index 5 --fsFile $FsFile'"
Write-Host ""

& $ProgrammerCli --device $DeviceArg --cable-index 4 --location $cableLocation --frequency $JtagFrequency --operation_index 5 --fsFile $FsFile

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
    Write-Host ""
    Write-Host "If the script froze and you had to Ctrl+C, see:"
    Write-Host "  windows\TROUBLESHOOTING.txt"
    exit 1
}

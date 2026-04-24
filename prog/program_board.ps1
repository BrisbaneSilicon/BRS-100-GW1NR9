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
    Write-Host "${underlinef}PROGRAM_BOARD${normf}`n"
    Write-Host "${boldf}NAME${normf}"
    Write-Host "`tprogram_board - program a BRS-100-GW1NR9 board with FPGA firmware`n"
    Write-Host "${boldf}SYNOPSIS${normf}"
    Write-Host "`t${boldf}program_board${normf} ${underlinef}[OPTIONS...]${normf}`n"
    Write-Host "${boldf}DESCRIPTION${normf}"
    Write-Host "`tProgram the BRS-100-GW1NR9 board via JTAG using programmer_cli.exe."
    Write-Host "`tIf firmware is not yet built, automatically triggers a build first.`n"
    Write-Host "${boldf}OPTIONS${normf}"
    Write-Host "`t${boldf}-h, -help${normf}`n`t`tDisplay this help and exit.`n"
    Write-Host "`t${boldf}-d, -list_default_target${normf}`n`t`tList the default build target.`n"
    Write-Host "`t${boldf}-c, -clean_target_prior${normf}`n`t`tClean TARGET_BOARD build prior to building and programming the BRS-100-GW1NR9 board.`n"
    Write-Host "`t${boldf}-f, -update_flash_only${normf} MCS_FILE_FULLPATH`n`t`tUpdate TARGET_BOARD flash with provided MCS_FILE_FULLPATH. (not implemented on Windows)`n"
    Write-Host "`t${boldf}-m, -custom_bitfile${normf} CUSTOM_BITFILE_FULLPATH`n`t`tProgram TARGET_BOARD with custom bitfile CUSTOM_BITFILE_FULLPATH.`n"
    Write-Host "`t${boldf}-l, -list_supported_targets${normf}`n`t`tList supported build targets and exit.`n"
    Write-Host "`t${boldf}-s, -check_if_target_supported${normf}`n`t`tPrint supported status of provided target board and exit.`n"
    Write-Host "`t${boldf}-b, -check_if_target_built${normf}`n`t`tPrint firmware built status of provided target board and exit.`n"
    Write-Host "`t${boldf}-t, -custom_target${normf} CUSTOM_TARGET`n`t`tInstead of the default target, target 'CUSTOM_TARGET'. (not implemented on Windows)`n"
    Write-Host "`t${boldf}-k, -clock_frequency${normf} ${underlinef}FREQUENCY_MHZ${normf}`n`t`tSystem clock frequency in MHz passed to the build script when auto-triggering a build."
    Write-Host "`t`tIgnored when using -m. Valid values: 51, 66, 75, 81, 87 (default: 51).`n"
    Write-Host "`t${boldf}-jtag_frequency${normf} ${underlinef}FREQ${normf}`n`t`tOverride the JTAG programming clock frequency (default: 0.02MHz)."
    Write-Host "`t`tValid values: $($ValidJtagFrequencies -join ', ')."
    Write-Host "`t`tWindows-only flag - no short form to avoid collision with -f.`n"
    Write-Host "${boldf}EXAMPLES${normf}"
    Write-Host "`t${boldf}.\program_board.ps1${normf}`n`t`tBuild (if needed) and program the board.`n"
    Write-Host "`t${boldf}.\program_board.ps1 -c${normf}`n`t`tClean, rebuild, and program the board.`n"
    Write-Host "`t${boldf}.\program_board.ps1 -b${normf}`n`t`tCheck whether firmware is built without programming.`n"
    Write-Host "`t${boldf}.\program_board.ps1 -m C:\path\to\custom.fs${normf}`n`t`tProgram the board with a custom bitstream file.`n"
    Write-Host "`t${boldf}.\program_board.ps1 -k 66${normf}`n`t`tBuild at 66 MHz and program the board.`n"
    Write-Host "`t${boldf}.\program_board.ps1 -jtag_frequency 2.5MHz${normf}`n`t`tProgram at 2.5MHz JTAG speed. Faster but less reliable.`n"
    Write-Host "${boldf}IMPORTANT NOTICE${normf}"
    Write-Host "`tThe Windows ftd2xx driver may cause programmer_cli.exe to hang at embFlash Erase."
    Write-Host "`tThis script detects the hang automatically (no progress for 10 seconds) and"
    Write-Host "`tkills programmer_cli.exe. To recover: disconnect the USB-C cable for 3-5"
    Write-Host "`tseconds, then reconnect and re-run. See TROUBLESHOOTING.txt for details.`n"
    Write-Host "${boldf}AUTHOR${normf}"
    Write-Host "`tWritten by Bruce Mao"
    Write-Host "`tAdapted from linux program_board.sh by Craig Haywood`n"
    Write-Host "${boldf}COPYRIGHT${normf}"
    Write-Host $copyright
}

if ($ShowHelp) {
    . "$PSScriptRoot\program_board_utils.ps1"
    Show-Help
    exit 0
}

# ---- GLOBALS ----
. "$PSScriptRoot\program_board_globals.ps1"
# exit 1 in another script does not reliably terminate the caller in powershell.
# $ProgrammerCli is only set if all globals completed without error, so null means
# globals already printed the error message and just need to exit here.
if (-not $ProgrammerCli) { exit 1 }







# ---- DUMMY FLAGS (not implemented for Gowin / single-target) ----
if ($UpdateFlashOnly) {
    Write-Host "ERROR: -f / -update_flash_only is not implemented on Windows."
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

# ---- PROJECT SETTINGS ----
$ProjectName    = "BRS-100-GW1NR9"

# ---- -d / -list_default_target ----
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

# ---- -l / -list_supported_targets ----
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

# ---- -s / -check_if_target_supported ----
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

# ---- -b / -check_if_target_built ----
# matches Linux format: "Target 'BRS-100-GW1NR9' firmware built status: true/false"
if ($CheckIfTargetBuilt) {
    if (Test-Path $DefaultFsFile) {
        Write-Host "Target '$ProjectName' firmware built status: true"
    } else {
        Write-Host "Target '$ProjectName' firmware built status: false"
    }
    exit 0
}

# ---- UTILS (FTDI, needed only for programming) ----
. "$PSScriptRoot\program_board_utils.ps1"

# ---- DETECT PROGRAMMER GUI RUNNING ----
# programmer.exe holds an exclusive lock on the USB cable - if it's running,
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
    # match Linux program_board.sh flow:
    #   1. if -c flag, clean build output first (separate step)
    #   2. then check if firmware exists
    #   3. if not, trigger a normal build (without -c)
    if (-not (Test-Path $BuildScript)) {
        Write-Host "ERROR: Cannot find build script at: $BuildScript"
        Write-Host "Please check the build script exists at that location."
        exit 1
    }

    if ($CleanBuild) {
        Write-Host ""
        Write-Host "Clean build requested - cleaning build output first..."
        Write-Host ""

        $cleanArgs = @{ c = $true }
        & $BuildScript @cleanArgs

        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "ERROR: Clean failed."
            exit 1
        }
    }

    if (-not (Test-Path $FsFile)) {
        if (-not $CleanBuild) {
            Write-Host ""
            Write-Host "Detected firmware not built - triggering build..."
        } else {
            Write-Host ""
            Write-Host "Rebuilding firmware..."
        }
        Write-Host ""

        # build without -c (clean already done above if requested)
        $buildArgs = @{}
        if ($ClockMhz -gt 0) {
            $buildArgs['k'] = $ClockMhz
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
#   --frequency      : JTAG clock speed (default 0.5MHz, configurable via -jtag_frequency)
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
Write-Host "  [i] Hang detection active: if no progress appears for 10 s, programmer_cli.exe"
Write-Host "      will be killed automatically. Replug USB and re-run this script to recover."
Write-Host ""

# echo exact command line before executing (matches Linux behaviour)
Write-Host "Program command line: '$ProgrammerCli --device $DeviceArg --cable-index 4 --location $cableLocation --frequency $JtagFrequency --operation_index 5 --fsFile $FsFile'"
Write-Host ""
Write-Host "*** GOWIN programmer_cli Command Line Console ***"
Write-Host ""

$result = Invoke-ProgrammerCliWithStallDetection `
    -Exe $ProgrammerCli `
    -Arguments @('--device', $DeviceArg, '--cable-index', '4',
                 '--location', $cableLocation, '--frequency', $JtagFrequency,
                 '--operation_index', '5', '--fsFile', $FsFile)

# ---- RESULT ----
if ($result.Stalled) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " PROGRAMMING STALLED"
    Write-Host "====================================="
    Write-Host ""
    Write-Host "ERROR: programmer_cli.exe produced no progress for 10 seconds."
    Write-Host "       The Windows ftd2xx driver has hung at embFlash Erase."
    Write-Host "       programmer_cli.exe has been killed."
    Write-Host ""
    Write-Host "To recover:"
    Write-Host "  1. Disconnect the USB-C cable"
    Write-Host "  2. Wait 3-5 seconds"
    Write-Host "  3. Reconnect the cable"
    Write-Host "  4. Re-run this script"
    Write-Host ""
    Write-Host "See TROUBLESHOOTING.txt for details."
    exit 1

} elseif ($result.ExitCode -eq 0) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " PROGRAMMING SUCCESS"
    Write-Host "====================================="
    Write-Host "Board programmed successfully."
    Write-Host "The design will auto-load on every power-on."

} else {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " PROGRAMMING FAILED (exit code: $($result.ExitCode))"
    Write-Host "====================================="
    Write-Host ""
    Write-Host "Common causes:"
    Write-Host "  1. Board not plugged in via USB-C"
    Write-Host "  2. Wrong USB cable (must support data, not just power)"
    Write-Host "  3. GOWIN Programmer GUI is open - close it and try again"
    Write-Host "  4. Driver issue - try unplugging and replugging the board"
    Write-Host "  5. License issue - check GOWIN license via IDE: Help > Manage License"
    Write-Host ""
    Write-Host "See TROUBLESHOOTING.txt for details."
    exit 1
}

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

    # ---- NOT YET IMPLEMENTED (Phase 3) ----
    [Alias('proj_only')]
    [switch]$p,

    [Alias('synth_only')]
    [switch]$s,

    [Alias('custom_target')]
    [string]$t          = "",

    [Alias('platform')]
    [string]$f          = "",

    [Alias('clean')]
    [switch]$c,

    [Alias('clean_platform')]
    [switch]$m,

    [Alias('clean_all_platforms')]
    [switch]$a,

    [Alias('list_default_target')]
    [switch]$d,

    [Alias('list_supported_platforms')]
    [switch]$i,

    [Alias('list_supported_targets')]
    [switch]$l,

    [Alias('list_supported_system_clock_frequencies')]
    [switch]$y
)

# v0.3

# ---- PROCESS CORE PARAMETERS INTO CLEAN VARIABLES ----
$BoardDemonstration = if ($b) { 1 } else { 0 }
$ClockMhz           = $k
$UartBaud           = $u
$PushbuttonReset    = if ($r) { 0 } else { 1 }

# ---- TOOL DIRECTORY - change according to your installation ----
$GowinInstallDir    = "C:\Gowin\Gowin_V1.9.12.01_x64"
$RepoRoot           = "C:\Users\JQ\BRS-100\Forked repo BRS-100\BRS-100-GW1NR9"

# note: user.sv file is specified by build.tcl
# ---- PATHS ----
$GwSh               = "$GowinInstallDir\IDE\bin\gw_sh.exe"
$BuildTcl           = "$RepoRoot\build\platforms\gowin\devices\GW1NR-9\build.tcl"
$OutputDir          = "$RepoRoot\build\platforms\gowin\devices\GW1NR-9\C7I6\output"

# ---- CHIP SETTINGS FROM CSV ----
$ProjectName        = "BRS-100-GW1NR9"
$PartNumber         = "GW1NR-LV9QN88PC7/I6"
$DeviceVersion      = "C"
$SpeedGrade         = "C7I6"
$DoProjectGenOnly   = "false"   # wired to -p in Phase 3
$DoSynthOnly        = "false"   # wired to -s in Phase 3

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
    Write-Host "  -h, -help                           Show this help and exit"
    Write-Host ""
    Write-Host "  Not Yet Implemented:"
    Write-Host "  -p, -proj_only                      Generate project file only, then exit"
    Write-Host "  -s, -synth_only                     Stop after synthesis, then exit"
    Write-Host "  -t, -custom_target <TARGET>         Target a different board"
    Write-Host "  -f, -platform <PLATFORM>            Specify platform explicitly"
    Write-Host "  -c, -clean                          Clean target build and exit"
    Write-Host "  -m, -clean_platform                 Clean all devices for platform and exit"
    Write-Host "  -a, -clean_all_platforms            Clean everything and exit"
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
    Write-Host ""
    exit 0
}

# ---- DUMMY HANDLERS FOR NOT YET IMPLEMENTED FLAGS ----
if ($p) { Write-Host "NOTE: -p / -proj_only is not yet implemented. Continuing with full build." }
if ($s) { Write-Host "NOTE: -s / -synth_only is not yet implemented. Continuing with full build." }
if ($t) { Write-Host "NOTE: -t / -custom_target is not yet implemented. Using default target." }
if ($f) { Write-Host "NOTE: -f / -platform is not yet implemented. Using default platform." }
if ($c) { Write-Host "NOTE: -c / -clean is not yet implemented."; exit 0 }
if ($m) { Write-Host "NOTE: -m / -clean_platform is not yet implemented."; exit 0 }
if ($a) { Write-Host "NOTE: -a / -clean_all_platforms is not yet implemented."; exit 0 }
if ($d) { Write-Host "NOTE: -d / -list_default_target is not yet implemented."; exit 0 }
if ($i) { Write-Host "NOTE: -i / -list_supported_platforms is not yet implemented."; exit 0 }
if ($l) { Write-Host "NOTE: -l / -list_supported_targets is not yet implemented."; exit 0 }
if ($y) { Write-Host "NOTE: -y / -list_supported_system_clock_frequencies is not yet implemented."; exit 0 }

# ---- PRE-FLIGHT CHECKS ----

## gowin software
if (-not (Test-Path $GwSh)) {
    Write-Host "ERROR: Cannot find gw_sh.exe at: $GwSh"
    Write-Host "Please update GowinInstallDir at the top of this script."
    exit 1
}

## build.tcl
if (-not (Test-Path $BuildTcl)) {
    Write-Host "ERROR: Cannot find build.tcl at: $BuildTcl"
    Write-Host "Please update RepoRoot at the top of this script."
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
Write-Host "====================================="
Write-Host "Starting build..."
Write-Host ""

& $GwSh $BuildTcl $ProjectName $RepoRoot $OutputDir $PartNumber $DeviceVersion $SpeedGrade $ClockMhz $DoProjectGenOnly $DoSynthOnly

# ---- RESULT ----
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " BUILD SUCCESS"
    Write-Host "====================================="

    $fsSource = "$OutputDir\.artifacts\BRS-100-GW1NR9.fs"
    $fsDest   = "$PSScriptRoot\output\BRS-100-GW1NR9.fs"

    if (Test-Path $fsSource) {
        Write-Host ".fs file ready at: $fsSource"

        # copy to clean windows output folder
        if (-not (Test-Path "$PSScriptRoot\output")) {
            New-Item -ItemType Directory -Path "$PSScriptRoot\output" -Force | Out-Null
        }
        Copy-Item $fsSource $fsDest -Force
        Write-Host ".fs file copied to: $fsDest"

    } else {
        Write-Host "WARNING: .fs not found at expected location."
        Write-Host "Searching output folder for .fs files..."
        Get-ChildItem -Recurse -Filter "*.fs" -Path $OutputDir
    }

} else {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " BUILD FAILED (exit code: $LASTEXITCODE)"
    Write-Host "====================================="
    exit 1
}
# version 1 - minimal functionality to build using gowin command line tools.

# tool directory - change according to your installation
$GowinInstallDir    = "C:\Gowin\Gowin_V1.9.12.01_x64"
$RepoRoot           = "C:\Users\JQ\BRS-100\Forked repo BRS-100\BRS-100-GW1NR9"

# note: user.sv file is specified by build.tcl
# paths
$GwSh               = "$GowinInstallDir\IDE\bin\gw_sh.exe"
$BuildTcl           = "$RepoRoot\build\platforms\gowin\devices\GW1NR-9\build.tcl"
$OutputDir          = "$RepoRoot\build\platforms\gowin\devices\GW1NR-9\C7I6\output"  # fixed

# chip settings from csv
$ProjectName        = "BRS-100-GW1NR9"
$PartNumber         = "GW1NR-LV9QN88PC7/I6"
$DeviceVersion      = "C"
$SpeedGrade         = "C7I6"
$ClockMhz           = "51"
$DoProjectGenOnly   = "false"
$DoSynthOnly        = "false"

# checks before building

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

## autogen file check BEFORE creating output dir (fixed order)
if (-not (Test-Path "$OutputDir\.artifacts\autogen_top_wrapper.sv")) {
    Write-Host "ERROR: autogen_top_wrapper.sv not found."
    Write-Host "Expected at: $OutputDir\.artifacts\autogen_top_wrapper.sv"
    exit 1
}

## create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    Write-Host "Creating output directory: $OutputDir"
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# run the build
Write-Host ""
Write-Host "====================================="
Write-Host " BRS-100-GW1NR9 Windows Build"
Write-Host "====================================="
Write-Host "Repo    : $RepoRoot"
Write-Host "Output  : $OutputDir"
Write-Host "Device  : $PartNumber (v$DeviceVersion, $SpeedGrade)"
Write-Host "Clock   : $ClockMhz MHz"
Write-Host "====================================="
Write-Host "Starting build..."
Write-Host ""

& $GwSh $BuildTcl $ProjectName $RepoRoot $OutputDir $PartNumber $DeviceVersion $SpeedGrade $ClockMhz $DoProjectGenOnly $DoSynthOnly

# result
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "====================================="
    Write-Host " BUILD SUCCESS"
    Write-Host "====================================="
    $fsFile = "$OutputDir\.artifacts\BRS-100-GW1NR9.fs"
    if (Test-Path $fsFile) {
        Write-Host ".fs file ready at: $fsFile"
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
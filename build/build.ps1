param (
    # ---- CORE BUILD FLAGS ----
    [Alias('board_demonstration')]
    [switch]$b,

    [Alias('o')]
    [string]$teststring = "Default SRAM/HRAM Test Data",

    [Alias('clock_frequency')]
    [int]$k             = 51,

    [Alias('uart_baud')]
    [int]$u             = 115200,

    [Alias('disable_pushbutton_reset')]
    [switch]$r,

    [Alias('help')]
    [switch]$h,

    # ---- IMPLEMENTED FLAGS ----
    [Alias('embedded_logic_analyzer')]
    [switch]$e,

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
    # ---- UTILS (needed for formatting vars and copyright) ----
    . "$PSScriptRoot\build_utils.ps1"

    Write-Host "${underlinef}BUILD${normf}`n"
    Write-Host "${boldf}NAME${normf}"
    Write-Host "`tbuild - build the BRS-100-GW1NR9 FPGA firmware`n"
    Write-Host "${boldf}SYNOPSIS${normf}"
    Write-Host "`t${boldf}build${normf} [OPTIONS...]`n"
    Write-Host "${boldf}DESCRIPTION${normf}"
    Write-Host "`tBuild or query build options for the BRS-100-GW1NR9 FPGA firmware.`n"
    Write-Host "${boldf}OPTIONS${normf}"
    Write-Host "${boldf}    Generic Program Information${normf}"
    Write-Host "`t${boldf}-h, -help${normf}`n`t`tDisplay this help and exit.`n"
    Write-Host "${boldf}    Build Target Information${normf}"
    Write-Host "`t${boldf}-d, -list_default_target${normf}`n`t`tList the default build target.`n"
    Write-Host "`t${boldf}-l, -list_supported_targets${normf}`n`t`tList supported build targets and exit.`n"
    Write-Host "`t${boldf}-i, -list_supported_platforms${normf}`n`t`tList supported target platforms and exit.`n"
    Write-Host "`t${boldf}-y, -list_supported_system_clock_frequencies${normf}`n`t`tList supported system clock frequencies and exit.`n"
    Write-Host "${boldf}    Build Related${normf}"
    Write-Host "`t${boldf}-u, -uart_baud${normf} ${underlinef}UART_BAUD${normf}`n`t`tSet user comms baud rate (default 115200).`n"
    Write-Host "`t${boldf}-r, -disable_pushbutton_reset${normf}`n`t`tDisable pushbutton 1 as hard reset.`n"
    Write-Host "`t${boldf}-b, -board_demonstration${normf}`n`t`tPerform build of board demonstration bitstream.`n"
    Write-Host "`t${boldf}-o, -teststring${normf} ${underlinef}TEST_STRING${normf}`n`t`tSet board demonstration SRAM/HRAM/Flash test payload (1-32 printable ASCII chars, no slash in custom strings). Requires -b.`n"
    Write-Host "`t${boldf}-e, -embedded_logic_analyzer${normf}`n`t`tInclude an Embedded Logic Analyzer (fpgacapZero) in the bitstream.`n"
    Write-Host "`t${boldf}-t, -custom_target${normf} ${underlinef}CUSTOM_TARGET${normf}`n`t`tPerform build targeting CUSTOM_TARGET.`n"
    Write-Host "`t${boldf}-k, -clock_frequency${normf} ${underlinef}FREQUENCY_MHZ${normf}`n`t`tUse a frequency of FREQUENCY_MHZ for the system clock (default 51 MHz)."
    Write-Host "`t`tSee '-y, -list_supported_system_clock_frequencies' above, for more information.`n"
    Write-Host "`t${boldf}-f, -platform${normf} PLATFORM`n`t`tSpecify PLATFORM for build or clean.`n"
    Write-Host "`t${boldf}-c, -clean${normf}`n`t`tPerform cleanup of TARGET for specified PLATFORM and exit.`n"
    Write-Host "`t${boldf}-m, -clean_platform${normf}`n`t`tPerform cleanup of all target devices for specified PLATFORM and exit.`n"
    Write-Host "`t${boldf}-a, -clean_all_platforms${normf}`n`t`tPerform cleanup of all target devices for all platforms and exit.`n"
    Write-Host "`t${boldf}-p, -proj_only${normf}`n`t`tOnly generate the project file, then exit. Takes priority over ${boldf}-s${normf}/${boldf}-synth_only${normf} if both are provided.`n"
    Write-Host "`t${boldf}-s, -synth_only${normf}`n`t`tOnly proceed with build until synthesis is complete, then exit.`n"
    Write-Host "${boldf}AUTHOR${normf}"
    Write-Host "`tWritten by Bruce Mao"
    Write-Host "`tAdapted from linux build.sh by Craig Haywood`n"
    Write-Host "${boldf}COPYRIGHT${normf}"
    Write-Host $copyright
    exit 0
}

# ---- CORE PARAMS ----
$BoardDemonstration = if ($b) { 1 } else { 0 }
$EmbeddedLogicAnalyzer 	= if ($e) { 1 } else { 0 }
$ClockMhz           = $k
$UartBaud           = $u
$PushbuttonReset    = if ($r) { 0 } else { 1 }
$DoProjectGenOnly   = if ($p) { "true" } else { "false" }
$DoSynthOnly        = if ($s) { "true" } else { "false" }
$TestStringWasProvided = $PSBoundParameters.ContainsKey('teststring')
$TestStringLen      = if ($null -eq $teststring) { 0 } else { $teststring.Length }

if ($TestStringWasProvided -and -not $b) {
    Write-Host ""
    Write-Host "Teststring is only valid with -b / --board_demonstration."
    Write-Host "Try '.\build.ps1 -h' or '.\build.bat -h' for more information."
    Write-Host ""
    exit 1
}

if ($b) {
    if ([string]::IsNullOrEmpty($teststring) -or $teststring.Length -gt 32) {
        Write-Host ""
        Write-Host "Teststring must be 1 to 32 characters."
        Write-Host "Try '.\build.ps1 -h' or '.\build.bat -h' for more information."
        Write-Host ""
        exit 1
    }

    for ($charIndex = 0; $charIndex -lt $teststring.Length; $charIndex++) {
        $code = [int][char]$teststring[$charIndex]
        $CustomSlash = $TestStringWasProvided -and ($code -eq 0x2F)
        if (($code -lt 0x20) -or ($code -gt 0x7E) -or ($code -eq 0x22) -or $CustomSlash -or ($code -eq 0x5C) -or ($code -eq 0x60)) {
            Write-Host ""
            Write-Host "Teststring must contain only printable ASCII and custom strings cannot contain double quote, slash, backtick, backslash, CR, or LF."
            Write-Host "Try '.\build.ps1 -h' or '.\build.bat -h' for more information."
            Write-Host ""
            exit 1
        }
    }

    $TestStringLen = $teststring.Length
}

# ---- UTILS & GLOBALS ----
. "$PSScriptRoot\build_utils.ps1"
. "$PSScriptRoot\build_globals.ps1"

# ---- IMPLEMENT -d / list_default_target ----
if ($d) {
    Write-Host $ProjectName
    exit 0
}

# ---- IMPLEMENT -i / list_supported_platforms ----
if ($i) {
    if (Test-Path $PlatformsDir) {
        Get-ChildItem -Directory $PlatformsDir |
            Select-Object -ExpandProperty Name |
            ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "ERROR: Platforms directory not found at: $PlatformsDir"
    }
    exit 0
}

# ---- IMPLEMENT -l / list_supported_targets ----
if ($l) {
    Write-Host "-----------------------------------------"
    Write-Host "Platform  : $Platform"
    $targetList = ($devices | ForEach-Object { $_.'Build Target'.Trim() }) -join ", "
    Write-Host "Target(s) : $targetList"
    Write-Host "-----------------------------------------"
    exit 0
}

# ---- IMPLEMENT -y / list_supported_system_clock_frequencies ----
if ($y) {
    Write-Host "----------------------------------------------------------------------------------"
    Write-Host "Platform           : $Platform"
    Write-Host "Target             : $ProjectName"
    Write-Host -NoNewline "Sysclk Freq (MHz)  : "
    Write-Host ($supportedFreqs -join ", ")
    Write-Host "----------------------------------------------------------------------------------"
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
# deletes current target build output only — matches Linux behaviour, no prompt
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

## generate_top_wrapper.ps1 — match Linux pattern of checking script exists
if (-not (Test-Path "$PSScriptRoot\generate_top_wrapper.ps1")) {
    Write-Host "ERROR: generate_top_wrapper.ps1 not found at: $PSScriptRoot"
    Write-Host "Make sure generate_top_wrapper.ps1 is in the same folder as this script."
    exit 1
}

## build.tcl
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
    -BoardDemonstration      $BoardDemonstration `
    -TestString              $teststring `
    -TestStringLen           $TestStringLen `
    -EmbeddedLogicAnalyzer   $EmbeddedLogicAnalyzer

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
Write-Host "ELA      : $(if ($EmbeddedLogicAnalyzer -eq 1) { 'enabled' } else { 'disabled' })"
Write-Host "Build    : $(if ($p) { 'project only' } elseif ($s) { 'synthesis only' } else { 'full build' })"
Write-Host "GOWIN    : $installFolderName"
Write-Host "====================================="
Write-Host "Starting build..."
Write-Host ""

# ---- START TIMER ----
$startTime = Get-Date

$EmbeddedLogicAnalyzerArg 	= if ($e) { "true" } else { "false" }

& $GwSh $BuildTcl $ProjectName $RepoRoot $OutputDir $PartNumber $DeviceVersion $SpeedGrade $ClockMhz $EmbeddedLogicAnalyzerArg $DoProjectGenOnly $DoSynthOnly

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

# ---- TEXT FORMATTING ----
$esc        = [char]0x1B
$boldf      = "${esc}[1m"
$underlinef = "${esc}[4m"
$normf      = "${esc}[0m"

# ---- COPYRIGHT ----
$copyright = @"
    The source code contained herein is provided on an "as is" basis. Brisbane Silicon, Pty Ltd.
    disclaims any and all warranties, whether express, implied, or statutory, including any implied
    warranties of merchantability or of fitness for a particular purpose. In no event shall Brisbane
    Silicon, Pty Ltd. be liable for any incidental, punitive, or consequential damages of any kind
    whatsoever arising from the use of this source code.

    This disclaimer of warranty extends to the user of this source code and user's customers,
    employees, agents, transferees, successors and assigns.

    This is not a grant of patent rights.
"@

# ---- FTDI USB RESET VIA ftd2xx.dll ----
# programmer_cli.exe occasionally hangs because the ftd2xx driver doesn't fully
# release the USB handle between invocations. calling FT_CyclePort forces the
# FTDI chip to USB re-enumerate (equivalent to physical unplug/replug), clearing
# any stale driver state that would cause the next programmer_cli call to deadlock.
#
# ftd2xx API reference: https://ftdichip.com/wp-content/uploads/2024/09/D2XX_Programmers_Guide.pdf
# FT_STATUS values: FT_OK=0, FT_INVALID_HANDLE=1, FT_DEVICE_NOT_FOUND=2, etc.
if (-not $GowinInstallDir) {
    # utils sourced before globals (e.g. help path) - skip FTDI init
    $script:Ftd2xxLoaded = $false
    return
}

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

function Invoke-ProgrammerCliWithStallDetection {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string[]]$Arguments,
        [int]$StallTimeoutSeconds = 3,
        [switch]$NewConsole
    )

    # quote any argument that contains spaces so Start-Process doesn't split it
    $argString = ($Arguments | ForEach-Object {
        if ($_ -match ' ') { "`"$_`"" } else { $_ }
    }) -join ' '

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    # -NewConsole: use WindowStyle Hidden to get a fresh console host (needed when
    # the retry must be isolated from the parent session to wake the ftd2xx driver).
    # Default: -NoNewWindow shares the parent console (normal run).
    $startArgs = @{
        FilePath               = $Exe
        ArgumentList           = $argString
        PassThru               = $true
        RedirectStandardOutput = $stdoutFile
        RedirectStandardError  = $stderrFile
    }
    if ($NewConsole) {
        $startArgs['WindowStyle'] = 'Hidden'
    } else {
        $startArgs['NoNewWindow'] = $true
    }
    $proc = Start-Process @startArgs

    # PS 5.1 quirk: touch Handle before the process can exit so the native
    # handle is pinned; otherwise $proc.ExitCode returns $null after exit.
    $null = $proc.Handle

    $lastOutput  = Get-Date
    $stalled     = $false
    $procExitCode = $null

    # keep streams open with ReadWrite sharing - Start-Process holds a write lock
    $stdoutStream = [System.IO.File]::Open($stdoutFile, 'Open', 'Read', 'ReadWrite')
    $stderrStream = [System.IO.File]::Open($stderrFile, 'Open', 'Read', 'ReadWrite')

    function Read-NewBytes($stream) {
        $available = $stream.Length - $stream.Position
        if ($available -le 0) { return }
        $buf = New-Object byte[] $available
        [void]$stream.Read($buf, 0, $available)
        [Console]::Write([System.Text.Encoding]::Default.GetString($buf))
    }

    try {
        while (-not $proc.HasExited) {
            Start-Sleep -Milliseconds 200

            $posBefore = $stdoutStream.Position + $stderrStream.Position
            Read-NewBytes $stdoutStream
            Read-NewBytes $stderrStream
            if (($stdoutStream.Position + $stderrStream.Position) -gt $posBefore) {
                $lastOutput = Get-Date
            }

            if (((Get-Date) - $lastOutput).TotalSeconds -gt $StallTimeoutSeconds) {
                $stalled = $true
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                break
            }
        }

        if (-not $stalled) {
            Read-NewBytes $stdoutStream
            Read-NewBytes $stderrStream
            # capture ExitCode inside try before finally closes resources;
            # WaitForExit(ms) is more reliable than WaitForExit() in PS 5.1
            [void]$proc.WaitForExit(30000)
            $procExitCode = $proc.ExitCode
        }
    } finally {
        $stdoutStream.Close()
        $stderrStream.Close()
        if (-not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
        Remove-Item $stdoutFile -ErrorAction SilentlyContinue
        Remove-Item $stderrFile -ErrorAction SilentlyContinue
    }

    $exitCode = if ($stalled) { 1 } else { $procExitCode }
    return [PSCustomObject]@{ ExitCode = $exitCode; Stalled = $stalled }
}

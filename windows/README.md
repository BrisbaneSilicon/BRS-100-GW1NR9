# BRS-100-GW1NR9 — Windows Guide

PowerShell scripts for building and programming the [BRS-100-GW1NR9](https://brisbanesilicon.com.au/devboards/brs-100-gw1nr9) FPGA development board on Windows.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
  - [GOWIN EDA Installation](#gowin-eda-installation)
  - [License Setup](#license-setup)
  - [PowerShell Execution Policy](#powershell-execution-policy)
  - [FTDI Driver Setup](#ftdi-driver-setup)
- [Build](#build)
  - [Build Arguments](#build-arguments)
  - [Build Examples](#build-examples)
- [Program Board](#program-board)
  - [Program Arguments](#program-arguments)
  - [Program Examples](#program-examples)
- [Board Demonstration](#board-demonstration)
- [Development](#development)
- [Things to Look Out For](#things-to-look-out-for)

---

## Overview

This directory contains Windows PowerShell scripts that replicate the Linux workflow for building FPGA bitstreams and programming them onto the BRS-100-GW1NR9 board. No GUI is required at any point.

| Script | Purpose |
| :--- | :--- |
| `build.ps1` | Compile RTL into a `.fs` bitstream via GOWIN EDA |
| `program_board.ps1` | Flash the `.fs` bitstream onto the board via JTAG |
| `generate_top_wrapper.ps1` | Auto-generate the top-level SystemVerilog wrapper (called by `build.ps1`) |

Built output (`.fs` file) is placed in `windows\output\`.

---

## Prerequisites

1. **Windows 11 x64** PC.

2. **Git for Windows** — required for the scripts to auto-detect the repository root.
   - Download from [git-scm.com](https://git-scm.com/).
   - Ensure `git` is on your system PATH.

3. **GOWIN EDA V1.9.12.02** — see [GOWIN EDA Installation](#gowin-eda-installation) below.

4. **A free GOWIN EDA license** — see [License Setup](#license-setup) below.

5. **PowerShell Execution Policy** set to `RemoteSigned` or higher — see [PowerShell Execution Policy](#powershell-execution-policy) below.

6. **FTDI drivers** with no conflicts — see [FTDI Driver Setup](#ftdi-driver-setup) below.

---

## Environment Setup

### GOWIN EDA Installation

Download GOWIN EDA **V1.9.12.02** from the official [GOWIN EDA download page](https://www.gowinsemi.com/en/support/download_eda/). You may need to register as a GOWIN member first.

> [!WARNING]
> **Do NOT install V1.9.12.01.** It has a known bug that prevents programming to the board. The scripts will refuse to run if this version is detected.
>
> GOWIN EDA V1.9.11.01 is also a known broken release and is blocked by the scripts.

The scripts auto-detect the GOWIN install directory by searching these locations in order:

```
C:\Gowin\Gowin_V1.9.12_x64
C:\Gowin\Gowin_V1.9.12
C:\Gowin\Gowin_V1.9.12.02_x64
C:\Gowin\Gowin_V1.9.12.02
C:\Program Files\Gowin\Gowin_V1.9.12.02_x64
C:\Program Files\Gowin\Gowin_V1.9.12.02
%LOCALAPPDATA%\Gowin\Gowin_V1.9.12.02_x64
%LOCALAPPDATA%\Gowin\Gowin_V1.9.12.02
```

If you installed GOWIN EDA to a different path, set the `GOWIN_INSTALL_DIR` environment variable before running the scripts. Run this once in PowerShell (then reopen PowerShell for it to take effect):

```powershell
[System.Environment]::SetEnvironmentVariable('GOWIN_INSTALL_DIR', 'C:\your\gowin\path', 'User')
```

Alternatively, add the GOWIN installation path as a system variable via the Windows GUI:

1. Right-click on the Start button and select **System**.
2. Click on **Advanced system settings**.
3. In the System Properties window, click on **Environment Variables**.
4. Under "System variables" (the lower section), click **New**.
5. Set the variable name to `GOWIN_INSTALL_DIR` and the value to the full path of your GOWIN installation directory (e.g., `C:\Gowin\Gowin_V1.9.12.02_x64`).
6. Click **OK** to close all open windows.
7. Restart any open Command Prompt or PowerShell windows for the changes to take effect.

### License Setup

A free GOWIN EDA license is required to build. There are two options:

**Option 1 — Local license file:**
Apply for a license at [gowinsemi.com/en/support/license](https://www.gowinsemi.com/en/support/license/). GOWIN typically responds within a few working days; the license is valid for one year.

**Option 2 — Floating license server:**
Point the license manager at a public community license server (quickest path):

| IP Address | Port |
| :------: | :------: |
| 106.55.34.119 | 10559 |
| 43.128.7.128 | 10559 |

To configure the license:

1. Open GOWIN EDA (`gw_ide.exe`) from your install directory.
2. Click **Help** → **Manage License**.
3. Enter either your local license file path or the server IP and port.
4. Click **Check** — a popup saying **Server is OK** confirms it works.
5. Click **Save**.

> [!NOTE]
> The first license check sometimes fails. Simply click **Check** again.

### PowerShell Execution Policy

The scripts require PowerShell's execution policy to be set to `RemoteSigned` or higher. To check your current policy:

```powershell
Get-ExecutionPolicy
```

If it does not return `RemoteSigned` or `Unrestricted`, open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### FTDI Driver Setup

The board uses an FTDI USB interface for both programming (JTAG) and UART. Mismatched FTDI driver versions can cause Windows to crash with `KERNEL_SECURITY_CHECK_FAILURE (0x139)`.

To check for driver conflicts:

```powershell
pnputil /enum-drivers | Select-String -Pattern "ftdi" -Context 5
```

Ensure all listed driver versions match. If they do not, follow the full FTDI reinstall procedure in [TROUBLESHOOTING.txt](TROUBLESHOOTING.txt).

---

## Build

Open PowerShell (Admin not required), `cd` into the repository root, then run:

```powershell
.\windows\build.ps1
```

The default build produces a LED-blink bitstream. On success, the `.fs` file is copied to `windows\output\BRS-100-GW1NR9.fs`.

For all available options:

```powershell
.\windows\build.ps1 -h
```

### Build Arguments

#### Core Build Options

| Argument | Description |
| :--- | :--- |
| `-b`, `-board_demonstration` | Build board demonstration firmware (GPIO, LED, UART) instead of default LED blink |
| `-k <MHz>`, `-clock_frequency` | System clock frequency in MHz (default: `51`). Use `-y` to list valid values |
| `-u <baud>`, `-uart_baud` | UART baud rate (default: `115200`) |
| `-r`, `-disable_pushbutton_reset` | Disable pushbutton 1 as a reset signal (default: enabled) |

#### Build Control

| Argument | Description |
| :--- | :--- |
| `-p`, `-proj_only` | Generate the GOWIN project file only, then exit. Useful for opening in GOWIN IDE |
| `-s`, `-synth_only` | Run synthesis only, then exit. Useful for checking resource utilisation and timing |
| `-c`, `-clean` | Delete the current target's build output and exit |
| `-a`, `-clean_all_platforms` | Delete all build output (prompts for confirmation) and exit |

#### Information Flags

| Argument | Description |
| :--- | :--- |
| `-y`, `-list_supported_system_clock_frequencies` | List all valid clock frequencies and exit |
| `-d`, `-list_default_target` | Print the default build target and exit |
| `-i`, `-list_supported_platforms` | List supported platforms and exit |
| `-l`, `-list_supported_targets` | List supported target boards and exit |
| `-h`, `-help` | Show help and exit |

#### Not Yet Implemented

| Argument | Description |
| :--- | :--- |
| `-t <TARGET>`, `-custom_target` | Target a different board (placeholder, currently only BRS-100-GW1NR9 supported) |
| `-f <PLATFORM>`, `-platform` | Specify platform explicitly |
| `-m`, `-clean_platform` | Clean all devices for a platform |

### Build Examples

```powershell
# Default LED blink build
.\windows\build.ps1

# Board demonstration build
.\windows\build.ps1 -b

# Build at 66 MHz
.\windows\build.ps1 -k 66

# Board demonstration at 75 MHz with 9600 baud UART
.\windows\build.ps1 -b -k 75 -u 9600

# Generate project file only (to open in GOWIN IDE)
.\windows\build.ps1 -p

# Synthesis only (check utilisation / timing)
.\windows\build.ps1 -s

# Clean current target build output
.\windows\build.ps1 -c

# List supported clock frequencies
.\windows\build.ps1 -y
```

---

## Program Board

> [!WARNING]
> Make sure there are no conflicts between FTDI driver versions before running this script — see [FTDI Driver Setup](#ftdi-driver-setup). Conflicting versions (e.g. different version dates) can cause Windows to crash and lose unsaved work. **Save your work before running this script.**

Plug the board into your PC via the USB-C cable, then open PowerShell, `cd` into the repository root, and run:

```powershell
.\windows\program_board.ps1
```

If no `.fs` file has been built yet, the script will automatically trigger a build first. The bitstream is programmed into the board's internal non-volatile flash, so it auto-loads after every power cycle.

For all available options:

```powershell
.\windows\program_board.ps1 -h
```

### Program Arguments

| Argument | Description |
| :--- | :--- |
| `-h`, `--help` | Display help and exit |
| `-d`, `--list_default_target` | Print the default target board name and exit |
| `-b`, `--check_if_target_built` | Print whether the firmware has been built, then exit |
| `-s`, `--check_if_target_supported` | Print whether the current target is supported, then exit |
| `-l`, `--list_supported_targets` | List all supported target boards and exit |
| `-c`, `--clean_target_prior` | Clean the build output before rebuilding and programming |
| `-k <MHz>`, `--clock_frequency` | Clock frequency passed to the build script when auto-building (default: `51`) |
| `-m <path>`, `--custom_bitfile` | Program a custom `.fs` file instead of the default build output |
| `-jtag_frequency <freq>` | Override JTAG programming clock frequency (default: `0.02MHz`). Valid values: `0.02MHz`, `0.1MHz`, `0.3MHz`, `0.4MHz`, `0.5MHz`, `0.75MHz`, `0.9MHz`, `1.1MHz`, `1.5MHz`, `2MHz`, `2.5MHz`, `10MHz`, `15MHz` |
| `-t`, `--custom_target` | Not yet implemented — placeholder for future multi-board support |
| `-f`, `--update_flash_only` | Not yet implemented — Xilinx only |

### Program Examples

```powershell
# Build (if needed) and program the board
.\windows\program_board.ps1

# Clean, rebuild, and program the board
.\windows\program_board.ps1 -c

# Check whether firmware has already been built
.\windows\program_board.ps1 -b

# Program with a custom bitstream file
.\windows\program_board.ps1 -m C:\path\to\custom.fs

# Build at 66 MHz and program
.\windows\program_board.ps1 -k 66

# Clean, rebuild at 75 MHz, and program
.\windows\program_board.ps1 -c -k 75

# Program with a faster JTAG speed (less reliable)
.\windows\program_board.ps1 -jtag_frequency 2.5MHz
```

---

## Board Demonstration

Board demonstration mode exercises the BRS-100-GW1NR9 hardware features: GPIO, LEDs, and UART.

Build the demonstration firmware:

```powershell
.\windows\build.ps1 -b
```

Then program it:

```powershell
.\windows\program_board.ps1
```

Connect a serial terminal (e.g. PuTTY, Tera Term) to the board's UART at **115200 baud**. Press pushbutton 1 (the pushbutton closest to Pin 1) to reset the board. The terminal should print something like:

```
BOARD: BRS-100-GW1NR9
FW: c2ce822|2025-12-09 15:30:43
```

The `FW` tag format is: `<git commit SHA> <-dirty if built with local changes> | <build date> <build time>`.

In board demonstration mode, GPIO inputs `<1..16>` are reflected on GPIO outputs `<17..32>`. For example, GPIO17 mirrors GPIO1 — connect GPIO1 to VCC or GND and monitor GPIO17 on an oscilloscope or multimeter.

> [!NOTE]
> If all six user LEDs slowly flash after programming, you built without the `-b` flag. That is the default `user.sv` LED blink firmware, not the board demonstration firmware.

---

## Development

To add your own RTL, modify `user.sv` located at:

```
<repo root>\proj\common\systemverilog\user.sv
```

To instantiate additional SystemVerilog or VHDL modules, add them to `synth.tcl` in the appropriate `scripts` directory under `build\platforms\`.

Running `.\windows\build.ps1` (without `-b`) will include `user.sv` in the build.

See the [official BRS-100-GW1NR9 documentation](https://brisbanesilicon.com.au/docs/BRS-100-GW1NR9_Datasheet.pdf) for full hardware reference.

---

## Things to Look Out For

### Script freezes at `Operation "embFlash Erase,Program" for device#1...`

The most common issue. The FTDI chip accumulates stale USB state across rapid programming attempts and stops responding.

**Recovery:**
1. Kill `programmer_cli.exe` in Task Manager, or run the following in a new PowerShell window:
   ```powershell
   Stop-Process -Name programmer_cli -Force -ErrorAction SilentlyContinue
   ```
2. Unplug the USB-C cable from the board.
3. Wait at least **3 seconds** (the FTDI chip needs to fully power down).
4. Reconnect the cable and wait 2–3 seconds for Windows to enumerate the device.
5. Run the script again.

You may need to attempt this 2–3 times.

**Prevention:** Wait a few seconds between programming runs. Do not run the script while the GOWIN Programmer GUI is open as it holds an exclusive lock on the cable.

### `Cable failed to open via the location`

The USB device is in a bad state from a previously killed `programmer_cli` process. Follow the same recovery steps above.

### `PROGRAMMING FAILED (exit code: 1)` with status `0x00015421`

The wrong cable driver path was selected internally. Unplug and replug the board, then retry. Status codes starting with `0x0001xxxx` indicate the wrong (FT2CH) driver path; `0x0003xxxx` is the correct (ftd2xx) path. Also double check the GOWIN EDA version (V1.9.12.02), as this error is also commonly seen when the wrong version is installed.

### `KERNEL_SECURITY_CHECK_FAILURE` (BSOD 0x139)

Windows crashes with a blue screen after repeated programming cycles. This is caused by a bug in the FTDI `ftd2xx.sys` kernel driver.

**Fix:** Fully remove and reinstall the FTDI D2XX driver. See [TROUBLESHOOTING.txt](TROUBLESHOOTING.txt) for the complete step-by-step procedure, including how to clear ghost devices from the driver store and verify driver version consistency.

### GOWIN EDA not found

The scripts search common install paths automatically. If GOWIN EDA is installed elsewhere, set the environment variable:

```powershell
[System.Environment]::SetEnvironmentVariable('GOWIN_INSTALL_DIR', 'C:\your\gowin\path', 'User')
```

Then reopen PowerShell.

### `cannot be loaded because running scripts is disabled on this system`

Set the PowerShell execution policy:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### GOWIN version warnings

- **V1.9.12.02** — recommended and verified.
- **V1.9.8–V1.9.11** — scripts will warn and continue, but these versions are untested.
- **V1.9.11.01** — blocked by the scripts. Known broken release.
- **V1.9.12.01** — blocked by the scripts. Do not use; the programmer component is broken.

### Build triggered automatically by `program_board.ps1`

If no `.fs` file exists, the program script will automatically run a full build before programming. To avoid this triggering an unwanted default build, pre-build with your desired options first:

```powershell
.\windows\build.ps1 -b -k 66
.\windows\program_board.ps1
```

---

For detailed troubleshooting, see [TROUBLESHOOTING.txt](TROUBLESHOOTING.txt).

For support, email support@brisbanesilicon.com.au.

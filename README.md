
# BRS-100-GW1NR9


Example project for the [BRS-100-GW1NR9](https://brisbanesilicon.com.au/devboards/brs-100-gw1nr9) FPGA development board by [BrisbaneSilicon](https://brisbanesilicon.com.au/).
<br><br>

## Table of Contents

*   [Overview](#overview)
*   [Getting Started](#getting-started)
*   [License Setup](#license-setup)
    *   [Public License Servers](#public-license-servers)
*   [Environment Variables](#environment-variables)
*   [Build](#build)
*   [Program](#program)
*   [Board Demonstration](#board-demonstration)
*   [Development](#development)
*   [Documentation](#documentation)
*   [Roadmap](#roadmap)
<br>

## Overview

This project allows the user to build an FPGA bitstream and program it onto the [BRS-100-GW1NR9](https://brisbanesilicon.com.au/devboards/brs-100-gw1nr9) FPGA development board.

The project can be built in [board demonstration](#board-demonstration) mode, which demonstrates the hardware functionality offered by the BRS-100-GW1NR9.

It can also be extended by the user to include their custom, application-specific, RTL modules.

The project workflow is fully scripted (fetch, build, program); it does not require the use of a GUI-based program at any point.
<br><br>

## Getting Started

Fulfill the below prerequisites.

### Prerequisites

To run the Linux version of this project:

1. A PC running an x64 compatible, Debian-based flavour of Linux.
   - Other flavours of Linux may work but aren't officially supported.
   - We recommend [Ubuntu](https://ubuntu.com/).
3. An installation of GOWIN EDA V1.9.12.
   - Available from the official GOWIN EDA [download page](https://www.gowinsemi.com/en/support/download_eda/) or direct link to [V1.9.12](https://cdn.gowinsemi.com.cn/Gowin_V1.9.12_linux.tar.gz).
   - You may need to first register as a GOWIN member [here](https://www.gowinsemi.com/en/member/).
   - On Linux, please ensure that GOWIN EDA is installed to one of the following directories (or be prepared to modify the build script):
     - `$HOME/Applications` `/opt/gowin` `/opt/GOWIN` `/opt/Gowin` `$HOME/Documents/Applications/`
4. A free license for GOWIN EDA. See section [License Setup](#license-setup) below.
5. A copy of this repository.
   - Launch a terminal program.
   - Navigate to the directory in which you wish to host the BRS-100-GW1NR9 repository.
   - `git clone https://github.com/BrisbaneSilicon/BRS-100-GW1NR9.git`<br>

To run the Windows version of this project:

1. Windows 11 x64 PC
2. Git for Windows — required for the scripts to auto-detect the repository root.
   - Download from [git-scm.com](https://git-scm.com/).
   - Ensure `git` is on your system PATH.
3. An installation of GOWIN EDA V1.9.12 or V1.9.12.02. 
   - You can download from the official [GOWIN EDA download page](https://www.gowinsemi.com/en/support/download_eda/).
   - You may need to register as a GOWIN member first.
   > [!WARNING]
   > **Do NOT install V1.9.12.01.** It has a known bug that prevents programming to the board. The scripts will refuse to run if this version is detected.
   - Make sure you install GOWIN EDA in the default location or any of the following:
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
   - If you install GOWIN EDA outside of the listed locations, set the `GOWIN_INSTALL_DIR` environment variable to your install path — see [Environment Variables](#environment-variables) below.
4. A free GOWIN EDA license — see [License Setup](#license-setup) below.
5. PowerShell Execution Policy set to `RemoteSigned` or higher — see [Windows PowerShell Execution Policy](#powershell-execution-policy).
6. FTDI drivers with no conflicts — see [FTDI Driver Setup](#ftdi-driver-setup) below.

### FTDI Driver Setup

1. An FTDI driver is required if you wish to communicate with the BRS-100-GW1NR9 via UART. On most Linux distributions they are part of the default installation of the OS. If you wish to install FTDI drivers manually, see their installation guides [here](https://ftdichip.com/document/installation-guides/).


2. Windows version require matching FTDI driver versions, if you already have FTDI installed earlier. Mismatched FTDI driver versions can cause Windows to crash with `KERNEL_SECURITY_CHECK_FAILURE (0x139)`.

To check for driver conflicts, run:
```powershell
pnputil /enum-drivers | Select-String -Pattern "ftdi" -Context 5
```
Ensure all listed driver versions match. If they do not, follow the full FTDI reinstall procedure: 

   1. Remove all FTDI devices and drivers
    Open Device Manager (devmgmt.msc), then enable hidden devices via View > Show hidden devices. Look under:

    "Universal Serial Bus controllers" — any FTDI entries
    "Ports (COM & LPT)" — any "USB Serial Port" entries
    "USB Debugger A" entries
    "USB Serial Converter" entries
    Right-click each device > Uninstall device > check "Attempt to remove the driver for this device" (important).

    2. Clear ghost devices

    With the board unplugged, open an admin PowerShell:

    ```pnputil /enum-drivers | Select-String -Pattern "ftdi" -Context 5```

    This lists any FTDI drivers still in the driver store. For each one, note the published name (e.g. oem12.inf) and remove it:

    ```pnputil /delete-driver oem12.inf /force```

    3. Clean leftover files

    Check for stale copies:

    Get-ChildItem C:\Windows\System32\drivers\ftd*.sys
    Get-ChildItem C:\Windows\System32\ftd2xx*.dll
    Get-ChildItem C:\Windows\SysWOW64\ftd2xx*.dll

    These should be gone after step 2. If any remain, note the versions (Right-click > Properties > Details > File version) before deleting — this tells you what was installed.

    4. Reboot

    Reboot before reinstalling anything. This ensures the kernel fully unloads the old drivers.

    5. Reinstall clean

    Download the latest D2XX driver from FTDI (not from GOWIN):
    https://ftdichip.com/drivers/d2xx-drivers/

    Run the installer. Then plug in the board — Windows should pick up the new drivers.

    6. Verify versions match

    After reinstall, check if the driver versions match by running: 
    ```
    pnputil /enum-drivers | Select-String -Pattern "ftdi" -Context 5
    ``` 



<br>

## License Setup

There are two options (both free) for licensing GOWIN EDA.
1. Using a local license file.
2. Using a floating license server.

Option (1) requires applying for a license from GOWIN [here](https://www.gowinsemi.com/en/support/license/). It can take up to a few working days for GOWIN to provide you with a license, which will be valid for a period of one year. Option (2) requires the same initial step if you wish to host your own license server. Alternatively you can point the GOWIN license manager at a public license server; this is likely the quickest path forwards. See [Public License Servers](#public-license-servers) for a list of public license servers.

### Linux

Launch a bash terminal and perform the following:

1. Change directory to the GOWIN IDE installation 'bin' directory.
   - `cd <GOWIN IDE install directory>/IDE/bin/`
2. Run the licensing manager.
   - `./license_config_gui`
   - Alternatively you can run the GOWIN IDE `./gw_ide` and click 'Help' - 'Manage License'.
3. Either point the licensing manager at your local license file (Option 1 above) or a floating license server.
4. Press 'Check' to validate the license.
   - If the license has been successfully validated, it should produce a popup window __INFO__ with the message __Server is OK__.
5. Click 'Save' to save your license setup.
<br>

> [!WARNING]
> Sometimes the first license check (step 4) will fail - simply repeat the step to validate the license.

### Windows

To configure the license on Windows GOWIN EDA:

1. Open GOWIN EDA (`gw_ide.exe`) from your install directory.
2. Click **Help** → **Manage License**.
3. Enter either your local license file path or the server IP and port.
4. Click **Check** — a popup saying **Server is OK** confirms it works.
5. Click **Save**.

> [!WARNING]
> Sometimes the first license check (step 4) will fail - simply repeat the step to validate the license.

### Public License Servers

A list of public GOWIN EDA license servers is below. These are community reported and might not be official or stable (see the previous instructions on how to check their validity).

| IP Address | Port |
| :------: | :------: |
| 106.55.34.119 | 10559 |
| 43.128.7.128 | 10559 |

<br>

## Environment Variables

### Linux

1. Prior to building the project, set 'LD_LIBRARY_PATH' to point at the GOWIN IDE libraries at `<GOWIN IDE install directory>/IDE/lib`. For example:
```bash
export LD_LIBRARY_PATH=/opt/Gowin/Gowin_V1.9.12_linux/IDE/lib
```
2. Prior to programing the BRS-100-GW1NR9 board, add `<GOWIN IDE install directory>/Programmer/bin/` to your PATH. For example:
```bash
export PATH=$PATH:/opt/Gowin/Gowin_V1.9.12_linux/Programmer/bin/
```

<br>

> [!WARNING]
> When attempting to build the project, you may get the following error:
> ```bash
> symbol lookup error: /<system library path>/libfontconfig.so.1: undefined symbol: FT_Done_MM_Var.
> ```
> To rectify this, setup the following environment variable as part of your pre-build environment, substituting '\<system library path>' to be as per your specific error message:
> ```bash
> export LD_PRELOAD=$LD_PRELOAD:/<system library path>/libfreetype.so
> ```
> 
> When attempting to program the board, you may get the following error:
> ```bash
> programmer_cli: /<GOWIN EDA install path>/Programmer/bin/libz.so.1: version `ZLIB_1.2.3.4' not found (required by /lib/x86_64-linux-gnu/libpng16.so.16)
> ```
> To rectify this, setup the following environment variable as part of your pre-build environment:
> ```bash
> export LD_PRELOAD=$LD_PRELOAD:/<system library path>/libz.so.1
> ```
> Note that the '\<system library path>' may differ from the build error - you might need to use the 'ldd' program to locate libz.so.1.

<br>

> [!NOTE]
> If you are going to be building the project often, we recommend (on Linux) you add a bash alias for the above environment variables to your '.bashrc'. For example: <br>
> ```bash
> alias gowin_ini='export LD_LIBRARY_PATH=/opt/Gowin/Gowin_V1.9.12_linux/IDE/lib; \
> export PATH=$PATH:/opt/Gowin/Gowin_V1.9.12_linux/Programmer/bin/; export \
> LD_PRELOAD=/lib/x86_64-linux-gnu/libfreetype.so'
> ```

Then to initialise the build environment, you can simply run `gowin_ini' from bash.

### Windows

#### PowerShell Execution Policy

The scripts require PowerShell's execution policy to be set to `RemoteSigned` or higher. To check your current policy:

```powershell
Get-ExecutionPolicy
```

If it does not return `RemoteSigned` or `Unrestricted`, open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy RemoteSigned
```

Or for current user only:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```



<br>

## Build

After fulfilling all of the prerequisites, and initializing your build environment, you are ready to build the BRS-100-GW1NR9 firmware! Simply perform the following:

### Linux

```bash
cd <BRS-100-GW1NR9 repository directory>/BRS-100-GW1NR9/build
./build.sh
```

That's all there is to it!<br><br>

The build script supports various customizations via command line arguments. To view the full set of supported command line arguments, simply perform the following:
```bash
./build.sh -h
```
<br>

The most commonly used are listed below.
<br>

| Build Argument | Description |
| :----------: | :----------: |
| -y, --list_supported_system_clock_frequencies | List the supported system clock frequencies and exit. |
| -k, --clock_frequency FREQUENCY_MHZ | Use a frequency of FREQUENCY_MHZ for the system clock (default 51 MHz). |
| -u, --uart_baud | Set the user comms baud rate (default 115200). |
| -b, --board_demonstration | Perform a build of the board demonstration bitstream. |
| -a, --clean_all_platforms | Perform cleanup of the entire build and exit. |
| -p, --proj_only | Only generate the project file, then exit. Useful if the user wishes to utilize GOWIN IDE.|
| -s, --synth_only | Only proceed with build until synthesis is complete, then exit. Useful to check FPGA utilization, timing etc. |

### Windows

Open PowerShell (Admin not required), `cd` into the repository root, then run:

```powershell
.\windows\build.ps1
```

The default build produces an LED-blink bitstream. On success, the `.fs` file is copied to `windows\output\BRS-100-GW1NR9.fs`.

For all available options:

```powershell
.\windows\build.ps1 -h
```

#### Build Arguments

##### Core Build Options

| Argument | Description |
| :--- | :--- |
| `-b`, `-board_demonstration` | Build board demonstration firmware (GPIO, LED, UART) instead of default LED blink |
| `-k <MHz>`, `-clock_frequency` | System clock frequency in MHz (default: `51`). Use `-y` to list valid values |
| `-u <baud>`, `-uart_baud` | UART baud rate (default: `115200`) |
| `-r`, `-disable_pushbutton_reset` | Disable pushbutton 1 as a reset signal (default: enabled) |

##### Build Control

| Argument | Description |
| :--- | :--- |
| `-p`, `-proj_only` | Generate the GOWIN project file only, then exit. Useful for opening in GOWIN IDE |
| `-s`, `-synth_only` | Run synthesis only, then exit. Useful for checking resource utilisation and timing |
| `-c`, `-clean` | Delete the current target's build output and exit |
| `-a`, `-clean_all_platforms` | Delete all build output (prompts for confirmation) and exit |

##### Information Flags

| Argument | Description |
| :--- | :--- |
| `-y`, `-list_supported_system_clock_frequencies` | List all valid clock frequencies and exit |
| `-d`, `-list_default_target` | Print the default build target and exit |
| `-i`, `-list_supported_platforms` | List supported platforms and exit |
| `-l`, `-list_supported_targets` | List supported target boards and exit |
| `-h`, `-help` | Show help and exit |

##### Not Yet Implemented

| Argument | Description |
| :--- | :--- |
| `-t <TARGET>`, `-custom_target` | Target a different board (placeholder, currently only BRS-100-GW1NR9 supported) |
| `-f <PLATFORM>`, `-platform` | Specify platform explicitly |
| `-m`, `-clean_platform` | Clean all devices for a platform |

#### Build Examples

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

<br><br>

## Program

After building the BRS-100-GW1NR9 firmware you are ready to program it to the board! It is worth noting that this stage also programs the internal non-volatile bitstream flash, so your firmware will auto-load after board power on! <br><br>After plugging the board into your PC via the USB-C cable, simply perform the following:

### Linux

The '\<this repository directory>' is the directory in which you performed Step (4) of [prerequisites](#prerequisites) - i.e. the directory in which you cloned this repository.

```bash
cd <this repository directory>/BRS-100-GW1NR9/prog
./program.sh
```
<br>

That's all there is to it!
<br>

> [!NOTE]
> The 'program' script will trigger a build the BRS-100-GW1NR9 firmware (with no command line customization arguments) if it detects it hasn't already been built.
<br>

Again, the program script supports various customizations via command line arguments. To view the full set of supported command line arguments, simply perform the following:

```bash
./program.sh -h
```
<br>
The most commonly used are listed below.
<br>

| Program Argument | Description |
| :----------: | :----------: |
| -d, --list_default_target | List the default build target. |
| -c, --clean_target_prior | Clean TARGET build prior to building and programming the BRS-100-GW1NR9 board. |
| -b, --check_if_target_built | Print firmware built status of provided target board and exit. |
| -t, --custom_target_device CUSTOM_TARGET | Instead of the default target, target 'CUSTOM_TARGET'. |
<br>

> [!WARNING]
> If you have previously loaded an FTDI driver in order to utilise the user comms, you will need to remove it prior to programming the board:
> ```bash
> sudo rmmod ftdi_sio
> ```

### Windows

#### Program Board

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

> [!NOTE]
> The script may freeze during programming at ``` Operation "embFlash Erase,Program" for device#1... ``` line and then hangs indefinitely with no further output. Typically occurs after 3-6 rapid programming commands.
> This is due to the FTDI chip accumulating internal states across rapid programmer_cli.exe calls. After a few cycles, the chip stops responding to new JTAG commands.
> This may take a few tries depending on the state of the FTDI chip.

Recovery steps:
1. Press Ctrl+C in the terminal to stop the script.
2. Open Task Manager (Ctrl+Shift+Esc) and check if programmer_cli.exe is still running. If it is, right-click it and select End Task. Alternatively, run in a new PowerShell window: ```Stop-Process -Name programmer_cli -Force -ErrorAction SilentlyContinue```
3. Unplug the USB-C cable from the board.
4. Wait at least 3 seconds before reconnecting. The FTDI chip's internal microcontroller needs time to fully power down and clear its state. If you replug too quickly (<3 seconds), the chip resumes with stale state and the first programming attempt will likely fail again.
5. Plug the USB-C cable back in.
6. Wait for Windows to finish enumerating the device (Device Manager will show "USB Debugger A" again — usually takes 2-3 seconds).
7. Run the programming script again.

##### Program Arguments

| Argument | Description |
| :--- | :--- |
| `-h`, `--help` | Display help and exit |
| `-d`, `--list_default_target` | Print the default target board name and exit |
| `-b`, `--check_if_target_built` | Print whether the firmware has been built, then exit |
| `-s`, `--check_if_target_supported` | Print whether the current target is supported, then exit |
| `-l`, `--list_supported_targets` | List all supported target boards and exit |
| `-c`, `--clean_target_prior` | Clean the build output before rebuilding and programming |
| `-k <MHz>`, `--clock_frequency` | Clock frequency passed to the build script when auto-building (default: `51`) |
| `-m "<full path to custom bitfile>"` | Program a custom `.fs` file instead of the default build output (ensure file full path is inside `""`) |
| `-jtag_frequency <freq>` | Override JTAG programming clock frequency (default: `0.5MHz`). Valid values: `0.02MHz`, `0.1MHz`, `0.3MHz`, `0.4MHz`, `0.5MHz`, `0.75MHz`, `0.9MHz`, `1.1MHz`, `1.5MHz`, `2MHz`, `2.5MHz`, `10MHz`, `15MHz` |
| `-t`, `--custom_target` | Not yet implemented — placeholder for future multi-board support |
| `-f`, `--update_flash_only` | Not yet implemented — Xilinx only |

##### Program Examples

```powershell
# Build (if needed) and program the board
.\windows\program_board.ps1

# Clean, rebuild, and program the board
.\windows\program_board.ps1 -c

# Check whether firmware has already been built
.\windows\program_board.ps1 -b

# Program with a custom bitstream file
.\windows\program_board.ps1 -m "C:\path\to\custom.fs"

# Build at 66 MHz and program
.\windows\program_board.ps1 -k 66

# Clean, rebuild at 75 MHz, and program
.\windows\program_board.ps1 -c -k 75

# Program with a faster JTAG speed (less reliable)
.\windows\program_board.ps1 -jtag_frequency 2.5MHz
```

---


## Board Demonstration

### Linux

This project can be built in 'board demonstration' mode to showcase the various hardware features (GPIO, UART, PSRAM - although as of 12/2025 not all features are demonstrated, see [roadmap](https://github.com/BrisbaneSilicon/BRS-100-GW1NR9?tab=readme-ov-file#roadmap)). To run the board demonstration firmware, build the firmware with the '-b' command line argument (below) and then program the board as per [program](https://github.com/BrisbaneSilicon/BRS-100-GW1NR9?tab=readme-ov-file#program).<br>
```bash
./build.sh -b
```
Once the board has been programmed, load your FTDI driver and connect a terminal program to UART1, as per the below (I have used the terminal program [tio](https://github.com/tio/tio) but any should work (Putty, Screen etc).
```bash
sudo modprobe ftdi_sio
sudo stty -F /dev/ttyUSB1 115200
sudo tio -b 115200 /dev/ttyUSB1 --output-delay 20
```
Next, reset the board by pressing pushbutton one (the pushbutton closest to Pin 1). The terminal should clear and then print out something similar to the following:
```bash
BOARD: BRS-100-GW1NR9
FW: c2ce822|2025-12-09 15:30:43
```

The 'FW' tag can be described as follows:<br>
```bash
<GIT repo commit SHA> <-dirty> (only if it was built with local changes) | <build date> <build time>.
```
<br>

So I built commit SHA ID [c2ce822](https://github.com/BrisbaneSilicon/BRS-100-GW1NR9/commit/c2ce822baf2d6a4d22435ef2df5be94f321e9bb4), with no local changes, on the __12/09/2025__ at approximately __3:30pm__. Note, there may be more printed, see [roadmap](#roadmap).<br><br>
In board demonstration mode, the state of GPIO<1..16> (the demonstration firmware configures these pins as inputs) will be reflected on GPIO<17..32> (the demonstration firmware configures these pins as outputs). For example, GPIO17 will reflect the state of GPIO1. To test this, simply connect GPIO1 alternatively to VCC or GND (both next to GPIO32) and monitor GPIO17 on your oscilloscope or multimeter.

### Windows

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


<br><br>

> [!NOTE]
> If you notice that after programming the board all six user LEDs are slowly flashing, it means you have built the example project without the '-b' switch. This results in the 'user.sv' module (why by default only flashes all LEDs) being included in the firmware instead of the 'board_demonstration.sv' module.

<br>

## Development

Extending the project with your custom firmware is quite straightforward, simply modify the __user.sv__ file (located in \<BRS-100-GW1NR9 repository directory>/BRS-100-GW1NR9/proj/common/systemverilog/). You can also instantiate your own Systemverilog or VHDL modules, but ensure you add them to the appropriate build script file __synth.tcl__ ('scripts' directories).

Further information related to user development with the BRS-100-GW1NR9 is detailed official documentation, see section [documentation](#documentation) below.

<br>

## Documentation

Official documentation for the BRS-100-GW1NR9 is available [here](https://brisbanesilicon.com.au/docs/BRS-100-GW1NR9_Datasheet.pdf).

<br>

## Roadmap

1. Enhance board demonstration mode to exercise both PSRAM and Flash memory.
2. Add the ability to target different development boards / ecosystems, i.e. Digilent ARTY-S7 / Xilinx/AMD.

<br>

## Authors

- [@brisbanesilicon](https://github.com/BrisbaneSilicon)
- [@Jingqim](https://github.com/Jingqim) (Windows Version)

<br>

## Appendix

For developing with the project, we recommend [Sublime Text](https://www.sublimetext.com/), with the VHDL and/or Systemverilog syntax highlighing enabled.<br><br>
If you like this project, follow us on X [here](https://x.com/brisbanesilicon)!
<br>

## Notes on Windows Scripts

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

The wrong cable driver path was selected internally. Unplug and replug the board, then retry. Status codes starting with `0x0001xxxx` indicate the wrong (FT2CH) driver path; `0x0003xxxx` is the correct (ftd2xx) path. Also double check the GOWIN EDA version (V1.9.12.02 or V1.9.12), as this error is also commonly seen when the wrong version is installed.

### `KERNEL_SECURITY_CHECK_FAILURE` (BSOD 0x139)

Windows crashes with a blue screen after repeated programming cycles. This is caused by a bug in the FTDI `ftd2xx.sys` kernel driver.

**Fix:** Fully remove and reinstall the FTDI D2XX driver. See [FTDI Driver Setup](#ftdi-driver-setup) for the complete step-by-step procedure, including how to clear ghost devices from the driver store and verify driver version consistency.

### GOWIN EDA not found

The scripts search common install paths automatically. If GOWIN EDA is installed elsewhere, follow steps in [Prerequisites](#prerequisites) to change where the script looks for the installation.

### `cannot be loaded because running scripts is disabled on this system`

Set the PowerShell execution policy:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or:

```powershell
Set-ExecutionPolicy RemoteSigned
```

### GOWIN version warnings

- **V1.9.8–V1.9.11** — scripts will warn and continue, but these versions are untested.
- **V1.9.11.01** — blocked by the scripts. Known broken release.
- **V1.9.12** — recommended and verified (Windows and Linux).
- **V1.9.12.01** — blocked by the scripts. Do not use; the programmer component is broken.
- **V1.9.12.02** — also compatible (Windows only).

### Build triggered automatically by `program_board.ps1`

If no `.fs` file exists, the program script will automatically run a full build before programming. To avoid this triggering an unwanted default build, pre-build with your desired options first:

```powershell
.\windows\build.ps1 -b -k 66
.\windows\program_board.ps1
```

---


## Support

For support, email support@brisbanesilicon.com.au.


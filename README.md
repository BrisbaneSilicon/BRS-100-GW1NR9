
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

Fufill the below prerequisites.

### Prerequisites

1. A PC running an x64 compatible, Debian-based flavour of Linux.
   - Other flavours of Linux may work but aren't officially supported.
   - We recommend [Ubuntu](https://ubuntu.com/).
   - Support for Windows is coming soon! See section [roadmap](#roadmap) below.
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

### Optional

1. An FTDI driver is required if you wish to communicate with the BRS-100-GW1NR9 via UART. On most Linux distributions they are part of the default installation of the OS. On Windows, you may need to install the driver from [here](https://ftdichip.com/drivers/vcp-drivers/). FTDI also provide installation guides, available [here](https://ftdichip.com/document/installation-guides/).

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

Support for Windows is coming soon! See section [roadmap](#roadmap) below.

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

Support for Windows is coming soon!

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

Support for Windows is coming soon!
<br><br>

## Program

After building the BRS-100-GW1NR9 firmware you are ready to program it to the board! It is worth noting that this stage also programs the internal non-volatile bitstream flash, so your firmware will auto-load after baord power on! <br><br>After plugging the board into your PC via the USB-C cable, simply perform the following:

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

Support for Windows is coming soon!
<br><br>

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

Support for Windows is coming soon!
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

1. Implement Windows-based project workflow.
2. Enhance board demonstration mode to exercise both PSRAM and Flash memory.
3. Add the ability to target different development boards / ecosystems, i.e. Digilent ARTY-S7 / Xilinx/AMD.

<br>

## Authors

- [@brisbanesilicon](https://github.com/BrisbaneSilicon)

<br>

## Appendix

For developing with the project, we recommend [Sublime Text](https://www.sublimetext.com/), with the VHDL and/or Systemverilog syntax highlighing enabled.<br><br>
If you like this project, follow us on X [here](https://x.com/brisbanesilicon)!
<br>

## Support

For support, email support@brisbanesilicon.com.au.


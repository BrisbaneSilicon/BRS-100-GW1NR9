## Overview

Windows script for building and programming the BRS-100-GW1NR9 FPGA board. 


## Getting Started

Fulfill the below prerequisites.

### Prerequisites

1. Windows 11 x64 PC

2. An installation of GOWIN EDA V1.9.12.02
    - Install in default GOWIN location, such as "C:\Gowin\Gowin_V1.9.12.02" or 
    "C:\Program Files\Gowin\Gowin_V1.9.12.02_x64". Alternatively add programmer_cli.exe and gw_sh.exe
    into the system path variables or edit $commonPaths variable in the scripts. 
4. A free license for GOWIN EDA.
5. A copy of this repository.
6. Execution Policy of RemoteSigned or higher. To check or change the policy, run Powershell in admin and run the command 
```
Get-ExecutionPolicy
```
If it doesn't return RemoteSigned or Unrestricted, run
```
Set-ExecutionPolicy RemoteSigned
```
7. Ensure FTDI drivers have no conflicts. Check by running 
```
pnputil /enum-drivers | Select-String -Pattern "ftdi" -Context 5
```
Ensure the driver versions match. Reinstall FTDI driver if they don't, otherwise windows might crash
with "Kernel Security Check Failure (0x139)" during programming. 

### How to build
Open PowerShell (with or without Admin), run ```.\<BRS-100-GW1NR9 repository directory>\BRS-100-GW1NR9\build.ps1```. 
Differnet build options:
| Build Argument | Description |


### How to program board


## board demonstration mode 
'board demonstration' mode can be built via calling ```.\build.ps1 -b``` in PowerShell, which demonstrates basic GPIO, LED and UART features.  Running ```.\build.ps1``` will build an example project that flashes 6 LEDs. You can find the built .fs file under ```\windows\output``` folder. For more command line options run ```.\build.ps1 -h``` for help message.  
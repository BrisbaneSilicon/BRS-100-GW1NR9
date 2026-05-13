# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

Behavioral guidelines to reduce common LLM coding mistakes.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## Scope

Only edit Windows files (`.ps1` or Windows command prompt scripts). Do **not** modify Linux scripts (`.sh` files) unless explicitly necessary — ask before doing so.

## Project: BRS-100-GW1NR9 RAM Demo (Multi-Platform FPGA)

Multi-platform FPGA firmware project for the **BRS-100-GW1NR9** development board. Currently supports:
- **GOWIN GW1NR-9** (primary platform)
- **Xilinx Spartan-7** (Arty-S7, board demonstration mode only)

The project is fully scriptable (no GUI required). Bitstream output: `build/output/*.fs` (GOWIN) or `build/output/*.bit` (Xilinx).

### Build

**Windows:**
```powershell
cd build
.\build.ps1                    # default LED blink @ 51 MHz
.\build.ps1 -b                 # board demonstration firmware
.\build.ps1 -b -k 66           # board demo @ 66 MHz
.\build.ps1 -s                 # synthesis only (check utilization/timing)
.\build.ps1 -p                 # generate GOWIN IDE project file only
.\build.ps1 -c                 # clean build artifacts
.\build.ps1 -h                 # show all options
```

**Linux:**
```bash
cd build
./build.sh                     # default LED blink @ 51 MHz
./build.sh -b                  # board demonstration firmware
./build.sh -h                  # show all options
```

**Key parameters:**
- `-k FREQ`: System clock frequency. Supported: 51, 66, 75, 81, 87 MHz (each has a dedicated PLL wrapper).
- `-u BAUD`: UART baud rate (default 115200).
- `-r`: Disable pushbutton 1 as hard reset.
- `-b`: Board demonstration mode (replaces `user.sv` with `board_demonstration.sv`).

### Program

**Windows:**
```powershell
cd prog
.\program_board.ps1            # build if needed, then program
.\program_board.ps1 -c         # clean, rebuild, program
```

**Linux:**
```bash
cd prog
./program_board.sh             # build if needed, then program
```

**Note:** After printing `*** GOWIN programmer_cli ***`, the script may stall for ~3 seconds (expected Windows FTDI behavior). The script auto-detects hangs and retries up to 2 times. If all 3 attempts stall, follow recovery in `TROUBLESHOOTING.txt`: unplug USB-C, wait 3–5 seconds, replug, retry.

### Architecture

```
proj/
  common/
    systemverilog/
      user.sv               ← USER ENTRY POINT (customization target)
      uart.sv               # AXI-Stream UART (valid/ready handshake)
      axis_*.sv             # AXI-Stream bus primitives (skid buffers, etc.)
      util.sv, muxes.sv, reg_sync.sv, rst_sync.sv, dff_sync.sv
    scripts/synth.tcl       # Add new cross-platform modules here
  foreign/
    gowin/GW1NR-9/C7I6/
      systemverilog/
        top.sv              # Platform top-level (PLL, UART, RAM, Flash, GPIO)
        board_demonstration.sv  # Demo firmware (selected via -b flag)
        clk{51,66,75,81,87}mhz.sv  # PLL wrappers
        flash_memory.sv, ram_memory.sv, psram_controller.sv
      scripts/synth.tcl     # Add GOWIN-specific modules here
      constraints/          # Timing (.sdc) and location (.cst) files
    xilinx/                 # Similar structure for Xilinx (Arty-S7)
```

**`top.sv`** instantiates PLL, UART, HyperRAM (`ram_memory`), Flash (`flash_memory`), and either `user` or `board_demonstration` logic. Exposes to user logic:
- `sysclk`, `sysclk_resetn`
- `microsecond_tick`, `millisecond_tick`, `second_tick`
- 6 LEDs (`leds[5:0]`)
- 32 GPIO (`io[31:0]`, bidirectional)
- AXI-Stream UART RX/TX (see below)

**`user.sv`** is the default custom firmware entry point. Receives all signals from `top.sv`; implements application logic.

### AXI-Stream Bus Handshake

**Critical:** Transactions complete on `valid && ready` — sample **both** signals, never just one.

Example (transmitting UART data):
```systemverilog
// Pre-load first byte before FSM starts
uart_tx_valid <= 1'b1;
uart_tx_data <= first_byte;

// FSM waits for uart_tx_ready
@(posedge sysclk) if (uart_tx_valid && uart_tx_ready) begin
    uart_tx_data <= next_byte;  // Load next byte *on* the handshake
end
```

Sampling only `ready` drops the first character; sampling only `valid` drops the last.

### Development Workflow

1. **Modify `user.sv`** or create new `.sv`/`.vhd` modules alongside existing ones.
2. **Register new modules** in the appropriate `scripts/synth.tcl`:
   - Cross-platform: `proj/common/scripts/synth.tcl`
   - GOWIN-specific: `proj/foreign/gowin/GW1NR-9/C7I6/scripts/synth.tcl`
3. **Build and verify**: `.\build.ps1 -s` (synthesis only, to check utilization/timing early).
4. **Program and test**: `.\program_board.ps1`

### Key RTL Conventions

- **No `"\r"` or `"\n"` in Verilog strings.** Use `8'h0D` (CR) and `8'h0A` (LF).
- **Flash SPI signals use GOWIN dedicated MSPI pins, not GPIO.** Requires constraint `-use_mspi_as_gpio 0` (already set).
- **System clock frequencies:** 51, 66, 75, 81, 87 MHz. Each has a dedicated PLL wrapper (`clkXXmhz.sv`); use the matching frequency to avoid PLL reconfiguration.
- **Reset timing:** Use `rst_sync.sv` (or `dff_sync.sv`) for cross-clock-domain resets; instantiate manually if needed.

### Licensing & Environment

**GOWIN EDA:** V1.9.12 or V1.9.12.02 (do **not** use V1.9.12.01 — broken programmer).
- Install to: `C:\Gowin` or `C:\Program Files\Gowin` (Windows), `/opt/gowin`, `/opt/GOWIN`, etc. (Linux).
- Free license available from [GOWIN](https://www.gowinsemi.com/en/support/license/) or via public license servers (see `README.md`).

**PowerShell (Windows):** Execution policy must be `RemoteSigned` or higher.
```powershell
Set-ExecutionPolicy RemoteSigned
```

### Troubleshooting

- **Programmer hangs at `Operation "embFlash Erase,Program"`:** See `TROUBLESHOOTING.txt`.
- **FTDI driver crashes (BSOD 0x139):** Verify driver versions match; reinstall if needed (see `README.md` for full steps).
- **Build fails to find GOWIN:** Set `GOWIN_INSTALL_DIR` environment variable or reinstall GOWIN EDA.

### Windows-Specific Notes

See `AGENTS.md` in the parent directory (`BRS-100`) for broader project context and multi-platform guidance. This directory focuses on the `ram_demo` example implementation.

Only edit Windows files (`.ps1` scripts); do not modify Linux shell scripts (`.sh`) unless necessary — ask first.

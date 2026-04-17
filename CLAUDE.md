# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## Project: BRS-100-GW1NR9 FPGA Development Board

FPGA firmware project for the BRS-100-GW1NR9 board (GOWIN GW1NR-9 FPGA). Toolchain: GOWIN EDA V1.9.12 or V1.9.12.02 (do **not** use V1.9.12.01 — broken programmer).

### Build

**Windows:**
```powershell
.\windows\build.ps1           # default LED blink
.\windows\build.ps1 -b        # board demonstration firmware (GPIO, UART)
.\windows\build.ps1 -b -k 66  # board demo at 66 MHz
.\windows\build.ps1 -s        # synthesis only (check utilisation/timing)
.\windows\build.ps1 -p        # generate project file only (for GOWIN IDE)
.\windows\build.ps1 -c        # clean current build output
.\windows\build.ps1 -h        # full options list
```

**Linux:**
```bash
cd build && ./build.sh        # default
./build.sh -b                 # board demonstration
./build.sh -h                 # full options list
```

Output `.fs` bitstream is written to `windows\output\BRS-100-GW1NR9.fs`.

### Program

```powershell
.\windows\program_board.ps1        # build if needed, then program
.\windows\program_board.ps1 -c     # clean, rebuild, program
```

If the script freezes at `Operation "embFlash Erase,Program"`: kill `programmer_cli.exe`, unplug, wait 3 s, replug, retry.

### Architecture

```
proj/
  common/
    systemverilog/     # platform-independent RTL
      user.sv          ← USER ENTRY POINT for custom firmware
      uart.sv          # AXI-S valid/ready UART
      axis_*.sv        # AXI-Stream bus primitives
      util.sv, muxes.sv, reg_sync.sv, rst_sync.sv, dff_sync.sv
    scripts/synth.tcl  # common source list (add new common modules here)
    vhdl/              # VHDL utilities
  foreign/
    gowin/GW1NR-9/C7I6/
      systemverilog/
        top.sv          # platform top-level (PLL, reset, UART, RAM, Flash, GPIO)
        board_demonstration.sv  # demo firmware (replaces user.sv when -b is passed)
        clk{51,66,75,81,87}mhz.sv  # PLL wrappers
        flash_memory.sv, ram_memory.sv, psram_controller.sv
      scripts/synth.tcl  # platform source list (add new GOWIN-specific modules here)
```

**`top.sv`** is the platform-specific wrapper. It instantiates the PLL, UART, HyperRAM (`ram_memory`), Flash (`flash_memory`), and either `user` or `board_demonstration` depending on the build mode. It exposes `sysclk`, `sysclk_resetn`, tick signals, UART AXI-S ports, and `io[31:0]` to user logic.

**`user.sv`** is the user's entry point. Receives `sysclk`, `sysclk_resetn`, `microsecond_tick`/`millisecond_tick`/`second_tick`, 6 LEDs, 32 GPIO `io`, and AXI-S UART ports.

To add new modules: place `.sv` files alongside existing ones and add them to the appropriate `scripts/synth.tcl`.

### RTL Conventions

- Bus handshake: AXI-Stream style — transactions complete on `valid && ready`. Check **both** signals; sampling only `ready` will drop the first character, sampling only `valid` will drop the last.
- For multi-character UART transmit (see `board_demonstration.sv`), pre-load the first byte before the FSM starts — the handshake needs it ready before the first `ready` pulse arrives.
- **No `"\r"` or `"\n"` string escapes in Verilog.** Use `8'h0D` for CR and `8'h0A` for LF.
- Flash SPI signals must use the GOWIN dedicated MSPI pins, not GPIO. Requires `-use_mspi_as_gpio 0` in the constraints / project settings.
- Supported system clock frequencies: 51, 66, 75, 81, 87 MHz (each has a dedicated PLL wrapper).

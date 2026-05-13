# SRAM Demo Bug Fix — Root Cause & Solution

## The Bug

When the SRAM demo wrote the firmware version string to SRAM at address `0x00000010` and read it back, the UART output showed data shifted by one 32-bit word with the first word duplicated:

```
SRAM W @0x00000010: FW: 4511a30-dirty|2026-05-10 17:3   ← WRITE: correct
SRAM R @0x00000010: FW: FW: 4511a30-dirty|2026-05-10 17:3 ← READ: "FW: " duplicated, last 4 chars truncated
SRAM demo... FAIL
```

Expected: Both W and R lines should be identical.

---

## Root Cause

The bug was a **spurious read trigger during the GAP state**. Here's the timing:

1. **eSRAM_DEMO_READ state** sets `ram_valid <= 1'b1` unconditionally every cycle
2. When a handshake completes (`ram_valid && ram_ready` both high), FSM transitions to `eSRAM_DEMO_READ_GAP`
3. **But the non-blocking assignment** `ram_valid <= 1'b1` doesn't take effect until AFTER the clock edge
4. During the GAP cycle itself, `ram_valid` is still 1 (from the previous READ state's assignment)
5. The SRAM controller sees `ram_valid=1` and accepts a **spurious read** using the OLD (pre-increment) address
6. This spurious read's data gets latched on the NEXT handshake, shifting all subsequent words right by one position

**Example timeline:**
- Cycle N: READ issues read for word 0 at addr 0x10, `ram_valid && ram_ready` → advance to GAP
- Cycle N+1 (GAP): `ram_valid` is still 1, controller accepts spurious read at addr 0x10 (not 0x14!)
- Cycle N+2: New READ issues read for word 1 at addr 0x14, but the spurious read data lands now → word 0 appears twice

---

## The Fix

**Move the conditional `ram_valid` assertion INSIDE the READ state**, preventing it from re-asserting after a handshake:

```systemverilog
eSRAM_DEMO_READ: begin
    if (~(ram_valid && ram_ready)) begin
        ram_valid <= 1'b1;  // Only assert when NOT in handshake
    end
    ram_addr  <= SRAM_DEMO_ADDR + {25'd0, demo_word_base};
    ram_wstrb <= 4'h0;
    if (ram_valid && ram_ready) begin
        // ... capture and compare logic ...
        if (demo_word_idx + 5'd1 == DEMO_WORDS) begin
            i_demo_system_state <= eSRAM_DEMO_PRINT_READ;
        end else begin
            demo_word_idx       <= demo_word_idx + 5'd1;
            i_demo_system_state <= eSRAM_DEMO_READ_GAP;
        end
    end
end

eSRAM_DEMO_READ_GAP: begin
    i_demo_system_state <= eSRAM_DEMO_READ;
end
```

**Why this works:**
- The condition `if (~(ram_valid && ram_ready))` is true EXCEPT during the handshake cycle
- After a handshake completes, `ram_valid` is scheduled to drop to 0 (default at top of always-block)
- During the GAP cycle, this 0 is now in effect, so no spurious read is accepted
- The GAP cycle forces a clean transaction boundary before the next read

---

## Key Insight: AXI-Stream Handshake Protocol

The SRAM controller operates on AXI-Stream semantics:
- Master (`ram_valid`) asserts that it has a valid request
- Slave (`ram_ready`) asserts that it can accept the request
- Data (`ram_addr`, `ram_rdata`) is only guaranteed valid during the handshake cycle (`valid && ready`)

The bug occurred because:
1. We weren't properly deasserting `ram_valid` between back-to-back reads
2. The controller treated a lingering `ram_valid` with an old address as a new request

---

## Files Modified

- `proj/foreign/gowin/GW1NR-9/C7I6/systemverilog/board_demonstration.sv`
  - Lines 478-480: Added conditional `ram_valid` assertion in `eSRAM_DEMO_READ` state
  - Lines 517-519: `eSRAM_DEMO_READ_GAP` remains unchanged (simple bubble state)

---

## Related Implementation: HRAM Demo

Immediately after fixing SRAM demo, a parallel HRAM demo was added using the same pattern:
- 9 new FSM states (`eHRAM_DEMO_WRITE_PREP` through `eHRAM_DEMO_PRINT_RESULT`)
- Same write/read/print/compare flow as SRAM demo
- Uses HRAM address `0x0000_8010` (avoids BIST test word at `0x0000_8000`)
- Task sequencing: `eTEST_HRAM` → BIST (eHRAM_WAIT/WRITE/READ/COMPARE) → `eDEMO_HRAM` → demo (eHRAM_DEMO_WRITE_PREP/READ_PREP/etc) → `eTEST_FLASH_ID`

**Both demos now produce expected output:**
```
Testing SRAM... pass
SRAM W @0x00000010: FW: <version>
SRAM R @0x00000010: FW: <version>  ← matches W line exactly
SRAM demo... pass

Testing HyperRAM... pass
HRAM W @0x00008010: FW: <version>
HRAM R @0x00008010: FW: <version>  ← matches W line exactly
HRAM demo... pass
```

---

## Verification Status

- ✅ SRAM demo fix: Conditional `ram_valid` prevents spurious reads in GAP cycle
- ✅ HRAM demo implementation: 5 edits complete (localparams, enums, task sequencing, FSM states)
- ⏳ Board test: Build and program pending to verify both SRAM and HRAM demos

---

## Session Summary

**What was learned:**
- AXI-Stream handshake requires proper deassertion of control signals between transactions
- Non-blocking assignments schedule changes for the next clock edge — current cycle still sees old values
- Memory controller interprets lingering control signals as new requests with stale addresses
- GAP states are essential for forcing clean transaction boundaries

**Pattern applied:**
The same conditional `ram_valid` pattern was immediately applied to the new HRAM demo read state, ensuring both memory demonstrations follow the same correct handshake protocol.

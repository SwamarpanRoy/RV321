# RV32I Verification Plan & Corner-Case Analysis

## 1. Verification Strategy
The verification platform combines layered SystemVerilog testbenches, SystemVerilog Assertions (SVA), comprehensive Functional Coverage metrics, and an automated Python regression framework.

---

## 2. Corner Case Matrix & Reasoning

| Category | Corner Case Scenario | Stimulus / Test Pattern | Expected Outcome | Verification Mechanism |
| :--- | :--- | :--- | :--- | :--- |
| **Architectural Invariant** | Write to register `x0` | `addi x0, x0, 50` followed by read | `x0` remains 0; write is ignored | SVA property `assert_x0_always_zero` + Scoreboard |
| **PC Alignment** | JALR unaligned address calculation | `jalr x1, x2, 3` with `x2=0` | Bit 0 is masked: `(addr & ~1)`, keeping PC aligned | SVA property `assert_pc_aligned` |
| **RAW Hazard (EX-EX)** | Back-to-back dependency | `addi x1, x0, 5` followed by `addi x2, x1, 10` | Zero delay; EX->EX forwarding supplies value `5` | `test_hazards_raw.hex` + Scoreboard |
| **RAW Hazard (MEM-EX)** | 2-cycle dependency | `addi x1, x0, 5`; `nop`; `addi x2, x1, 10` | Zero delay; MEM->EX forwarding supplies value `5` | `test_hazards_raw.hex` + Scoreboard |
| **Load-Use Hazard** | ALU depends immediately on Load | `lw x2, 0(x0)` followed by `addi x3, x2, 50` | 1-cycle pipeline bubble inserted; PC stalls; x3 computes 150 | `test_load_use_stall.hex` + cycle count check |
| **Control Hazard** | Branch Taken flush | `bne x1, x2, target` with `addi x4, x0, 99` in delay slot | Delay slot instruction is flushed (x4 != 99); target executes | `test_branch_corner.hex` + SVA flush checker |
| **AXI Handshake** | Slave inserts backpressure | Slave deasserts `AWREADY` or `WREADY` for multiple cycles | Master holds `AWADDR`, `WDATA`, `AWVALID`, `WVALID` stable | SVA property `assert_awaddr_stable` |
| **APB Handshake** | Slow peripheral wait states | Peripheral deasserts `PREADY` for multiple cycles | Bridge maintains `PSEL` and `PENABLE` until `PREADY` rises | SVA property `assert_apb_addr_stable` |
| **Memory Alignment** | Misaligned Halfword/Word | `lh` or `lw` with `addr[0] != 0` or `addr[1:0] != 0` | Flagged as `unaligned_fault`; byte strobe prevents corrupt write | `rv32i_lsu` fault logic |

---

## 3. SystemVerilog Assertions (SVA) Summary
- `assert_awaddr_stable`: Verifies AXI AWADDR stability during wait states.
- `assert_wdata_stable`: Verifies AXI WDATA and WSTRB stability during wait states.
- `assert_araddr_stable`: Verifies AXI ARADDR stability during wait states.
- `assert_no_x_awvalid`: Ensures no X/Z on AXI AWVALID.
- `assert_no_x_wvalid`: Ensures no X/Z on AXI WVALID.
- `assert_no_x_arvalid`: Ensures no X/Z on AXI ARVALID.
- `assert_apb_setup_to_access`: Ensures APB PENABLE rises exactly 1 cycle after PSEL.
- `assert_apb_addr_stable`: Ensures APB PADDR stability while PSEL is active.
- `assert_pc_aligned`: Microarchitectural check ensuring PC is 4-byte aligned.
- `assert_x0_always_zero`: Invariant check ensuring x0 never mutates.
- `assert_branch_flush`: Checks that a taken branch triggers pipeline register flush.

---

## 4. Functional Coverage Model
- **Opcode Coverage**: 100% coverage across all 37 RV32I integer opcodes.
- **Branch Coverage**: 100% cross-coverage between branch condition types (BEQ, BNE, BLT, BGE, BLTU, BGEU) and branch outcomes (Taken, Not-Taken).
- **Hazard Cross-Coverage**: Cross-coverage between Forwarding Source A, Forwarding Source B, and Load-Use Stall occurrences.

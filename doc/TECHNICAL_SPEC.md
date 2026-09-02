# RV32I Processor & SoC Technical Specification

## 1. Overview & Architectural Goals
This document specifies the microarchitecture of the **Enterprise-Grade RV32I RISC-V SoC**, engineered specifically for high-reliability embedded applications and tailored to the rigorous standards of Cisco Hardware, ASIC, and FPGA engineering teams.

Key Architectural Features:
- **ISA**: Standard 32-bit RISC-V Base Integer Instruction Set (RV32I).
- **Core Microarchitecture**: Classic 5-stage in-order pipeline (IF, ID, EX, MEM, WB).
- **Hazard Resolution**: Fully integrated data forwarding unit (EX->EX, MEM->EX), hardware load-use hazard stall unit, and branch misprediction flushing.
- **Interconnect**: Standard **AMBA AXI4-Lite** system bus with master adapter and multi-slave decoding.
- **Peripheral Subsystem**: Standard **AMBA APB4** bridge with memory-mapped UART, 32-bit GPIO with interrupt generation, and a 32-bit SysTick timer.
- **Clock & Reset Scheme**: Dual-stage flip-flop asynchronous assert, synchronous de-assert reset synchronizer (`rst_sync`).

---

## 2. Pipeline Microarchitecture

```text
  +---------+      +---------+      +---------+      +---------+      +---------+
  |   IF    | ---> |   ID    | ---> |   EX    | ---> |   MEM   | ---> |   WB    |
  |  Fetch  |      | Decode  |      | Execute |      | Memory  |      |Writeback|
  +---------+      +---------+      +---------+      +---------+      +---------+
       ^                                 |                |                |
       |             Branch / Jump Flush |                |                |
       +---------------------------------+                |                |
                                                          |                |
                     EX-to-EX Data Forwarding             |                |
                     <------------------------------------+                |
                     MEM-to-EX Data Forwarding                             |
                     <-----------------------------------------------------+
```

### 2.1 Stage Breakdown
1. **Instruction Fetch (IF)**:
   - Program Counter (`pc_reg`) increments by 4 or redirects to branch/jump target.
   - Generates 32-bit instruction fetch request to SRAM.
2. **Instruction Decode (ID)**:
   - Decodes opcode, funct3, funct7, rs1, rs2, and rd.
   - Dual-port asynchronous read from 32x32 Register File.
   - Immediate generation for I, S, B, U, J types.
   - Hazard detection evaluates potential load-use conditions against IF/ID registers.
3. **Execute (EX)**:
   - 32-bit ALU performs arithmetic, logical, shift, and comparison operations.
   - Forwarding multiplexers select between register operands, EX/MEM result, or MEM/WB writeback data.
   - Branch comparator evaluates condition (BEQ, BNE, BLT, BGE, BLTU, BGEU).
   - Computes branch target address (`pc + imm`) or JALR target (`(rs1 + imm) & ~1`).
4. **Memory Access (MEM)**:
   - Load/Store Unit (`rv32i_lsu`) computes byte enables (`wstrb`) and aligns byte/half-word/word read/write transfers.
   - Drives memory load/store requests to the AXI4-Lite Master adapter.
5. **Writeback (WB)**:
   - Selects final writeback value from ALU result, Memory load data, or PC+4 (for JAL/JALR link register).
   - Writes synchronously into register file. Register `x0` is hardwired to zero.

---

## 3. Hazard Resolution & Forwarding Equations

### 3.1 Forwarding Logic (EX Stage)
- **EX/MEM Forwarding**:
  ```verilog
  if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1))
      fwd_a = FWD_EX_MEM;
  if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2))
      fwd_b = FWD_EX_MEM;
  ```
- **MEM/WB Forwarding**:
  ```verilog
  if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1) && !(ex_mem_forward_condition))
      fwd_a = FWD_MEM_WB;
  if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2) && !(ex_mem_forward_condition))
      fwd_b = FWD_MEM_WB;
  ```

### 3.2 Load-Use Hazard Condition
When an instruction in the EX stage is a LOAD (`id_ex_mem_read == 1`), and its destination register `id_ex_rd` matches `if_id_rs1` or `if_id_rs2`:
- `stall_pc = 1` (PC register holds current value)
- `stall_if_id = 1` (IF/ID pipeline register holds current instruction)
- `flush_id_ex = 1` (Inserts NOP bubble into EX stage)

### 3.3 Branch Misprediction
When a branch is resolved as taken in EX or a jump occurs:
- `flush_if_id = 1` (Discards fetched instruction)
- `flush_id_ex = 1` (Discards decoded instruction)
- `pc_next = branch_target_ex` (PC redirects to branch target)

---

## 4. SoC Memory Map

| Address Range | Size | Component | Protocol | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x0000_0000 - 0x0000_FFFF` | 64 KB | Boot SRAM / Data RAM | AXI4-Lite | Unified Instruction & Data Memory |
| `0x4000_0000 - 0x4000_000F` | 16 B | UART Controller | APB4 | Baud Divisor, TX Data, RX Data, Status |
| `0x4000_1000 - 0x4000_100F` | 16 B | GPIO Controller | APB4 | 32-bit Direction, Data, Interrupt Enable |
| `0x4000_2000 - 0x4000_200F` | 16 B | SysTick Timer | APB4 | Control, 32-bit Counter, Compare Match |

---

## 5. Bus Protocols & State Machines

### 5.1 AXI4-Lite Handshake Engine
All channels (AW, W, B, AR, R) obey standard valid-ready handshake conventions:
- A transfer occurs when both `VALID` and `READY` are high on the same rising clock edge.
- Once `VALID` is asserted, control, address, and data lines remain completely stable until `READY` is asserted.

### 5.2 APB4 Bridge State Machine
```text
  [ ST_IDLE ] ---> AXI Request detected
       |
       v
  [ ST_SETUP ]  (PSEL=1, PENABLE=0)
       |
       v
  [ ST_ACCESS ] (PSEL=1, PENABLE=1, wait PREADY)
       |
       v
  [ ST_RESP ]   (Generate AXI BVALID / RVALID)
       |
       v
  [ ST_IDLE ]
```

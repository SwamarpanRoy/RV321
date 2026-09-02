#!/usr/bin/env python3
"""
Architectural Reference Model & Golden Simulator for RV32I Processor Core.
Simulates RV32I instructions, maintains register file state, handles memory-mapped
peripherals (UART, GPIO, Timer), and generates expected register dumps.
Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
"""

import sys

def to_signed(val, bits=32):
    val = val & ((1 << bits) - 1)
    if val & (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def to_unsigned(val, bits=32):
    return val & ((1 << bits) - 1)

class RV32IRefModel:
    def __init__(self, mem_words=16384):
        self.regs = [0] * 32
        self.pc = 0
        self.mem = [0] * mem_words
        self.cycle_count = 0
        self.wb_history = []
        
        # Peripheral state
        self.uart_tx_buffer = []
        self.gpio_dir = 0
        self.gpio_data = 0
        self.timer_ctrl = 0
        self.timer_count = 0
        self.timer_cmp = 0xFFFFFFFF

    def load_hex(self, hex_file_path):
        with open(hex_file_path, 'r') as f:
            idx = 0
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                self.mem[idx] = int(line, 16)
                idx += 1

    def step(self):
        if self.pc // 4 >= len(self.mem):
            return False # Program ended

        instr = self.mem[self.pc // 4]
        if instr == 0x00000000 and self.pc > 0:
            return False # Terminate on 0

        self.cycle_count += 1
        pc_curr = self.pc
        self.pc += 4

        opcode = instr & 0x7F
        rd     = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x07
        rs1    = (instr >> 15) & 0x1F
        rs2    = (instr >> 20) & 0x1F
        funct7 = (instr >> 25) & 0x7F

        val_rs1 = self.regs[rs1]
        val_rs2 = self.regs[rs2]
        wb_val = None

        if opcode == 0x37: # LUI
            imm = to_signed(instr & 0xFFFFF000)
            wb_val = to_unsigned(imm)
            if rd != 0: self.regs[rd] = wb_val

        elif opcode == 0x17: # AUIPC
            imm = to_signed(instr & 0xFFFFF000)
            wb_val = to_unsigned(pc_curr + imm)
            if rd != 0: self.regs[rd] = wb_val

        elif opcode == 0x6F: # JAL
            imm = ((instr >> 31) & 1) << 20 |                   ((instr >> 12) & 0xFF) << 12 |                   ((instr >> 20) & 1) << 11 |                   ((instr >> 21) & 0x3FF) << 1
            imm = to_signed(imm, 21)
            wb_val = pc_curr + 4
            if rd != 0: self.regs[rd] = wb_val
            self.pc = to_unsigned(pc_curr + imm)

        elif opcode == 0x67: # JALR
            imm = to_signed(instr >> 20, 12)
            wb_val = pc_curr + 4
            if rd != 0: self.regs[rd] = wb_val
            self.pc = (val_rs1 + imm) & ~1

        elif opcode == 0x63: # BRANCH
            imm = ((instr >> 31) & 1) << 12 |                   ((instr >> 7) & 1) << 11 |                   ((instr >> 25) & 0x3F) << 5 |                   ((instr >> 8) & 0xF) << 1
            imm = to_signed(imm, 13)
            taken = False
            if funct3 == 0:   taken = (val_rs1 == val_rs2)         # BEQ
            elif funct3 == 1: taken = (val_rs1 != val_rs2)         # BNE
            elif funct3 == 4: taken = (to_signed(val_rs1) < to_signed(val_rs2))  # BLT
            elif funct3 == 5: taken = (to_signed(val_rs1) >= to_signed(val_rs2)) # BGE
            elif funct3 == 6: taken = (val_rs1 < val_rs2)          # BLTU
            elif funct3 == 7: taken = (val_rs1 >= val_rs2)         # BGEU
            if taken:
                self.pc = to_unsigned(pc_curr + imm)

        elif opcode == 0x03: # LOAD (LW)
            imm = to_signed(instr >> 20, 12)
            addr = to_unsigned(val_rs1 + imm)
            data = 0
            if addr < len(self.mem) * 4:
                data = self.mem[addr // 4]
            wb_val = data
            if rd != 0: self.regs[rd] = wb_val

        elif opcode == 0x23: # STORE (SW)
            imm = ((instr >> 25) & 0x7F) << 5 | ((instr >> 7) & 0x1F)
            imm = to_signed(imm, 12)
            addr = to_unsigned(val_rs1 + imm)
            # Memory or Peripheral
            if addr == 0x40000000: # UART DATA
                self.uart_tx_buffer.append(chr(val_rs2 & 0xFF))
            elif addr == 0x40001004: # GPIO DIR
                self.gpio_dir = val_rs2
            elif addr == 0x40001000: # GPIO DATA
                self.gpio_data = val_rs2
            elif addr == 0x40002008: # TIMER CMP
                self.timer_cmp = val_rs2
            elif addr < len(self.mem) * 4:
                self.mem[addr // 4] = val_rs2

        elif opcode == 0x13: # OP-IMM
            imm = to_signed(instr >> 20, 12)
            shamt = imm & 0x1F
            if funct3 == 0:   wb_val = to_unsigned(val_rs1 + imm)
            elif funct3 == 1: wb_val = to_unsigned(val_rs1 << shamt)
            elif funct3 == 2: wb_val = 1 if to_signed(val_rs1) < imm else 0
            elif funct3 == 3: wb_val = 1 if val_rs1 < to_unsigned(imm) else 0
            elif funct3 == 4: wb_val = val_rs1 ^ to_unsigned(imm)
            elif funct3 == 5:
                if funct7 & 0x20: wb_val = to_unsigned(to_signed(val_rs1) >> shamt) # SRAI
                else:             wb_val = to_unsigned(val_rs1 >> shamt)            # SRLI
            elif funct3 == 6: wb_val = val_rs1 | to_unsigned(imm)
            elif funct3 == 7: wb_val = val_rs1 & to_unsigned(imm)
            if rd != 0: self.regs[rd] = wb_val

        elif opcode == 0x33: # OP (R-type)
            shamt = val_rs2 & 0x1F
            if funct3 == 0:
                if funct7 & 0x20: wb_val = to_unsigned(val_rs1 - val_rs2)
                else:             wb_val = to_unsigned(val_rs1 + val_rs2)
            elif funct3 == 1: wb_val = to_unsigned(val_rs1 << shamt)
            elif funct3 == 2: wb_val = 1 if to_signed(val_rs1) < to_signed(val_rs2) else 0
            elif funct3 == 3: wb_val = 1 if val_rs1 < val_rs2 else 0
            elif funct3 == 4: wb_val = val_rs1 ^ val_rs2
            elif funct3 == 5:
                if funct7 & 0x20: wb_val = to_unsigned(to_signed(val_rs1) >> shamt)
                else:             wb_val = to_unsigned(val_rs1 >> shamt)
            elif funct3 == 6: wb_val = val_rs1 | val_rs2
            elif funct3 == 7: wb_val = val_rs1 & val_rs2
            if rd != 0: self.regs[rd] = wb_val

        self.regs[0] = 0 # Architectural Invariant
        if wb_val is not None and rd != 0:
            self.wb_history.append((pc_curr, rd, wb_val))
        return True

    def run(self, max_cycles=1000):
        for _ in range(max_cycles):
            if not self.step():
                break
        return self.regs

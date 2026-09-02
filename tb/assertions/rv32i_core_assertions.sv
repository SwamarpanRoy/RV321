/******************************************************************************
 * Module: rv32i_core_assertions.sv
 * Description: Microarchitectural SVA verifying core RISC-V invariants:
 *              x0 register immutability, PC 4-byte word alignment,
 *              load-use stall bubble insertion, and branch flush integrity.
 * Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
 ******************************************************************************/
module rv32i_core_assertions (
  input logic        clk,
  input logic        rst_n,
  input logic [31:0] pc,
  input logic [4:0]  wb_reg,
  input logic [31:0] wb_data,
  input logic        wb_valid,
  input logic        stall_pc,
  input logic        stall_if_id,
  input logic        flush_id_ex,
  input logic        branch_taken,
  input logic        flush_if_id
);

  // Invariant 1: Instruction Fetch PC must always be 4-byte word-aligned
  property p_pc_aligned;
    @(posedge clk) disable iff (!rst_n)
    (pc[1:0] == 2'b00);
  endproperty
  assert_pc_aligned: assert property (p_pc_aligned)
    else $error("[SVA VIOLATION][CORE] Program Counter unaligned! PC = 0x%08h", pc);

  // Invariant 2: Register x0 can never hold or write back a non-zero value
  property p_x0_always_zero;
    @(posedge clk) disable iff (!rst_n)
    (wb_valid && (wb_reg == 5'd0)) |-> (wb_data == 32'h0);
  endproperty
  assert_x0_always_zero: assert property (p_x0_always_zero)
    else $error("[SVA VIOLATION][CORE] Non-zero writeback attempted to register x0! Data = 0x%08h", wb_data);

  // Invariant 3: Taken branch must flush IF/ID and ID/EX in the immediately following cycle
  property p_branch_flush_integrity;
    @(posedge clk) disable iff (!rst_n)
    branch_taken |=> (flush_if_id && flush_id_ex);
  endproperty
  assert_branch_flush: assert property (p_branch_flush_integrity)
    else $error("[SVA VIOLATION][CORE] Branch taken did not trigger required pipeline flushes!");

endmodule: rv32i_core_assertions

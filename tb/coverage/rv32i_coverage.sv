/******************************************************************************
 * Module: rv32i_coverage.sv
 * Description: Comprehensive Functional Coverage model measuring instruction
 *              opcode space, ALU corner cases, branch outcomes, and hazard states.
 * Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
 ******************************************************************************/
import rv32i_pkg::*;

module rv32i_coverage (
  input logic        clk,
  input logic        rst_n,

  // Monitored Signals
  input logic [31:0] instruction,
  input logic [31:0] pc,
  input logic [31:0] alu_op_a,
  input logic [31:0] alu_op_b,
  input alu_op_e     alu_operation,
  input logic        branch_taken,
  input logic        is_branch,
  input fwd_sel_e    fwd_a,
  input fwd_sel_e    fwd_b,
  input logic        load_use_stall
);

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  assign opcode = instruction[6:0];
  assign funct3 = instruction[14:12];
  assign funct7 = instruction[31:25];

  // 1. Instruction Opcode & Type Coverage
  covergroup cg_instructions @(posedge clk);
    option.per_instance = 1;
    option.comment      = "RV32I Instruction Opcode Coverage";

    cp_opcode: coverpoint opcode {
      bins lui      = {OPCODE_LUI};
      bins auipc    = {OPCODE_AUIPC};
      bins jal      = {OPCODE_JAL};
      bins jalr     = {OPCODE_JALR};
      bins branch   = {OPCODE_BRANCH};
      bins load     = {OPCODE_LOAD};
      bins store    = {OPCODE_STORE};
      bins op_imm   = {OPCODE_OP_IMM};
      bins op_reg   = {OPCODE_OP};
    }

    cp_alu_ops: coverpoint alu_operation {
      bins add  = {ALU_ADD};
      bins sub  = {ALU_SUB};
      bins sll  = {ALU_SLL};
      bins slt  = {ALU_SLT};
      bins sltu = {ALU_SLTU};
      bins xor_ = {ALU_XOR};
      bins srl  = {ALU_SRL};
      bins sra  = {ALU_SRA};
      bins or_  = {ALU_OR};
      bins and_ = {ALU_AND};
    }
  endgroup

  // 2. Branch Outcome & Direction Coverage
  covergroup cg_branches @(posedge clk);
    option.per_instance = 1;
    option.comment      = "Branch Taken vs Not-Taken Coverage";

    cp_branch_type: coverpoint funct3 iff (is_branch) {
      bins beq  = {BR_BEQ};
      bins bne  = {BR_BNE};
      bins blt  = {BR_BLT};
      bins bge  = {BR_BGE};
      bins bltu = {BR_BLTU};
      bins bgeu = {BR_BGEU};
    }

    cp_taken: coverpoint branch_taken iff (is_branch) {
      bins not_taken = {1'b0};
      bins taken     = {1'b1};
    }

    // Cross branch type with outcome
    cx_branch_outcome: cross cp_branch_type, cp_taken;
  endgroup

  // 3. Pipeline Hazard & Forwarding Coverage
  covergroup cg_hazards @(posedge clk);
    option.per_instance = 1;
    option.comment      = "Data Hazards and Pipeline Forwarding Coverage";

    cp_fwd_a: coverpoint fwd_a {
      bins no_fwd     = {FWD_NONE};
      bins fwd_ex_mem = {FWD_EX_MEM};
      bins fwd_mem_wb = {FWD_MEM_WB};
    }

    cp_fwd_b: coverpoint fwd_b {
      bins no_fwd     = {FWD_NONE};
      bins fwd_ex_mem = {FWD_EX_MEM};
      bins fwd_mem_wb = {FWD_MEM_WB};
    }

    cp_load_use: coverpoint load_use_stall {
      bins normal = {1'b0};
      bins stall  = {1'b1};
    }

    cx_fwd: cross cp_fwd_a, cp_fwd_b;
  endgroup

  // Instantiate covergroups
  cg_instructions cov_inst  = new();
  cg_branches     cov_br    = new();
  cg_hazards      cov_hz    = new();

endmodule: rv32i_coverage

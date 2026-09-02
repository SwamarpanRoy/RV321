/******************************************************************************
 * Module: rv32i_hazard_unit.sv
 * Description: Pipeline hazard detection, data forwarding, and flush unit.
 *              Resolves RAW dependencies via EX-EX and MEM-EX forwarding,
 *              detects load-use dependencies by inserting 1-cycle bubbles,
 *              and flushes pipeline stages on branch/jump redirects.
 ******************************************************************************/
import rv32i_pkg::*;

module rv32i_hazard_unit (
  // Register addresses from pipeline stages
  input  logic [REG_ADDR_WIDTH-1:0] if_id_rs1,
  input  logic [REG_ADDR_WIDTH-1:0] if_id_rs2,
  input  logic [REG_ADDR_WIDTH-1:0] id_ex_rs1,
  input  logic [REG_ADDR_WIDTH-1:0] id_ex_rs2,
  input  logic [REG_ADDR_WIDTH-1:0] id_ex_rd,
  input  logic [REG_ADDR_WIDTH-1:0] ex_mem_rd,
  input  logic [REG_ADDR_WIDTH-1:0] mem_wb_rd,

  // Control signals from pipeline stages
  input  logic                      id_ex_mem_read,
  input  logic                      ex_mem_reg_write,
  input  logic                      mem_wb_reg_write,
  input  logic                      branch_taken_ex,
  input  logic                      jump_ex,
  input  logic                      bus_stall,

  // Forwarding outputs to Execute stage
  output fwd_sel_e                  fwd_a,
  output fwd_sel_e                  fwd_b,

  // Stall & Flush controls
  output logic                      stall_pc,
  output logic                      stall_if_id,
  output logic                      flush_if_id,
  output logic                      flush_id_ex,
  output logic                      stall_ex_mem,
  output logic                      stall_mem_wb
);

  logic load_use_hazard;
  logic branch_or_jump;

  assign branch_or_jump = branch_taken_ex | jump_ex;

  // 1. Data Forwarding Logic (EX/MEM and MEM/WB -> EX)
  always_comb begin
    // Default: No forwarding
    fwd_a = FWD_NONE;
    fwd_b = FWD_NONE;

    // Operand A Forwarding
    if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
      fwd_a = FWD_EX_MEM;
    end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
      fwd_a = FWD_MEM_WB;
    end

    // Operand B Forwarding
    if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) begin
      fwd_b = FWD_EX_MEM;
    end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) begin
      fwd_b = FWD_MEM_WB;
    end
  end

  // 2. Load-Use Hazard Detection
  // If instruction currently in EX is a LOAD and will write to rs1 or rs2 of instruction in ID
  always_comb begin
    if (id_ex_mem_read && (id_ex_rd != 5'd0) && 
        ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
      load_use_hazard = 1'b1;
    end else begin
      load_use_hazard = 1'b0;
    end
  end

  // 3. Pipeline Stall and Flush Generation
  always_comb begin
    // Bus stall freezes entire pipeline
    if (bus_stall) begin
      stall_pc     = 1'b1;
      stall_if_id  = 1'b1;
      flush_if_id  = 1'b0;
      flush_id_ex  = 1'b0;
      stall_ex_mem = 1'b1;
      stall_mem_wb = 1'b1;
    end else if (branch_or_jump) begin
      // Branch penalty: Flush IF/ID and ID/EX, resume PC at target
      stall_pc     = 1'b0;
      stall_if_id  = 1'b0;
      flush_if_id  = 1'b1;
      flush_id_ex  = 1'b1;
      stall_ex_mem = 1'b0;
      stall_mem_wb = 1'b0;
    end else if (load_use_hazard) begin
      // Load-use stall: Freeze PC and IF/ID, insert bubble (flush) into ID/EX
      stall_pc     = 1'b1;
      stall_if_id  = 1'b1;
      flush_if_id  = 1'b0;
      flush_id_ex  = 1'b1;
      stall_ex_mem = 1'b0;
      stall_mem_wb = 1'b0;
    end else begin
      // Normal continuous flow
      stall_pc     = 1'b0;
      stall_if_id  = 1'b0;
      flush_if_id  = 1'b0;
      flush_id_ex  = 1'b0;
      stall_ex_mem = 1'b0;
      stall_mem_wb = 1'b0;
    end
  end

endmodule: rv32i_hazard_unit

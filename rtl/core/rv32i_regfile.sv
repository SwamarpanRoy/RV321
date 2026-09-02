/******************************************************************************
 * Module: rv32i_regfile.sv
 * Description: 32x32-bit dual-read single-write register file.
 *              Guarantees the architectural invariant x0 == 0 at all times.
 ******************************************************************************/
import rv32i_pkg::*;

module rv32i_regfile (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  reg_write,
  input  logic [REG_ADDR_WIDTH-1:0] raddr1,
  input  logic [REG_ADDR_WIDTH-1:0] raddr2,
  input  logic [REG_ADDR_WIDTH-1:0] waddr,
  input  logic [XLEN-1:0]       wdata,
  output logic [XLEN-1:0]       rdata1,
  output logic [XLEN-1:0]       rdata2
);

  logic [XLEN-1:0] registers [1:31];

  // Synchronous write with x0 protection
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < 32; i++) begin
        registers[i] <= 32'h0000_0000;
      end
    end else if (reg_write && (waddr != 5'd0)) begin
      registers[waddr] <= wdata;
    end
  end

  // Asynchronous read (x0 always evaluates to 0)
  assign rdata1 = (raddr1 == 5'd0) ? 32'h0000_0000 : registers[raddr1];
  assign rdata2 = (raddr2 == 5'd0) ? 32'h0000_0000 : registers[raddr2];

endmodule: rv32i_regfile

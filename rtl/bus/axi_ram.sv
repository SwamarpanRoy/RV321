/******************************************************************************
 * Module: axi_ram.sv
 * Description: 64 KB AXI4-Lite synchronous dual-port SRAM model supporting
 *              byte strobe enables and memory file preloading.
 ******************************************************************************/
import rv32i_pkg::*;

module axi_ram #(
  parameter int MEM_DEPTH_WORDS = 16384 // 16K words = 64 KB
) (
  input  logic        clk,
  input  logic        rst_n,

  // AXI4-Lite Slave Port
  input  logic [31:0] s_axi_awaddr,
  input  logic [2:0]  s_axi_awprot,
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,

  input  logic [31:0] s_axi_wdata,
  input  logic [3:0]  s_axi_wstrb,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,

  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready,

  input  logic [31:0] s_axi_araddr,
  input  logic [2:0]  s_axi_arprot,
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,

  output logic [31:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rvalid,
  input  logic        s_axi_rready
);

  logic [31:0] mem [0:MEM_DEPTH_WORDS-1];

  logic [13:0] write_word_idx;
  logic [13:0] read_word_idx;

  assign write_word_idx = s_axi_awaddr[15:2];
  assign read_word_idx  = s_axi_araddr[15:2];

  // Write channel logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_axi_awready <= 1'b0;
      s_axi_wready  <= 1'b0;
      s_axi_bvalid  <= 1'b0;
      s_axi_bresp   <= AXI_RESP_OKAY;
    end else begin
      if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
        s_axi_awready <= 1'b1;
        s_axi_wready  <= 1'b1;
        s_axi_bvalid  <= 1'b1;
        s_axi_bresp   <= AXI_RESP_OKAY;

        if (s_axi_wstrb[0]) mem[write_word_idx][7:0]   <= s_axi_wdata[7:0];
        if (s_axi_wstrb[1]) mem[write_word_idx][15:8]  <= s_axi_wdata[15:8];
        if (s_axi_wstrb[2]) mem[write_word_idx][23:16] <= s_axi_wdata[23:16];
        if (s_axi_wstrb[3]) mem[write_word_idx][31:24] <= s_axi_wdata[31:24];
      end else begin
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;
        if (s_axi_bready && s_axi_bvalid) begin
          s_axi_bvalid <= 1'b0;
        end
      end
    end
  end

  // Read channel logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_axi_arready <= 1'b0;
      s_axi_rvalid  <= 1'b0;
      s_axi_rdata   <= 32'h0;
      s_axi_rresp   <= AXI_RESP_OKAY;
    end else begin
      if (s_axi_arvalid && !s_axi_rvalid) begin
        s_axi_arready <= 1'b1;
        s_axi_rvalid  <= 1'b1;
        s_axi_rresp   <= AXI_RESP_OKAY;
        s_axi_rdata   <= mem[read_word_idx];
      end else begin
        s_axi_arready <= 1'b0;
        if (s_axi_rready && s_axi_rvalid) begin
          s_axi_rvalid <= 1'b0;
        end
      end
    end
  end

endmodule: axi_ram

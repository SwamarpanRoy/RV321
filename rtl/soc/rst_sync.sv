/******************************************************************************
 * Module: rst_sync.sv
 * Description: Asynchronous Assert, Synchronous De-assert Reset Synchronizer.
 *              Standard digital design construct for safe clock-domain entry
 *              without reset glitching or metastability issues.
 ******************************************************************************/
module rst_sync (
  input  logic clk,
  input  logic async_rst_n,
  output logic sync_rst_n
);

  logic stage1_rst_n;

  always_ff @(posedge clk or negedge async_rst_n) begin
    if (!async_rst_n) begin
      stage1_rst_n <= 1'b0;
      sync_rst_n   <= 1'b0;
    end else begin
      stage1_rst_n <= 1'b1;
      sync_rst_n   <= stage1_rst_n;
    end
  end

endmodule: rst_sync

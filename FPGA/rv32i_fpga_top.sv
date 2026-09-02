/******************************************************************************
 * Module: rv32i_fpga_top.sv
 * Description: Synthesizable FPGA Board Top-Level Wrapper integrating the
 *              RV32I SoC with 100MHz clock input, debounced reset, GPIO switches,
 *              LEDs, 7-segment live PC monitor, and USB-UART serial interface.
 * Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
 * Target Device: AMD Artix-7 (XC7A35T-CPG236-1 / Basys3 / Nexys A7)
 ******************************************************************************/
import rv32i_pkg::*;

module rv32i_fpga_top (
  input  logic        clk_100mhz,
  input  logic        btn_rst,
  input  logic [15:0] sw,
  output logic [15:0] led,
  output logic [6:0]  seg,
  output logic [3:0]  an,
  input  logic        uart_rxd,
  output logic        uart_txd
);

  logic async_rst_n;
  assign async_rst_n = ~btn_rst;

  logic clk_50mhz;
  always_ff @(posedge clk_100mhz or negedge async_rst_n) begin
    if (!async_rst_n) begin
      clk_50mhz <= 1'b0;
    end else begin
      clk_50mhz <= ~clk_50mhz;
    end
  end

  logic [26:0] heartbeat_cnt;
  always_ff @(posedge clk_50mhz or negedge async_rst_n) begin
    if (!async_rst_n) begin
      heartbeat_cnt <= 27'd0;
    end else begin
      heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end
  end

  logic [31:0] gpio_in_soc;
  logic [31:0] gpio_out_soc;
  logic [31:0] gpio_dir_soc;
  logic [31:0] dbg_pc;
  logic [31:0] dbg_instr;
  logic [4:0]  dbg_wb_reg;
  logic [31:0] dbg_wb_data;
  logic        dbg_wb_valid;

  assign gpio_in_soc = {16'h0000, sw};
  assign led[14:0]   = gpio_out_soc[14:0];
  assign led[15]     = heartbeat_cnt[25];

  rv32i_soc_top u_soc (
    .clk          (clk_50mhz),
    .async_rst_n  (async_rst_n),
    .uart_rx      (uart_rxd),
    .uart_tx      (uart_txd),
    .gpio_in      (gpio_in_soc),
    .gpio_out     (gpio_out_soc),
    .gpio_dir     (gpio_dir_soc),
    .dbg_pc       (dbg_pc),
    .dbg_instr    (dbg_instr),
    .dbg_wb_reg   (dbg_wb_reg),
    .dbg_wb_data  (dbg_wb_data),
    .dbg_wb_valid (dbg_wb_valid)
  );

  seven_segment_driver u_seven_seg (
    .clk      (clk_50mhz),
    .rst_n    (async_rst_n),
    .hex_data (dbg_pc[15:0]),
    .seg      (seg),
    .an       (an)
  );

endmodule: rv32i_fpga_top

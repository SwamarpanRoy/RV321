/******************************************************************************
 * Module: apb_gpio.sv
 * Description: 32-bit Memory-mapped APB GPIO peripheral with programmable
 *              pin direction, input synchronization, and edge interrupt.
 ******************************************************************************/
import rv32i_pkg::*;

module apb_gpio (
  input  logic        clk,
  input  logic        rst_n,

  // APB Slave Interface
  input  logic [31:0] paddr,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [31:0] pwdata,
  output logic        pready,
  output logic [31:0] prdata,
  output logic        pslverr,

  // External Physical Pins
  input  logic [31:0] gpio_in,
  output logic [31:0] gpio_out,
  output logic [31:0] gpio_dir, // 0 = Input, 1 = Output
  output logic        gpio_irq
);

  logic [31:0] data_out_reg;
  logic [31:0] dir_reg;
  logic [31:0] int_en_reg;
  logic [31:0] int_stat_reg;

  // 2-stage input synchronizer for external async signals
  logic [31:0] gpio_in_sync1;
  logic [31:0] gpio_in_sync2;
  logic [31:0] gpio_in_prev;

  assign pready   = 1'b1;
  assign pslverr  = 1'b0;
  assign gpio_out = data_out_reg;
  assign gpio_dir = dir_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      gpio_in_sync1 <= 32'h0;
      gpio_in_sync2 <= 32'h0;
      gpio_in_prev  <= 32'h0;
    end else begin
      gpio_in_sync1 <= gpio_in;
      gpio_in_sync2 <= gpio_in_sync1;
      gpio_in_prev  <= gpio_in_sync2;
    end
  end

  // Register access
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out_reg <= 32'h0;
      dir_reg      <= 32'h0;
      int_en_reg   <= 32'h0;
      int_stat_reg <= 32'h0;
      prdata       <= 32'h0;
    end else begin
      // Edge detection for interrupts (rising edge on input pins)
      int_stat_reg <= int_stat_reg | ((gpio_in_sync2 & ~gpio_in_prev) & int_en_reg);

      if (psel && penable && pwrite) begin
        case (paddr[3:0])
          GPIO_REG_DATA:   data_out_reg <= pwdata;
          GPIO_REG_DIR:    dir_reg      <= pwdata;
          GPIO_REG_INT_EN: int_en_reg   <= pwdata;
          4'hC:            int_stat_reg <= int_stat_reg & ~pwdata; // W1C
        endcase
      end else if (psel && !pwrite) begin
        case (paddr[3:0])
          GPIO_REG_DATA:   prdata <= (gpio_in_sync2 & ~dir_reg) | (data_out_reg & dir_reg);
          GPIO_REG_DIR:    prdata <= dir_reg;
          GPIO_REG_INT_EN: prdata <= int_en_reg;
          4'hC:            prdata <= int_stat_reg;
          default:         prdata <= 32'h0;
        endcase
      end
    end
  end

  assign gpio_irq = |int_stat_reg;

endmodule: apb_gpio

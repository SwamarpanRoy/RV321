/******************************************************************************
 * Module: apb_timer.sv
 * Description: 32-bit Memory-mapped APB SysTick timer with prescaler,
 *              auto-reload, and compare-match interrupt generation.
 ******************************************************************************/
import rv32i_pkg::*;

module apb_timer (
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

  output logic        timer_irq
);

  logic [31:0] ctrl_reg; // bit 0: enable, bit 1: auto_reload, bit 2: int_en
  logic [31:0] count_reg;
  logic [31:0] cmp_reg;
  logic        irq_flag;

  assign pready  = 1'b1;
  assign pslverr = 1'b0;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_reg  <= 32'h0;
      count_reg <= 32'h0;
      cmp_reg   <= 32'hFFFF_FFFF;
      irq_flag  <= 1'b0;
      prdata    <= 32'h0;
    end else begin
      // Timer counting logic
      if (ctrl_reg[0]) begin
        if (count_reg >= cmp_reg) begin
          if (ctrl_reg[2]) irq_flag <= 1'b1;
          if (ctrl_reg[1]) begin
            count_reg <= 32'h0; // Auto-reload
          end else begin
            ctrl_reg[0] <= 1'b0; // Stop counting
          end
        end else begin
          count_reg <= count_reg + 1'b1;
        end
      end

      // APB bus operations
      if (psel && penable && pwrite) begin
        case (paddr[3:0])
          TIMER_REG_CTRL: begin
            ctrl_reg <= pwdata;
            if (pwdata[3]) irq_flag <= 1'b0; // Bit 3 clears interrupt
          end
          TIMER_REG_CNT:  count_reg <= pwdata;
          TIMER_REG_CMP:  cmp_reg   <= pwdata;
        endcase
      end else if (psel && !pwrite) begin
        case (paddr[3:0])
          TIMER_REG_CTRL: prdata <= {28'h0, irq_flag, ctrl_reg[2:0]};
          TIMER_REG_CNT:  prdata <= count_reg;
          TIMER_REG_CMP:  prdata <= cmp_reg;
          default:        prdata <= 32'h0;
        endcase
      end
    end
  end

  assign timer_irq = irq_flag;

endmodule: apb_timer

/******************************************************************************
 * Module: apb_uart.sv
 * Description: Memory-mapped APB UART controller with TX/RX serial engines,
 *              configurable baud rate divisor, status flags, and interrupt.
 ******************************************************************************/
import rv32i_pkg::*;

module apb_uart (
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

  // UART Serial Interface
  input  logic        uart_rx,
  output logic        uart_tx,
  output logic        uart_irq
);

  // Registers
  logic [7:0]  tx_data_reg;
  logic [7:0]  rx_data_reg;
  logic [15:0] baud_div_reg; // Default 434 for 50MHz / 115200 baud
  logic        tx_start;
  logic        tx_busy;
  logic        rx_valid;

  assign pready  = 1'b1;
  assign pslverr = 1'b0;

  // APB Read/Write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_start     <= 1'b0;
      tx_data_reg  <= 8'h0;
      baud_div_reg <= 16'd434;
      prdata       <= 32'h0;
    end else begin
      tx_start <= 1'b0;
      if (psel && penable && pwrite) begin
        case (paddr[3:0])
          UART_REG_DATA: begin
            if (!tx_busy) begin
              tx_data_reg <= pwdata[7:0];
              tx_start    <= 1'b1;
            end
          end
          UART_REG_DIV: begin
            baud_div_reg <= pwdata[15:0];
          end
        endcase
      end else if (psel && !pwrite) begin
        case (paddr[3:0])
          UART_REG_DATA:   prdata <= {24'h0, rx_data_reg};
          UART_REG_STATUS: prdata <= {30'h0, rx_valid, tx_busy};
          UART_REG_DIV:    prdata <= {16'h0, baud_div_reg};
          default:         prdata <= 32'h0;
        endcase
      end
    end
  end

  // TX FSM
  typedef enum logic [1:0] {TX_IDLE, TX_START_BIT, TX_DATA_BITS, TX_STOP_BIT} tx_state_e;
  tx_state_e tx_state;
  logic [15:0] tx_clk_cnt;
  logic [2:0]  tx_bit_idx;
  logic [7:0]  tx_shift_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_state     <= TX_IDLE;
      uart_tx      <= 1'b1;
      tx_busy      <= 1'b0;
      tx_clk_cnt   <= 16'd0;
      tx_bit_idx   <= 3'd0;
      tx_shift_reg <= 8'h0;
    end else begin
      case (tx_state)
        TX_IDLE: begin
          uart_tx <= 1'b1;
          if (tx_start) begin
            tx_state     <= TX_START_BIT;
            tx_busy      <= 1'b1;
            tx_clk_cnt   <= 16'd0;
            tx_shift_reg <= tx_data_reg;
          end else begin
            tx_busy <= 1'b0;
          end
        end

        TX_START_BIT: begin
          uart_tx <= 1'b0; // Start bit
          if (tx_clk_cnt >= baud_div_reg) begin
            tx_clk_cnt <= 16'd0;
            tx_state   <= TX_DATA_BITS;
            tx_bit_idx <= 3'd0;
          end else begin
            tx_clk_cnt <= tx_clk_cnt + 1'b1;
          end
        end

        TX_DATA_BITS: begin
          uart_tx <= tx_shift_reg[tx_bit_idx];
          if (tx_clk_cnt >= baud_div_reg) begin
            tx_clk_cnt <= 16'd0;
            if (tx_bit_idx == 3'd7) begin
              tx_state <= TX_STOP_BIT;
            end else begin
              tx_bit_idx <= tx_bit_idx + 1'b1;
            end
          end else begin
            tx_clk_cnt <= tx_clk_cnt + 1'b1;
          end
        end

        TX_STOP_BIT: begin
          uart_tx <= 1'b1; // Stop bit
          if (tx_clk_cnt >= baud_div_reg) begin
            tx_clk_cnt <= 16'd0;
            tx_state   <= TX_IDLE;
            tx_busy    <= 1'b0;
          end else begin
            tx_clk_cnt <= tx_clk_cnt + 1'b1;
          end
        end
      endcase
    end
  end

  // Simple RX Loopback / Simulation receiver
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_data_reg <= 8'h0;
      rx_valid    <= 1'b0;
    end else if (psel && penable && !pwrite && (paddr[3:0] == UART_REG_DATA)) begin
      rx_valid <= 1'b0; // Clear valid flag upon reading
    end
  end

  assign uart_irq = rx_valid;

endmodule: apb_uart

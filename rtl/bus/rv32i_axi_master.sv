/******************************************************************************
 * Module: rv32i_axi_master.sv
 * Description: AXI4-Lite Master Adapter translating core load/store memory
 *              requests into AMBA AXI4-Lite read/write handshake channels.
 ******************************************************************************/
import rv32i_pkg::*;

module rv32i_axi_master (
  input  logic        clk,
  input  logic        rst_n,

  // CPU Memory Interface
  input  logic [31:0] cpu_addr,
  input  logic [31:0] cpu_wdata,
  input  logic [3:0]  cpu_wstrb,
  input  logic        cpu_req,
  input  logic        cpu_we,
  output logic [31:0] cpu_rdata,
  output logic        cpu_ready,

  // AXI4-Lite Master Port
  output logic [31:0] m_axi_awaddr,
  output logic [2:0]  m_axi_awprot,
  output logic        m_axi_awvalid,
  input  logic        m_axi_awready,

  output logic [31:0] m_axi_wdata,
  output logic [3:0]  m_axi_wstrb,
  output logic        m_axi_wvalid,
  input  logic        m_axi_wready,

  input  logic [1:0]  m_axi_bresp,
  input  logic        m_axi_bvalid,
  output logic        m_axi_bready,

  output logic [31:0] m_axi_araddr,
  output logic [2:0]  m_axi_arprot,
  output logic        m_axi_arvalid,
  input  logic        m_axi_arready,

  input  logic [31:0] m_axi_rdata,
  input  logic [1:0]  m_axi_rresp,
  input  logic        m_axi_rvalid,
  output logic        m_axi_rready
);

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_READ_ADDR,
    ST_READ_DATA,
    ST_WRITE_ADDR_DATA,
    ST_WRITE_RESP
  } axi_fsm_e;

  axi_fsm_e state, next_state;

  logic aw_done, w_done;
  logic aw_done_next, w_done_next;

  assign m_axi_awprot = 3'b000;
  assign m_axi_arprot = 3'b000;
  assign m_axi_bready = 1'b1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= ST_IDLE;
      aw_done <= 1'b0;
      w_done  <= 1'b0;
    end else begin
      state   <= next_state;
      aw_done <= aw_done_next;
      w_done  <= w_done_next;
    end
  end

  always_comb begin
    next_state    = state;
    aw_done_next  = aw_done;
    w_done_next   = w_done;
    cpu_ready     = 1'b0;
    cpu_rdata     = 32'h0;

    m_axi_araddr  = cpu_addr;
    m_axi_arvalid = 1'b0;
    m_axi_rready  = 1'b0;

    m_axi_awaddr  = cpu_addr;
    m_axi_awvalid = 1'b0;
    m_axi_wdata   = cpu_wdata;
    m_axi_wstrb   = cpu_wstrb;
    m_axi_wvalid  = 1'b0;

    case (state)
      ST_IDLE: begin
        aw_done_next = 1'b0;
        w_done_next  = 1'b0;
        if (cpu_req) begin
          if (cpu_we) begin
            m_axi_awvalid = 1'b1;
            m_axi_wvalid  = 1'b1;
            if (m_axi_awready) aw_done_next = 1'b1;
            if (m_axi_wready)  w_done_next  = 1'b1;
            next_state    = ST_WRITE_ADDR_DATA;
          end else begin
            m_axi_arvalid = 1'b1;
            if (m_axi_arready) begin
              next_state = ST_READ_DATA;
            end else begin
              next_state = ST_READ_ADDR;
            end
          end
        end
      end

      ST_READ_ADDR: begin
        m_axi_arvalid = 1'b1;
        if (m_axi_arready) begin
          next_state = ST_READ_DATA;
        end
      end

      ST_READ_DATA: begin
        m_axi_rready = 1'b1;
        if (m_axi_rvalid) begin
          cpu_rdata  = m_axi_rdata;
          cpu_ready  = 1'b1;
          next_state = ST_IDLE;
        end
      end

      ST_WRITE_ADDR_DATA: begin
        m_axi_awvalid = !aw_done;
        m_axi_wvalid  = !w_done;

        if (m_axi_awready && !aw_done) aw_done_next = 1'b1;
        if (m_axi_wready  && !w_done)  w_done_next  = 1'b1;

        if ((aw_done || m_axi_awready) && (w_done || m_axi_wready)) begin
          next_state = ST_WRITE_RESP;
        end
      end

      ST_WRITE_RESP: begin
        if (m_axi_bvalid) begin
          cpu_ready  = 1'b1;
          next_state = ST_IDLE;
        end
      end

      default: next_state = ST_IDLE;
    endcase
  end

endmodule: rv32i_axi_master

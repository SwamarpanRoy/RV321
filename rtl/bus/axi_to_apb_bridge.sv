/******************************************************************************
 * Module: axi_to_apb_bridge.sv
 * Description: High-reliability AMBA AXI4-Lite to APB4 Bridge with FSM-based
 *              SETUP and ACCESS phases, error tracking, and response mapping.
 ******************************************************************************/
import rv32i_pkg::*;

module axi_to_apb_bridge (
  input  logic        clk,
  input  logic        rst_n,

  // AXI4-Lite Slave Interface
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
  input  logic        s_axi_rready,

  // APB4 Master Interface
  output logic [31:0] m_apb_paddr,
  output logic        m_apb_psel,
  output logic        m_apb_penable,
  output logic        m_apb_pwrite,
  output logic [31:0] m_apb_pwdata,
  output logic [3:0]  m_apb_pstrb,
  input  logic        m_apb_pready,
  input  logic [31:0] m_apb_prdata,
  input  logic        m_apb_pslverr
);

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_SETUP,
    ST_ACCESS,
    ST_RESP
  } bridge_fsm_e;

  bridge_fsm_e state;
  logic [31:0] addr_reg;
  logic [31:0] wdata_reg;
  logic [3:0]  wstrb_reg;
  logic        is_write;
  logic [31:0] rdata_reg;
  logic        slverr_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= ST_IDLE;
      addr_reg      <= 32'h0;
      wdata_reg     <= 32'h0;
      wstrb_reg     <= 4'h0;
      is_write      <= 1'b0;
      rdata_reg     <= 32'h0;
      slverr_reg    <= 1'b0;
      s_axi_awready <= 1'b0;
      s_axi_wready  <= 1'b0;
      s_axi_arready <= 1'b0;
      s_axi_bvalid  <= 1'b0;
      s_axi_rvalid  <= 1'b0;
      s_axi_bresp   <= 2'b00;
      s_axi_rresp   <= 2'b00;
      m_apb_psel    <= 1'b0;
      m_apb_penable <= 1'b0;
    end else begin
      case (state)
        ST_IDLE: begin
          s_axi_bvalid <= 1'b0;
          s_axi_rvalid <= 1'b0;
          if (s_axi_awvalid && s_axi_wvalid) begin
            // Write transaction detected
            addr_reg      <= s_axi_awaddr;
            wdata_reg     <= s_axi_wdata;
            wstrb_reg     <= s_axi_wstrb;
            is_write      <= 1'b1;
            s_axi_awready <= 1'b1;
            s_axi_wready  <= 1'b1;
            state         <= ST_SETUP;
          end else if (s_axi_arvalid) begin
            // Read transaction detected
            addr_reg      <= s_axi_araddr;
            is_write      <= 1'b0;
            s_axi_arready <= 1'b1;
            state         <= ST_SETUP;
          end
        end

        ST_SETUP: begin
          s_axi_awready <= 1'b0;
          s_axi_wready  <= 1'b0;
          s_axi_arready <= 1'b0;
          // APB SETUP phase: assert PSEL, keep PENABLE low
          m_apb_psel    <= 1'b1;
          m_apb_penable <= 1'b0;
          state         <= ST_ACCESS;
        end

        ST_ACCESS: begin
          // APB ACCESS phase: assert PENABLE, wait for PREADY
          m_apb_penable <= 1'b1;
          if (m_apb_pready) begin
            rdata_reg     <= m_apb_prdata;
            slverr_reg    <= m_apb_pslverr;
            m_apb_psel    <= 1'b0;
            m_apb_penable <= 1'b0;
            state         <= ST_RESP;
          end
        end

        ST_RESP: begin
          if (is_write) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= slverr_reg ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
            if (s_axi_bready) begin
              s_axi_bvalid <= 1'b0;
              state        <= ST_IDLE;
            end
          end else begin
            s_axi_rvalid <= 1'b1;
            s_axi_rdata  <= rdata_reg;
            s_axi_rresp  <= slverr_reg ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
            if (s_axi_rready) begin
              s_axi_rvalid <= 1'b0;
              state        <= ST_IDLE;
            end
          end
        end
      endcase
    end
  end

  assign m_apb_paddr  = addr_reg;
  assign m_apb_pwrite = is_write;
  assign m_apb_pwdata = wdata_reg;
  assign m_apb_pstrb  = wstrb_reg;

endmodule: axi_to_apb_bridge

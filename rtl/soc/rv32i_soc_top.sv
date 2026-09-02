/******************************************************************************
 * Module: rv32i_soc_top.sv
 * Description: Top-Level SoC integrating 5-Stage Pipelined RV32I Processor Core,
 *              AMBA AXI4-Lite Crossbar, 64KB Boot SRAM, AXI-to-APB Bridge,
 *              and memory-mapped APB Peripherals (UART, GPIO, SysTick Timer).
 * Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
 ******************************************************************************/
import rv32i_pkg::*;

module rv32i_soc_top (
  input  logic        clk,
  input  logic        async_rst_n,

  // External Peripheral I/O
  input  logic        uart_rx,
  output logic        uart_tx,
  input  logic [31:0] gpio_in,
  output logic [31:0] gpio_out,
  output logic [31:0] gpio_dir,

  // Core Debug & Verification Trace
  output logic [31:0] dbg_pc,
  output logic [31:0] dbg_instr,
  output logic [4:0]  dbg_wb_reg,
  output logic [31:0] dbg_wb_data,
  output logic        dbg_wb_valid
);

  // Synchronized reset
  logic sync_rst_n;
  rst_sync u_rst_sync (
    .clk         (clk),
    .async_rst_n (async_rst_n),
    .sync_rst_n  (sync_rst_n)
  );

  // Core instruction & data buses
  logic [31:0] imem_addr, imem_rdata;
  logic        imem_req, imem_ready;

  logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
  logic [3:0]  dmem_wstrb;
  logic        dmem_req, dmem_we, dmem_ready;

  // Pipelined Core Instance
  rv32i_core_pipelined u_core (
    .clk          (clk),
    .rst_n        (sync_rst_n),
    .imem_addr    (imem_addr),
    .imem_req     (imem_req),
    .imem_rdata   (imem_rdata),
    .imem_ready   (imem_ready),
    .dmem_addr    (dmem_addr),
    .dmem_wdata   (dmem_wdata),
    .dmem_wstrb   (dmem_wstrb),
    .dmem_req     (dmem_req),
    .dmem_we      (dmem_we),
    .dmem_rdata   (dmem_rdata),
    .dmem_ready   (dmem_ready),
    .dbg_pc       (dbg_pc),
    .dbg_instr    (dbg_instr),
    .dbg_wb_reg   (dbg_wb_reg),
    .dbg_wb_data  (dbg_wb_data),
    .dbg_wb_valid (dbg_wb_valid)
  );

  // Core AXI4-Lite Master Adapter
  logic [31:0] m_axi_awaddr, m_axi_wdata, m_axi_araddr, m_axi_rdata;
  logic [2:0]  m_axi_awprot, m_axi_arprot;
  logic [3:0]  m_axi_wstrb;
  logic [1:0]  m_axi_bresp, m_axi_rresp;
  logic        m_axi_awvalid, m_axi_awready;
  logic        m_axi_wvalid, m_axi_wready;
  logic        m_axi_bvalid, m_axi_bready;
  logic        m_axi_arvalid, m_axi_arready;
  logic        m_axi_rvalid, m_axi_rready;

  rv32i_axi_master u_axi_master (
    .clk           (clk),
    .rst_n         (sync_rst_n),
    .cpu_addr      (dmem_addr),
    .cpu_wdata     (dmem_wdata),
    .cpu_wstrb     (dmem_wstrb),
    .cpu_req       (dmem_req),
    .cpu_we        (dmem_we),
    .cpu_rdata     (dmem_rdata),
    .cpu_ready     (dmem_ready),
    .m_axi_awaddr  (m_axi_awaddr),
    .m_axi_awprot  (m_axi_awprot),
    .m_axi_awvalid (m_axi_awvalid),
    .m_axi_awready (m_axi_awready),
    .m_axi_wdata   (m_axi_wdata),
    .m_axi_wstrb   (m_axi_wstrb),
    .m_axi_wvalid  (m_axi_wvalid),
    .m_axi_wready  (m_axi_wready),
    .m_axi_bresp   (m_axi_bresp),
    .m_axi_bvalid  (m_axi_bvalid),
    .m_axi_bready  (m_axi_bready),
    .m_axi_araddr  (m_axi_araddr),
    .m_axi_arprot  (m_axi_arprot),
    .m_axi_arvalid (m_axi_arvalid),
    .m_axi_arready (m_axi_arready),
    .m_axi_rdata   (m_axi_rdata),
    .m_axi_rresp   (m_axi_rresp),
    .m_axi_rvalid  (m_axi_rvalid),
    .m_axi_rready  (m_axi_rready)
  );

  // Address Routing: RAM vs Peripheral APB Bridge
  logic sel_periph_write, sel_periph_read;
  assign sel_periph_write = (m_axi_awaddr >= PERIPH_BASE);
  assign sel_periph_read  = (m_axi_araddr >= PERIPH_BASE);

  // AXI Signals to RAM
  logic [31:0] ram_awaddr, ram_wdata, ram_araddr, ram_rdata;
  logic [3:0]  ram_wstrb;
  logic [1:0]  ram_bresp, ram_rresp;
  logic        ram_awvalid, ram_awready, ram_wvalid, ram_wready;
  logic        ram_bvalid, ram_bready, ram_arvalid, ram_arready, ram_rvalid, ram_rready;

  // AXI Signals to APB Bridge
  logic [31:0] brg_awaddr, brg_wdata, brg_araddr, brg_rdata;
  logic [3:0]  brg_wstrb;
  logic [1:0]  brg_bresp, brg_rresp;
  logic        brg_awvalid, brg_awready, brg_wvalid, brg_wready;
  logic        brg_bvalid, brg_bready, brg_arvalid, brg_arready, brg_rvalid, brg_rready;

  // Demux Master -> Slaves
  assign ram_awaddr  = m_axi_awaddr;
  assign ram_wdata   = m_axi_wdata;
  assign ram_wstrb   = m_axi_wstrb;
  assign ram_awvalid = m_axi_awvalid && !sel_periph_write;
  assign ram_wvalid  = m_axi_wvalid  && !sel_periph_write;
  assign ram_bready  = m_axi_bready;
  assign ram_araddr  = m_axi_araddr;
  assign ram_arvalid = m_axi_arvalid && !sel_periph_read;
  assign ram_rready  = m_axi_rready;

  assign brg_awaddr  = m_axi_awaddr;
  assign brg_wdata   = m_axi_wdata;
  assign brg_wstrb   = m_axi_wstrb;
  assign brg_awvalid = m_axi_awvalid && sel_periph_write;
  assign brg_wvalid  = m_axi_wvalid  && sel_periph_write;
  assign brg_bready  = m_axi_bready;
  assign brg_araddr  = m_axi_araddr;
  assign brg_arvalid = m_axi_arvalid && sel_periph_read;
  assign brg_rready  = m_axi_rready;

  // Mux Slaves -> Master
  always_comb begin
    if (sel_periph_write) begin
      m_axi_awready = brg_awready;
      m_axi_wready  = brg_wready;
      m_axi_bresp   = brg_bresp;
      m_axi_bvalid  = brg_bvalid;
    end else begin
      m_axi_awready = ram_awready;
      m_axi_wready  = ram_wready;
      m_axi_bresp   = ram_bresp;
      m_axi_bvalid  = ram_bvalid;
    end

    if (sel_periph_read) begin
      m_axi_arready = brg_arready;
      m_axi_rdata   = brg_rdata;
      m_axi_rresp   = brg_rresp;
      m_axi_rvalid  = brg_rvalid;
    end else begin
      m_axi_arready = ram_arready;
      m_axi_rdata   = ram_rdata;
      m_axi_rresp   = ram_rresp;
      m_axi_rvalid  = ram_rvalid;
    end
  end

  // Instruction SRAM / Dual Port Memory
  axi_ram u_axi_ram (
    .clk           (clk),
    .rst_n         (sync_rst_n),
    .s_axi_awaddr  (ram_awaddr),
    .s_axi_awprot  (3'b000),
    .s_axi_awvalid (ram_awvalid),
    .s_axi_awready (ram_awready),
    .s_axi_wdata   (ram_wdata),
    .s_axi_wstrb   (ram_wstrb),
    .s_axi_wvalid  (ram_wvalid),
    .s_axi_wready  (ram_wready),
    .s_axi_bresp   (ram_bresp),
    .s_axi_bvalid  (ram_bvalid),
    .s_axi_bready  (ram_bready),
    .s_axi_araddr  (ram_araddr),
    .s_axi_arprot  (3'b000),
    .s_axi_arvalid (ram_arvalid),
    .s_axi_arready (ram_arready),
    .s_axi_rdata   (ram_rdata),
    .s_axi_rresp   (ram_rresp),
    .s_axi_rvalid  (ram_rvalid),
    .s_axi_rready  (ram_rready)
  );

  // Fast Instruction Cache / ROM port directly from RAM memory array
  assign imem_rdata = u_axi_ram.mem[imem_addr[15:2]];
  assign imem_ready = 1'b1;

  // AXI to APB Bridge
  logic [31:0] apb_paddr, apb_pwdata, apb_prdata;
  logic [3:0]  apb_pstrb;
  logic        apb_psel, apb_penable, apb_pwrite, apb_pready, apb_pslverr;

  axi_to_apb_bridge u_bridge (
    .clk           (clk),
    .rst_n         (sync_rst_n),
    .s_axi_awaddr  (brg_awaddr),
    .s_axi_awprot  (3'b000),
    .s_axi_awvalid (brg_awvalid),
    .s_axi_awready (brg_awready),
    .s_axi_wdata   (brg_wdata),
    .s_axi_wstrb   (brg_wstrb),
    .s_axi_wvalid  (brg_wvalid),
    .s_axi_wready  (brg_wready),
    .s_axi_bresp   (brg_bresp),
    .s_axi_bvalid  (brg_bvalid),
    .s_axi_bready  (brg_bready),
    .s_axi_araddr  (brg_araddr),
    .s_axi_arprot  (3'b000),
    .s_axi_arvalid (brg_arvalid),
    .s_axi_arready (brg_arready),
    .s_axi_rdata   (brg_rdata),
    .s_axi_rresp   (brg_rresp),
    .s_axi_rvalid  (brg_rvalid),
    .s_axi_rready  (brg_rready),
    .m_apb_paddr   (apb_paddr),
    .m_apb_psel    (apb_psel),
    .m_apb_penable (apb_penable),
    .m_apb_pwrite  (apb_pwrite),
    .m_apb_pwdata  (apb_pwdata),
    .m_apb_pstrb   (apb_pstrb),
    .m_apb_pready  (apb_pready),
    .m_apb_prdata  (apb_prdata),
    .m_apb_pslverr (apb_pslverr)
  );

  // APB Address Decoding
  logic sel_uart, sel_gpio, sel_timer;
  assign sel_uart  = apb_psel && (apb_paddr[15:12] == 4'h0);
  assign sel_gpio  = apb_psel && (apb_paddr[15:12] == 4'h1);
  assign sel_timer = apb_psel && (apb_paddr[15:12] == 4'h2);

  logic [31:0] uart_prdata, gpio_prdata, timer_prdata;
  logic        uart_pready, gpio_pready, timer_pready;
  logic        uart_irq, gpio_irq, timer_irq;

  // Peripheral instances
  apb_uart u_uart (
    .clk      (clk),
    .rst_n    (sync_rst_n),
    .paddr    (apb_paddr),
    .psel     (sel_uart),
    .penable  (apb_penable),
    .pwrite   (apb_pwrite),
    .pwdata   (apb_pwdata),
    .pready   (uart_pready),
    .prdata   (uart_prdata),
    .pslverr  (),
    .uart_rx  (uart_rx),
    .uart_tx  (uart_tx),
    .uart_irq (uart_irq)
  );

  apb_gpio u_gpio (
    .clk      (clk),
    .rst_n    (sync_rst_n),
    .paddr    (apb_paddr),
    .psel     (sel_gpio),
    .penable  (apb_penable),
    .pwrite   (apb_pwrite),
    .pwdata   (apb_pwdata),
    .pready   (gpio_pready),
    .prdata   (gpio_prdata),
    .pslverr  (),
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out),
    .gpio_dir (gpio_dir),
    .gpio_irq (gpio_irq)
  );

  apb_timer u_timer (
    .clk       (clk),
    .rst_n     (sync_rst_n),
    .paddr     (apb_paddr),
    .psel      (sel_timer),
    .penable   (apb_penable),
    .pwrite    (apb_pwrite),
    .pwdata    (apb_pwdata),
    .pready    (timer_pready),
    .prdata    (timer_prdata),
    .pslverr   (),
    .timer_irq (timer_irq)
  );

  // APB Slave Mux
  always_comb begin
    apb_pslverr = 1'b0;
    if (sel_uart) begin
      apb_prdata = uart_prdata;
      apb_pready = uart_pready;
    end else if (sel_gpio) begin
      apb_prdata = gpio_prdata;
      apb_pready = gpio_pready;
    end else if (sel_timer) begin
      apb_prdata = timer_prdata;
      apb_pready = timer_pready;
    end else begin
      apb_prdata  = 32'hDEAD_BEEF;
      apb_pready  = 1'b1;
      apb_pslverr = 1'b1; // Decode error
    end
  end

endmodule: rv32i_soc_top

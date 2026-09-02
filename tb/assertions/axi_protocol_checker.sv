/******************************************************************************
 * Module: axi_protocol_checker.sv
 * Description: SystemVerilog Assertions (SVA) checking AMBA AXI4-Lite protocol
 *              handshake stability, non-X/Z integrity, and valid response codes.
 * Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
 ******************************************************************************/
module axi_protocol_checker (
  input logic clk,
  input logic rst_n,

  // Write Address Channel
  input logic [31:0] awaddr,
  input logic        awvalid,
  input logic        awready,

  // Write Data Channel
  input logic [31:0] wdata,
  input logic [3:0]  wstrb,
  input logic        wvalid,
  input logic        wready,

  // Write Response Channel
  input logic [1:0]  bresp,
  input logic        bvalid,
  input logic        bready,

  // Read Address Channel
  input logic [31:0] araddr,
  input logic        arvalid,
  input logic        arready,

  // Read Data Channel
  input logic [31:0] rdata,
  input logic [1:0]  rresp,
  input logic        rvalid,
  input logic        rready
);

  // Property 1: AWVALID stability - Once asserted, AWADDR must remain stable until AWREADY
  property p_awaddr_stable;
    @(posedge clk) disable iff (!rst_n)
    (awvalid && !awready) |=> ($stable(awaddr) && awvalid);
  endproperty
  assert_awaddr_stable: assert property (p_awaddr_stable)
    else $error("[SVA VIOLATION][AXI] AWADDR changed while AWVALID was high and AWREADY low!");

  // Property 2: WVALID stability - Once asserted, WDATA must remain stable until WREADY
  property p_wdata_stable;
    @(posedge clk) disable iff (!rst_n)
    (wvalid && !wready) |=> ($stable(wdata) && $stable(wstrb) && wvalid);
  endproperty
  assert_wdata_stable: assert property (p_wdata_stable)
    else $error("[SVA VIOLATION][AXI] WDATA/WSTRB changed while WVALID was high and WREADY low!");

  // Property 3: ARVALID stability - Once asserted, ARADDR must remain stable until ARREADY
  property p_araddr_stable;
    @(posedge clk) disable iff (!rst_n)
    (arvalid && !arready) |=> ($stable(araddr) && arvalid);
  endproperty
  assert_araddr_stable: assert property (p_araddr_stable)
    else $error("[SVA VIOLATION][AXI] ARADDR changed while ARVALID was high and ARREADY low!");

  // Property 4: No unknown (X/Z) states on active handshakes
  property p_no_x_on_awvalid;
    @(posedge clk) disable iff (!rst_n)
    !$isunknown(awvalid);
  endproperty
  assert_no_x_awvalid: assert property (p_no_x_on_awvalid)
    else $error("[SVA VIOLATION][AXI] AWVALID is in unknown (X/Z) state!");

  property p_no_x_on_wvalid;
    @(posedge clk) disable iff (!rst_n)
    !$isunknown(wvalid);
  endproperty
  assert_no_x_wvalid: assert property (p_no_x_on_wvalid)
    else $error("[SVA VIOLATION][AXI] WVALID is in unknown (X/Z) state!");

  property p_no_x_on_arvalid;
    @(posedge clk) disable iff (!rst_n)
    !$isunknown(arvalid);
  endproperty
  assert_no_x_arvalid: assert property (p_no_x_on_arvalid)
    else $error("[SVA VIOLATION][AXI] ARVALID is in unknown (X/Z) state!");

  // Property 5: Write response validity
  property p_valid_bresp;
    @(posedge clk) disable iff (!rst_n)
    bvalid |-> (bresp != 2'b11); // DECERR or invalid
  endproperty
  assert_valid_bresp: assert property (p_valid_bresp)
    else $error("[SVA VIOLATION][AXI] Illegal BRESP value detected!");

endmodule: axi_protocol_checker

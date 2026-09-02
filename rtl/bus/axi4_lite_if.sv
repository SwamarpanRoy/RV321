/******************************************************************************
 * Interface: axi4_lite_if.sv
 * Description: AMBA AXI4-Lite SystemVerilog Interface with standard channels:
 *              AW (Write Addr), W (Write Data), B (Write Resp),
 *              AR (Read Addr), R (Read Data), and Modports.
 ******************************************************************************/
interface axi4_lite_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input logic clk,
  input logic rst_n
);

  // Write Address Channel
  logic [ADDR_WIDTH-1:0] awaddr;
  logic [2:0]            awprot;
  logic                  awvalid;
  logic                  awready;

  // Write Data Channel
  logic [DATA_WIDTH-1:0] wdata;
  logic [(DATA_WIDTH/8)-1:0] wstrb;
  logic                  wvalid;
  logic                  wready;

  // Write Response Channel
  logic [1:0]            bresp;
  logic                  bvalid;
  logic                  bready;

  // Read Address Channel
  logic [ADDR_WIDTH-1:0] araddr;
  logic [2:0]            arprot;
  logic                  arvalid;
  logic                  arready;

  // Read Data Channel
  logic [DATA_WIDTH-1:0] rdata;
  logic [1:0]            rresp;
  logic                  rvalid;
  logic                  rready;

  // Modports
  modport master (
    input  clk, rst_n,
    output awaddr, awprot, awvalid,
    input  awready,
    output wdata, wstrb, wvalid,
    input  wready,
    input  bresp, bvalid,
    output bready,
    output araddr, arprot, arvalid,
    input  arready,
    input  rdata, rresp, rvalid,
    output rready
  );

  modport slave (
    input  clk, rst_n,
    input  awaddr, awprot, awvalid,
    output awready,
    input  wdata, wstrb, wvalid,
    output wready,
    output bresp, bvalid,
    input  bready,
    input  araddr, arprot, arvalid,
    output arready,
    output rdata, rresp, rvalid,
    input  rready
  );

  modport monitor (
    input clk, rst_n,
    input awaddr, awprot, awvalid, awready,
    input wdata, wstrb, wvalid, wready,
    input bresp, bvalid, bready,
    input araddr, arprot, arvalid, arready,
    input rdata, rresp, rvalid, rready
  );

endinterface: axi4_lite_if

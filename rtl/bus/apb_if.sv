/******************************************************************************
 * Interface: apb_if.sv
 * Description: AMBA APB4 SystemVerilog Interface with standard signals:
 *              PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB, PREADY, PRDATA, PSLVERR.
 ******************************************************************************/
interface apb_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input logic clk,
  input logic rst_n
);

  logic [ADDR_WIDTH-1:0]     paddr;
  logic                      psel;
  logic                      penable;
  logic                      pwrite;
  logic [DATA_WIDTH-1:0]     pwdata;
  logic [(DATA_WIDTH/8)-1:0] pstrb;
  logic                      pready;
  logic [DATA_WIDTH-1:0]     prdata;
  logic                      pslverr;

  modport master (
    input  clk, rst_n,
    output paddr, psel, penable, pwrite, pwdata, pstrb,
    input  pready, prdata, pslverr
  );

  modport slave (
    input  clk, rst_n,
    input  paddr, psel, penable, pwrite, pwdata, pstrb,
    output pready, prdata, pslverr
  );

  modport monitor (
    input clk, rst_n,
    input paddr, psel, penable, pwrite, pwdata, pstrb,
    input pready, prdata, pslverr
  );

endinterface: apb_if

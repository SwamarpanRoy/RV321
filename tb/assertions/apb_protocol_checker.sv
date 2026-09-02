/******************************************************************************
 * Module: apb_protocol_checker.sv
 * Description: SystemVerilog Assertions (SVA) verifying AMBA APB4 protocol rules:
 *              SETUP phase -> ACCESS phase transitions, signal stability,
 *              and PENABLE timing requirements.
 ******************************************************************************/
module apb_protocol_checker (
  input logic        clk,
  input logic        rst_n,
  input logic [31:0] paddr,
  input logic        psel,
  input logic        penable,
  input logic        pwrite,
  input logic [31:0] pwdata,
  input logic        pready
);

  // Property 1: PENABLE must be asserted exactly 1 cycle after PSEL rises
  property p_apb_setup_to_access;
    @(posedge clk) disable iff (!rst_n)
    ($rose(psel) && !penable) |=> (psel && penable);
  endproperty
  assert_apb_setup_to_access: assert property (p_apb_setup_to_access)
    else $error("[SVA VIOLATION][APB] PENABLE was not asserted 1 cycle after PSEL!");

  // Property 2: PADDR must remain stable during SETUP and ACCESS phases
  property p_apb_addr_stable;
    @(posedge clk) disable iff (!rst_n)
    (psel && !pready) |=> $stable(paddr);
  endproperty
  assert_apb_addr_stable: assert property (p_apb_addr_stable)
    else $error("[SVA VIOLATION][APB] PADDR changed before PREADY transaction completion!");

  // Property 3: PWDATA must remain stable during write transactions
  property p_apb_wdata_stable;
    @(posedge clk) disable iff (!rst_n)
    (psel && pwrite && !pready) |=> $stable(pwdata);
  endproperty
  assert_apb_wdata_stable: assert property (p_apb_wdata_stable)
    else $error("[SVA VIOLATION][APB] PWDATA changed during active write before PREADY!");

endmodule: apb_protocol_checker

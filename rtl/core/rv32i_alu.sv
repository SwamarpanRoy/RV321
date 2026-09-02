/******************************************************************************
 * Module: rv32i_alu.sv
 * Description: 32-bit Arithmetic Logic Unit supporting all RV32I ALU ops
 *              with arithmetic sign-preserving shift and zero flag generation.
 ******************************************************************************/
import rv32i_pkg::*;

module rv32i_alu (
  input  logic [31:0]      a,
  input  logic [31:0]      b,
  input  alu_op_e          alu_op,
  output logic [31:0]      result,
  output logic             zero_flag
);

  logic [31:0] sub_res;
  logic [31:0] add_res;
  logic        slt_res;
  logic        sltu_res;

  assign add_res  = a + b;
  assign sub_res  = a - b;
  assign slt_res  = ($signed(a) < $signed(b)) ? 1'b1 : 1'b0;
  assign sltu_res = (a < b) ? 1'b1 : 1'b0;

  always_comb begin
    case (alu_op)
      ALU_ADD:    result = add_res;
      ALU_SUB:    result = sub_res;
      ALU_SLL:    result = a << b[4:0];
      ALU_SLT:    result = {31'b0, slt_res};
      ALU_SLTU:   result = {31'b0, sltu_res};
      ALU_XOR:    result = a ^ b;
      ALU_SRL:    result = a >> b[4:0];
      ALU_SRA:    result = $signed(a) >>> b[4:0];
      ALU_OR:     result = a | b;
      ALU_AND:    result = a & b;
      ALU_PASS_B: result = b;
      default:    result = 32'h0000_0000;
    endcase
  end

  assign zero_flag = (result == 32'h0000_0000);

endmodule: rv32i_alu

/******************************************************************************
 * Module: rv32i_imm_gen.sv
 * Description: Immediate generator and sign extender for RV32I formats:
 *              I-type, S-type, B-type, U-type, and J-type.
 ******************************************************************************/
import rv32i_pkg::*;

module rv32i_imm_gen (
  input  logic [31:0]  instruction,
  input  imm_format_e  imm_format,
  output logic [31:0]  immediate
);

  always_comb begin
    case (imm_format)
      // I-type: [31:20] -> [11:0] sign extended
      IMM_I: immediate = {{20{instruction[31]}}, instruction[31:20]};

      // S-type: [31:25], [11:7] -> [11:0] sign extended
      IMM_S: immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

      // B-type: [31], [7], [30:25], [11:8], 1'b0 -> [12:0] sign extended
      IMM_B: immediate = {{19{instruction[31]}}, instruction[31], instruction[7], 
                          instruction[30:25], instruction[11:8], 1'b0};

      // U-type: [31:12] -> [31:12], lower 12 bits zero
      IMM_U: immediate = {instruction[31:12], 12'h000};

      // J-type: [31], [19:12], [20], [30:21], 1'b0 -> [20:0] sign extended
      IMM_J: immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12], 
                          instruction[20], instruction[30:21], 1'b0};

      default: immediate = 32'h0000_0000;
    endcase
  end

endmodule: rv32i_imm_gen

/******************************************************************************
 * Module: rv32i_lsu.sv
 * Description: Load/Store unit handling byte, half-word, and word memory
 *              accesses, unaligned address detection, and byte write strobes.
 ******************************************************************************/
import rv32i_pkg::*;

module rv32i_lsu (
  input  logic [31:0]  raw_mem_data,
  input  logic [31:0]  store_reg_data,
  input  logic [31:0]  addr,
  input  lsu_op_e      lsu_op,
  output logic [31:0]  load_data,
  output logic [31:0]  mem_write_data,
  output logic [3:0]   byte_strobe,
  output logic         unaligned_fault
);

  logic [1:0] byte_offset;
  assign byte_offset = addr[1:0];

  // Load alignment and sign/zero extension
  always_comb begin
    unaligned_fault = 1'b0;
    load_data       = 32'h0000_0000;

    case (lsu_op)
      LSU_BYTE: begin // LB (sign-extended byte)
        case (byte_offset)
          2'b00: load_data = {{24{raw_mem_data[7]}},  raw_mem_data[7:0]};
          2'b01: load_data = {{24{raw_mem_data[15]}}, raw_mem_data[15:8]};
          2'b10: load_data = {{24{raw_mem_data[23]}}, raw_mem_data[23:16]};
          2'b11: load_data = {{24{raw_mem_data[31]}}, raw_mem_data[31:24]};
        endcase
      end

      LSU_BYTE_U: begin // LBU (zero-extended byte)
        case (byte_offset)
          2'b00: load_data = {24'h0, raw_mem_data[7:0]};
          2'b01: load_data = {24'h0, raw_mem_data[15:8]};
          2'b10: load_data = {24'h0, raw_mem_data[23:16]};
          2'b11: load_data = {24'h0, raw_mem_data[31:24]};
        endcase
      end

      LSU_HALF: begin // LH (sign-extended halfword)
        if (byte_offset[0] != 1'b0) begin
          unaligned_fault = 1'b1;
        end
        case (byte_offset[1])
          1'b0: load_data = {{16{raw_mem_data[15]}}, raw_mem_data[15:0]};
          1'b1: load_data = {{16{raw_mem_data[31]}}, raw_mem_data[31:16]};
        endcase
      end

      LSU_HALF_U: begin // LHU (zero-extended halfword)
        if (byte_offset[0] != 1'b0) begin
          unaligned_fault = 1'b1;
        end
        case (byte_offset[1])
          1'b0: load_data = {16'h0, raw_mem_data[15:0]};
          1'b1: load_data = {16'h0, raw_mem_data[31:16]};
        endcase
      end

      LSU_WORD: begin // LW (32-bit word)
        if (byte_offset != 2'b00) begin
          unaligned_fault = 1'b1;
        end
        load_data = raw_mem_data;
      end

      default: load_data = raw_mem_data;
    endcase
  end

  // Store byte alignment and byte strobe generation
  always_comb begin
    byte_strobe    = 4'b0000;
    mem_write_data = 32'h0000_0000;

    case (lsu_op)
      LSU_BYTE, LSU_BYTE_U: begin
        case (byte_offset)
          2'b00: begin byte_strobe = 4'b0001; mem_write_data = {24'h0, store_reg_data[7:0]}; end
          2'b01: begin byte_strobe = 4'b0010; mem_write_data = {16'h0, store_reg_data[7:0], 8'h0}; end
          2'b10: begin byte_strobe = 4'b0100; mem_write_data = {8'h0,  store_reg_data[7:0], 16'h0}; end
          2'b11: begin byte_strobe = 4'b1000; mem_write_data = {store_reg_data[7:0], 24'h0}; end
        endcase
      end

      LSU_HALF, LSU_HALF_U: begin
        case (byte_offset[1])
          1'b0: begin byte_strobe = 4'b0011; mem_write_data = {16'h0, store_reg_data[15:0]}; end
          1'b1: begin byte_strobe = 4'b1100; mem_write_data = {store_reg_data[15:0], 16'h0}; end
        endcase
      end

      LSU_WORD: begin
        byte_strobe    = 4'b1111;
        mem_write_data = store_reg_data;
      end

      default: begin
        byte_strobe    = 4'b1111;
        mem_write_data = store_reg_data;
      end
    endcase
  end

endmodule: rv32i_lsu

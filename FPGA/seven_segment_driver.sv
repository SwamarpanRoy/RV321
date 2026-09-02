/******************************************************************************
 * Module: seven_segment_driver.sv
 * Description: Time-multiplexed 4-digit 7-segment display driver with hex
 *              decoding for live hardware FPGA board debugging of PC / registers.
 * Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
 ******************************************************************************/
module seven_segment_driver (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [15:0] hex_data,
  output logic [6:0]  seg,
  output logic [3:0]  an
);

  logic [16:0] refresh_cnt;
  logic [1:0]  active_digit;
  logic [3:0]  digit_val;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      refresh_cnt <= 17'd0;
    end else begin
      refresh_cnt <= refresh_cnt + 1'b1;
    end
  end

  assign active_digit = refresh_cnt[16:15];

  always_comb begin
    case (active_digit)
      2'b00: begin an = 4'b1110; digit_val = hex_data[3:0];   end
      2'b01: begin an = 4'b1101; digit_val = hex_data[7:4];   end
      2'b10: begin an = 4'b1011; digit_val = hex_data[11:8];  end
      2'b11: begin an = 4'b0111; digit_val = hex_data[15:12]; end
    endcase
  end

  always_comb begin
    case (digit_val)
      4'h0: seg = 7'b1000000;
      4'h1: seg = 7'b1111001;
      4'h2: seg = 7'b0100100;
      4'h3: seg = 7'b0110000;
      4'h4: seg = 7'b0011001;
      4'h5: seg = 7'b0010010;
      4'h6: seg = 7'b0000010;
      4'h7: seg = 7'b1111000;
      4'h8: seg = 7'b0000000;
      4'h9: seg = 7'b0010000;
      4'hA: seg = 7'b0001000;
      4'hB: seg = 7'b0000011;
      4'hC: seg = 7'b1000110;
      4'hD: seg = 7'b0100001;
      4'hE: seg = 7'b0000110;
      4'hF: seg = 7'b0001110;
      default: seg = 7'b1111111;
    endcase
  end
endmodule: seven_segment_driver

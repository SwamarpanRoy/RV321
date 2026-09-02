/******************************************************************************
 * Module: rv32i_core_pipelined.sv
 * Description: 5-Stage Pipelined RV32I Processor Core (IF, ID, EX, MEM, WB).
 *              Integrates Hazard Unit with EX-EX and MEM-EX forwarding,
 *              load-use stalling, and branch misprediction flushing.
 * Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
 ******************************************************************************/
import rv32i_pkg::*;

module rv32i_core_pipelined (
  input  logic        clk,
  input  logic        rst_n,

  // Instruction Fetch Interface
  output logic [31:0] imem_addr,
  output logic        imem_req,
  input  logic [31:0] imem_rdata,
  input  logic        imem_ready,

  // Data Memory Interface
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_wstrb,
  output logic        dmem_req,
  output logic        dmem_we,
  input  logic [31:0] dmem_rdata,
  input  logic        dmem_ready,

  // Debug / Verification Trace
  output logic [31:0] dbg_pc,
  output logic [31:0] dbg_instr,
  output logic [4:0]  dbg_wb_reg,
  output logic [31:0] dbg_wb_data,
  output logic        dbg_wb_valid
);

  //===========================================================================
  // Internal Signals & Pipeline Registers
  //===========================================================================

  // Hazard control signals
  fwd_sel_e fwd_a, fwd_b;
  logic stall_pc, stall_if_id, flush_if_id, flush_id_ex;
  logic stall_ex_mem, stall_mem_wb;
  logic bus_stall;

  // IF Stage
  logic [31:0] pc_reg, pc_next, pc_plus4_if;
  logic [31:0] branch_target_ex;
  logic        branch_taken_ex;
  logic        jump_ex;

  // IF/ID Pipeline Registers
  logic [31:0] if_id_pc, if_id_pc_plus4, if_id_instr;

  // ID Stage
  logic [6:0]  id_opcode;
  logic [2:0]  id_funct3;
  logic [6:0]  id_funct7;
  logic [4:0]  id_rs1, id_rs2, id_rd;
  logic [31:0] id_rf_rdata1, id_rf_rdata2;
  logic [31:0] id_imm;
  imm_format_e id_imm_format;
  alu_op_e     id_alu_op;
  lsu_op_e     id_lsu_op;
  logic        id_reg_write, id_mem_read, id_mem_write;
  logic        id_alu_src_b_imm, id_branch, id_jal, id_jalr;

  // ID/EX Pipeline Registers
  logic [31:0] id_ex_pc, id_ex_pc_plus4;
  logic [31:0] id_ex_rdata1, id_ex_rdata2, id_ex_imm;
  logic [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;
  alu_op_e     id_ex_alu_op;
  lsu_op_e     id_ex_lsu_op;
  logic [2:0]  id_ex_funct3;
  logic        id_ex_reg_write, id_ex_mem_read, id_ex_mem_write;
  logic        id_ex_alu_src_b_imm, id_ex_branch, id_ex_jal, id_ex_jalr;
  logic [31:0] id_ex_instr;

  // EX Stage
  logic [31:0] ex_op_a, ex_op_b, ex_alu_in_b;
  logic [31:0] ex_alu_result;
  logic        ex_alu_zero;
  logic [31:0] ex_forwarded_b;

  // EX/MEM Pipeline Registers
  logic [31:0] ex_mem_alu_result, ex_mem_write_data;
  logic [31:0] ex_mem_pc_plus4;
  logic [4:0]  ex_mem_rd;
  lsu_op_e     ex_mem_lsu_op;
  logic        ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write;
  logic        ex_mem_jal_or_jalr;
  logic [31:0] ex_mem_instr;

  // MEM Stage
  logic [31:0] mem_lsu_load_data, mem_lsu_write_data;
  logic [3:0]  mem_lsu_byte_strobe;
  logic        mem_unaligned_fault;

  // MEM/WB Pipeline Registers
  logic [31:0] mem_wb_alu_result, mem_wb_load_data, mem_wb_pc_plus4;
  logic [4:0]  mem_wb_rd;
  logic        mem_wb_reg_write, mem_wb_mem_to_reg, mem_wb_jal_or_jalr;
  logic [31:0] mem_wb_instr;

  // WB Stage
  logic [31:0] wb_final_data;

  // Bus stall when memory request is active but memory is not ready
  assign bus_stall = (dmem_req && !dmem_ready) || (imem_req && !imem_ready);

  //===========================================================================
  // 1. IF Stage (Instruction Fetch)
  //===========================================================================
  assign pc_plus4_if = pc_reg + 32'd4;

  always_comb begin
    if (branch_taken_ex || jump_ex) begin
      pc_next = branch_target_ex;
    end else begin
      pc_next = pc_plus4_if;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_reg <= 32'h0000_0000;
    end else if (!stall_pc) begin
      pc_reg <= pc_next;
    end
  end

  assign imem_addr = pc_reg;
  assign imem_req  = 1'b1;

  // IF/ID Pipeline Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      if_id_pc       <= 32'h0;
      if_id_pc_plus4 <= 32'h0;
      if_id_instr    <= 32'h0000_0013; // NOP (addi x0, x0, 0)
    end else if (flush_if_id) begin
      if_id_pc       <= 32'h0;
      if_id_pc_plus4 <= 32'h0;
      if_id_instr    <= 32'h0000_0013; // NOP bubble
    end else if (!stall_if_id) begin
      if_id_pc       <= pc_reg;
      if_id_pc_plus4 <= pc_plus4_if;
      if_id_instr    <= imem_rdata;
    end
  end

  //===========================================================================
  // 2. ID Stage (Instruction Decode & Register Fetch)
  //===========================================================================
  assign id_opcode = if_id_instr[6:0];
  assign id_rd     = if_id_instr[11:7];
  assign id_funct3 = if_id_instr[14:12];
  assign id_rs1    = if_id_instr[19:15];
  assign id_rs2    = if_id_instr[24:20];
  assign id_funct7 = if_id_instr[31:25];

  // Control Decoder
  always_comb begin
    id_reg_write        = 1'b0;
    id_mem_read         = 1'b0;
    id_mem_write        = 1'b0;
    id_alu_src_b_imm    = 1'b0;
    id_branch           = 1'b0;
    id_jal              = 1'b0;
    id_jalr             = 1'b0;
    id_imm_format       = IMM_I;
    id_alu_op           = ALU_ADD;
    id_lsu_op           = LSU_WORD;

    case (id_opcode)
      OPCODE_OP: begin // R-type
        id_reg_write     = 1'b1;
        id_alu_src_b_imm = 1'b0;
        case (id_funct3)
          3'b000: id_alu_op = (id_funct7[5]) ? ALU_SUB : ALU_ADD;
          3'b001: id_alu_op = ALU_SLL;
          3'b010: id_alu_op = ALU_SLT;
          3'b011: id_alu_op = ALU_SLTU;
          3'b100: id_alu_op = ALU_XOR;
          3'b101: id_alu_op = (id_funct7[5]) ? ALU_SRA : ALU_SRL;
          3'b110: id_alu_op = ALU_OR;
          3'b111: id_alu_op = ALU_AND;
        endcase
      end

      OPCODE_OP_IMM: begin // I-type ALU
        id_reg_write     = 1'b1;
        id_alu_src_b_imm = 1'b1;
        id_imm_format    = IMM_I;
        case (id_funct3)
          3'b000: id_alu_op = ALU_ADD;
          3'b001: id_alu_op = ALU_SLL;
          3'b010: id_alu_op = ALU_SLT;
          3'b011: id_alu_op = ALU_SLTU;
          3'b100: id_alu_op = ALU_XOR;
          3'b101: id_alu_op = (id_funct7[5]) ? ALU_SRA : ALU_SRL;
          3'b110: id_alu_op = ALU_OR;
          3'b111: id_alu_op = ALU_AND;
        endcase
      end

      OPCODE_LOAD: begin // Load
        id_reg_write     = 1'b1;
        id_mem_read      = 1'b1;
        id_alu_src_b_imm = 1'b1;
        id_imm_format    = IMM_I;
        id_alu_op        = ALU_ADD;
        id_lsu_op        = lsu_op_e'(id_funct3);
      end

      OPCODE_STORE: begin // Store
        id_mem_write     = 1'b1;
        id_alu_src_b_imm = 1'b1;
        id_imm_format    = IMM_S;
        id_alu_op        = ALU_ADD;
        id_lsu_op        = lsu_op_e'(id_funct3);
      end

      OPCODE_BRANCH: begin // Branch
        id_branch        = 1'b1;
        id_imm_format    = IMM_B;
        id_alu_op        = ALU_SUB;
      end

      OPCODE_LUI: begin // LUI
        id_reg_write     = 1'b1;
        id_alu_src_b_imm = 1'b1;
        id_imm_format    = IMM_U;
        id_alu_op        = ALU_PASS_B;
      end

      OPCODE_AUIPC: begin // AUIPC
        id_reg_write     = 1'b1;
        id_alu_src_b_imm = 1'b1;
        id_imm_format    = IMM_U;
        id_alu_op        = ALU_ADD;
      end

      OPCODE_JAL: begin // JAL
        id_reg_write     = 1'b1;
        id_jal           = 1'b1;
        id_imm_format    = IMM_J;
      end

      OPCODE_JALR: begin // JALR
        id_reg_write     = 1'b1;
        id_jalr          = 1'b1;
        id_imm_format    = IMM_I;
        id_alu_op        = ALU_ADD;
      end

      default: begin
        // Default safe NOP behavior
      end
    endcase
  end

  // Register File
  rv32i_regfile u_regfile (
    .clk       (clk),
    .rst_n     (rst_n),
    .reg_write (mem_wb_reg_write),
    .raddr1    (id_rs1),
    .raddr2    (id_rs2),
    .waddr     (mem_wb_rd),
    .wdata     (wb_final_data),
    .rdata1    (id_rf_rdata1),
    .rdata2    (id_rf_rdata2)
  );

  // Immediate Generator
  rv32i_imm_gen u_imm_gen (
    .instruction (if_id_instr),
    .imm_format  (id_imm_format),
    .immediate   (id_imm)
  );

  // ID/EX Pipeline Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      id_ex_pc            <= 32'h0;
      id_ex_pc_plus4      <= 32'h0;
      id_ex_rdata1        <= 32'h0;
      id_ex_rdata2        <= 32'h0;
      id_ex_imm           <= 32'h0;
      id_ex_rs1           <= 5'h0;
      id_ex_rs2           <= 5'h0;
      id_ex_rd            <= 5'h0;
      id_ex_funct3        <= 3'h0;
      id_ex_alu_op        <= ALU_ADD;
      id_ex_lsu_op        <= LSU_WORD;
      id_ex_reg_write     <= 1'b0;
      id_ex_mem_read      <= 1'b0;
      id_ex_mem_write     <= 1'b0;
      id_ex_alu_src_b_imm <= 1'b0;
      id_ex_branch        <= 1'b0;
      id_ex_jal           <= 1'b0;
      id_ex_jalr          <= 1'b0;
      id_ex_instr         <= 32'h0000_0013;
    end else if (flush_id_ex) begin
      id_ex_pc            <= 32'h0;
      id_ex_pc_plus4      <= 32'h0;
      id_ex_rdata1        <= 32'h0;
      id_ex_rdata2        <= 32'h0;
      id_ex_imm           <= 32'h0;
      id_ex_rs1           <= 5'h0;
      id_ex_rs2           <= 5'h0;
      id_ex_rd            <= 5'h0;
      id_ex_funct3        <= 3'h0;
      id_ex_alu_op        <= ALU_ADD;
      id_ex_lsu_op        <= LSU_WORD;
      id_ex_reg_write     <= 1'b0;
      id_ex_mem_read      <= 1'b0;
      id_ex_mem_write     <= 1'b0;
      id_ex_alu_src_b_imm <= 1'b0;
      id_ex_branch        <= 1'b0;
      id_ex_jal           <= 1'b0;
      id_ex_jalr          <= 1'b0;
      id_ex_instr         <= 32'h0000_0013;
    end else if (!bus_stall) begin
      id_ex_pc            <= if_id_pc;
      id_ex_pc_plus4      <= if_id_pc_plus4;
      id_ex_rdata1        <= id_rf_rdata1;
      id_ex_rdata2        <= id_rf_rdata2;
      id_ex_imm           <= id_imm;
      id_ex_rs1           <= id_rs1;
      id_ex_rs2           <= id_rs2;
      id_ex_rd            <= id_rd;
      id_ex_funct3        <= id_funct3;
      id_ex_alu_op        <= id_alu_op;
      id_ex_lsu_op        <= id_lsu_op;
      id_ex_reg_write     <= id_reg_write;
      id_ex_mem_read      <= id_mem_read;
      id_ex_mem_write     <= id_mem_write;
      id_ex_alu_src_b_imm <= id_alu_src_b_imm;
      id_ex_branch        <= id_branch;
      id_ex_jal           <= id_jal;
      id_ex_jalr          <= id_jalr;
      id_ex_instr         <= if_id_instr;
    end
  end

  //===========================================================================
  // 3. EX Stage (Execute & Branch Resolution)
  //===========================================================================

  // Operand A Forwarding Mux
  always_comb begin
    case (fwd_a)
      FWD_EX_MEM: ex_op_a = ex_mem_alu_result;
      FWD_MEM_WB: ex_op_a = wb_final_data;
      default:    ex_op_a = id_ex_rdata1;
    endcase
  end

  // Operand B Forwarding Mux
  always_comb begin
    case (fwd_b)
      FWD_EX_MEM: ex_forwarded_b = ex_mem_alu_result;
      FWD_MEM_WB: ex_forwarded_b = wb_final_data;
      default:    ex_forwarded_b = id_ex_rdata2;
    endcase
  end

  // ALU In B Mux (Immediate vs Register operand)
  assign ex_alu_in_b = (id_ex_alu_src_b_imm) ? id_ex_imm : ex_forwarded_b;

  // ALU Instance
  rv32i_alu u_alu (
    .a         (ex_op_a),
    .b         (ex_alu_in_b),
    .alu_op    (id_ex_alu_op),
    .result    (ex_alu_result),
    .zero_flag (ex_alu_zero)
  );

  // Branch Comparator
  always_comb begin
    branch_taken_ex = 1'b0;
    if (id_ex_branch) begin
      case (id_ex_funct3)
        BR_BEQ:  branch_taken_ex = (ex_op_a == ex_forwarded_b);
        BR_BNE:  branch_taken_ex = (ex_op_a != ex_forwarded_b);
        BR_BLT:  branch_taken_ex = ($signed(ex_op_a) < $signed(ex_forwarded_b));
        BR_BGE:  branch_taken_ex = ($signed(ex_op_a) >= $signed(ex_forwarded_b));
        BR_BLTU: branch_taken_ex = (ex_op_a < ex_forwarded_b);
        BR_BGEU: branch_taken_ex = (ex_op_a >= ex_forwarded_b);
        default: branch_taken_ex = 1'b0;
      endcase
    end
  end

  // Branch / Jump Target Generation
  assign jump_ex = id_ex_jal | id_ex_jalr;

  always_comb begin
    if (id_ex_jalr) begin
      branch_target_ex = (ex_op_a + id_ex_imm) & ~32'd1;
    end else begin
      branch_target_ex = id_ex_pc + id_ex_imm;
    end
  end

  // EX/MEM Pipeline Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ex_mem_alu_result   <= 32'h0;
      ex_mem_write_data   <= 32'h0;
      ex_mem_pc_plus4     <= 32'h0;
      ex_mem_rd           <= 5'h0;
      ex_mem_lsu_op       <= LSU_WORD;
      ex_mem_reg_write    <= 1'b0;
      ex_mem_mem_read     <= 1'b0;
      ex_mem_mem_write    <= 1'b0;
      ex_mem_jal_or_jalr  <= 1'b0;
      ex_mem_instr        <= 32'h0000_0013;
    end else if (!bus_stall) begin
      ex_mem_alu_result   <= ex_alu_result;
      ex_mem_write_data   <= ex_forwarded_b;
      ex_mem_pc_plus4     <= id_ex_pc_plus4;
      ex_mem_rd           <= id_ex_rd;
      ex_mem_lsu_op       <= id_ex_lsu_op;
      ex_mem_reg_write    <= id_ex_reg_write;
      ex_mem_mem_read     <= id_ex_mem_read;
      ex_mem_mem_write    <= id_ex_mem_write;
      ex_mem_jal_or_jalr  <= id_ex_jal | id_ex_jalr;
      ex_mem_instr        <= id_ex_instr;
    end
  end

  //===========================================================================
  // 4. MEM Stage (Memory Access & Alignment)
  //===========================================================================
  rv32i_lsu u_lsu (
    .raw_mem_data    (dmem_rdata),
    .store_reg_data  (ex_mem_write_data),
    .addr            (ex_mem_alu_result),
    .lsu_op          (ex_mem_lsu_op),
    .load_data       (mem_lsu_load_data),
    .mem_write_data  (mem_lsu_write_data),
    .byte_strobe     (mem_lsu_byte_strobe),
    .unaligned_fault (mem_unaligned_fault)
  );

  // External memory driving
  assign dmem_addr  = ex_mem_alu_result;
  assign dmem_wdata = mem_lsu_write_data;
  assign dmem_wstrb = mem_lsu_byte_strobe;
  assign dmem_req   = (ex_mem_mem_read | ex_mem_mem_write);
  assign dmem_we    = ex_mem_mem_write;

  // MEM/WB Pipeline Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_wb_alu_result  <= 32'h0;
      mem_wb_load_data   <= 32'h0;
      mem_wb_pc_plus4    <= 32'h0;
      mem_wb_rd          <= 5'h0;
      mem_wb_reg_write   <= 1'b0;
      mem_wb_mem_to_reg  <= 1'b0;
      mem_wb_jal_or_jalr <= 1'b0;
      mem_wb_instr       <= 32'h0000_0013;
    end else if (!bus_stall) begin
      mem_wb_alu_result  <= ex_mem_alu_result;
      mem_wb_load_data   <= mem_lsu_load_data;
      mem_wb_pc_plus4    <= ex_mem_pc_plus4;
      mem_wb_rd          <= ex_mem_rd;
      mem_wb_reg_write   <= ex_mem_reg_write;
      mem_wb_mem_to_reg  <= ex_mem_mem_read;
      mem_wb_jal_or_jalr <= ex_mem_jal_or_jalr;
      mem_wb_instr       <= ex_mem_instr;
    end
  end

  //===========================================================================
  // 5. WB Stage (Writeback to Register File)
  //===========================================================================
  always_comb begin
    if (mem_wb_jal_or_jalr) begin
      wb_final_data = mem_wb_pc_plus4;
    end else if (mem_wb_mem_to_reg) begin
      wb_final_data = mem_wb_load_data;
    end else begin
      wb_final_data = mem_wb_alu_result;
    end
  end

  // Debug / Trace Interface
  assign dbg_pc       = mem_wb_pc_plus4 - 32'd4;
  assign dbg_instr    = mem_wb_instr;
  assign dbg_wb_reg   = mem_wb_rd;
  assign dbg_wb_data  = wb_final_data;
  assign dbg_wb_valid = mem_wb_reg_write && (mem_wb_rd != 5'd0);

  //===========================================================================
  // 6. Hazard & Forwarding Unit Instance
  //===========================================================================
  rv32i_hazard_unit u_hazard (
    .if_id_rs1        (id_rs1),
    .if_id_rs2        (id_rs2),
    .id_ex_rs1        (id_ex_rs1),
    .id_ex_rs2        (id_ex_rs2),
    .id_ex_rd         (id_ex_rd),
    .ex_mem_rd        (ex_mem_rd),
    .mem_wb_rd        (mem_wb_rd),
    .id_ex_mem_read   (id_ex_mem_read),
    .ex_mem_reg_write (ex_mem_reg_write),
    .mem_wb_reg_write (mem_wb_reg_write),
    .branch_taken_ex  (branch_taken_ex),
    .jump_ex          (jump_ex),
    .bus_stall        (bus_stall),
    .fwd_a            (fwd_a),
    .fwd_b            (fwd_b),
    .stall_pc         (stall_pc),
    .stall_if_id      (stall_if_id),
    .flush_if_id      (flush_if_id),
    .flush_id_ex      (flush_id_ex),
    .stall_ex_mem     (stall_ex_mem),
    .stall_mem_wb     (stall_mem_wb)
  );

endmodule: rv32i_core_pipelined

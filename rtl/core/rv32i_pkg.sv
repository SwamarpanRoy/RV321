/******************************************************************************
 * Project: Enterprise-Grade RV32I RISC-V SoC & Verification Platform
 * Package: rv32i_pkg.sv
 * Description: Unified package containing architectural parameters, opcodes,
 *              ALU controls, hazard types, and memory map definitions.
 * Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
 ******************************************************************************/

package rv32i_pkg;

  // Architectural widths
  parameter int XLEN           = 32;
  parameter int ADDR_WIDTH     = 32;
  parameter int REG_ADDR_WIDTH = 5;
  parameter int DATA_WIDTH     = 32;

  // Standard RISC-V 7-bit Opcodes
  typedef enum logic [6:0] {
    OPCODE_LUI      = 7'b0110111,
    OPCODE_AUIPC    = 7'b0010111,
    OPCODE_JAL      = 7'b1101111,
    OPCODE_JALR     = 7'b1100111,
    OPCODE_BRANCH   = 7'b1100011,
    OPCODE_LOAD     = 7'b0000011,
    OPCODE_STORE    = 7'b0100011,
    OPCODE_OP_IMM   = 7'b0010011,
    OPCODE_OP       = 7'b0110011,
    OPCODE_FENCE    = 7'b0001111,
    OPCODE_SYSTEM   = 7'b1110011
  } opcode_e;

  // ALU Operations
  typedef enum logic [3:0] {
    ALU_ADD    = 4'b0000,
    ALU_SUB    = 4'b1000,
    ALU_SLL    = 4'b0001,
    ALU_SLT    = 4'b0010,
    ALU_SLTU   = 4'b0011,
    ALU_XOR    = 4'b0100,
    ALU_SRL    = 4'b0101,
    ALU_SRA    = 4'b1101,
    ALU_OR     = 4'b0110,
    ALU_AND    = 4'b0111,
    ALU_PASS_B = 4'b1111
  } alu_op_e;

  // Branch Comparison Types (funct3 for BRANCH)
  typedef enum logic [2:0] {
    BR_BEQ  = 3'b000,
    BR_BNE  = 3'b001,
    BR_BLT  = 3'b100,
    BR_BGE  = 3'b101,
    BR_BLTU = 3'b110,
    BR_BGEU = 3'b111
  } branch_op_e;

  // Immediate Decoding Formats
  typedef enum logic [2:0] {
    IMM_I,
    IMM_S,
    IMM_B,
    IMM_U,
    IMM_J
  } imm_format_e;

  // Load/Store Memory Access Sizes
  typedef enum logic [2:0] {
    LSU_BYTE   = 3'b000, // LB
    LSU_HALF   = 3'b001, // LH
    LSU_WORD   = 3'b010, // LW
    LSU_BYTE_U = 3'b100, // LBU
    LSU_HALF_U = 3'b101  // LHU
  } lsu_op_e;

  // Pipeline Data Forwarding Control
  typedef enum logic [1:0] {
    FWD_NONE   = 2'b00,  // Use register file operand
    FWD_EX_MEM = 2'b01,  // Forward from EX/MEM pipeline stage
    FWD_MEM_WB = 2'b10   // Forward from MEM/WB pipeline stage
  } fwd_sel_e;

  // AMBA AXI4-Lite Response Codes
  typedef enum logic [1:0] {
    AXI_RESP_OKAY   = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11
  } axi_resp_e;

  // Memory Map Configuration (SoC Address Space)
  localparam logic [31:0] BOOT_MEM_BASE  = 32'h0000_0000;
  localparam logic [31:0] BOOT_MEM_SIZE  = 32'h0001_0000; // 64 KB RAM
  localparam logic [31:0] PERIPH_BASE    = 32'h4000_0000; // APB Peripherals Base
  localparam logic [31:0] UART_BASE      = 32'h4000_0000; // APB UART: 0x4000_0000 - 0x4000_000F
  localparam logic [31:0] GPIO_BASE      = 32'h4000_1000; // APB GPIO: 0x4000_1000 - 0x4000_100F
  localparam logic [31:0] TIMER_BASE     = 32'h4000_2000; // APB Timer: 0x4000_2000 - 0x4000_200F

  // Peripheral Register Offsets
  localparam logic [3:0] UART_REG_DATA   = 4'h0;
  localparam logic [3:0] UART_REG_STATUS = 4'h4;
  localparam logic [3:0] UART_REG_DIV    = 4'h8;

  localparam logic [3:0] GPIO_REG_DATA   = 4'h0;
  localparam logic [3:0] GPIO_REG_DIR    = 4'h4;
  localparam logic [3:0] GPIO_REG_INT_EN = 4'h8;

  localparam logic [3:0] TIMER_REG_CTRL  = 4'h0;
  localparam logic [3:0] TIMER_REG_CNT   = 4'h4;
  localparam logic [3:0] TIMER_REG_CMP   = 4'h8;

endpackage: rv32i_pkg

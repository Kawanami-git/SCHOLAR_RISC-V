// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       scholar_riscv_core.sv
\brief      SCHOLAR RISC-V Core Module
\author     Kawanami
\date       23/09/2025
\version    1.1

\details
  This module is the top-level module of the SCHOLAR RISC-V core.
  The SCHOLAR RISC-V core is an education-oriented 32-bit or 64-bit
  RISC-V implementation.

  ISA:
    - RV32I base integer instruction set
      + 32-bit cycle counter (Zicntr subset).
    - RV64I base integer instruction set
      + 64-bit cycle counter (Zicntr subset).

  Limitations:
  - No operating system support:
      - `ECALL` is treated as a NOP (no operation).
  - No debug support:
      - `EBREAK` is treated as a NOP.
  - No support for multicore or memory consistency operations:
      - `FENCE` and `FENCE.I` are treated as NOPs.

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section scholar_riscv_core_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/07/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 23/09/2025 | Kawanami   | Remove packages.sv and provide useful metadata through parameters.<br>Add RV64 support.<br>Update the whole file for coding style compliance.<br>Update the whole file comments for doxygen support. |
********************************************************************************
*/
module scholar_riscv_core #(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int                   Archi        = 32,
    /// Core boot/start address
    parameter logic [Archi - 1 : 0] StartAddress = '0
) (
`ifdef SIM
    /* GPR signals */
    /// GPR write enable (SIM only)
    input  wire                         gpr_en_i,
    /// GPR write address (SIM only)
    input  wire [RF_ADDR_WIDTH - 1 : 0] gpr_addr_i,
    /// GPR write data (SIM only)
    input  wire [     Archi    - 1 : 0] gpr_data_i,
    /// GPR memory (SIM only)
    output wire [     Archi    - 1 : 0] gpr_memory_o  [NB_GPR],
    /// GPR program counter (SIM only)
    output wire [     Archi    - 1 : 0] gpr_pc_q_o,
    /* CSR signals */
    /// CSR mcycle register (SIM only)
    output wire [        Archi - 1 : 0] csr_mcycle_q_o,
`endif
    /* Global signals */
    /// System clock
    input  wire                         clk_i,
    /// System active low reset
    input  wire                         rstn_i,
    /* Instruction memory wires */
    /// Memory output data
    input  wire [               31 : 0] i_m_dout_i,
    /// Memory hit flag (1: hit, 0: miss)
    input  wire                         i_m_hit_i,
    /// Memory address
    output wire [        Archi - 1 : 0] i_m_addr_o,
    /// Memory read enable (1: enable, 0: disable)
    output wire                         i_m_rden_o,
    /* Data memory signals */
    /// Data read from memory
    input  wire [   Archi      - 1 : 0] d_m_dout_i,
    /// Data to write to memory
    output wire [   Archi      - 1 : 0] d_m_din_o,
    /// Memory hit flag
    input  wire                         d_m_hit_i,
    /// Memory address for LOAD or STORE
    output wire [        Archi - 1 : 0] d_m_addr_o,
    /// Memory read enable
    output wire                         d_m_rden_o,
    /// Memory write enable
    output wire                         d_m_wren_o,
    /// Byte-level write mask for STOREs
    output wire [   (Archi/8)  - 1 : 0] d_m_wmask_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */
  if (Archi != 32 && Archi != 64) begin : gen_architecture_check
    $fatal("FATAL ERROR: Only 32-bit and 64-bit architectures are supported.");
  end

  /* local parameters */
  /// Number of bits in a byte
  localparam int BYTE_LENGTH = 8;
  /// Width of an instruction (in bits)
  localparam int INSTR_WIDTH = 32;
  /// Number of general-purpose registers
  localparam int NB_GPR = 32;
  /// Address width of the general-purpose register file
  localparam int RF_ADDR_WIDTH = $clog2(NB_GPR);
  /// Address width of Control and Status Registers (CSR)
  localparam int CSR_ADDR_WIDTH = 12;
  /* EXE control signal */
  /// EXE control signal width
  localparam int EXE_CTRL_WIDTH = 5;
  /// Addition operation
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] ADD = 5'b00000;
  /// Subtraction operation
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] SUB = 5'b00001;
  /// Logical shift left
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] SLL = 5'b00010;
  /// Logical shift right
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] SRL = 5'b00011;
  /// Arithmetic shift right
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] SRA = 5'b00100;
  /// Set if less than (signed comparison)
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] SLT = 5'b00101;
  /// Set if less than (unsigned comparison)
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] SLTU = 5'b00110;
  /// Bitwise XOR
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] XOR = 5'b00111;
  /// Bitwise OR
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] OR = 5'b01000;
  /// Bitwise AND
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] AND = 5'b01001;
  /// Equality comparison
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] EQ = 5'b01010;
  /// Not equal comparison
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] NE = 5'b01011;
  /// Greater than or equal (signed comparison)
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] GE = 5'b01100;
  /// Greater than or equal (unsigned comparison)
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] GEU = 5'b01101;
  /// Addition operation on word (64 bits Architecture)
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] ADDW = 5'b10000;
  /// Subtraction operation on word (64 bits Architecture)
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] SUBW = 5'b10001;
  /// Logical shift left on word (64 bits Architecture)
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] SLLW = 5'b10010;
  /// Logical shift right on word (64 bits Architecture)
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] SRLW = 5'b10011;
  /// Arithmetic shift right on word (64 bits Architecture)
  localparam logic [EXE_CTRL_WIDTH - 1 : 0] SRAW = 5'b10100;
  /* Program Counter (PC) Control Signal */
  /// PC control signal width
  localparam int PC_CTRL_WIDTH = 2;
  /// Increment PC (PC = PC + ADDR_OFFSET)
  localparam logic [PC_CTRL_WIDTH - 1 : 0] PC_INC = 2'b00;
  /// Set PC to EXE output (used in JALR)
  localparam logic [PC_CTRL_WIDTH - 1 : 0] PC_SET = 2'b01;
  /// Compute PC as PC + EXE output (used in JAL)
  localparam logic [PC_CTRL_WIDTH - 1 : 0] PC_ADD = 2'b10;
  /// Conditional branch (PC = PC + offset if condition met, else PC + ADDR_OFFSET)
  localparam logic [PC_CTRL_WIDTH - 1 : 0] PC_COND = 2'b11;
  /* Memory Control Signal */
  /// Memory control signal width
  localparam int MEM_CTRL_WIDTH = 5;
  /// No memory operation (idle)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_IDLE = 5'b00000;
  /// Read byte (8-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_RB = 5'b00001;
  /// Read unsigned byte (8-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_RBU = 5'b01001;
  /// Write byte (8-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_WB = 5'b10001;
  /// Read half-word (16-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_RH = 5'b00010;
  /// Read unsigned half-word (16-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_RHU = 5'b01010;
  /// Write half-word (16-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_WH = 5'b10010;
  /// Read word (32-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_RW = 5'b00011;
  /// Write word (32-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_WW = 5'b10011;
  /// Read unsigned word (32-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_RWU = 5'b01011;
  /// Read double word (64-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_RD = 5'b00100;
  /// Write double word (64-bit)
  localparam logic [MEM_CTRL_WIDTH - 1 : 0] MEM_WD = 5'b10100;
  /* General purpose register file Control Signal */
  /// Register file control signal width
  localparam int GPR_CTRL_WIDTH = 3;
  /// No register update (idle)
  localparam logic [GPR_CTRL_WIDTH - 1 : 0] GPR_IDLE = 3'b000;
  /// writeback from memory to register file (load byte/half/word/double)
  localparam logic [GPR_CTRL_WIDTH - 1 : 0] GPR_MEM = 3'b100;
  /// writeback from EXE output to register file (ALU operations)
  localparam logic [GPR_CTRL_WIDTH - 1 : 0] GPR_ALU = 3'b101;
  /// writeback from PC to register file (JAL, JALR instructions)
  localparam logic [GPR_CTRL_WIDTH - 1 : 0] GPR_PRGMC = 3'b110;
  /// writeback from RS2 operand to register file (used in CSR operations)
  localparam logic [GPR_CTRL_WIDTH - 1 : 0] GPR_OP3 = 3'b111;
  /* Control and Status Register (CSR) Control Signal */
  /// CSR control signal width
  localparam int CSR_CTRL_WIDTH = 1;
  /// No CSR update (idle)
  localparam logic [CSR_CTRL_WIDTH - 1 : 0] CSR_IDLE = 1'b0;
  /* verilator lint_off UNUSED */
  /// Writeback from EXE output to CSR (CSR instructions)
  localparam logic [CSR_CTRL_WIDTH - 1 : 0] CSR_ALU = 1'b1;
  /* verilator lint_on UNUSED */

  /* functions */

  /* wires */
  /* General purpose register file */
  /// General purpose register file RS1 value
  wire [Archi          - 1 : 0] gpr_rs1_val;
  /// General purpose register file RS2 value
  wire [Archi          - 1 : 0] gpr_rs2_val;
  /// Program counter
  wire [Archi          - 1 : 0] gpr_pc;
  /* CSR file */
  /// CSR read value
  wire [Archi          - 1 : 0] csr_val;
  /* fetch */
  wire [INSTR_WIDTH    - 1 : 0] fetch_instr;
  wire                          fetch_valid;
  /* Decode */
  /// General purpose register file port 0 read address
  wire [RF_ADDR_WIDTH  - 1 : 0] decode_rs1;
  /// General purpose register file port 1 read address
  wire [RF_ADDR_WIDTH  - 1 : 0] decode_rs2;
  /// RS1 value or zeroes
  wire [Archi          - 1 : 0] decode_op1;
  /// RS2 value (REG_OP or BRANCH_OP) or immediate
  wire [Archi          - 1 : 0] decode_op2;
  /// EXE unit control
  wire [EXE_CTRL_WIDTH - 1 : 0] decode_exe_ctrl;
  /// Immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
  wire [Archi          - 1 : 0] decode_op3;
  /// Destination register
  wire [RF_ADDR_WIDTH  - 1 : 0] decode_rd;
  /// Program counter control
  wire [PC_CTRL_WIDTH  - 1 : 0] decode_pc_ctrl;
  /// Memory control
  wire [MEM_CTRL_WIDTH - 1 : 0] decode_mem_ctrl;
  /// General purpose register file control
  wire [GPR_CTRL_WIDTH - 1 : 0] decode_gpr_ctrl;
  /// Control/status register file control
  wire [CSR_CTRL_WIDTH - 1 : 0] decode_csr_ctrl;
  /// Control/status register file read address
  wire [CSR_ADDR_WIDTH - 1 : 0] decode_csr_raddr;
  /// valid flag
  wire                          decode_valid;
  /// EXE operation result
  wire [Archi          - 1 : 0] exe_out;
  /* write-back */
  /// Register index to be written (GPR destination)
  wire [RF_ADDR_WIDTH  - 1 : 0] writeback_rd;
  /// Data to write to the destination register
  wire [Archi          - 1 : 0] writeback_rd_val;
  /// Write enable for GPR destination register
  wire                          writeback_rd_valid;
  /// Next program counter value
  wire [Archi          - 1 : 0] writeback_pc_next;
  /// Write address for CSR file
  wire [CSR_ADDR_WIDTH - 1 : 0] writeback_csr_waddr;
  /// Data to write to CSR
  wire [Archi          - 1 : 0] writeback_csr_val;
  /// CSR write enable signal
  wire                          writeback_csr_valid;

  /* registers */

  /********************             ********************/


  gpr #(
      .AddrWidth   (Archi),
      .DataWidth   (Archi),
      .NbGpr       (NB_GPR),
      .RfAddrWidth (RF_ADDR_WIDTH),
      .StartAddress(StartAddress)
  ) gpr (
`ifdef SIM
      .en_i      (gpr_en_i),
      .addr_i    (gpr_addr_i),
      .data_i    (gpr_data_i),
      .memory_o  (gpr_memory_o),
      .pc_q_o    (gpr_pc_q_o),
`endif
      .clk_i     (clk_i),
      .rstn_i    (rstn_i),
      .rs1_i     (decode_rs1),
      .rs2_i     (decode_rs2),
      .rd_i      (writeback_rd),
      .rd_val_i  (writeback_rd_val),
      .rd_valid_i(writeback_rd_valid),
      .pc_next_i (writeback_pc_next),
      .rs1_val_o (gpr_rs1_val),
      .rs2_val_o (gpr_rs2_val),
      .pc_o      (gpr_pc)
  );




  csr #(
      .DataWidth   (Archi),
      .CsrAddrWidth(CSR_ADDR_WIDTH)
  ) csr (
`ifdef SIM
      .mcycle_q_o (csr_mcycle_q_o),
`endif
      .clk_i      (clk_i),
      .rstn_i     (rstn_i),
      .csr_waddr_i(writeback_csr_waddr),
      .csr_val_i  (writeback_csr_val),
      .csr_valid_i(writeback_csr_valid),
      .raddr_i    (decode_csr_raddr),
      .csr_val_o  (csr_val)
  );





  fetch #(
      .AddrWidth (Archi),
      .InstrWidth(INSTR_WIDTH)
  ) fetch (
      .clk_i    (clk_i),
      .rstn_i   (rstn_i),
      .pc_next_i(writeback_pc_next),
      .instr_o  (fetch_instr),
      .valid_o  (fetch_valid),
      .m_addr_o (i_m_addr_o),
      .m_rden_o (i_m_rden_o),
      .m_dout_i (i_m_dout_i),
      .m_hit_i  (i_m_hit_i)
  );





  decode #(
      .AddrWidth   (Archi),
      .DataWidth   (Archi),
      .InstrWidth  (INSTR_WIDTH),
      .RfAddrWidth (RF_ADDR_WIDTH),
      .CsrAddrWidth(CSR_ADDR_WIDTH),
      .ExeCtrlWidth(EXE_CTRL_WIDTH),
      .Add         (ADD),
      .Sub         (SUB),
      .Sll         (SLL),
      .Srl         (SRL),
      .Sra         (SRA),
      .Slt         (SLT),
      .Sltu        (SLTU),
      .Xor         (XOR),
      .Or          (OR),
      .And         (AND),
      .Eq          (EQ),
      .Ne          (NE),
      .Ge          (GE),
      .Geu         (GEU),
      .Addw        (ADDW),
      .Subw        (SUBW),
      .Sllw        (SLLW),
      .Srlw        (SRLW),
      .Sraw        (SRAW),
      .PcCtrlWidth (PC_CTRL_WIDTH),
      .PcInc       (PC_INC),
      .PcSet       (PC_SET),
      .PcAdd       (PC_ADD),
      .PcCond      (PC_COND),
      .MemCtrlWidth(MEM_CTRL_WIDTH),
      .MemIdle     (MEM_IDLE),
      .MemRb       (MEM_RB),
      .MemRbu      (MEM_RBU),
      .MemWb       (MEM_WB),
      .MemRh       (MEM_RH),
      .MemRhu      (MEM_RHU),
      .MemWh       (MEM_WH),
      .MemRw       (MEM_RW),
      .MemWw       (MEM_WW),
      .MemRwu      (MEM_RWU),
      .MemRd       (MEM_RD),
      .MemWd       (MEM_WD),
      .GprCtrlWidth(GPR_CTRL_WIDTH),
      .GprIdle     (GPR_IDLE),
      .GprMem      (GPR_MEM),
      .GprAlu      (GPR_ALU),
      .GprPrgmc    (GPR_PRGMC),
      .GprOp3      (GPR_OP3),
      .CsrCtrlWidth(CSR_CTRL_WIDTH),
      .CsrIdle     (CSR_IDLE)
  ) decode (
      .rstn_i       (rstn_i),
      .valid_o      (decode_valid),
      .instr_i      (fetch_instr),
      .instr_valid_i(fetch_valid),
      .rs1_o        (decode_rs1),
      .rs1_val_i    (gpr_rs1_val),
      .rs2_o        (decode_rs2),
      .rs2_val_i    (gpr_rs2_val),
      .pc_i         (gpr_pc),
      .csr_raddr_o  (decode_csr_raddr),
      .csr_val_i    (csr_val),
      .op1_o        (decode_op1),
      .op2_o        (decode_op2),
      .exe_ctrl_o   (decode_exe_ctrl),
      .op3_o        (decode_op3),
      .rd_o         (decode_rd),
      .pc_ctrl_o    (decode_pc_ctrl),
      .mem_ctrl_o   (decode_mem_ctrl),
      .gpr_ctrl_o   (decode_gpr_ctrl),
      .csr_ctrl_o   (decode_csr_ctrl)
  );





  exe #(
      .DataWidth   (Archi),
      .ExeCtrlWidth(EXE_CTRL_WIDTH),
      .Add         (ADD),
      .Sub         (SUB),
      .Sll         (SLL),
      .Srl         (SRL),
      .Sra         (SRA),
      .Slt         (SLT),
      .Sltu        (SLTU),
      .Xor         (XOR),
      .Or          (OR),
      .And         (AND),
      .Eq          (EQ),
      .Ne          (NE),
      .Ge          (GE),
      .Geu         (GEU),
      .Addw        (ADDW),
      .Subw        (SUBW),
      .Sllw        (SLLW),
      .Srlw        (SRLW),
      .Sraw        (SRAW)
  ) exe (
      .op1_i     (decode_op1),
      .op2_i     (decode_op2),
      .exe_ctrl_i(decode_exe_ctrl),
      .out_o     (exe_out)
  );





  writeback #(
      .ByteLength  (BYTE_LENGTH),
      .AddrWidth   (Archi),
      .DataWidth   (Archi),
      .RfAddrWidth (RF_ADDR_WIDTH),
      .CsrAddrWidth(CSR_ADDR_WIDTH),
      .PcCtrlWidth (PC_CTRL_WIDTH),
      .PcInc       (PC_INC),
      .PcSet       (PC_SET),
      .PcAdd       (PC_ADD),
      .PcCond      (PC_COND),
      .MemCtrlWidth(MEM_CTRL_WIDTH),
      .MemIdle     (MEM_IDLE),
      .MemRb       (MEM_RB),
      .MemRbu      (MEM_RBU),
      .MemWb       (MEM_WB),
      .MemRh       (MEM_RH),
      .MemRhu      (MEM_RHU),
      .MemWh       (MEM_WH),
      .MemRw       (MEM_RW),
      .MemWw       (MEM_WW),
      .MemRwu      (MEM_RWU),
      .GprCtrlWidth(GPR_CTRL_WIDTH),
      .GprMem      (GPR_MEM),
      .GprAlu      (GPR_ALU),
      .GprPrgmc    (GPR_PRGMC),
      .GprOp3      (GPR_OP3),
      .CsrCtrlWidth(CSR_CTRL_WIDTH),
      .StartAddress(StartAddress)
  ) writeback (
      .clk_i         (clk_i),
      .rstn_i        (rstn_i),
      .decode_valid_i(decode_valid),
      .exe_out_i     (exe_out),
      .op3_i         (decode_op3),
      .rd_i          (decode_rd),
      .pc_ctrl_i     (decode_pc_ctrl),
      .mem_ctrl_i    (decode_mem_ctrl),
      .gpr_ctrl_i    (decode_gpr_ctrl),
      .csr_ctrl_i    (decode_csr_ctrl),
      .rd_val_o      (writeback_rd_val),
      .rd_o          (writeback_rd),
      .rd_valid_o    (writeback_rd_valid),
      .pc_i          (gpr_pc),
      .pc_next_o     (writeback_pc_next),
      .csr_waddr_o   (writeback_csr_waddr),
      .csr_val_o     (writeback_csr_val),
      .csr_valid_o   (writeback_csr_valid),
      .m_addr_o      (d_m_addr_o),
      .m_rden_o      (d_m_rden_o),
      .m_wren_o      (d_m_wren_o),
      .m_wmask_o     (d_m_wmask_o),
      .m_din_o       (d_m_din_o),
      .m_dout_i      (d_m_dout_i),
      .m_hit_i       (d_m_hit_i)
  );

endmodule

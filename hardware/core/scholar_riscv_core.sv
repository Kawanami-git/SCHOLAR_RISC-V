// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       scholar_riscv_core.sv
\brief      SCHOLAR RISC-V Core Module
\author     Kawanami
\date       15/04/2026
\version    1.5

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
| 1.2     | 13/02/2026 | Kawanami   | Replace custom interface with OBI standard. |
| 1.3     | 28/03/2026 | Kawanami   | Improve spike compatibility.              |
| 1.4     | 29/03/2026 | Kawanami   | Improve global lisibility by using package instead of parameters. |
| 1.5     | 15/04/2026 | Kawanami   | Add a reset synchronizer. |
********************************************************************************
*/
module scholar_riscv_core

  import core_pkg::INSTR_WIDTH;
  import core_pkg::NB_GPR;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::OP_WIDTH;
  import core_pkg::FUNCT3_WIDTH;
  import core_pkg::FUNCT7_WIDTH;
  import core_pkg::LOAD_OP;
  import core_pkg::IMM_OP;
  import core_pkg::IMMW_OP;
  import core_pkg::REGW_OP;
  import core_pkg::AUIPC_OP;
  import core_pkg::STORE_OP;
  import core_pkg::REG_OP;
  import core_pkg::LUI_OP;
  import core_pkg::BRANCH_OP;
  import core_pkg::JALR_OP;
  import core_pkg::JAL_OP;
  import core_pkg::SYS_OP;
  import core_pkg::EXE_CTRL_WIDTH;
  import core_pkg::EXE_ADD;
  import core_pkg::EXE_SUB;
  import core_pkg::EXE_SLL;
  import core_pkg::EXE_SRL;
  import core_pkg::EXE_SRA;
  import core_pkg::EXE_SLT;
  import core_pkg::EXE_SLTU;
  import core_pkg::EXE_XOR;
  import core_pkg::EXE_OR;
  import core_pkg::EXE_AND;
  import core_pkg::EXE_EQ;
  import core_pkg::EXE_NE;
  import core_pkg::EXE_GE;
  import core_pkg::EXE_GEU;
  import core_pkg::EXE_ADDW;
  import core_pkg::EXE_SUBW;
  import core_pkg::EXE_SLLW;
  import core_pkg::EXE_SRLW;
  import core_pkg::EXE_SRAW;
  import core_pkg::PC_CTRL_WIDTH;
  import core_pkg::PC_INC;
  import core_pkg::PC_SET;
  import core_pkg::PC_ADD;
  import core_pkg::PC_COND;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::MEM_IDLE;
  import core_pkg::MEM_RB;
  import core_pkg::MEM_RBU;
  import core_pkg::MEM_WB;
  import core_pkg::MEM_RH;
  import core_pkg::MEM_RHU;
  import core_pkg::MEM_WH;
  import core_pkg::MEM_RW;
  import core_pkg::MEM_RWU;
  import core_pkg::MEM_WW;
  import core_pkg::MEM_RD;
  import core_pkg::MEM_WD;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::GPR_IDLE;
  import core_pkg::GPR_MEM;
  import core_pkg::GPR_ALU;
  import core_pkg::GPR_PRGMC;
  import core_pkg::GPR_OP3;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::CSR_IDLE;
  import core_pkg::CSR_ALU;

#(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned                 Archi        = 32,
    /// Core boot/start address
    parameter logic        [Archi - 1 : 0] StartAddress = '0
) (
`ifdef SIM
    /// Simulation CSR overwrite enable
    input  wire                          csr_en_i,
    /// Simulation CSR overwrite data
    input  wire [Archi          - 1 : 0] csr_data_i,
    /// Decode to CSR raddr
    output wire [                11 : 0] decode_csr_raddr_o,
    /// GPR memory (SIM only)
    output wire [      Archi    - 1 : 0] gpr_memory_o      [NB_GPR],
    /// GPR program counter (SIM only)
    output wire [      Archi    - 1 : 0] gpr_pc_q_o,
    /// CSR mcycle register (SIM only)
    output wire [         Archi - 1 : 0] csr_mcycle_q_o,
    /// Writeback instruction commited flag
    output wire                          instr_committed_o,
`endif
    /* Global signals */
    /// System clock
    input  wire                          clk_i,
    /// System active low reset
    input  wire                          rstn_i,
    /* Instruction memory wires */
    /// Address transfer request
    output wire                          imem_req_o,
    /// Grant: Ready to accept address transfert
    input  wire                          imem_gnt_i,
    /// Address for memory access
    output wire [        Archi  - 1 : 0] imem_addr_o,
    /// Response transfer valid
    input  wire                          imem_rvalid_i,
    /// Read data
    input  wire [                31 : 0] imem_rdata_i,
    /// Error response
    input  wire                          imem_err_i,
    /* Data memory signals */
    /// Address transfer request
    output wire                          dmem_req_o,
    /// Grant: Ready to accept address transfert
    input  wire                          dmem_gnt_i,
    /// Address for memory access
    output wire [        Archi  - 1 : 0] dmem_addr_o,
    /// Write enable (1: write - 0: read)
    output wire                          dmem_we_o,
    /// Write data
    output wire [         Archi - 1 : 0] dmem_wdata_o,
    /// Byte enable
    output wire [     (Archi/8) - 1 : 0] dmem_be_o,
    /// Response transfer valid
    input  wire                          dmem_rvalid_i,
    /// Read data
    input  wire [         Archi - 1 : 0] dmem_rdata_i,
    /// Error response
    input  wire                          dmem_err_i
);

  /******************** DECLARATION ********************/
  /* parameters verification */
  /// Ensure XLEN is supported by the build (32 or 64)
  if (Archi != 32 && Archi != 64) begin : gen_architecture_check
    $fatal("FATAL ERROR: Only 32-bit and 64-bit architectures are supported.");
  end

  /* local parameters */

  /* functions */

  /* wires */
  /* General purpose register file */
  /// General purpose register file RS1 value
  wire  [Archi          - 1 : 0] gpr_rs1_val;
  /// General purpose register file RS2 value
  wire  [Archi          - 1 : 0] gpr_rs2_val;
  /// Program counter
  wire  [Archi          - 1 : 0] gpr_pc;
  /* CSR file */
  /// CSR read value
  wire  [Archi          - 1 : 0] csr_val;
  /* fetch */
  wire  [INSTR_WIDTH    - 1 : 0] fetch_instr;
  wire                           fetch_valid;
  /* Decode */
  /// General purpose register file port 0 read address
  wire  [RF_ADDR_WIDTH  - 1 : 0] decode_rs1;
  /// General purpose register file port 1 read address
  wire  [RF_ADDR_WIDTH  - 1 : 0] decode_rs2;
  /// RS1 value or zeroes
  wire  [Archi          - 1 : 0] decode_op1;
  /// RS2 value (REG_OP or BRANCH_OP) or immediate
  wire  [Archi          - 1 : 0] decode_op2;
  /// EXE unit control
  wire  [EXE_CTRL_WIDTH - 1 : 0] decode_exe_ctrl;
  /// Immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
  wire  [Archi          - 1 : 0] decode_op3;
  /// Destination register
  wire  [RF_ADDR_WIDTH  - 1 : 0] decode_rd;
  /// Program counter control
  wire  [PC_CTRL_WIDTH  - 1 : 0] decode_pc_ctrl;
  /// Memory control
  wire  [MEM_CTRL_WIDTH - 1 : 0] decode_mem_ctrl;
  /// General purpose register file control
  wire  [GPR_CTRL_WIDTH - 1 : 0] decode_gpr_ctrl;
  /// Control/status register file control
  wire  [CSR_CTRL_WIDTH - 1 : 0] decode_csr_ctrl;
  /// Control/status register file read address
  wire  [CSR_ADDR_WIDTH - 1 : 0] decode_csr_raddr;
  /// valid flag
  wire                           decode_valid;
  /// EXE operation result
  wire  [Archi          - 1 : 0] exe_out;
  /* write-back */
  /// Register index to be written (GPR destination)
  wire  [RF_ADDR_WIDTH  - 1 : 0] writeback_rd;
  /// Data to write to the destination register
  wire  [Archi          - 1 : 0] writeback_rd_val;
  /// Write enable for GPR destination register
  wire                           writeback_rd_valid;
  /// Next program counter value
  wire  [Archi          - 1 : 0] writeback_pc_next;
  /// Write address for CSR file
  wire  [CSR_ADDR_WIDTH - 1 : 0] writeback_csr_waddr;
  /// Data to write to CSR
  wire  [Archi          - 1 : 0] writeback_csr_val;
  /// CSR write enable signal
  wire                           writeback_csr_valid;

  /* registers */
  /// First stage of the reset synchronizer
  (* ASYNC_REG = "TRUE" *)logic                          core_rstn_q;

  /// Second stage of the reset synchronizer
  (* ASYNC_REG = "TRUE" *)logic                          core_rstn_q_d;
  /********************             ********************/

  /*!
   * \brief Synchronize the external reset into the local clock domain.
   *
   * This 2-flop synchronizer reduces the risk of metastability when the
   * external active-low reset `rstn_i` is sampled by logic running on `clk_i`.
   */
  always_ff @(posedge clk_i) begin : rst_sync
    core_rstn_q   <= rstn_i;
    core_rstn_q_d <= core_rstn_q;
  end


  gpr #(
      .Archi       (Archi),
      .StartAddress(StartAddress)
  ) gpr (
`ifdef SIM
      .memory_o  (gpr_memory_o),
      .pc_q_o    (gpr_pc_q_o),
`endif
      .clk_i     (clk_i),
      .rstn_i    (core_rstn_q_d),
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
      .Archi(Archi)
  ) csr (
`ifdef SIM
      .en_i       (csr_en_i),
      .data_i     (csr_data_i),
      .mcycle_q_o (csr_mcycle_q_o),
`endif
      .clk_i      (clk_i),
      .rstn_i     (core_rstn_q_d),
      .csr_waddr_i(writeback_csr_waddr),
      .csr_val_i  (writeback_csr_val),
      .csr_valid_i(writeback_csr_valid),
      .raddr_i    (decode_csr_raddr),
      .csr_val_o  (csr_val)
  );

`ifdef SIM
  assign decode_csr_raddr_o = decode_csr_raddr;
`endif


  fetch #(
      .Archi(Archi)
  ) fetch (
      .clk_i    (clk_i),
      .rstn_i   (core_rstn_q_d),
      .pc_next_i(writeback_pc_next),
      .instr_o  (fetch_instr),
      .valid_o  (fetch_valid),
      .req_o    (imem_req_o),
      .gnt_i    (imem_gnt_i),
      .addr_o   (imem_addr_o),
      .rvalid_i (imem_rvalid_i),
      .rdata_i  (imem_rdata_i),
      .err_i    (imem_err_i)
  );

  decode #(
      .Archi(Archi)
  ) decode (
      .rstn_i       (core_rstn_q_d),
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
      .Archi(Archi)
  ) exe (
      .op1_i     (decode_op1),
      .op2_i     (decode_op2),
      .exe_ctrl_i(decode_exe_ctrl),
      .out_o     (exe_out)
  );

  writeback #(
      .Archi       (Archi),
      .StartAddress(StartAddress)
  ) writeback (
`ifdef SIM
      .instr_committed_o(instr_committed_o),
`endif
      .clk_i            (clk_i),
      .rstn_i           (core_rstn_q_d),
      .decode_valid_i   (decode_valid),
      .exe_out_i        (exe_out),
      .op3_i            (decode_op3),
      .rd_i             (decode_rd),
      .pc_ctrl_i        (decode_pc_ctrl),
      .mem_ctrl_i       (decode_mem_ctrl),
      .gpr_ctrl_i       (decode_gpr_ctrl),
      .csr_ctrl_i       (decode_csr_ctrl),
      .rd_val_o         (writeback_rd_val),
      .rd_o             (writeback_rd),
      .rd_valid_o       (writeback_rd_valid),
      .pc_i             (gpr_pc),
      .pc_next_o        (writeback_pc_next),
      .csr_waddr_o      (writeback_csr_waddr),
      .csr_val_o        (writeback_csr_val),
      .csr_valid_o      (writeback_csr_valid),
      .req_o            (dmem_req_o),
      .gnt_i            (dmem_gnt_i),
      .addr_o           (dmem_addr_o),
      .we_o             (dmem_we_o),
      .wdata_o          (dmem_wdata_o),
      .be_o             (dmem_be_o),
      .rvalid_i         (dmem_rvalid_i),
      .rdata_i          (dmem_rdata_i),
      .err_i            (dmem_err_i)
  );

endmodule

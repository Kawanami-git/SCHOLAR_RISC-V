// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       scholar_riscv_core.sv
\brief      SCHOLAR RISC-V Core Module
\author     Kawanami
\date       10/01/2026
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
| 1.0     | 19/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 10/01/2026 | Kawanami | Add non-perfect memory support in the controller by checking `mem_ready_i` before triggering the softreset. |
********************************************************************************
*/

/*!
* Import useful packages.
*/
import if2id_pkg::if2id_t;
import id2exe_pkg::id2exe_t;
import exe2mem_pkg::exe2mem_t;
import mem2wb_pkg::mem2wb_t;
import exe2pc_pkg::exe2pc_t;

import core_pkg::ADDR_WIDTH;
import core_pkg::DATA_WIDTH;
import core_pkg::RF_ADDR_WIDTH;
import core_pkg::CSR_ADDR_WIDTH;
import core_pkg::NB_GPR;
/**/

module scholar_riscv_core #(
    /// Core boot/start address
    parameter logic [ADDR_WIDTH - 1 : 0] StartAddress = '0
) (
`ifdef SIM
    /* GPR signals */
    /// GPR write enable (SIM only)
    input  wire                           gpr_en_i,
    /// GPR write address (SIM only)
    input  wire [  RF_ADDR_WIDTH - 1 : 0] gpr_addr_i,
    /// GPR write data (SIM only)
    input  wire [  DATA_WIDTH    - 1 : 0] gpr_data_i,
    /// GPR memory (SIM only)
    output wire [  DATA_WIDTH    - 1 : 0] gpr_memory_o    [NB_GPR],
    /* CSR signals */
    /// CSR mhpmcounter0 register
    output wire [     DATA_WIDTH - 1 : 0] mhpmcounter0_q_o,
    /// CSR mhpmcounter3 register
    output wire [     DATA_WIDTH - 1 : 0] mhpmcounter3_q_o,
    /// CSR mhpmcounter4 register
    output wire [     DATA_WIDTH - 1 : 0] mhpmcounter4_q_o,
    /// Writeback to GPR write enable
    output wire                           wb_valid_o,
`endif
    /* Global signals */
    /// System clock
    input  wire                           clk_i,
    /// System active low reset
    input  wire                           rstn_i,
    /* Instruction memory wires */
    /// Memory output data
    input  wire [                 31 : 0] i_m_rdata_i,
    /// Memory hit flag (1: hit, 0: miss)
    input  wire                           i_m_hit_i,
    /// Memory address
    output wire [     ADDR_WIDTH - 1 : 0] i_m_addr_o,
    /// Memory read enable (1: enable, 0: disable)
    output wire                           i_m_rden_o,
    /* Data memory signals */
    /// Data read from memory
    input  wire [DATA_WIDTH      - 1 : 0] d_m_rdata_i,
    /// Data to write to memory
    output wire [DATA_WIDTH      - 1 : 0] d_m_wdata_o,
    /// Memory hit flag
    input  wire                           d_m_hit_i,
    /// Memory address for LOAD or STORE
    output wire [     ADDR_WIDTH - 1 : 0] d_m_addr_o,
    /// Memory read enable
    output wire                           d_m_rden_o,
    /// Memory write enable
    output wire                           d_m_wren_o,
    /// Byte-level write mask for STOREs
    output wire [(DATA_WIDTH/8)  - 1 : 0] d_m_wmask_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */
  if (DATA_WIDTH != 32 && DATA_WIDTH != 64) begin : gen_architecture_check
    $fatal("FATAL ERROR: Only 32-bit and 64-bit architectures are supported.");
  end

  /* local parameters */

  /* functions */

  /* wires */

  /* Control / PC */
  /// Active-low softreset (branch handling)
  wire                                    softresetn;
  /// Program counter
  wire      [DATA_WIDTH          - 1 : 0] pc;
  /// Instruction rs1 dirty flag
  wire                                    ctrl_rs1_dirty;
  /// Instruction rs2 dirty flag
  wire                                    ctrl_rs2_dirty;
  /* General purpose register file */
  /// General purpose register file RS1 value
  wire      [DATA_WIDTH          - 1 : 0] gpr_rs1_data;
  /// General purpose register file RS2 value
  wire      [DATA_WIDTH          - 1 : 0] gpr_rs2_data;
  /* CSR file */
  /// CSR read value
  wire      [DATA_WIDTH          - 1 : 0] csr_data;
  /* Fetch */
  /// Fetch to decode stage control/data package
  if2id_t                                 if2id;
  /// Fetch valid flag
  wire                                    fetch_valid;
  /// Fetch pre-decode destination register
  wire      [      RF_ADDR_WIDTH - 1 : 0] fetch_rd;
  /// Fetch pre-decode source 1 register
  wire      [      RF_ADDR_WIDTH - 1 : 0] fetch_rs1;
  /// Fetch pre-decode source 2 register
  wire      [      RF_ADDR_WIDTH - 1 : 0] fetch_rs2;
  /* Decode */
  /// Decode ready flag
  wire                                    decode_ready;
  /// Decode valid flag
  wire                                    decode_valid;
  /// General purpose register file port 0 read address
  wire      [     RF_ADDR_WIDTH  - 1 : 0] decode_rs1;
  /// General purpose register file port 1 read address
  wire      [     RF_ADDR_WIDTH  - 1 : 0] decode_rs2;
  /// Decode to exe control/data package
  id2exe_t                                id2exe;
  /// Control/status register file read address
  wire      [     CSR_ADDR_WIDTH - 1 : 0] decode_csr_raddr;
  /* Exe */
  /// Exe ready flag
  wire                                    exe_ready;
  /// Exe valid flag
  wire                                    exe_valid;
  /// Exe to mem control/data package
  exe2mem_t                               exe2mem;
  /// Exe to pc (control) control/data package
  exe2pc_t                                exe2pc;
  /* mem */
  /// Mem ready flag
  wire                                    mem_ready;
  /// Mem valid flag
  wire                                    mem_valid;
  /// Mem to writeback control/data package
  mem2wb_t                                mem2wb;
  /* write-back */
  /// Writeback valid flag
  wire                                    wb_valid;
  /// General purpose register file write port address
  wire      [          RF_ADDR_WIDTH-1:0] wb_rd;
  /// General purpose register file write port data
  wire      [             DATA_WIDTH-1:0] wb_gpr_wdata;
  /// CSR write port address
  wire      [         CSR_ADDR_WIDTH-1:0] wb_csr_waddr;
  /// CSR file write port data
  wire      [             DATA_WIDTH-1:0] wb_csr_wdata;


  /* registers */

  /********************             ********************/

  gpr #() gpr (
`ifdef SIM
      .en_i      (gpr_en_i),
      .addr_i    (gpr_addr_i),
      .data_i    (gpr_data_i),
      .memory_o  (gpr_memory_o),
`endif
      .clk_i     (clk_i),
      .rstn_i    (rstn_i),
      .rs1_i     (decode_rs1),
      .rs2_i     (decode_rs2),
      .wb_valid_i(wb_valid),
      .rd_i      (wb_rd),
      .rd_data_i (wb_gpr_wdata),
      .rs1_data_o(gpr_rs1_data),
      .rs2_data_o(gpr_rs2_data)
  );


  csr #() csr (
`ifdef SIM
      .mhpmcounter0_q_o(mhpmcounter0_q_o),
      .mhpmcounter3_q_o(mhpmcounter3_q_o),
      .mhpmcounter4_q_o(mhpmcounter4_q_o),
`endif
      .clk_i           (clk_i),
      .rstn_i          (rstn_i),
      .waddr_i         (wb_csr_waddr),
      .wdata_i         (wb_csr_wdata),
      .raddr_i         (decode_csr_raddr),
      .rdata_o         (csr_data),
      .mhpmevent3      (ctrl_rs1_dirty || ctrl_rs2_dirty),
      .mhpmevent4      (!softresetn)
  );

  ctrl #(
      .StartAddress(StartAddress)
  ) ctrl (
      .clk_i         (clk_i),
      .rstn_i        (rstn_i),
      .i_m_hit_i     (i_m_hit_i),
      .exe2pc_i      (exe2pc),
      .rs1_i         (fetch_rs1),
      .rs1_dirty_o   (ctrl_rs1_dirty),
      .rs2_i         (fetch_rs2),
      .rs2_dirty_o   (ctrl_rs2_dirty),
      .fetch_rd_i    (fetch_rd),
      .decode_valid_i(decode_valid),
      .decode_ready_i(decode_ready),
      .mem_ready_i   (mem_ready),
      .softresetn_o  (softresetn),
      .wb_rd_i       (wb_rd),
      .pc_o          (pc)
  );

`ifdef SIM
  assign wb_valid_o = wb_valid;
`endif

  fetch #() fetch (
      .clk_i         (clk_i),
      .rstn_i        (rstn_i && softresetn),
      .pc_i          (pc),
      .decode_ready_i(decode_ready),
      .valid_o       (fetch_valid),
      .if2id_o       (if2id),
      .rs1_o         (fetch_rs1),
      .rs2_o         (fetch_rs2),
      .rd_o          (fetch_rd),
      .i_m_rdata_i   (i_m_rdata_i),
      .i_m_hit_i     (i_m_hit_i),
      .i_m_addr_o    (i_m_addr_o),
      .i_m_rden_o    (i_m_rden_o)
  );

  decode #() decode (
      .clk_i        (clk_i),
      .rstn_i       (rstn_i && softresetn),
      .fetch_valid_i(fetch_valid),
      .exe_ready_i  (exe_ready),
      .ready_o      (decode_ready),
      .valid_o      (decode_valid),
      .rs1_o        (decode_rs1),
      .rs1_data_i   (gpr_rs1_data),
      .rs1_dirty_i  (ctrl_rs1_dirty),
      .rs2_o        (decode_rs2),
      .rs2_data_i   (gpr_rs2_data),
      .rs2_dirty_i  (ctrl_rs2_dirty),
      .csr_raddr_o  (decode_csr_raddr),
      .csr_data_i   (csr_data),
      .if2id_i      (if2id),
      .id2exe_o     (id2exe)
  );

  exe #() exe (
      .clk_i         (clk_i),
      .rstn_i        (rstn_i && softresetn),
      .decode_valid_i(decode_valid),
      .mem_ready_i   (mem_ready),
      .ready_o       (exe_ready),
      .valid_o       (exe_valid),
      .id2exe_i      (id2exe),
      .exe2mem_o     (exe2mem),
      .exe2pc_o      (exe2pc)
  );

  mem #() mem (
      .clk_i      (clk_i),
      .rstn_i     (rstn_i),
      .exe_valid_i(exe_valid),
      .ready_o    (mem_ready),
      .valid_o    (mem_valid),
      .exe2mem_i  (exe2mem),
      .mem2wb_o   (mem2wb),
      .d_m_wdata_o(d_m_wdata_o),
      .d_m_hit_i  (d_m_hit_i),
      .d_m_addr_o (d_m_addr_o),
      .d_m_rden_o (d_m_rden_o),
      .d_m_wren_o (d_m_wren_o),
      .d_m_wmask_o(d_m_wmask_o)
  );

  writeback #() writeback (
      .clk_i      (clk_i),
      .rstn_i     (rstn_i),
      .mem_valid_i(mem_valid),
      .mem2wb_i   (mem2wb),
      .rd_o       (wb_rd),
      .valid_o    (wb_valid),
      .gpr_wdata_o(wb_gpr_wdata),
      .csr_waddr_o(wb_csr_waddr),
      .csr_wdata_o(wb_csr_wdata),
      .d_m_rdata_i(d_m_rdata_i)
  );

endmodule

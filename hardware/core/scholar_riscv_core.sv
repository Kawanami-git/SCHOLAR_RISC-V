// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       scholar_riscv_core.sv
\brief      SCHOLAR RISC-V Core Module
\author     Kawanami
\date       07/03/2026
\version    1.0

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
| 1.0     | 07/03/2026 | Kawanami   | Initial version of the module.            |
********************************************************************************
*/

module scholar_riscv_core

  /*!
* Import useful packages.
*/
  import if2id_pkg::if2id_t;
  import if2ctrl_pkg::if2ctrl_t;
  import ctrl2id_pkg::ctrl2id_t;
  import id2exe_pkg::id2exe_t;
  import exe2mem_pkg::exe2mem_t;
  import exe2ctrl_pkg::exe2ctrl_t;
  import mem2wb_pkg::mem2wb_t;
  import mem2ctrl_pkg::mem2ctrl_t;
  import wb2ctrl_pkg::wb2ctrl_t;
  import mem2id_pkg::mem2id_t;
  import exe2id_pkg::exe2id_t;
  import wb2id_pkg::wb2id_t;
  import wb2exe_pkg::wb2exe_t;
  import wb2mem_pkg::wb2mem_t;

  import core_pkg::ADDR_WIDTH;
  import core_pkg::INSTR_WIDTH;
  import core_pkg::DATA_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::NB_GPR;
  import core_pkg::SEL_CTRL_WIDTH;
  import core_pkg::SEL_NONE;
  import core_pkg::SEL_EXE;
  import core_pkg::SEL_MEM;
  import core_pkg::SEL_WB;
/**/

#(
    /// Core boot/start address
    parameter logic [ADDR_WIDTH - 1 : 0] StartAddress = '0
) (
`ifdef SIM
    /* GPR signals */
    /// GPR write enable (SIM only)
    input  wire                          gpr_en_i,
    /// GPR write address (SIM only)
    input  wire [ RF_ADDR_WIDTH - 1 : 0] gpr_addr_i,
    /// GPR write data (SIM only)
    input  wire [ DATA_WIDTH    - 1 : 0] gpr_data_i,
    /// GPR memory (SIM only)
    output wire [ DATA_WIDTH    - 1 : 0] gpr_memory_o      [NB_GPR],
    /// Decode to CSR raddr
    output wire [                11 : 0] decode_csr_raddr_o,
    /// Pipeline flush flag
    output wire                          pipeline_flush_o,
    /// CSR mhpmcounter0 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter0_o,
    /// CSR mhpmcounter3 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter3_o,
    /// CSR mhpmcounter4 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter4_o,
    /// CSR mhpmcounter5 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter5_o,
    /// CSR mhpmcounter6 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter6_o,
    /// CSR mhpmcounter7 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter7_o,
    /// CSR mhpmcounter8 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter8_o,
    /// CSR mhpmcounter9 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter9_o,
    /// CSR mhpmcounter10 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter10_o,
    /// CSR mhpmcounter11 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter11_o,
    /// CSR mhpmcounter12 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter12_o,
    /// CSR mhpmcounter13 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter13_o,
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
    output wire [   ADDR_WIDTH  - 1 : 0] imem_addr_o,
    /// Response transfer valid
    input  wire                          imem_rvalid_i,
    /// Read data
    input  wire [   INSTR_WIDTH - 1 : 0] imem_rdata_i,
    /// Error response
    input  wire                          imem_err_i,
    /* Data memory signals */
    /// Address transfer request
    output wire                          dmem_req_o,
    /// Grant: Ready to accept address transfert
    input  wire                          dmem_gnt_i,
    /// Address for memory access
    output wire [   ADDR_WIDTH  - 1 : 0] dmem_addr_o,
    /// Write enable (1: write - 0: read)
    output wire                          dmem_we_o,
    /// Write data
    output wire [    DATA_WIDTH - 1 : 0] dmem_wdata_o,
    /// Byte enable
    output wire [(DATA_WIDTH/8) - 1 : 0] dmem_be_o,
    /// Response transfer valid
    input  wire                          dmem_rvalid_i,
    /// Read data
    input  wire [    DATA_WIDTH - 1 : 0] dmem_rdata_i,
    /// Error response
    input  wire                          dmem_err_i
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
  wire                               softresetn;
  /// Program counter
  wire [DATA_WIDTH          - 1 : 0] pc;
`ifdef SIM
  /// Stall cycle event
  wire mhpmevent3 = (ctrl2id.rs1_dirty || ctrl2id.rs2_dirty) && softresetn;
  /// Branch event
  wire mhpmevent4 = !softresetn;
  /// Exe -> Decode bypass (op1 or op2) event
  wire mhpmevent5 = (ctrl2id.decode_op1_sel == SEL_EXE || ctrl2id.decode_op2_sel == SEL_EXE) &&
      softresetn && softresetn_q && decode_valid && exe_ready;
  /// Exe -> Decode bypass (opE) event
  wire mhpmevent6 = (ctrl2id.decode_op3_sel == SEL_EXE) && softresetn && softresetn_q &&
      decode_valid && exe_ready;
  /// Mem -> Decode bypass (op1 or op2) event
  wire mhpmevent7 = (ctrl2id.decode_op1_sel == SEL_MEM || ctrl2id.decode_op2_sel == SEL_MEM) &&
      softresetn && softresetn_q && decode_valid && exe_ready;
  /// Mem -> Decode bypass (op3) event
  wire mhpmevent8 = (ctrl2id.decode_op3_sel == SEL_MEM) && softresetn && softresetn_q &&
      decode_valid && exe_ready;
  /// Writeback -> Decode bypass (op1 or op2) event
  wire mhpmevent9 = (ctrl2id.decode_op1_sel == SEL_WB || ctrl2id.decode_op2_sel == SEL_WB) &&
      softresetn && softresetn_q && decode_valid && exe_ready;
  /// Writeback -> Decode bypass (op3) event
  wire mhpmevent10 = (ctrl2id.decode_op3_sel == SEL_WB) && softresetn && softresetn_q &&
      decode_valid && exe_ready;
  /// Writeback -> Exe bypass (op1 or op2) event
  wire mhpmevent11 = '0;
  // wire mhpmevent11 = (ctrl2id.exe_op1_sel == SEL_WB || ctrl2id.exe_op2_sel == SEL_WB) &&
  //     softresetn && softresetn_q && decode_valid && exe_ready;
  /// Writeback -> Exe bypass (op3) event
  wire mhpmevent12 = (ctrl2id.exe_op3_sel == SEL_WB) && softresetn && softresetn_q &&
      decode_valid && exe_ready;
  /// Writeback -> Mem bypass (op3) event
  wire mhpmevent13 = '0;
  // wire mhpmevent13 = (ctrl2id.mem_op3_sel == SEL_WB) && softresetn && softresetn_q &&
  //     decode_valid && exe_ready;
`endif

  /* General purpose register file */
  /// General purpose register file RS1 value
  wire       [DATA_WIDTH          - 1 : 0] gpr_rs1_data;
  /// General purpose register file RS2 value
  wire       [DATA_WIDTH          - 1 : 0] gpr_rs2_data;
  /* CSR file */
  /// CSR read value
  wire       [DATA_WIDTH          - 1 : 0] csr_data;
  /* Fetch */
  /// Fetch to decode stage control/data package
  if2id_t                                  if2id;
  /// Fetch valid flag
  wire                                     fetch_valid;
  /// Fetch to control package
  if2ctrl_t                                if2ctrl;
  /* Decode */
  /// Decode ready flag
  wire                                     decode_ready;
  /// Decode valid flag
  wire                                     decode_valid;
  /// General purpose register file port 0 read address
  wire       [     RF_ADDR_WIDTH  - 1 : 0] decode_rs1;
  /// General purpose register file port 1 read address
  wire       [     RF_ADDR_WIDTH  - 1 : 0] decode_rs2;
  /// CTRL->ID payload (dirty flags + bypass control)
  ctrl2id_t                                ctrl2id;
  /// Decode to exe control/data package
  id2exe_t                                 id2exe;
  /// Control/status register file read address
  wire       [     CSR_ADDR_WIDTH - 1 : 0] decode_csr_raddr;
  /* Exe */
  /// Exe ready flag
  wire                                     exe_ready;
  /// Exe valid flag
  wire                                     exe_valid;
  /// Exe to mem package
  exe2mem_t                                exe2mem;
  /// Exe to Control package
  exe2ctrl_t                               exe2ctrl;
  /// Exe To Decode bypass
  exe2id_t                                 exe2id;
  /* mem */
  /// Mem ready flag
  wire                                     mem_ready;
  /// Mem valid flag
  wire                                     mem_valid;
  /// Mem to writeback control/data package
  mem2wb_t                                 mem2wb;
  /// Mem to Control package
  mem2ctrl_t                               mem2ctrl;
  /// Mem To Decode bypass
  mem2id_t                                 mem2id;
  /* write-back */
  /// Writeback GPR wdata valid flag
  wire                                     wb_gpr_wdata_valid;
  /// Writeback CSR wdata valid flag
  wire                                     wb_csr_wdata_valid;
  /// General purpose register file write port address
  wire       [          RF_ADDR_WIDTH-1:0] wb_rd;
  /// General purpose register file write port data
  wire       [             DATA_WIDTH-1:0] wb_gpr_wdata;
  /// CSR write port address
  wire       [         CSR_ADDR_WIDTH-1:0] wb_csr_waddr;
  /// CSR file write port data
  wire       [             DATA_WIDTH-1:0] wb_csr_wdata;
  /// Writeback to Control package
  wb2ctrl_t                                wb2ctrl;
  /// Writeback to Decode bypass
  wb2id_t                                  wb2id;
  /// Writeback to Exe bypass
  wb2exe_t                                 wb2exe;
  // Writeback to Mem bypass
  // wb2mem_t wb2mem;

  /* registers */
  /// softresetn register
  reg                                      softresetn_q;
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
      .wb_valid_i(wb_gpr_wdata_valid),
      .rd_i      (wb_rd),
      .rd_data_i (wb_gpr_wdata),
      .rs1_data_o(gpr_rs1_data),
      .rs2_data_o(gpr_rs2_data)
  );


  csr #() csr (
`ifdef SIM
      .mhpmcounter0_q_o (mhpmcounter0_o),
      .mhpmcounter3_q_o (mhpmcounter3_o),
      .mhpmcounter4_q_o (mhpmcounter4_o),
      .mhpmcounter5_q_o (mhpmcounter5_o),
      .mhpmcounter6_q_o (mhpmcounter6_o),
      .mhpmcounter7_q_o (mhpmcounter7_o),
      .mhpmcounter8_q_o (mhpmcounter8_o),
      .mhpmcounter9_q_o (mhpmcounter9_o),
      .mhpmcounter10_q_o(mhpmcounter10_o),
      .mhpmcounter11_q_o(mhpmcounter11_o),
      .mhpmcounter12_q_o(mhpmcounter12_o),
      .mhpmcounter13_q_o(mhpmcounter13_o),

      .mhpmevent3_i (mhpmevent3),
      .mhpmevent4_i (mhpmevent4),
      .mhpmevent5_i (mhpmevent5),
      .mhpmevent6_i (mhpmevent6),
      .mhpmevent7_i (mhpmevent7),
      .mhpmevent8_i (mhpmevent8),
      .mhpmevent9_i (mhpmevent9),
      .mhpmevent10_i(mhpmevent10),
      .mhpmevent11_i(mhpmevent11),
      .mhpmevent12_i(mhpmevent12),
      .mhpmevent13_i(mhpmevent13),
`endif
      .clk_i        (clk_i),
      .rstn_i       (rstn_i),
      .waddr_i      (wb_csr_waddr),
      .wdata_i      (wb_csr_wdata),
      .wen_i        (wb_csr_wdata_valid),
      .raddr_i      (decode_csr_raddr),
      .rdata_o      (csr_data)
  );

  ctrl #(
      .StartAddress(StartAddress)
  ) ctrl (
      .clk_i         (clk_i),
      .rstn_i        (rstn_i),
      .imem_rvalid_i (imem_rvalid_i),
      .if2ctrl_i     (if2ctrl),
      .fetch_valid_i (fetch_valid),
      .ctrl2id_o     (ctrl2id),
      .exe2ctrl_i    (exe2ctrl),
      .mem2ctrl_i    (mem2ctrl),
      .wb2ctrl_i     (wb2ctrl),
      .decode_ready_i(decode_ready),
      .mem_ready_i   (mem_ready),
      .softresetn_o  (softresetn),
      .pc_o          (pc)
  );

`ifdef SIM
  assign decode_csr_raddr_o = decode_csr_raddr;
  assign pipeline_flush_o   = !softresetn || !softresetn_q;
`endif

  /// softresetn registration
  /*
  * This block saves the softresetn value.
  * This value is then used to trigger a flush of the
  * Decode stage.
  *
  * Using this register and not the `softresetn`
  * signal breaks the critical path
  * due to data hazard handling.
  *
  * From a behavioral point of view, this has no consequences
  * and the front-end of the pipeline (fetch/decode/exe) is
  * correctly flushed.
  */
  always_ff @(posedge clk_i) begin : softresetn_reg
    if (!rstn_i) begin
      softresetn_q <= '0;
    end
    else begin
      softresetn_q <= softresetn;
    end
  end

  /*!
  * When a jump occurs:
  * - First cycle: fetch is flushed
  * - Second cycle: decode is flushed (= not ready).
  *
  * As fetch requests a new instruction only if decode is ready,
  * there is a two cycles penality.
  * To avoid the second cycle penality, fetch verifies if decode is
  * ready or under reset:
  * - If ready, no issues.
  * - If under reset, it will be ready at the next cycle
  *   when the instruction will be available because `softresetn`
  *   is a one cyle pulse.
  */
  fetch #() fetch (
      .clk_i         (clk_i),
      .rstn_i        (rstn_i && softresetn),
      .pc_i          (pc),
      .decode_ready_i(decode_ready || !softresetn_q),
      .valid_o       (fetch_valid),
      .if2id_o       (if2id),
      .if2ctrl_o     (if2ctrl),
      .req_o         (imem_req_o),
      .gnt_i         (imem_gnt_i),
      .addr_o        (imem_addr_o),
      .rvalid_i      (imem_rvalid_i),
      .rdata_i       (imem_rdata_i),
      .err_i         (imem_err_i)
  );

  decode #() decode (
      .clk_i        (clk_i),
      .rstn_i       (rstn_i && softresetn_q),
      .fetch_valid_i(fetch_valid),
      .exe_ready_i  (exe_ready),
      .ready_o      (decode_ready),
      .valid_o      (decode_valid),
      .rs1_o        (decode_rs1),
      .rs1_data_i   (gpr_rs1_data),
      .rs2_o        (decode_rs2),
      .rs2_data_i   (gpr_rs2_data),
      .exe2id_i     (exe2id),
      .mem2id_i     (mem2id),
      .wb2id_i      (wb2id),
      .csr_raddr_o  (decode_csr_raddr),
      .csr_data_i   (csr_data),
      .ctrl2id_i    (ctrl2id),
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
      .wb2exe_i      (wb2exe),
      .exe2mem_o     (exe2mem),
      .exe2ctrl_o    (exe2ctrl),
      .exe2id_o      (exe2id)
  );

  mem #() mem (
      .clk_i      (clk_i),
      .rstn_i     (rstn_i),
      .exe_valid_i(exe_valid),
      .ready_o    (mem_ready),
      .valid_o    (mem_valid),
      .exe2mem_i  (exe2mem),
      // .wb2mem_i   (wb2mem),
      .mem2wb_o   (mem2wb),
      .mem2ctrl_o (mem2ctrl),
      .mem2id_o   (mem2id),
      .req_o      (dmem_req_o),
      .gnt_i      (dmem_gnt_i),
      .addr_o     (dmem_addr_o),
      .we_o       (dmem_we_o),
      .wdata_o    (dmem_wdata_o),
      .be_o       (dmem_be_o),
      .rvalid_i   (dmem_rvalid_i),
      .err_i      (dmem_err_i)
  );

  writeback #() writeback (
`ifdef SIM
      .instr_committed_o(instr_committed_o),
`endif
      .clk_i            (clk_i),
      .rstn_i           (rstn_i),
      .mem_valid_i      (mem_valid),
      .mem2wb_i         (mem2wb),
      .wb2ctrl_o        (wb2ctrl),
      .wb2id_o          (wb2id),
      .wb2exe_o         (wb2exe),
      // .wb2mem_o         (wb2mem),
      .rd_o             (wb_rd),
      .gpr_wdata_o      (wb_gpr_wdata),
      .csr_waddr_o      (wb_csr_waddr),
      .csr_wdata_o      (wb_csr_wdata),
      .rdata_i          (dmem_rdata_i),
      .gpr_wdata_valid_o(wb_gpr_wdata_valid),
      .csr_wdata_valid_o(wb_csr_wdata_valid)
  );

endmodule

// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       scholar_riscv_core.sv
\brief      SCHOLAR RISC-V Core Module
\author     Kawanami
\date       15/02/2026
\version    1.4

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
| 1.1     | 10/01/2026 | Kawanami   | Add non-perfect memory support in the controller by checking `mem_ready_i` before triggering the softreset. |
| 1.2     | 15/01/2026 | Kawanami   | Expose few more signals to Verilator to improve CSRs verification.  |
| 1.3     | 03/02/2026 | Kawanami   | Add CSR write path and non-perfect memory support. |
| 1.4     | 15/02/2026 | Kawanami   | Replace custom interface with OBI standard. |
********************************************************************************
*/

module scholar_riscv_core

  /*!
* Import useful packages.
*/
  import if2id_pkg::if2id_t;
  import if2ctrl_pkg::if2ctrl_t;
  import id2exe_pkg::id2exe_t;
  import exe2mem_pkg::exe2mem_t;
  import exe2ctrl_pkg::exe2ctrl_t;
  import mem2wb_pkg::mem2wb_t;
  import mem2ctrl_pkg::mem2ctrl_t;
  import wb2ctrl_pkg::wb2ctrl_t;

  import core_pkg::ADDR_WIDTH;
  import core_pkg::INSTR_WIDTH;
  import core_pkg::DATA_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::NB_GPR;
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
    /// CSR mhpmcounter0 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter0_o,
    /// CSR mhpmcounter3 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter3_o,
    /// CSR mhpmcounter4 register
    output wire [    DATA_WIDTH - 1 : 0] mhpmcounter4_o,
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
  wire                                     softresetn;
  /// Program counter
  wire       [DATA_WIDTH          - 1 : 0] pc;
  /// Instruction rs1 dirty flag
  wire                                     ctrl_rs1_dirty;
  /// Instruction rs2 dirty flag
  wire                                     ctrl_rs2_dirty;
  /// Instruction CSR dirty flag
  wire                                     ctrl_csr_dirty;
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
  /* mem */
  /// Mem ready flag
  wire                                     mem_ready;
  /// Mem valid flag
  wire                                     mem_valid;
  /// Mem to writeback control/data package
  mem2wb_t                                 mem2wb;
  /// Mem to Control package
  mem2ctrl_t                               mem2ctrl;
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
      .mhpmcounter0_q_o(mhpmcounter0_o),
      .mhpmcounter3_q_o(mhpmcounter3_o),
      .mhpmcounter4_q_o(mhpmcounter4_o),
`endif
      .clk_i           (clk_i),
      .rstn_i          (rstn_i),
      .waddr_i         (wb_csr_waddr),
      .wdata_i         (wb_csr_wdata),
      .wen_i           (wb_csr_wdata_valid),
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
      .imem_rvalid_i (imem_rvalid_i),
      .if2ctrl_i     (if2ctrl),
      .exe2ctrl_i    (exe2ctrl),
      .mem2ctrl_i    (mem2ctrl),
      .wb2ctrl_i     (wb2ctrl),
      .rs1_dirty_o   (ctrl_rs1_dirty),
      .rs2_dirty_o   (ctrl_rs2_dirty),
      .csr_dirty_o   (ctrl_csr_dirty),
      .decode_ready_i(decode_ready),
      .mem_ready_i   (mem_ready),
      .softresetn_o  (softresetn),
      .pc_o          (pc)
  );

`ifdef SIM
  assign decode_csr_raddr_o = decode_csr_raddr;
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
      .rs1_dirty_i  (ctrl_rs1_dirty),
      .rs2_o        (decode_rs2),
      .rs2_data_i   (gpr_rs2_data),
      .rs2_dirty_i  (ctrl_rs2_dirty),
      .csr_raddr_o  (decode_csr_raddr),
      .csr_data_i   (csr_data),
      .csr_dirty_i  (ctrl_csr_dirty),
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
      .exe2ctrl_o    (exe2ctrl)
  );

  mem #() mem (
      .clk_i      (clk_i),
      .rstn_i     (rstn_i),
      .exe_valid_i(exe_valid),
      .ready_o    (mem_ready),
      .valid_o    (mem_valid),
      .exe2mem_i  (exe2mem),
      .mem2wb_o   (mem2wb),
      .mem2ctrl_o (mem2ctrl),
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
      .rd_o             (wb_rd),
      .gpr_wdata_o      (wb_gpr_wdata),
      .csr_waddr_o      (wb_csr_waddr),
      .csr_wdata_o      (wb_csr_wdata),
      .rdata_i          (dmem_rdata_i),
      .gpr_wdata_valid_o(wb_gpr_wdata_valid),
      .csr_wdata_valid_o(wb_csr_wdata_valid)
  );

endmodule

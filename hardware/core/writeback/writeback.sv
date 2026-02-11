// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       writeback.sv
\brief      SCHOLAR RISC-V core write-back stage
\author     Kawanami
\date       03/02/2026
\version    1.1

\details
  This module implements the Writeback (WB) stage of the SCHOLAR RISC-V core.

  The WB stage is responsible for committing results to the General-Purpose
  Registers (GPR) and Control and Status Registers (CSR).

\remarks
- This implementation complies with [reference or standard].
- TODO: [possible improvements or future features]

\section writeback_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 17/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 03/02/2026 | Kawanami   | Add Mem->WB payload handling and expose useful signal for verilator. |
********************************************************************************
*/

module writeback

  /*!
* Import useful packages.
*/
  import mem2wb_pkg::mem2wb_t;
  import wb2ctrl_pkg::wb2ctrl_t;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::DATA_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::GPR_IDLE;
  import core_pkg::CSR_IDLE;
/**/

#(
) (
`ifdef SIM
    /// To verilator (used in simulation_vs_spike)
    output wire instr_committed_o,
`endif

    /// System clock
    input  wire                                clk_i,
    /// System active low reset
    input  wire                                rstn_i,
    /// Mem stage valid signal (1: valid  0: not valid)
    input  wire                                mem_valid_i,
    /// MEM->WB payload (operands + control micro-ops)
    input  mem2wb_t                            mem2wb_i,
    /// WB->CTRL payload
    output wb2ctrl_t                           wb2ctrl_o,
    /// GPR destination register index
    output wire      [  RF_ADDR_WIDTH - 1 : 0] rd_o,
    /// Data to write into the destination GPR
    output wire      [     DATA_WIDTH - 1 : 0] gpr_wdata_o,
    /// CSR address
    output wire      [ CSR_ADDR_WIDTH - 1 : 0] csr_waddr_o,
    /// Data to write in the CSR
    output wire      [     DATA_WIDTH - 1 : 0] csr_wdata_o,
    /// Data read from memory
    input  wire      [DATA_WIDTH      - 1 : 0] d_m_rdata_i,
    /// GPR data valid flag (1: valid  0: not valid)
    output wire                                gpr_wdata_valid_o,
    /// CSR data valid flag (1: valid  0: not valid)
    output wire                                csr_wdata_valid_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */

  /* registers */
  /// MEM->WB payload register
  mem2wb_t mem2wb_q;
  /********************             ********************/

  /// MEM->WB pipeline register
  /*!
  * Capture when MEM provides a valid uop (`mem_valid_i`).
  * This stage is always ready: both GPR and CSR writes take one cycle.
  *
  * NOP injection:
  *  - If `mem_valid_i` is low, WB clears `rd` and controls,
  *    ensuring no inappropriate GPR/CSR writes occur.
  */
  always_ff @(posedge clk_i) begin : mem_wb
    if (!rstn_i) begin
      mem2wb_q <= '0;
    end
    else if (mem_valid_i) begin
      mem2wb_q <= mem2wb_i;
    end
    else begin
      mem2wb_q.gpr_ctrl <= GPR_IDLE;
      mem2wb_q.csr_ctrl <= CSR_IDLE;
      mem2wb_q.rd       <= '0;
    end
  end

  /// output driven by mem_wb
  assign wb2ctrl_o.rd        = mem2wb_q.rd;
  /// output driven by mem_wb
  assign wb2ctrl_o.csr_waddr = mem2wb_q.csr_waddr;
  /// output driven by mem_wb
  assign wb2ctrl_o.csr_ctrl  = mem2wb_q.csr_ctrl;


`ifdef SIM
  reg instr_committed_q;
  /// Instruction commit
  /*!
  * Detect when a new instruction is committed.
  * Used by Verilator for simulation_vs_spike.
  */
  always_ff @(posedge clk_i) begin : instr_commit
    if (!rstn_i) begin
      instr_committed_q <= '0;
    end
    else if (mem_valid_i) begin
      instr_committed_q <= 1'b1;
    end
    else begin
      instr_committed_q <= '0;
    end
  end
  /// Output driven by instr_commit
  assign instr_committed_o = instr_committed_q;
`endif

  /// Writeback unit instantiation
  /*!
  * Drives commits into the GPR and/or CSR files from the MEM payload and
  * memory read data when applicable.
  */
  writeback_unit #() writeback_unit (
      .exe_out_i        (mem2wb_q.exe_out),
      .op3_i            (mem2wb_q.op3),
      .rd_i             (mem2wb_q.rd),
      .csr_waddr_i      (mem2wb_q.csr_waddr),
      .gpr_ctrl_i       (mem2wb_q.gpr_ctrl),
      .csr_ctrl_i       (mem2wb_q.csr_ctrl),
      .mem_ctrl_i       (mem2wb_q.mem_ctrl),
      .rd_o             (rd_o),
      .gpr_wdata_o      (gpr_wdata_o),
      .csr_waddr_o      (csr_waddr_o),
      .csr_wdata_o      (csr_wdata_o),
      .d_m_rdata_i      (d_m_rdata_i),
      .gpr_wdata_valid_o(gpr_wdata_valid_o),
      .csr_wdata_valid_o(csr_wdata_valid_o)
  );

endmodule

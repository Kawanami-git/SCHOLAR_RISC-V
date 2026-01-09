// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       writeback.sv
\brief      SCHOLAR RISC-V core write-back stage
\author     Kawanami
\date       17/12/2025
\version    1.0

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
********************************************************************************
*/

/*!
* Import useful packages.
*/
import mem2wb_pkg::mem2wb_t;
import core_pkg::RF_ADDR_WIDTH;
import core_pkg::DATA_WIDTH;
import core_pkg::CSR_ADDR_WIDTH;
/**/

module writeback #(
) (
    /// System clock
    input  wire                               clk_i,
    /// System active low reset
    input  wire                               rstn_i,
    /// Mem stage valid signal (1: valid  0: not valid)
    input  wire                               mem_valid_i,
    /// Writeback complete this cycle (valid toward the register files)
    output wire                               valid_o,
    /// MEM->WB payload (operands + control micro-ops)
    input  mem2wb_t                           mem2wb_i,
    /// GPR destination register index
    output wire     [  RF_ADDR_WIDTH - 1 : 0] rd_o,
    /// Data to write into the destination GPR
    output wire     [     DATA_WIDTH - 1 : 0] gpr_wdata_o,
    /// CSR address
    output wire     [ CSR_ADDR_WIDTH - 1 : 0] csr_waddr_o,
    /// Data to write in the CSR
    output wire     [     DATA_WIDTH - 1 : 0] csr_wdata_o,
    /// Data read from memory
    input  wire     [DATA_WIDTH      - 1 : 0] d_m_rdata_i
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */

  /* registers */
  /// MEM->WB payload register
  mem2wb_t mem2wb_q;
  /// Valid flag register for WB
  reg      valid_q;
  /********************             ********************/

  /// MEM->WB pipeline register
  /*!
  * Capture when MEM provides a valid uop (`mem_valid_i`).
  * This stage is always ready: both GPR and CSR writes take one cycle.
  *
  * NOP injection:
  *  - If `mem_valid_i` is low, WB clears `rd` and deasserts `valid_q`,
  *    ensuring no inappropriate GPR/CSR writes occur.
  */
  always_ff @(posedge clk_i) begin : mem_wb
    if (!rstn_i) begin
      mem2wb_q <= '0;
      valid_q  <= 1'b0;
    end
    else if (mem_valid_i) begin
      mem2wb_q <= mem2wb_i;
      valid_q  <= 1'b1;
    end
    else begin
      mem2wb_q.rd <= '0;
      valid_q     <= 1'b0;
    end
  end

  /// Output driven by stage_inputs
  assign valid_o = valid_q;

  /// Writeback unit instantiation
  /*!
  * Drives commits into the GPR and/or CSR files from the MEM payload and
  * memory read data when applicable.
  */
  writeback_unit #() writeback_unit (
      .exe_out_i  (mem2wb_q.exe_out),
      .op3_i      (mem2wb_q.op3),
      .rd_i       (mem2wb_q.rd),
      .gpr_ctrl_i (mem2wb_q.gpr_ctrl),
      .csr_ctrl_i (mem2wb_q.csr_ctrl),
      .mem_ctrl_i (mem2wb_q.mem_ctrl),
      .rd_o       (rd_o),
      .gpr_wdata_o(gpr_wdata_o),
      .csr_waddr_o(csr_waddr_o),
      .csr_wdata_o(csr_wdata_o),
      .d_m_rdata_i(d_m_rdata_i)
  );

endmodule

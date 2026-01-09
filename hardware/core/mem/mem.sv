// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       mem.sv
\brief      SCHOLAR RISC-V core memory module
\author     Kawanami
\date       17/12/2025
\version    1.0

\details
  This module implements the Memory (MEM) stage of the SCHOLAR RISC-V core.

  The MEM stage performs data-memory transactions when required by the current
  micro-operation. It enforces data alignment via byte-enable masks for writes
  and performs sign/zero extension on reads as dictated by the control signals.

  Latency model:
  - Both writes and reads are modeled as 1-cycle transactions with a perfect
    memory: read requests are issued in MEM, and the data is registered in WB
    on the next cycle.

  Handshake:
  - EXE -> MEM uses (exe_valid_i, ready_o). When ready_o=1, MEM can capture a
    new uop. If ready_o=0, MEM holds its input register to complete the
    outstanding memory transaction.
  - MEM -> WB uses valid_o to indicate the completion of a memory transaction.

\remarks
- External data memories are assumed to be perfect 1-cycle memories.
- TODO: [possible improvements or future features]

\section mem_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 17/12/2025 | Kawanami   | Initial version of the module.            |
********************************************************************************
*/

/*!
* Import useful packages.
*/
import exe2mem_pkg::exe2mem_t;
import mem2wb_pkg::mem2wb_t;
import core_pkg::ADDR_WIDTH;
import core_pkg::DATA_WIDTH;
/**/


module mem #(
) (
    /// System clock
    input  wire                                clk_i,
    /// System active low reset
    input  wire                                rstn_i,
    /// Exe stage valid signal (1: valid  0: not valid)
    input  wire                                exe_valid_i,
    /// Mem stage ready (1: can accept a new EXE->MEM payload)
    output wire                                ready_o,
    /// Mem operation complete
    output wire                                valid_o,
    /// EXE->MEM payload (operands + control micro-ops)
    input  exe2mem_t                           exe2mem_i,
    /// MEM->WB payload (operands + control micro-ops)
    output mem2wb_t                            mem2wb_o,
    /// Data to write to memory
    output wire      [DATA_WIDTH      - 1 : 0] d_m_wdata_o,
    /// Memory hit flag
    input  wire                                d_m_hit_i,
    /// Memory address for LOAD or STORE
    output wire      [     ADDR_WIDTH - 1 : 0] d_m_addr_o,
    /// Memory read enable
    output wire                                d_m_rden_o,
    /// Memory write enable
    output wire                                d_m_wren_o,
    /// Byte-level write mask for STOREs
    output wire      [(DATA_WIDTH/8)  - 1 : 0] d_m_wmask_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// Ready flag
  logic     ready;

  /* registers */
  /// EXE->MEM payload register
  exe2mem_t exe2mem_q;
  /********************             ********************/

  /// EXE->MEM pipeline register
  /*!
  * Capture when EXE provides a valid uop (`exe_valid_i`) and MEM is ready.
  *
  * Backpressure:
  *  - If `ready` is low, MEM holds `exe2mem_q` to ensure the memory
  *    transaction completes without losing the associated control.
  *
  * NOP injection:
  *  - If `ready` is high but `exe_valid_i` is low, MEM clears control
  *    `signals. This propagates a NOP-like uop downstream:
  *      - Disables potential memory side effects in the next stage
  *      - Disables any write to GPR and CSR by setting control to IDLE.
  */
  always_ff @(posedge clk_i) begin : exe_mem
    if (!rstn_i) begin
      exe2mem_q <= '0;
    end
    else if (exe_valid_i && ready) begin
      exe2mem_q <= exe2mem_i;
    end
    else if (ready) begin
      exe2mem_q.mem_ctrl <= '0;
      exe2mem_q.gpr_ctrl <= '0;
      exe2mem_q.csr_ctrl <= '0;
    end
  end

  /// Forward EXE output to writeback
  assign mem2wb_o.exe_out  = exe2mem_q.exe_out;
  /// Forward op3 to writeback
  assign mem2wb_o.op3      = exe2mem_q.op3;
  /// Forward rd to writeback
  assign mem2wb_o.rd       = exe2mem_q.rd;
  /// Forward GPR control signal to writeback
  assign mem2wb_o.gpr_ctrl = exe2mem_q.gpr_ctrl;
  /// Forward CSR control signal to writeback
  assign mem2wb_o.csr_ctrl = exe2mem_q.csr_ctrl;
  /// Forward MEM control signal to writeback (sign-extention)
  assign mem2wb_o.mem_ctrl = exe2mem_q.mem_ctrl;
  /// Output driven by mem unit.
  assign ready_o           = ready;

  /// Memory unit instantiation
  /*!
  * Drives write/read transactions to the external data memory assuming a
  * single-cycle response model. `valid_o` qualifies the MEM->WB transfer.
  */
  mem_unit #() mem_unit (
      .clk_i      (clk_i),
      .rstn_i     (rstn_i),
      .exe_valid_i(exe_valid_i),
      .ready_o    (ready),
      .valid_o    (valid_o),
      .op3_i      (exe2mem_q.op3),
      .exe_out_i  (exe2mem_q.exe_out),
      .mem_ctrl_i (exe2mem_q.mem_ctrl),
      .d_m_wdata_o(d_m_wdata_o),
      .d_m_hit_i  (d_m_hit_i),
      .d_m_addr_o (d_m_addr_o),
      .d_m_rden_o (d_m_rden_o),
      .d_m_wren_o (d_m_wren_o),
      .d_m_wmask_o(d_m_wmask_o)
  );

endmodule

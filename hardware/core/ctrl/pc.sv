// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       pc.sv
\brief      SCHOLAR RISC-V core pc updater
\author     Kawanami
\date       19/12/2025
\version    1.0

\details
  This module updates the Program Counter (PC) according to control
  and data signals coming from the pipeline (EXE stage).

  Notes:
   - PC increments by 4 (no C-extension). If C is enabled later,
     replace fixed +4 by a decode-driven step (2 or 4).
   - For PC_SET, the LSB is forced to 0 to keep alignment.


\remarks
- TODO: .

\section pc_version_history Version history
| Version | Date       | Author   | Description                    |
|:-------:|:----------:|:---------|:-------------------------------|
| 1.0     | 19/12/2025 | Kawanami | Initial version of the module. |
********************************************************************************
*/

/*!
* Import useful packages.
*/
import core_pkg::PC_CTRL_WIDTH;
import core_pkg::ADDR_WIDTH;
import core_pkg::DATA_WIDTH;
import core_pkg::PC_INC;
import core_pkg::PC_SET;
import core_pkg::PC_ADD;
import core_pkg::PC_COND;
/**/


module pc #(
    /// Core boot/start address
    parameter logic [ADDR_WIDTH - 1 : 0] StartAddress = '0
) (
    /// System clock
    input  wire                         clk_i,
    /// System active-low reset
    input  wire                         rstn_i,
    /// Enable flag (1: update PC, 0: hold)
    input  wire                         en_i,
    /// PC control signal
    input  wire [PC_CTRL_WIDTH - 1 : 0] ctrl_i,
    /// EXE stage PC (base for PC_ADD / PC_COND)
    input  wire [   ADDR_WIDTH - 1 : 0] pc_i,
    /// EXE stage third operand (branch/jump immediate)
    input  wire [   ADDR_WIDTH - 1 : 0] op3_i,
    /// EXE result (target, comparator flag on bit[0] for PC_COND, etc.)
    input  wire [   ADDR_WIDTH - 1 : 0] exe_out_i,
    /// Updated PC
    output wire [   ADDR_WIDTH - 1 : 0] pc_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// Next program counter (combinational)
  logic [ADDR_WIDTH - 1 : 0] programCounter;

  /* registers */
  /// Registered PC
  reg   [ADDR_WIDTH - 1 : 0] pc_q;
  /// Registered enable flag
  reg                        en_q;
  /// Registered control
  reg   [ PC_CTRL_WIDTH-1:0] ctrl_q;
  /// Registered EXE stage PC
  reg   [ADDR_WIDTH - 1 : 0] pc_i_q;
  /// Registered third operand (imm)
  reg   [ADDR_WIDTH - 1 : 0] op3_q;
  /// Registered EXE output
  reg   [ADDR_WIDTH - 1 : 0] exe_out_q;
  /********************             ********************/




  /// PC inputs registration
  /*!
  * Captures inputs and the current PC. PC is updated with the
  * combinational next value `programCounter`.
  */
  always_ff @(posedge clk_i) begin : inputs
    if (!rstn_i) begin
      pc_q      <= StartAddress;
      en_q      <= 1'b0;
      ctrl_q    <= 'b0;
      pc_i_q    <= '0;
      op3_q     <= '0;
      exe_out_q <= '0;
    end
    else begin
      pc_q      <= programCounter;
      en_q      <= en_i;
      ctrl_q    <= ctrl_i;
      pc_i_q    <= pc_i;
      op3_q     <= op3_i;
      exe_out_q <= exe_out_i;
    end
  end


  /// PC next-value generation
  /*!
  * Computes the next PC according to the registered control.
  * - PC_INC : increment by 4 (no C-ext).
  * - PC_SET : set to EXE target, force LSB=0 (alignment).
  * - PC_ADD : pc_i + exe_out (e.g., AUIPC/JAL style update).
  * - PC_COND: if exe_out_q[0]==1 (taken), pc_i + op3; else fall-through +4.
  */
  always_comb begin : pc_gen
    if (!rstn_i) begin
      programCounter = pc_q;
    end
    else if (en_q) begin
      case (ctrl_q)
        PC_INC:  programCounter = pc_q + 4;
        PC_SET:  programCounter = {exe_out_q[DATA_WIDTH-1:1], 1'b0};
        PC_ADD:  programCounter = pc_i_q + exe_out_q;
        PC_COND: programCounter = exe_out_q[0] ? pc_i_q + op3_q : pc_q + 4;
        default: programCounter = pc_q + 4;
      endcase
    end
    else begin
      programCounter = pc_q;
    end
  end

  /// Output driven by pc_gen
  assign pc_o = programCounter;



endmodule

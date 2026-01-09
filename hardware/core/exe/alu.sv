// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       alu.sv
\brief      SCHOLAR RISC-V core arithmetic and logic unit
\author     Kawanami
\date       17/12/2025
\version    1.0

\details
  This module implements the arithmetic and logic unit
  of the SCHOLAR RISC-V processor core.

  Its main role is to perform the actual computation
  specified by each instruction, using the control signal
  computed by the previous stage.

  This unit typically involves arithmetic and logical operations
  (performed by the ALU), as well as comparisons used by branch instructions.

  The operands (`RS1`, `RS2` or immediate) are provided by the decode stage
  through `op1_i` and `op2_i`.
  The computed result is then forwarded to the mem stage,
  writeback stage or the controller,
  either for memory access, register write-back,
  or control flow resolution (e.g., branch target).

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section alu_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 17/12/2025 | Kawanami   | Initial version of the module.            |
********************************************************************************
*/

/*!
* Import useful packages.
*/
import core_pkg::DATA_WIDTH;
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
import core_pkg::EXE_ADDW;
import core_pkg::EXE_SUBW;
import core_pkg::EXE_SLLW;
import core_pkg::EXE_SRLW;
import core_pkg::EXE_SRAW;
import core_pkg::EXE_EQ;
import core_pkg::EXE_NE;
import core_pkg::EXE_GE;
import core_pkg::EXE_GEU;
/**/

/* verilator lint_off UNUSEDSIGNAL */
module alu #(
) (
    /// System active low reset
    input  wire                          rstn_i,
    /// Operation result is valid
    output wire                          valid_o,
    /// First operand
    input  wire [    DATA_WIDTH - 1 : 0] op1_i,
    /// Second operand
    input  wire [    DATA_WIDTH - 1 : 0] op2_i,
    /// Operation selector
    input  wire [EXE_CTRL_WIDTH - 1 : 0] ctrl_i,
    /// Operation result
    output wire [DATA_WIDTH     - 1 : 0] out_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */
  /*!
  * This function verifies if the input control signal is valid or not.
  * It is considered as valid if different from zero.
  */
  function automatic logic exe_ctrl_is_valid(input logic [EXE_CTRL_WIDTH - 1:0] alu_ctrl);
    return |alu_ctrl;
  endfunction
  /* wires */
  /// Operation result
  logic [DATA_WIDTH - 1 : 0] out;
  /// Valid flag (1: valid  0: not valid)
  logic                      valid;
  /* registers */

  /********************             ********************/

  /// Valid generation
  /*!
  * `valid` is asserted when the operation to perform is supported.
  */
  always_comb begin : ctrl
    if (exe_ctrl_is_valid(ctrl_i)) begin
      valid = 1'b1;
    end
    else begin
      valid = 1'b0;
    end
  end

  /// Output driven by ctrl
  assign valid_o = valid;

  /// ALU
  /*!
  * This block computes the result of the operation
  * based on the decoded control signal (`ctrl_i`)
  * and the two operands (`op1_i`, `op2_i`),
  * both coming from the decode stage.
  *
  * The `ctrl_i` signal selects
  * the arithmetic or logical operation to apply.
  *
  * - Arithmetic/logical operations (`ADD`, `SUB`, `SLL`, etc.)
  *   directly apply the operation to `op1_i` and `op2_i`.
  *
  * - Shift amounts are truncated to log2(`DATA_WIDTH`) bits (as per RISC-V spec).
  *
  * - Comparison operations return 1 or 0 depending on
  *   the result (used in branches or `SLT`/`SLTU`).
  *
  * - Signed operations use `$signed()` to enforce correct signed behavior.
  *
  * For RV64I, the "word" operations use the 32 less significant bits to
  * calculate the output.
  *
  * If `ctrl_i` does not match a valid operation, the output defaults to zero.
  */
  generate
    if (DATA_WIDTH == 64) begin : gen_alu_64

      always_comb begin : alu
        out = '0;
        case (ctrl_i)

          EXE_ADD:  out = op1_i + op2_i;
          EXE_SUB:  out = op1_i - op2_i;
          EXE_SLL:  out = op1_i << op2_i[$clog2(DATA_WIDTH)-1 : 0];
          EXE_SRL:  out = op1_i >> op2_i[$clog2(DATA_WIDTH)-1 : 0];
          EXE_SRA:  out = $signed(op1_i) >>> op2_i[$clog2(DATA_WIDTH)-1 : 0];
          EXE_SLT:  out = ($signed(op1_i) < $signed(op2_i)) ? 1 : 0;
          EXE_SLTU: out = (op1_i < op2_i) ? 1 : 0;
          EXE_XOR:  out = op1_i ^ op2_i;
          EXE_OR:   out = op1_i | op2_i;
          EXE_AND:  out = op1_i & op2_i;

          EXE_ADDW: out[31:0] = op1_i[31:0] + op2_i[31:0];
          EXE_SUBW: out[31:0] = op1_i[31:0] - op2_i[31:0];
          EXE_SLLW: out[31:0] = op1_i[31:0] << op2_i[4 : 0];
          EXE_SRLW: out[31:0] = op1_i[31:0] >> op2_i[4 : 0];
          EXE_SRAW: out[31:0] = $signed(op1_i[31:0]) >>> op2_i[4 : 0];

          EXE_EQ:  out = (op1_i == op2_i) ? 1 : 0;
          EXE_NE:  out = (op1_i != op2_i) ? 1 : 0;
          EXE_GE:  out = ($signed(op1_i) >= $signed(op2_i)) ? 1 : 0;
          EXE_GEU: out = (op1_i >= op2_i) ? 1 : 0;

          default: out = '0;

        endcase
      end

      /// Output driven by alu
      assign out_o = ctrl_i[4] ? {{DATA_WIDTH - 32{out[31]}}, out[31:0]} : out;

    end
    else begin : gen_alu_32

      always_comb begin : alu
        out = '0;
        case (ctrl_i)

          EXE_ADD:  out = op1_i + op2_i;
          EXE_SUB:  out = op1_i - op2_i;
          EXE_SLL:  out = op1_i << op2_i[$clog2(DATA_WIDTH)-1 : 0];
          EXE_SRL:  out = op1_i >> op2_i[$clog2(DATA_WIDTH)-1 : 0];
          EXE_SRA:  out = $signed(op1_i) >>> op2_i[$clog2(DATA_WIDTH)-1 : 0];
          EXE_SLT:  out = ($signed(op1_i) < $signed(op2_i)) ? 1 : 0;
          EXE_SLTU: out = (op1_i < op2_i) ? 1 : 0;
          EXE_XOR:  out = op1_i ^ op2_i;
          EXE_OR:   out = op1_i | op2_i;
          EXE_AND:  out = op1_i & op2_i;

          EXE_EQ:  out = (op1_i == op2_i) ? 1 : 0;
          EXE_NE:  out = (op1_i != op2_i) ? 1 : 0;
          EXE_GE:  out = ($signed(op1_i) >= $signed(op2_i)) ? 1 : 0;
          EXE_GEU: out = (op1_i >= op2_i) ? 1 : 0;

          default: out = '0;

        endcase
      end

      /// Output driven by alu
      assign out_o = out;

    end
  endgenerate



endmodule

// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe.sv
\brief      SCHOLAR RISC-V core execution module
\author     Kawanami
\date       21/09/2025
\version    1.1

\details
  This module implements the execution (exe) unit
  of the SCHOLAR RISC-V processor core.

  Its main role is to perform the actual computation
  specified by each instruction, using the control signal
  computed by the previous unit.

  This unit typically involves arithmetic and logical operations
  (performed by the ALU), as well as comparisons used by branch instructions.

  The operands (`RS1`, `RS2` or immediate) are provided by the decode unit
  through `op1_i` and `op2_i`.
  The computed result is then forwarded to the write_back unit,
  either for memory access, register write-back,
  or control flow resolution (e.g., branch target).

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section exe_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/07/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 21/09/2025 | Kawanami   | Remove packages.sv and provide useful metadata through parameters.<br>Add RV64 support.<br>Update the whole file for coding style compliance.<br>Update the whole file comments for doxygen support. |
********************************************************************************
*/
module exe #(
    /// Width of data paths (in bits)
    parameter int                          DataWidth    = 32,
    /// Width of the execution unit control signal
    parameter int                          ExeCtrlWidth = 5,
    /// Add operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Add          = 5'b00000,
    /// Sub operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Sub          = 5'b00001,
    /// Shift Left Logical operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Sll          = 5'b00010,
    /// Shift Right Logical operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Srl          = 5'b00011,
    /// Shift Right Arithmetic operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Sra          = 5'b00100,
    /// Set on Less Than operation code (signed)
    parameter logic [ExeCtrlWidth - 1 : 0] Slt          = 5'b00101,
    /// Set on Less Than operation code (unsigned)
    parameter logic [ExeCtrlWidth - 1 : 0] Sltu         = 5'b00110,
    /// Bitwise Xor operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Xor          = 5'b00111,
    /// Bitwise Or operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Or           = 5'b01000,
    /// Bitwise And operation code
    parameter logic [ExeCtrlWidth - 1 : 0] And          = 5'b01001,
    /// Compare Equal operation code (branch condition)
    parameter logic [ExeCtrlWidth - 1 : 0] Eq           = 5'b01010,
    /// Compare Not Equal operation code (branch condition)
    parameter logic [ExeCtrlWidth - 1 : 0] Ne           = 5'b01011,
    /// Greater or Equal operation code (signed compare)
    parameter logic [ExeCtrlWidth - 1 : 0] Ge           = 5'b01100,
    /// Greater or Equal Unsigned operation code (unsigned compare)
    parameter logic [ExeCtrlWidth - 1 : 0] Geu          = 5'b01101,
    /// Add Word operation code (RV64 only)
    parameter logic [ExeCtrlWidth - 1 : 0] Addw         = 5'b10000,
    /// Sub Word operation code (RV64 only)
    parameter logic [ExeCtrlWidth - 1 : 0] Subw         = 5'b10001,
    /// Shift Left Logical Word operation code (RV64 only)
    parameter logic [ExeCtrlWidth - 1 : 0] Sllw         = 5'b10010,
    /// Shift Right Logical Word operation code (RV64 only)
    parameter logic [ExeCtrlWidth - 1 : 0] Srlw         = 5'b10011,
    /// Shift Right Arithmetic Word operation code (RV64 only)
    parameter logic [ExeCtrlWidth - 1 : 0] Sraw         = 5'b10100
) (
    /* Decode signals */
    /// First operand
    input  wire [DataWidth     - 1 : 0] op1_i,
    /// Second operand
    input  wire [DataWidth     - 1 : 0] op2_i,
    /// Operation to perform
    input  wire [ ExeCtrlWidth - 1 : 0] exe_ctrl_i,
    /* Output signal */
    /// Operation result
    output wire [DataWidth     - 1 : 0] out_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// Operation result
  logic [DataWidth - 1 : 0] out;

  /* registers */
  /********************             ********************/

  /// ALU
  /*!
  * This block computes the result of the operation
  * based on the decoded control signal (`exe_ctrl_i`)
  * and the two operands (`op1_i`, `op2_i`),
  * both coming from the decode unit.
  *
  * The `exe_ctrl_i` signal selects
  * the arithmetic or logical operation to apply.
  *
  * - Arithmetic/logical operations (`ADD`, `SUB`, `SLL`, etc.)
  *   directly apply the operation to `op1_i` and `op2_i`.
  *
  * - Shift amounts are truncated to log2(`DataWidth`) bits (as per RISC-V spec).
  *
  * - Comparison operations return 1 or 0 depending on
  *   the result (used in branches or `SLT`/`SLTU`).
  *
  * - Signed operations use `$signed()` to enforce correct signed behavior.
  *
  * For RV64I, the "word" operations use the 32 less significant bits to
  * calculate the output.
  *
  * If `exe_ctrl_i` does not match a valid operation, the output defaults to zero.
  */
  generate
    if (DataWidth == 64) begin : gen_alu_64

      always_comb begin : alu
        out = '0;
        case (exe_ctrl_i)

          Add:  out = op1_i + op2_i;
          Sub:  out = op1_i - op2_i;
          Sll:  out = op1_i << op2_i[$clog2(DataWidth)-1 : 0];
          Srl:  out = op1_i >> op2_i[$clog2(DataWidth)-1 : 0];
          Sra:  out = $signed(op1_i) >>> op2_i[$clog2(DataWidth)-1 : 0];
          Slt:  out = ($signed(op1_i) < $signed(op2_i)) ? 1 : 0;
          Sltu: out = (op1_i < op2_i) ? 1 : 0;
          Xor:  out = op1_i ^ op2_i;
          Or:   out = op1_i | op2_i;
          And:  out = op1_i & op2_i;

          Addw: out[31:0] = op1_i[31:0] + op2_i[31:0];
          Subw: out[31:0] = op1_i[31:0] - op2_i[31:0];
          Sllw: out[31:0] = op1_i[31:0] << op2_i[4 : 0];
          Srlw: out[31:0] = op1_i[31:0] >> op2_i[4 : 0];
          Sraw: out[31:0] = $signed(op1_i[31:0]) >>> op2_i[4 : 0];

          Eq:  out = (op1_i == op2_i) ? 1 : 0;
          Ne:  out = (op1_i != op2_i) ? 1 : 0;
          Ge:  out = ($signed(op1_i) >= $signed(op2_i)) ? 1 : 0;
          Geu: out = (op1_i >= op2_i) ? 1 : 0;

          default: out = '0;

        endcase
      end

      /// Output driven by alu
      assign out_o = exe_ctrl_i[4] ? {{DataWidth - 32{out[31]}}, out[31:0]} : out;

    end
    else begin : gen_alu_32

      always_comb begin : alu
        out = '0;
        case (exe_ctrl_i)

          Add:  out = op1_i + op2_i;
          Sub:  out = op1_i - op2_i;
          Sll:  out = op1_i << op2_i[$clog2(DataWidth)-1 : 0];
          Srl:  out = op1_i >> op2_i[$clog2(DataWidth)-1 : 0];
          Sra:  out = $signed(op1_i) >>> op2_i[$clog2(DataWidth)-1 : 0];
          Slt:  out = ($signed(op1_i) < $signed(op2_i)) ? 1 : 0;
          Sltu: out = (op1_i < op2_i) ? 1 : 0;
          Xor:  out = op1_i ^ op2_i;
          Or:   out = op1_i | op2_i;
          And:  out = op1_i & op2_i;

          Eq:  out = (op1_i == op2_i) ? 1 : 0;
          Ne:  out = (op1_i != op2_i) ? 1 : 0;
          Ge:  out = ($signed(op1_i) >= $signed(op2_i)) ? 1 : 0;
          Geu: out = (op1_i >= op2_i) ? 1 : 0;

          default: out = '0;

        endcase
      end

      /// Output driven by alu
      assign out_o = out;

    end
  endgenerate



endmodule

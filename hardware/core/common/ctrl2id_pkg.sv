// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       ctrl2id_pkg.sv
\brief      CTRL->ID payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       01/03/2026
\version    1.0

\details
  Defines the packed structure ctrl2id_t transported from the
  Controller to the Instruction Decode (ID) stage.
  It bundles:
    - rs1_dirty      : rs1 dirty flag.
    - rs2_dirty      : rs2 dirty flag.
    - csr_dirty      : csr dirty flag.
    - decode_op1_sel : Decode stage op1 selector (GPR or bypasses).
    - decode_op2_sel : Decode stage op2 selector (GPR or bypasses).
    - decode_op3_sel : Decode stage op3 selector (GPR or bypasses).
    - exe_op3_sel    : Exe stage op3 selector (Decode or bypass).

\remarks


\section ctrl2id_pkg_version_history Version history
| Version | Date       | Author   | Description                           |
|:-------:|:----------:|:---------|:--------------------------------------|
| 1.0     | 01/03/2026 | Kawanami | Initial definition of CTRL->ID payload. |
********************************************************************************
*/


package ctrl2id_pkg;

  import core_pkg::SEL_CTRL_WIDTH;

  typedef struct packed {
    logic rs1_dirty;
    logic rs2_dirty;
    logic csr_dirty;
    logic [SEL_CTRL_WIDTH - 1 : 0] decode_op1_sel;
    logic [SEL_CTRL_WIDTH - 1 : 0] decode_op2_sel;
    logic [SEL_CTRL_WIDTH - 1 : 0] decode_op3_sel;
    // logic [SEL_CTRL_WIDTH - 1 : 0] exe_op1_sel;
    // logic [SEL_CTRL_WIDTH - 1 : 0] exe_op2_sel;
    logic [SEL_CTRL_WIDTH - 1 : 0] exe_op3_sel;
    // logic [SEL_CTRL_WIDTH - 1 : 0] mem_op3_sel;
  } ctrl2id_t;

endpackage

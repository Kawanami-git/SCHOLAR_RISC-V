// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe2pc_pkg.sv
\brief      EXE→PC control payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       19/12/2025
\version    1.0

\details
  Defines the packed structure exe2pc_t transported from the Execute (EXE)
  stage to the Program Counter (PC) updater. It bundles:
    - pc       : PC of the instruction in EXE (base for PC-relative ops),
    - exe_out  : EXE result (e.g., JALR target, branch compare flag),
    - op3      : third operand (e.g., branch/jump immediate),
    - pc_ctrl  : PC control micro-op selecting update mode.

  The pc_ctrl field selects the PC update behavior (see core_pkg):
    - PC_INC  : pc ← pc + 4
    - PC_SET  : pc ← exe_out (aligned if required)
    - PC_ADD  : pc ← pc + exe_out
    - PC_COND : pc ← (exe_out[0] ? pc + op3 : pc + 4)

\remarks
  - Field widths follow XLEN/ADDR settings defined in core_pkg.
  - Encodings for pc_ctrl come from core_pkg.

\section exe2pc_pkg_version_history Version history
| Version | Date       | Author   | Description                                |
|:-------:|:----------:|:---------|:-------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami | Initial definition of EXE→PC payload.      |
********************************************************************************
*/


package exe2pc_pkg;

  import core_pkg::ADDR_WIDTH;
  import core_pkg::DATA_WIDTH;
  import core_pkg::PC_CTRL_WIDTH;

  typedef struct packed {
    logic [ADDR_WIDTH - 1 : 0] pc;
    logic [DATA_WIDTH - 1 : 0] exe_out;
    logic [DATA_WIDTH - 1 : 0] op3;
    logic [PC_CTRL_WIDTH-1:0]  pc_ctrl;
  } exe2pc_t;

endpackage

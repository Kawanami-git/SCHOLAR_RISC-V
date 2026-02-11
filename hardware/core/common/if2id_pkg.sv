// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       if2id_pkg.sv
\brief      IF->ID payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       28/01/2026
\version    1.0

\details
  Defines the packed structure if2id_t transported from the
  Instruction Fetch (IF) stage to the Instruction Decode (ID) stage.
  It bundles:
    - pc     : program counter of the fetched instruction,
    - instr  : raw instruction word.

  Field widths follow the parameters defined in core_pkg
  (e.g., ADDR_WIDTH and INSTR_WIDTH).

\remarks
  - instr is the unmodified instruction as seen at IF output.
  - pc corresponds to the address of instr.

\section if2id_pkg_version_history Version history
| Version | Date       | Author   | Description                           |
|:-------:|:----------:|:---------|:--------------------------------------|
| 1.0     | 28/01/2026 | Kawanami | Initial definition of IF->ID payload. |
********************************************************************************
*/


package if2id_pkg;

  import core_pkg::ADDR_WIDTH;
  import core_pkg::INSTR_WIDTH;

  typedef struct packed {
    logic [ADDR_WIDTH - 1 : 0] pc;
    logic [INSTR_WIDTH-1:0]    instr;
  } if2id_t;

endpackage

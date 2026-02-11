// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       if2ctrl_pkg.sv
\brief      IF->CTRL payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       28/01/2026
\version    1.0

\details
  Defines the packed structure if2ctrl_t transported from the Instruction
  Fetch (IF) stage to the Pipeline Controller (CTRL).

  This payload carries a minimal pre-decode used by the controller for
  dependency tracking and hazard handling.

  It bundles:
    - rs1       : Source register 1 index
    - rs2       : Source register 2 index
    - csr_raddr : Source CSR address (for CSR instructions)

\remarks
  - Field widths follow settings defined in core_pkg.
  - For instructions that do not use rs1/rs2, indices must be set to x0.

\section if2ctrl_pkg_version_history Version history
| Version | Date       | Author   | Description                           |
|:-------:|:----------:|:---------|:--------------------------------------|
| 1.0     | 28/01/2026 | Kawanami | Initial IF→CTRL payload definition.   |
********************************************************************************
*/

package if2ctrl_pkg;

  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;

  typedef struct packed {
    logic [RF_ADDR_WIDTH  - 1 : 0] rs1;
    logic [RF_ADDR_WIDTH  - 1 : 0] rs2;
    logic [CSR_ADDR_WIDTH - 1 : 0] csr_raddr;
  } if2ctrl_t;

endpackage

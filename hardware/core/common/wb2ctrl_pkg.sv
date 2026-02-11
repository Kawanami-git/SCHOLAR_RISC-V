// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       wb2ctrl_pkg.sv
\brief      WB->CTRL payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       28/01/2026
\version    1.0

\details
  Defines the packed structure wb2ctrl_t transported from the Write-Back (WB)
  stage to the Pipeline Controller (CTRL).

  This payload provides the controller with commit information required for
  data hazard handling.

  It bundles:
    - rd        : Destination GPR index written back in WB (when applicable)
    - csr_waddr : Destination CSR address updated by the instruction (when applicable)
    - csr_ctrl  : CSR control micro-op indicating whether/how a CSR is updated

\remarks
  - Field widths follow settings defined in core_pkg.
  - rd may be set to x0 when the instruction does not update the GPR file.

\section wb2ctrl_pkg_version_history Version history
| Version | Date       | Author   | Description                          |
|:-------:|:----------:|:---------|:-------------------------------------|
| 1.0     | 28/01/2026 | Kawanami | Initial WB->CTRL payload definition. |
********************************************************************************
*/

package wb2ctrl_pkg;

  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;

  typedef struct packed {
    logic [RF_ADDR_WIDTH  - 1 : 0] rd;
    logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
    logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;
  } wb2ctrl_t;

endpackage

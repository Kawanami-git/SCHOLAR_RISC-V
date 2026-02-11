// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       mem2ctrl_pkg.sv
\brief      MEM->CTRL payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       28/01/2026
\version    1.0

\details
  Defines the packed structure mem2ctrl_t transported from the Memory (MEM)
  stage to the Pipeline Controller (CTRL).

  This payload provides the controller with information required
  to handle data hazard.

  It bundles:
    - rd        : Destination GPR index (when applicable)
    - csr_waddr : Destination CSR address (when applicable)
    - csr_ctrl  : CSR control micro-op indicating whether/how a CSR is updated

\remarks
  - Field widths follow settings defined in core_pkg.
  - rd may be set to x0 for instructions that do not write the GPR file.

\section mem2ctrl_pkg_version_history Version history
| Version | Date       | Author   | Description                           |
|:-------:|:----------:|:---------|:--------------------------------------|
| 1.0     | 28/01/2026 | Kawanami | Initial MEM->CTRL payload definition. |
********************************************************************************
*/

package mem2ctrl_pkg;

  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;

  typedef struct packed {
    logic [RF_ADDR_WIDTH  - 1 : 0] rd;
    logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
    logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;
  } mem2ctrl_t;

endpackage

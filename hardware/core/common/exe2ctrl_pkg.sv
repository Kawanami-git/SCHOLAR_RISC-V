// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe2ctrl_pkg.sv
\brief      EXE->CTRL payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       28/01/2026
\version    1.0

\details
  Defines the packed structure exe2ctrl_t transported from the Execute (EXE)
  stage to the Pipeline Controller (CTRL). This payload provides the controller
  with all information required to update the program counter and to handle
  control/data hazard.

  It bundles:
    - pc        : Program counter of the instruction in EXE (base for PC-relative ops)
    - rd        : Destination GPR index (when applicable)
    - csr_waddr : Destination CSR address (when applicable)
    - exe_out   : EXE computed value (e.g., JALR target address, branch condition result)
    - op3       : Third operand (e.g., branch/jump immediate)
    - pc_ctrl   : PC control micro-op selecting the update mode
    - csr_ctrl  : CSR control micro-op indicating whether/how a CSR is updated

\remarks
  - Field widths follow XLEN/ADDR settings defined in core_pkg.
  - Encodings for pc_ctrl and csr_ctrl are defined in core_pkg.

\section exe2ctrl_pkg_version_history Version history
| Version | Date       | Author   | Description                             |
|:-------:|:----------:|:---------|:----------------------------------------|
| 1.0     | 28/01/2026 | Kawanami | Initial EXE->CTRL payload definition.    |
********************************************************************************
*/

package exe2ctrl_pkg;

  import core_pkg::ADDR_WIDTH;
  import core_pkg::DATA_WIDTH;
  import core_pkg::PC_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;

  typedef struct packed {
    logic [ADDR_WIDTH     - 1 : 0] pc;
    logic [RF_ADDR_WIDTH  - 1 : 0] rd;
    logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
    logic [DATA_WIDTH     - 1 : 0] exe_out;
    logic [DATA_WIDTH     - 1 : 0] op3;
    logic [PC_CTRL_WIDTH  - 1 : 0] pc_ctrl;
    logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;
  } exe2ctrl_t;

endpackage

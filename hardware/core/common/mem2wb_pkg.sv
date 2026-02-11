// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       mem2wb_pkg.sv
\brief      MEM->WB payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       28/01/2026
\version    1.1

\details
  Defines the packed structure mem2wb_t transported from the Memory (MEM)
  stage to the Write-Back (WB) stage.

  It bundles:
    - exe_out   : MEM-stage forwarded result (typically ALU/address result)
    - op3       : Third operand forwarded to WB (e.g., CSR read value path)
    - rd        : Destination GPR index (when applicable)
    - csr_waddr : Destination CSR address (when applicable)
    - gpr_ctrl  : GPR write-back source select
    - csr_ctrl  : CSR write-back control (if any)
    - mem_ctrl  : Load formatting info (width and sign/zero extension)

  Field widths derive from core_pkg parameters.

\remarks
  - mem_ctrl drives load result formatting in WB (sign/zero extension).

\section mem2wb_pkg_version_history Version history
| Version | Date       | Author   | Description                          |
|:-------:|:----------:|:---------|:-------------------------------------|
| 1.0     | 19/12/2025 | Kawanami | Initial definition of MEM->WB payload |
| 1.1     | 28/01/2026 | Kawanami | Add csr_waddr for CSR data path.     |
********************************************************************************
*/

package mem2wb_pkg;

  import core_pkg::DATA_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;

  typedef struct packed {
    logic [DATA_WIDTH     - 1 : 0] exe_out;
    logic [DATA_WIDTH     - 1 : 0] op3;
    logic [RF_ADDR_WIDTH  - 1 : 0] rd;
    logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
    logic [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl;
    logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;
    logic [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl;
  } mem2wb_t;

endpackage

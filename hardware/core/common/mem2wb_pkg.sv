// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       mem2wb_pkg.sv
\brief      MEM→WB payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       19/12/2025
\version    1.0

\details
  Defines the packed structure mem2wb_t transported from the
  Memory (MEM) stage to the Write-Back (WB) stage. It bundles:
    - exe_out   : execution result forwarded to WB,
    - op3       : third operand (e.g., CSR path / store source),
    - rd        : destination GPR index,
    - gpr_ctrl  : GPR write-back control,
    - csr_ctrl  : CSR control (WB-side usage if applicable),
    - mem_ctrl  : memory read-format info (e.g., sign/width for loads).

  Field widths derive from core_pkg parameters.

\remarks
  - mem_ctrl guides load result formatting in WB (sign/zero extension).
  - csr_ctrl is present for completeness even if some micro-arches
    do not perform CSR writes in WB.

\section mem2wb_pkg_version_history Version history
| Version | Date       | Author   | Description                          |
|:-------:|:----------:|:---------|:-------------------------------------|
| 1.0     | 19/12/2025 | Kawanami | Initial definition of MEM→WB payload |
********************************************************************************
*/


package mem2wb_pkg;

  import core_pkg::DATA_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;

  typedef struct packed {
    logic [DATA_WIDTH - 1 : 0] exe_out;
    logic [DATA_WIDTH - 1 : 0] op3;
    logic [RF_ADDR_WIDTH - 1 : 0] rd;
    logic [GPR_CTRL_WIDTH-1:0] gpr_ctrl;
    logic [CSR_CTRL_WIDTH-1:0] csr_ctrl;
    logic [MEM_CTRL_WIDTH-1:0] mem_ctrl;
  } mem2wb_t;

endpackage

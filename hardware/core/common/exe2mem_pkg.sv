// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe2mem_pkg.sv
\brief      EXE→MEM pipeline payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       19/12/2025
\version    1.0

\details
  Defines the packed structure exe2mem_t transported from the Execute (EXE)
  stage to the Memory (MEM) stage. It bundles:
    - exe_out   : EXE result (ALU/branch evaluation),
    - op3       : third operand (e.g., store data / CSR path),
    - rd        : destination GPR index,
    - mem_ctrl  : memory micro-op (load/store kind, width, sign),
    - gpr_ctrl  : GPR write-back source select,
    - csr_ctrl  : CSR write-back control (if any).

\remarks
  - Encodings for mem_ctrl, gpr_ctrl, csr_ctrl come from core_pkg.
  - Widths follow XLEN settings defined in core_pkg.

\section exe2mem_pkg_version_history Version history
| Version | Date       | Author   | Description                                 |
|:-------:|:----------:|:---------|:--------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami | Initial definition of EXE→MEM payload.      |
********************************************************************************
*/


package exe2mem_pkg;

  import core_pkg::DATA_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;


  typedef struct packed {
    logic [DATA_WIDTH - 1 : 0] exe_out;
    logic [DATA_WIDTH - 1 : 0] op3;
    logic [RF_ADDR_WIDTH - 1 : 0] rd;
    logic [MEM_CTRL_WIDTH-1:0] mem_ctrl;
    logic [GPR_CTRL_WIDTH-1:0] gpr_ctrl;
    logic [CSR_CTRL_WIDTH-1:0] csr_ctrl;
  } exe2mem_t;

endpackage

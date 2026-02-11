// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe2mem_pkg.sv
\brief      EXE->MEM pipeline payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       28/01/2026
\version    1.1

\details
  Defines the packed structure exe2mem_t transported from the Execute (EXE)
  stage to the Memory (MEM) stage.

  It bundles:
    - exe_out   : EXE computed value (ALU result / address / branch condition result)
    - op3       : Third operand (e.g., store data / CSR read value path)
    - rd        : Destination GPR index (when applicable)
    - csr_waddr : Destination CSR address (when applicable)
    - mem_ctrl  : Memory micro-op (load/store kind, width, sign)
    - gpr_ctrl  : GPR write-back source select
    - csr_ctrl  : CSR write-back control (if any)

\remarks
  - Encodings for mem_ctrl, gpr_ctrl, and csr_ctrl are defined in core_pkg.
  - Field widths follow XLEN settings defined in core_pkg.

\section exe2mem_pkg_version_history Version history
| Version | Date       | Author   | Description                          |
|:-------:|:----------:|:---------|:-------------------------------------|
| 1.0     | 19/12/2025 | Kawanami | Initial EXE->MEM payload definition. |
| 1.1     | 28/01/2026 | Kawanami | Add csr_waddr for CSR data path.     |
********************************************************************************
*/

package exe2mem_pkg;

  import core_pkg::DATA_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;

  typedef struct packed {
    logic [DATA_WIDTH     - 1 : 0] exe_out;
    logic [DATA_WIDTH     - 1 : 0] op3;
    logic [RF_ADDR_WIDTH  - 1 : 0] rd;
    logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
    logic [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl;
    logic [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl;
    logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;
  } exe2mem_t;

endpackage

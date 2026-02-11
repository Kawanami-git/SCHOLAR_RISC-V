// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       id2exe_pkg.sv
\brief      ID->EXE payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       28/01/2026
\version    1.1

\details
  Defines the packed structure id2exe_t transported from the Decode (ID)
  stage to the Execute (EXE) stage.

  It bundles:
    - pc        : Program counter of the decoded instruction
    - op1/op2   : Primary ALU operands
    - op3       : Auxiliary operand (e.g., immediate, store data, CSR read value)
    - rd        : Destination GPR index (when applicable)
    - csr_waddr : Destination CSR address (when applicable)
    - exe_ctrl  : EXE micro-op (ALU operation select)
    - mem_ctrl  : Memory micro-op (load/store kind, width, sign)
    - csr_ctrl  : CSR micro-op (update/idle)
    - gpr_ctrl  : GPR write-back source select
    - pc_ctrl   : PC update control (INC/SET/ADD/COND)

  Field widths follow the XLEN- and address-related parameters defined in
  core_pkg. Control encodings are also defined in core_pkg.

\remarks
  - op3 carries immediate values, store data, or CSR operand depending on the instruction.
  - pc_ctrl cooperates with the PC unit; see core_pkg for encodings.

\section id2exe_pkg_version_history Version history
| Version | Date       | Author   | Description                          |
|:-------:|:----------:|:---------|:-------------------------------------|
| 1.0     | 19/12/2025 | Kawanami | Initial ID->EXE payload definition.  |
| 1.1     | 28/01/2026 | Kawanami | Add csr_waddr for CSR data path.     |
********************************************************************************
*/

package id2exe_pkg;

  import core_pkg::ADDR_WIDTH;
  import core_pkg::DATA_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::EXE_CTRL_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::PC_CTRL_WIDTH;

  typedef struct packed {
    logic [ADDR_WIDTH     - 1 : 0] pc;
    logic [DATA_WIDTH     - 1 : 0] op1;
    logic [DATA_WIDTH     - 1 : 0] op2;
    logic [DATA_WIDTH     - 1 : 0] op3;
    logic [RF_ADDR_WIDTH  - 1 : 0] rd;
    logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
    logic [EXE_CTRL_WIDTH - 1 : 0] exe_ctrl;
    logic [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl;
    logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;
    logic [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl;
    logic [PC_CTRL_WIDTH  - 1 : 0] pc_ctrl;
  } id2exe_t;

endpackage

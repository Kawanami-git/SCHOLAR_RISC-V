// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe2id_pkg.sv
\brief      EXE->ID payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       01/03/2026
\version    1.0

\details
  Defines the packed structure exe2id_t transported from the Execution (EXE)
  stage to the Decode stage (ID).

  This payload provides the Decode stage with information required
  to bypass data hazard.

  It bundles:
    - bypass  : ALU output or op3 of the current instruction in Exe

\remarks
  - Field widths follow settings defined in core_pkg.

\section exe2id_pkg_version_history Version history
| Version | Date       | Author   | Description                           |
|:-------:|:----------:|:---------|:--------------------------------------|
| 1.0     | 01/03/2026 | Kawanami | Initial EXE->ID bypass payload definition. |
********************************************************************************
*/

package exe2id_pkg;

  import core_pkg::DATA_WIDTH;

  typedef struct packed {logic [DATA_WIDTH     - 1 : 0] bypass;} exe2id_t;

endpackage

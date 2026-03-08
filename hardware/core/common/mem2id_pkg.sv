// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       mem2id_pkg.sv
\brief      MEM->ID payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       01/03/2026
\version    1.0

\details
  Defines the packed structure mem2id_t transported from the Memory (MEM)
  stage to the Decode stage (ID).

  This payload provides the Decode stage with information required
  to bypass data hazard.

  It bundles:
    - bypass  : ALU output or op3 of the current instruction in Mem

\remarks
  - Field widths follow settings defined in core_pkg.

\section mem2id_pkg_version_history Version history
| Version | Date       | Author   | Description                           |
|:-------:|:----------:|:---------|:--------------------------------------|
| 1.0     | 01/03/2026 | Kawanami | Initial MEM->ID bypass payload definition. |
********************************************************************************
*/

package mem2id_pkg;

  import core_pkg::DATA_WIDTH;

  typedef struct packed {logic [DATA_WIDTH     - 1 : 0] bypass;} mem2id_t;

endpackage

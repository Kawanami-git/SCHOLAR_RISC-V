// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       wb2id_pkg.sv
\brief      WB->ID payload definition for SCHOLAR RISC-V
\author     Kawanami
\date       01/03/2026
\version    1.0

\details
  Defines the packed structure wb2id_t transported from the Writeback (WB)
  stage to the Decode stage (ID).

  This payload provides the Decode stage with information required
  to bypass data hazard.

  It bundles:
    - bypass  : ALU output, op3 or loaded data of the current instruction in Writeback

\remarks
  - Field widths follow settings defined in core_pkg.

\section wb2id_pkg_version_history Version history
| Version | Date       | Author   | Description                           |
|:-------:|:----------:|:---------|:--------------------------------------|
| 1.0     | 01/03/2026 | Kawanami | Initial WB->ID bypass payload definition. |
********************************************************************************
*/

package wb2id_pkg;

  import core_pkg::DATA_WIDTH;

  typedef struct packed {logic [DATA_WIDTH     - 1 : 0] bypass;} wb2id_t;

endpackage

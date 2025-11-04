// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       csr.sv
\brief      SCHOLAR RISC-V core control/status registers file module
\author     Kawanami
\date       23/09/2025
\version    1.1

\details
  This module implements the SCHOLAR RISC-V
  Control and Status Register (CSR) file.

  It currently supports only the `mcycle` register,
  which counts the number of cycles since reset.
  According to the RISC-V specification, `mcycle` can be accessed through:
    - Address 0xC00 → lower 32 bits (LSB)
    - Address 0xC80 → upper 32 bits (MSB)

  For simplicity, this implementation only provides access
  to the lower 32 bits (`mcycle[31:0]`), and this value
  is returned through the `csr_val_o` output regardless of the address used.

  The `mcycle` register is read-only: writes to it are ignored,
  and no write-enable logic is implemented.

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section csr_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/07/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 23/09/2025 | Kawanami   | Remove packages.sv and provide useful metadata through parameters.<br>Add RV64 support.<br>Update the whole file for coding style compliance.<br>Update the whole file comments for doxygen support. |
********************************************************************************
*/
module csr #(
    /// Width of data paths (in bits)
    parameter int DataWidth    = 32,
    /// Number of bits for addressing the CSRs
    parameter int CsrAddrWidth = 12
) (
`ifdef SIM
    /// CSR mcycle register (SIM only)
    output wire [DataWidth - 1 : 0] mcycle_q_o,
`endif

    /// System clock
    input  wire                         clk_i,
    /// System active low reset
    input  wire                         rstn_i,
    /* verilator lint_off UNUSED */
    /// CSR write address
    input  wire [ CsrAddrWidth - 1 : 0] csr_waddr_i,
    /// Data to write in the CSR
    input  wire [DataWidth     - 1 : 0] csr_val_i,
    /// Data to write in the CSR valid flag
    input  wire                         csr_valid_i,
    /// CSR read address
    input  wire [ CsrAddrWidth - 1 : 0] raddr_i,
    /* verilator lint_on UNUSED */
    /// CSR read value
    output wire [DataWidth     - 1 : 0] csr_val_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */

  /* registers */
  /// mcycle register
  reg [63 : 0] mcycle_q;
  /********************             ********************/


  /*!
  * This block implements the `mcycle` CSR,
  * which counts the number of clock cycles since reset.
  *
  * - The register is incremented on every rising edge of `CLK`.
  * - On reset (`RSTN` low), it is initialized to 0.
  *
  * - The CSR is read-only and does not support write operations.
  *   Since `mcycle` is the only CSR available in this module,
  *   the output `csr_val_o` always returns its lower bits (`mcycle[DataWidth-1:0]`),
  *   regardless of the address.
  *
  * - Reads are handled combinatorially and reflect
  *   the current value of the cycle counter.
  *
  * This register can be used for basic performance monitoring
  * or instruction timing analysis.
  */
  always_ff @(posedge clk_i) begin : mcycle
    if (!rstn_i) mcycle_q <= '0;
    else mcycle_q <= mcycle_q + 1;
  end

  /// Output driven by mcycle
  assign csr_val_o = mcycle_q[DataWidth-1:0];



  /*!
  * This block is active only when the design is simulated (SIM).
  * It forwards the control/status registers (CSRs)
  * to Verilator for verification of the core's internal states.
  */
`ifdef SIM
  /// Provide access to the CSR mcycle through `csr_mcycle_q_o`
  assign mcycle_q_o = mcycle_q[DataWidth-1:0];
`endif

endmodule

// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       csr.sv
\brief      SCHOLAR RISC-V core control/status registers file module
\author     Kawanami
\date       01/05/2026
\version    1.5

\details
  This module implements the SCHOLAR RISC-V
  Control and Status Register (CSR) file.

  It currently supports only the `mcycle` register,
  which counts the number of cycles since reset.
  According to the RISC-V specification, `mcycle` can be accessed through:
    - Address 0xB00 → lower 32 bits (LSB)
    - Address 0xB80 → upper 32 bits (MSB)

  For simplicity, for the 32-bit architecture,
  this implementation only provides access
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
| 1.2     | 29/12/2025 | Kawanami   | Update header documentation. |
| 1.3     | 28/03/2026 | Kawanami   | Add simulation-driven signals for spike compatibility. |
| 1.4     | 29/03/2026 | Kawanami   | Improve global lisibility by using package instead of parameters. |
| 1.5     | 01/05/2026 | Kawanami   | Global refactor of the CSR module. |
********************************************************************************
*/
module csr

  import core_pkg::CSR_ADDR_WIDTH;

#(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi              = 32,
    /* verilator lint_off UNUSEDPARAM */
    /// Enable performance Counters
    parameter bit          EnablePerfCounters = 1'b1
    /* verilator lint_on UNUSEDPARAM */
) (
`ifdef SIM
    /// Simulation CSR overwrite enable
    input  wire                          en_i,
    /// Simulation CSR overwrite data
    input  wire [Archi          - 1 : 0] data_i,
`endif
    /// System clock
    input  wire                          clk_i,
    /// System active low reset
    input  wire                          rstn_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// CSR write address
    input  wire [CSR_ADDR_WIDTH - 1 : 0] waddr_i,
    /// CSR write enable
    input  wire                          wen_i,
    /// Data to write in the CSR
    input  wire [     Archi     - 1 : 0] wdata_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// CSR read address
    input  wire [CSR_ADDR_WIDTH - 1 : 0] raddr_i,
    /// CSR read value
    output wire [     Archi     - 1 : 0] rdata_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER0_ADDR_HI = 'hb80;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER0_ADDR = 'hb00;

  /* functions */

  /* wires */
  /// Read data
  logic [Archi - 1 : 0] rdata;

  /* registers */
  /// mhpmcounter0 register (mcycle)
  reg   [       63 : 0] mhpmcounter0_q;
  /********************             ********************/

  /// mhpmcounters write logic
  /*!
  * This block drives the mhpmcounter0 register.
  *
  * This register is read-only and cannot be
  * overwritten using CSR instructions.
  *
  * this register can be used for basic performance monitoring
  * or instruction timing analysis.
  */
  always_ff @(posedge clk_i) begin : mhpmcounters_write
    if (!rstn_i) begin
      mhpmcounter0_q <= '0;
    end
    else begin
      mhpmcounter0_q <= mhpmcounter0_q + 1;
    end
  end

  /// CSR read logic
  /*!
  * This block drives rdata according to raddr_i.
  * On RV32, the low and high halves are exposed through the standard CSR addresses.
  * On RV64, both low and high addresses return the full 64-bit counter value for compatibility.
  */
  generate
    if (Archi == 64) begin : gen_csrs_read_64
      always_comb begin : csrs_read
        case (raddr_i)
          MHPMCOUNTER0_ADDR_HI, MHPMCOUNTER0_ADDR: rdata = mhpmcounter0_q;
          default:                                 rdata = '0;
        endcase
      end
    end
    else begin : gen_csrs_read_32
      always_comb begin : csrs_read
        case (raddr_i)
          MHPMCOUNTER0_ADDR_HI: rdata = mhpmcounter0_q[63:32];
          MHPMCOUNTER0_ADDR:    rdata = mhpmcounter0_q[31:0];
          default:              rdata = '0;
        endcase
      end
    end
  endgenerate

`ifdef SIM
  /// Output driven by csrs_read
  assign rdata_o = en_i ? data_i : rdata;
`else
  /// Output driven by csrs_read
  assign rdata_o = rdata;
`endif

endmodule

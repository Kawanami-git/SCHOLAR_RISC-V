// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       csr.sv
\brief      SCHOLAR RISC-V core control/status registers file module
\author     Kawanami
\date       28/01/2026
\version    1.1

\details
  This module implements the SCHOLAR RISC-V
  Control and Status Register (CSR) file.

  It currently supports a cycle counter (mhpmcounter0, mapped to the standard mcycle CSR addresses), mhpmcounter3 (stall cycles) and mhpmcounter4 (softresetn events).

  According to the RISC-V specification, `mhpmcounter0` can be accessed through:
    - Address 0xB00 → lower 32 bits (LSB)
    - Address 0xB80 → upper 32 bits (MSB)

  `mhpmcounter3` can be accessed through:
    - Address 0xB03 → lower 32 bits (LSB)
    - Address 0xB83 → upper 32 bits (MSB)

  `mhpmcounter4` can be accessed through:
    - Address 0xB04 → lower 32 bits (LSB)
    - Address 0xB84 → upper 32 bits (MSB)

 These registers are read-only: writes to them are ignored,
  and no write-enable logic is implemented.

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section csr_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 28/01/2026 | Kawanami   | Add RV32 hi-addresses, RV64-compatible CSR address aliases and return zero on unsupported CSR reads. |
********************************************************************************
*/

module csr

  /*!
* Import useful packages.
*/
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::ADDR_WIDTH;
  import core_pkg::DATA_WIDTH;
/**/

#(
) (
`ifdef SIM
    /// CSR mhpmcounter0 register (SIM only)
    output wire [DATA_WIDTH - 1 : 0] mhpmcounter0_q_o,
    /// CSR mhpmcounter3 register (SIM only)
    output wire [DATA_WIDTH - 1 : 0] mhpmcounter3_q_o,
    /// CSR mhpmcounter4 register (SIM only)
    output wire [DATA_WIDTH - 1 : 0] mhpmcounter4_q_o,
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
    input  wire [DATA_WIDTH     - 1 : 0] wdata_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// CSR read address
    input  wire [CSR_ADDR_WIDTH - 1 : 0] raddr_i,
    /// CSR read value
    output wire [DATA_WIDTH     - 1 : 0] rdata_o,
    /// Data hazard stall (rs1 or rs1 dirty)
    input  wire                          mhpmevent3,
    /// Softreset event
    input  wire                          mhpmevent4
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER0_ADDR_HI = 'hb80;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER0_ADDR = 'hb00;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER3_ADDR_HI = 'hb83;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER3_ADDR = 'hb03;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER4_ADDR_HI = 'hb84;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER4_ADDR = 'hb04;

  /* functions */

  /* wires */
  /// Read data
  logic [DATA_WIDTH - 1 : 0] rdata;


  /* registers */
  /// mhpmcounter0 register (mcycle)
  reg   [            63 : 0] mhpmcounter0_q;
  /// mhpmcounter3 register (stall)
  reg   [            63 : 0] mhpmcounter3_q;
  /// mhpmcounter4 register (taken branches)
  reg   [            63 : 0] mhpmcounter4_q;

  /********************             ********************/

  /// mhpmcounters write logic
  /*!
  * This block drives the mhpmcounter0, mhpmcounter3,
  * and mhpmcounter4 registers.
  *
  * The mhpmcounter0 counts the number of clock cycles since reset.
  * The mhpmcounter3 counts the number of stalled cycles.
  * The mhpmcounter4 count the number of taken branches.
  *
  * All of these registers are read-only and cannot be
  * overwritten using CSR instructions.
  *
  * These registers can be used for basic performance monitoring
  * or instruction timing analysis.
  */
  always_ff @(posedge clk_i) begin : mhpmcounters_write
    if (!rstn_i) begin
      mhpmcounter0_q <= '0;
      mhpmcounter3_q <= '0;
      mhpmcounter4_q <= '0;
    end
    else begin
      mhpmcounter0_q <= mhpmcounter0_q + 1;
      if (mhpmevent3) mhpmcounter3_q <= mhpmcounter3_q + 1;
      if (mhpmevent4) mhpmcounter4_q <= mhpmcounter4_q + 1;
    end
  end


  /// CSR read logic
  /*!
  * This block drives rdata according to raddr_i.
  * On RV32, the low and high halves are exposed through the standard CSR addresses.
  * On RV64, both low and high addresses return the full 64-bit counter value for compatibility.
  */
  generate
    if (DATA_WIDTH == 64) begin : gen_csrs_read_64
      always_comb begin : csrs_read
        case (raddr_i)
          MHPMCOUNTER0_ADDR_HI, MHPMCOUNTER0_ADDR: rdata = mhpmcounter0_q[DATA_WIDTH-1:0];
          MHPMCOUNTER3_ADDR_HI, MHPMCOUNTER3_ADDR: rdata = mhpmcounter3_q[DATA_WIDTH-1:0];
          MHPMCOUNTER4_ADDR_HI, MHPMCOUNTER4_ADDR: rdata = mhpmcounter4_q[DATA_WIDTH-1:0];
          default:                                 rdata = '0;
        endcase
      end
    end
    else begin : gen_csrs_read_32
      always_comb begin : csrs_read
        case (raddr_i)
          MHPMCOUNTER0_ADDR_HI: rdata = mhpmcounter0_q[63:32];
          MHPMCOUNTER0_ADDR:    rdata = mhpmcounter0_q[31:0];
          MHPMCOUNTER3_ADDR_HI: rdata = mhpmcounter3_q[63:32];
          MHPMCOUNTER3_ADDR:    rdata = mhpmcounter3_q[31:0];
          MHPMCOUNTER4_ADDR_HI: rdata = mhpmcounter4_q[63:32];
          MHPMCOUNTER4_ADDR:    rdata = mhpmcounter4_q[31:0];
          default:              rdata = '0;
        endcase
      end
    end
  endgenerate

  /// Output driven by csrs_read
  assign rdata_o = rdata;


  /*!
  * This block is active only when the design is simulated (SIM).
  * It forwards the control/status registers (CSRs)
  * to Verilator for verification of the core's internal states.
  */
`ifdef SIM
  /// Provide access to the CSR mhpmcounter0_q through `mhpmcounter0_q_o`
  assign mhpmcounter0_q_o = mhpmcounter0_q[DATA_WIDTH-1:0];
  /// Provide access to the CSR mhpmcounter3_q through `mhpmcounter3_q_o`
  assign mhpmcounter3_q_o = mhpmcounter3_q[DATA_WIDTH-1:0];
  /// Provide access to the CSR mhpmcounter4_q through `mhpmcounter4_q_o`
  assign mhpmcounter4_q_o = mhpmcounter4_q[DATA_WIDTH-1:0];
`endif

endmodule

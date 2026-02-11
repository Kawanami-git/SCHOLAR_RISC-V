// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       gpr.sv
\brief      SCHOLAR RISC-V core General Purpose Registers file module
\author     Kawanami
\date       30/01/2026
\version    1.1

\details
  This module implements the SCHOLAR RISC-V register file.
  It contains all general-purpose registers (GPRs).
  It consists of a RAM with two read ports
  (for operand fetch) and one write port (for result storage).

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section gpr_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 30/01/2026 | Kawanami   | Comments improvment and use local package import instead of global. |
********************************************************************************
*/

module gpr

  /*!
* Import useful packages.
*/
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::DATA_WIDTH;
  import core_pkg::NB_GPR;
/**/

#(
) (
`ifdef SIM
    /// GPR write enable (SIM only)
    input  wire                         en_i,
    /// GPR write address (SIM only)
    input  wire [RF_ADDR_WIDTH - 1 : 0] addr_i,
    /// GPR write data (SIM only)
    input  wire [DATA_WIDTH    - 1 : 0] data_i,
    /// GPR memory (SIM only)
    output wire [DATA_WIDTH    - 1 : 0] memory_o[NB_GPR],
`endif

    /// System clock
    input  wire                         clk_i,
    /// System active low reset
    input  wire                         rstn_i,
    /// Register Source 1 (rs1)
    input  wire [RF_ADDR_WIDTH - 1 : 0] rs1_i,
    /// Register Source 2 (rs2)
    input  wire [RF_ADDR_WIDTH - 1 : 0] rs2_i,
    /// Writeback stage data valid
    input  wire                         wb_valid_i,
    /// Destination register address
    input  wire [RF_ADDR_WIDTH - 1 : 0] rd_i,
    /// Data written to destination register
    input  wire [DATA_WIDTH    - 1 : 0] rd_data_i,
    /// Register Source 1 value
    output wire [DATA_WIDTH    - 1 : 0] rs1_data_o,
    /// Register Source 1 value
    output wire [DATA_WIDTH    - 1 : 0] rs2_data_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
`ifndef SIM
  /// writeback valid
  logic                         wb_valid;
  /// Destination register
  logic [RF_ADDR_WIDTH - 1 : 0] rd;
  /// Destination register data
  logic [   DATA_WIDTH - 1 : 0] rd_data;
`endif

  /* registers */
`ifdef SIM
  /// General Purpose Registers (SIM ONLY). x0 = mem[0], x1 = mem[1] ... x31 = mem[31].
  reg [DATA_WIDTH - 1 : 0] mem[NB_GPR];
`endif
  /********************             ********************/

`ifdef SIM
  /// GPR & PC management (SIM ONLY)
  /*!
  * Write operations are performed synchronously,
  * while read operations are handled asynchronously.
  * On reset, the pc_o register is initialized to `StartAddress`
  * and the register 0 is initialized with zeroes.
  * Not resetting the other registers does not affect system behavior,
  * and it helps to reduce hardware costs.
  *
  * The pc_o register is updated each cycle. Thus, to hold an instruction,
  * the `pc_next_i` shall remain the same.
  * Memory (mem) is updated only if:
  *   - The address is valid (i.e., greater than 0, to prevent writing to register x0).
  *   - `rd_valid_i` is asserted, indicating that the data input is valid for writing.
  */
  always_ff @(posedge clk_i) begin : gpr_write
    if (!rstn_i) mem[0] <= '0;
    else if (rd_i != '0 && wb_valid_i) mem[rd_i] <= rd_data_i;
  end

  /// Register source 1 value according to Register source address (SIM ONLY)
  assign rs1_data_o = mem[rs1_i];
  /// Register source 2 value according to Register source address (SIM ONLY)
  assign rs2_data_o = mem[rs2_i];


  /// GPR debug access (SIM ONLY)
  /*
  * This block is active only when the design is simulated (SIM).
  * It forwards the General Purpose Registers (GPRs)
  * to Verilator for verification of the core's internal states.
  * This also allows Verilator to modify these internal states during testing.
  */
  always_latch begin : gpr_debug
    if (en_i && (addr_i != '0)) mem[addr_i] = data_i;
  end

  /// Provide access to the GPR internal memory through `memory_o` (SIM ONLY)
  assign memory_o = mem;

`else

  /// x0 reset
  /*!
  * This block allows to set GPR x0 to 0 when
  * the core is under reset.
  * Otherwise, it fowards the writeback stage
  * write requests.
  */
  always_comb begin : x0_reset
    if (!rstn_i) begin
      wb_valid = 1'b1;
      rd       = '0;
      rd_data  = '0;
    end
    else begin
      wb_valid = wb_valid_i && rd_i != '0;
      rd       = rd_i;
      rd_data  = rd_data_i;
    end
  end

  generate
    if (core_pkg::DATA_WIDTH == 64) begin : gen_64
      usram_64 gpr_rs1 (
          .W_DATA(rd_data),
          .R_ADDR(rs1_i),
          .W_ADDR(rd),
          .W_EN  (wb_valid),
          .CLK   (clk_i),
          .R_DATA(rs1_data_o)
      );

      usram_64 gpr_rs2 (
          .W_DATA(rd_data),
          .R_ADDR(rs2_i),
          .W_ADDR(rd),
          .W_EN  (wb_valid),
          .CLK   (clk_i),
          .R_DATA(rs2_data_o)
      );
    end
    else begin : gen_32
      usram_32 gpr_rs1 (
          .W_DATA(rd_data),
          .R_ADDR(rs1_i),
          .W_ADDR(rd),
          .W_EN  (wb_valid),
          .CLK   (clk_i),
          .R_DATA(rs1_data_o)
      );

      usram_32 gpr_rs2 (
          .W_DATA(rd_data),
          .R_ADDR(rs2_i),
          .W_ADDR(rd),
          .W_EN  (wb_valid),
          .CLK   (clk_i),
          .R_DATA(rs2_data_o)
      );
    end
  endgenerate

`endif

endmodule

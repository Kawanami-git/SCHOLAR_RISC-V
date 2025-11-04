// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       dpram_40x1024.sv
\brief      40-bit Dual-Port RAM (composed from two 20×1024 Microchip blocks)

\author     Kawanami
\date       17/10/2025
\version    1.0

\details
  This wrapper presents a 40-bit true dual-port RAM by composing two
  `dpram_20x1024` Microchip blocks:
    - **Upper 20-bit slice**  → bits [39:20]
    - **Lower 20-bit slice**  → bits [19:0]

  Both ports (A and B) share address and control semantics. The 40-bit
  write-strobes are abstracted as 4 lanes (`BeWidth=4`) matching the
  usage in 32-bit wrappers (each lane conceptually maps to one data byte when
  interfacing with 32-bit packs that insert pad bits).

\section dpram40x1024_scope Scope and limitations
  - Read and write latency is one cycle (synchronous read; data valid one
    clock after read enable/address sampling).
  - Write strobes are forwarded as two lanes per 20-bit slice:
      - lanes `[3:2]` control writes to bits `[39:20]`
      - lanes `[1:0]` control writes to bits `[19:0]`
    Exact bit-to-byte gating follows the vendor macro semantics.
  - This module is intended as a thin composition layer around the Microchip IP.

\section dpram40x1024_version_history Version history
| Version | Date       | Author   | Description                                 |
|:-------:|:----------:|:---------|:--------------------------------------------|
| 1.0     | 17/10/2025 | Kawanami | Initial version of the module               |
| 1.1     | xx/xx/xxxx | Name     |                                             |
********************************************************************************
*/
module dpram_40x1024 #(
    /// External interface width in bits (kept as a parameter; expected 40)
    parameter int unsigned DataWidth = 40,
    /// Total number of words (expected 1024 for this macro)
    parameter int unsigned Depth     = 1024,
    /// Address width in bits (derived)
    parameter int unsigned AddrWidth = $clog2(Depth),
    /// Number of write-strobe lanes (4 lanes = 2 per 20-bit slice)
    parameter int unsigned BeWidth   = 4
) (
`ifdef SIM
    /// (Simulation only) Exposes the composed 40-bit memory words
    output logic [DataWidth-1:0] mem_o[Depth],
`endif

    //============================= Port A ===================================//
    /// Port A clock
    input  logic                       a_clk_i,
    /// Port A address
    input  logic [AddrWidth   - 1 : 0] a_addr_i,
    /// Port A write data (40-bit)
    input  logic [DataWidth   - 1 : 0] a_din_i,
    /// Port A write-strobes (lanes): [3:2]→upper slice, [1:0]→lower slice
    input  logic [BeWidth     - 1 : 0] a_be_i,
    /// Port A write enable (1 = write)
    input  logic                       a_wren_i,
    /// Port A read  enable (1 = read)
    input  logic                       a_rden_i,
    /// Port A read data (registered, 1-cycle latency)
    output logic [DataWidth   - 1 : 0] a_dout_o,

    //============================= Port B ===================================//
    /// Port B clock
    input  logic                       b_clk_i,
    /// Port B address
    input  logic [AddrWidth   - 1 : 0] b_addr_i,
    /// Port B write data (40-bit)
    input  logic [DataWidth   - 1 : 0] b_din_i,
    /// Port B write-strobes (lanes): [3:2]→upper slice, [1:0]→lower slice
    input  logic [BeWidth     - 1 : 0] b_be_i,
    /// Port B write enable (1 = write)
    input  logic                       b_wren_i,
    /// Port B read  enable (1 = read)
    input  logic                       b_rden_i,
    /// Port B read data (registered, 1-cycle latency)
    output logic [DataWidth   - 1 : 0] b_dout_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* machine states */

  /* functions */

  /* wires */
  generate
`ifdef SIM
    /// Upper 20-bit slice memory view (per word)
    wire [(DataWidth/2) - 1 : 0] mem_hi[Depth];
    /// Lower 20-bit slice memory view (per word)
    wire [(DataWidth/2) - 1 : 0] mem_lo[Depth];
`endif
  endgenerate
  /* registers */

  /********************             ********************/

  /// SIM-only public memory exposure and hi/lo concatenation
  generate
`ifdef SIM
    genvar i;
    /// Concatenate the two 20-bit slices into a single 40-bit word
    for (i = 0; i < Depth; i++) begin : gen_mem_concat
      assign mem_o[i] = {mem_hi[i], mem_lo[i]};
    end
`endif

    /*!
     * Handles bits [39:20] for both ports. Write lanes `a_be_i[3:2]`
     * and `b_be_i[3:2]` are forwarded to this slice.
     */
    dpram_20x1024 ram_hi (
`ifdef SIM
        .mem_o   (mem_hi),
`endif
        .a_clk_i (a_clk_i),
        .a_addr_i(a_addr_i),
        .a_din_i (a_din_i[39:20]),
        .a_be_i  (a_be_i[3:2]),
        .a_wren_i(a_wren_i),
        .a_rden_i(a_rden_i),
        .a_dout_o(a_dout_o[39:20]),
        .b_clk_i (b_clk_i),
        .b_addr_i(b_addr_i),
        .b_din_i (b_din_i[39:20]),
        .b_be_i  (b_be_i[3:2]),
        .b_wren_i(b_wren_i),
        .b_rden_i(b_rden_i),
        .b_dout_o(b_dout_o[39:20])
    );

    /*!
     * Handles bits [19:0] for both ports. Write lanes `a_be_i[1:0]`
     * and `b_be_i[1:0]` are forwarded to this slice.
     */
    dpram_20x1024 ram_lo (
`ifdef SIM
        .mem_o   (mem_lo),
`endif
        .a_clk_i (a_clk_i),
        .a_addr_i(a_addr_i),
        .a_din_i (a_din_i[19:0]),
        .a_be_i  (a_be_i[1:0]),
        .a_wren_i(a_wren_i),
        .a_rden_i(a_rden_i),
        .a_dout_o(a_dout_o[19:0]),
        .b_clk_i (b_clk_i),
        .b_addr_i(b_addr_i),
        .b_din_i (b_din_i[19:0]),
        .b_be_i  (b_be_i[1:0]),
        .b_wren_i(b_wren_i),
        .b_rden_i(b_rden_i),
        .b_dout_o(b_dout_o[19:0])
    );

  endgenerate

endmodule

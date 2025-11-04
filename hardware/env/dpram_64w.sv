// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       dpram_64w.sv
\brief      64-bit Dual-Port RAM (composed from two 32-bit vendor-backed halves)

\author     Kawanami
\date       17/10/2025
\version    1.0

\details
  This module builds a 64-bit true dual-port RAM by composing two instances of
  `dpram_32w`, each implementing a 32-bit-wide, banked dual-port memory based
  on Microchip blocks (20×1024). The 64-bit interface is presented as:
    - upper 32-bit lane (bits [63:32]) handled by `ram_hi`
    - lower 32-bit lane (bits [31:0])  handled by `ram_lo`

  Both ports (A and B) share the same address, clocking, and enable semantics.
  Byte write enables are split between the two 32-bit halves.

\section dpram_64w_scope Scope and limitations
  - Read and write latency is one cycle (read address/enables sampled, data on
    the next rising edge).
  - Byte-enable writes are supported on both ports (8 lanes total, 4 per half).
  - The composition assumes `dpram_32w` exposes synchronous read and per-byte
    write behavior compatible with the underlying vendor IP.

\remarks
  - TODO: .

\section dpram_64w_version_history Version history
| Version | Date       | Author   | Description                                 |
|:-------:|:----------:|:---------|:--------------------------------------------|
| 1.0     | 17/10/2025 | Kawanami | Initial version of the module               |
| 1.1     | xx/xx/xxxx | name     |                                             |
********************************************************************************
*/
module dpram_64w #(
    /// External data width in bits (kept as a parameter; expected 64)
    parameter int unsigned DataWidth = 64,
    /// Total number of 64-bit words (must be a multiple of 1024)
    parameter int unsigned Depth     = 1280,
    /// Address width in bits (derived from Depth)
    parameter int unsigned AddrWidth = $clog2(Depth)
) (
`ifdef SIM
    /// (Simulation only) Exposes the composed 64-bit memory words
    output logic [      DataWidth-1:0] mem_o   [Depth],
`endif
    /// Port A clock
    input  logic                       a_clk_i,
    /// Port A address (word address in the 64-bit logical space)
    input  logic [AddrWidth   - 1 : 0] a_addr_i,
    /// Port A write data (64-bit)
    input  logic [DataWidth   - 1 : 0] a_din_i,
    /// Port A byte-enable (one bit per byte; 8 bits for 64-bit data)
    input  logic [DataWidth/8 - 1 : 0] a_be_i,
    /// Port A write enable (1 = write)
    input  logic                       a_wren_i,
    /// Port A read enable  (1 = read)
    input  logic                       a_rden_i,
    /// Port A read data (registered, 1-cycle latency)
    output logic [DataWidth   - 1 : 0] a_dout_o,
    /// Port B clock
    input  logic                       b_clk_i,
    /// Port B address (word address in the 64-bit logical space)
    input  logic [AddrWidth   - 1 : 0] b_addr_i,
    /// Port B write data (64-bit)
    input  logic [DataWidth   - 1 : 0] b_din_i,
    /// Port B byte-enable (one bit per byte; 8 bits for 64-bit data)
    input  logic [DataWidth/8 - 1 : 0] b_be_i,
    /// Port B write enable (1 = write)
    input  logic                       b_wren_i,
    /// Port B read enable  (1 = read)
    input  logic                       b_rden_i,
    /// Port B read data (registered, 1-cycle latency)
    output logic [DataWidth   - 1 : 0] b_dout_o
);

  /******************** DECLARATION ********************/
  /* local parameters */
  /// Microchip bank depth (in 32-bit words inside dpram_32w; maps to 1024 rows)
  localparam int unsigned RAM_DEPTH = 1024;

  /* parameters verification */
  if (Depth % RAM_DEPTH != 0) begin : gen_Depth_check
    $fatal(0, "FATAL ERROR: Depth (%0d) shall be a multiple of %0d.", Depth, RAM_DEPTH);
  end

  /* machine states */

  /* functions */

  /* wires */

  /* registers */

  /********************             ********************/

  generate
`ifdef SIM
    /// (SIM only) Upper 32-bit lane storage view
    wire [(DataWidth/2) - 1 : 0] mem_hi[Depth];
    /// (SIM only) Lower 32-bit lane storage view
    wire [(DataWidth/2) - 1 : 0] mem_lo[Depth];

    genvar i;
    /// Concatenate simulation views into the 64-bit public array
    for (i = 0; i < Depth; i++) begin : gen_mem_concat
      assign mem_o[i] = {mem_hi[i], mem_lo[i]};
    end
`endif

    /*!
     * `ram_hi` handles the upper 32-bit lane [63:32] for both ports.
     * Byte enable bits [7:4] map to this lane.
     */
    dpram_32w #(
        .Depth(Depth)
    ) ram_hi (
`ifdef SIM
        .mem_o   (mem_hi),
`endif
        .a_clk_i (a_clk_i),
        .a_addr_i(a_addr_i),
        .a_din_i (a_din_i[63:32]),
        .a_be_i  (a_be_i[7:4]),
        .a_wren_i(a_wren_i),
        .a_rden_i(a_rden_i),
        .a_dout_o(a_dout_o[63:32]),
        .b_clk_i (b_clk_i),
        .b_addr_i(b_addr_i),
        .b_din_i (b_din_i[63:32]),
        .b_be_i  (b_be_i[7:4]),
        .b_wren_i(b_wren_i),
        .b_rden_i(b_rden_i),
        .b_dout_o(b_dout_o[63:32])
    );

    /*!
     * `ram_lo` handles the lower 32-bit lane [31:0] for both ports.
     * Byte enable bits [3:0] map to this lane.
     */
    dpram_32w #(
        .Depth(Depth)
    ) ram_lo (
`ifdef SIM
        .mem_o   (mem_lo),
`endif
        .a_clk_i (a_clk_i),
        .a_addr_i(a_addr_i),
        .a_din_i (a_din_i[31:0]),
        .a_be_i  (a_be_i[3:0]),
        .a_wren_i(a_wren_i),
        .a_rden_i(a_rden_i),
        .a_dout_o(a_dout_o[31:0]),
        .b_clk_i (b_clk_i),
        .b_addr_i(b_addr_i),
        .b_din_i (b_din_i[31:0]),
        .b_be_i  (b_be_i[3:0]),
        .b_wren_i(b_wren_i),
        .b_rden_i(b_rden_i),
        .b_dout_o(b_dout_o[31:0])
    );

  endgenerate
  //==========================================================================

endmodule

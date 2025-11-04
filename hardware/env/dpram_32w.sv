// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       dpram_32w.sv
\brief      32-bit Dual-Port RAM (Microchip-backed composition from 40×1024 blocks)

\author     Kawanami
\date       17/10/2025
\version    1.0

\details
  This module composes a 32-bit wide true dual-port RAM from one or more
  `dpram_40x1024` blocks. Each Microchip block implements a 20-bit × 1024
  dual-port SRAM on the MPFS Discovery Kit. To obtain a 32-bit interface,
  two blocks are associated to create a 40-bit x 1024 dual-port SRAM, but
  only 32 of the 40 data bits are used; the remaining 8 bits are treated
  as unused “pad” bits.

  The composition supports any total depth that is an integer multiple of
  1024 words, by banking several 40×1024 instances. Bank selection is derived
  from the MSBs of the port address; the row index within a bank comes from
  the LSBs.

\section dpram_32w_scope Scope and limitations
  - Read and write latency is one cycle (address captured on read enable, data
    returned on the next rising edge of the respective clock).
  - Byte-enable writes are supported on both ports (4 byte lanes mapped into
    the 40-bit word with padding bits interleaved).
  - This wrapper assumes the Microchip macro uses compatible control semantics
    (per-byte write, synchronous read).

\remarks
  - TODO: Document the Microchip byte-enable mapping precisely.

\section dpram_32w_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 17/10/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | xx/xx/xxxx | Name       |                                           |
********************************************************************************
*/

module dpram_32w #(
    /// External data width in bits (kept as a parameter; expected 32)
    parameter int unsigned DataWidth = 32,
    /// Total number of words (must be a multiple of 1024)
    parameter int unsigned Depth     = 1024,
    /// Address width in bits (derived from Depth)
    parameter int unsigned AddrWidth = $clog2(Depth)
) (
`ifdef SIM
    /// (Simulation only) Exposes the composed memory as 32-bit words
    output wire [DataWidth-1:0] mem_o[Depth],
`endif

    /// Port A clock
    input  logic                       a_clk_i,
    /// Port A address (word address in the 32-bit logical space)
    input  logic [AddrWidth   - 1 : 0] a_addr_i,
    /// Port A write data (32-bit)
    input  logic [DataWidth   - 1 : 0] a_din_i,
    /// Port A byte-enable (one bit per byte; 4 bits for 32-bit data)
    input  logic [DataWidth/8 - 1 : 0] a_be_i,
    /// Port A write enable (1 = write)
    input  logic                       a_wren_i,
    /// Port A read enable  (1 = read)
    input  logic                       a_rden_i,
    /// Port A read data (registered, 1-cycle latency)
    output logic [DataWidth   - 1 : 0] a_dout_o,
    /// Port B clock
    input  logic                       b_clk_i,
    /// Port B address (word address in the 32-bit logical space)
    input  logic [AddrWidth   - 1 : 0] b_addr_i,
    /// Port B write data (32-bit)
    input  logic [DataWidth   - 1 : 0] b_din_i,
    /// Port B byte-enable (one bit per byte; 4 bits for 32-bit data)
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
  /// Depth of a single vendor bank (40×1024)
  localparam int unsigned BANK_DEPTH = 1024;
  /// Address bits needed inside a bank (row index)
  localparam int unsigned BANK_ADDR_W = $clog2(BANK_DEPTH);
  /// Number of banks required to reach `Depth`
  localparam int unsigned NB_BANKS = (Depth + BANK_DEPTH - 1) / BANK_DEPTH;
  /// Bank select width (at least 1 to keep vectors well-formed)
  localparam int unsigned BANK_SEL_W = (NB_BANKS <= 1) ? 1 : $clog2(NB_BANKS);

  /* parameter checks */
  /// `Depth` must be a multiple of BANK_DEPTH to allow clean banking
  if (Depth % BANK_DEPTH != 0) begin : gen_Depth_check
    initial $fatal(0, "FATAL ERROR: Depth (%0d) shall be a multiple of %0d.", Depth, BANK_DEPTH);
  end


  /* functions */

  /* verilator lint_off UNUSEDSIGNAL */
  /// 32-bit → 40-bit packer (interleaves 8 pad bits across 4 bytes)
  /*!
   * The vendor block uses 40-bit words. We embed a 32-bit word by inserting
   * 2 pad bits in front of each byte, producing the packed layout:
   *   {pad[1:0], d[31:24], pad[1:0], d[23:16], pad[1:0], d[15:8], pad[1:0], d[7:0]}.
   * Pad bits are tied to zero on writes.
   */
  function automatic [39:0] pack40(input logic [31:0] d);
    return {2'b00, d[31:24], 2'b00, d[23:16], 2'b00, d[15:8], 2'b00, d[7:0]};
  endfunction

  /// 40-bit → 32-bit unpacker (drops interleaved pad bits)
  /*!
   * Extracts the 4 data bytes from the 40-bit word and discards the pad bits:
   *   {w[37:30], w[27:20], w[17:10], w[7:0]} → 32-bit word.
   */
  function automatic [31:0] unpack32(input logic [39:0] w);
    return {w[37:30], w[27:20], w[17:10], w[7:0]};
  endfunction
  /* verilator lint_on UNUSEDSIGNAL */


  /* wires */

  /// Port A bank select (MSBs of logical address)
  wire [ BANK_SEL_W-1:0] A_BANK_SEL;
  /// Port A row index inside the selected bank
  wire [BANK_ADDR_W-1:0] A_ROW;

  /// Port B bank select (MSBs of logical address)
  wire [ BANK_SEL_W-1:0] B_BANK_SEL;
  /// Port B row index inside the selected bank
  wire [BANK_ADDR_W-1:0] B_ROW;

  /// Per-bank 40-bit read data (Port A)
  wire [           39:0] a_dout_o_bank[NB_BANKS];
  /// Per-bank 40-bit read data (Port B)
  wire [           39:0] b_dout_o_bank[NB_BANKS];

`ifdef SIM
  /// (Simulation only) Per-bank raw 40-bit memory exposure
  wire [39:0] bank_mem[NB_BANKS][BANK_DEPTH];
`endif

  /* registers */

  /// Registered bank select for Port A (aligns MUX select with data timing)
  logic [BANK_SEL_W-1:0] a_bank_sel_q;
  /// Registered bank select for Port B (aligns MUX select with data timing)
  logic [BANK_SEL_W-1:0] b_bank_sel_q;
  /********************             ********************/

  /*!
  * Address decoding into {bank, row} for each port.
  * - If only one bank is instantiated, the bank select is tied to 0.
  * - Otherwise, MSBs of the logical address select the bank and LSBs
  *   select the row within that bank.
  */
  generate
    if (NB_BANKS == 1) begin : gen_single_bank_sel
      /// One bank only (index 0)
      assign A_BANK_SEL = '0;
      /// One bank only (index 0)
      assign B_BANK_SEL = '0;
      /// Port A row address
      assign A_ROW      = a_addr_i[BANK_ADDR_W-1:0];
      /// Port B row address
      assign B_ROW      = b_addr_i[BANK_ADDR_W-1:0];
    end
    else begin : gen_multi_bank_sel
      /// Port A bank select = upper address bits
      assign A_BANK_SEL = a_addr_i[AddrWidth-1 : BANK_ADDR_W];
      /// Port B bank select = upper address bits
      assign B_BANK_SEL = b_addr_i[AddrWidth-1 : BANK_ADDR_W];
      /// Port A row address
      assign A_ROW      = a_addr_i[BANK_ADDR_W-1:0];
      /// Port B row address
      assign B_ROW      = b_addr_i[BANK_ADDR_W-1:0];
    end
  endgenerate

  /// Bank select retiming (aligns with 1-cycle read data latency)
  always_ff @(posedge a_clk_i) a_bank_sel_q <= A_BANK_SEL;
  /// Bank select retiming (aligns with 1-cycle read data latency)
  always_ff @(posedge b_clk_i) b_bank_sel_q <= B_BANK_SEL;

  /******************************* BANKING CORE ******************************/

  genvar b;
  generate
    if (NB_BANKS == 1) begin : gen_single_bank
      /*!
       * Single-bank case (Depth = 1024): directly hook both ports to the
       * underlying 40×1024 macro. Byte enables are passed through; 32-bit data
       * are packed to 40-bit on write and unpacked on read.
       */
      dpram_40x1024 u_bank0 (
`ifdef SIM
          .mem_o   (bank_mem[0]),
`endif
          // --- Port A ---
          .a_clk_i (a_clk_i),
          .a_addr_i(A_ROW),
          .a_din_i (pack40(a_din_i)),
          .a_be_i  (a_be_i),
          .a_wren_i(a_wren_i),
          .a_rden_i(a_rden_i),
          .a_dout_o(a_dout_o_bank[0]),
          // --- Port B ---
          .b_clk_i (b_clk_i),
          .b_addr_i(B_ROW),
          .b_din_i (pack40(b_din_i)),
          .b_be_i  (b_be_i),
          .b_wren_i(b_wren_i),
          .b_rden_i(b_rden_i),
          .b_dout_o(b_dout_o_bank[0])
      );
    end
    else begin : gen_multi_banks
      /*!
       * Multi-bank case (Depth = NB_BANKS × 1024): one Microchip macro per bank.
       * A combinational bank “hit” enables only the addressed bank per port;
       * row addresses are presented to all banks. Read data from each bank
       * are captured and later selected using the registered bank select.
       */
      for (b = 0; b < NB_BANKS; b++) begin : gen_banks
        /// Bank enable for Port A (combinational, same cycle as address)
        wire a_hit = (A_BANK_SEL == BANK_SEL_W'(b));
        /// Bank enable for Port B (combinational, same cycle as address)
        wire b_hit = (B_BANK_SEL == BANK_SEL_W'(b));

        dpram_40x1024 u_bank (
`ifdef SIM
            .mem_o   (bank_mem[b]),
`endif
            .a_clk_i (a_clk_i),
            .a_addr_i(A_ROW),
            .a_din_i (pack40(a_din_i)),
            .a_be_i  (a_be_i),
            .a_wren_i(a_wren_i & a_hit),
            .a_rden_i(a_rden_i & a_hit),
            .a_dout_o(a_dout_o_bank[b]),
            .b_clk_i (b_clk_i),
            .b_addr_i(B_ROW),
            .b_din_i (pack40(b_din_i)),
            .b_be_i  (b_be_i),
            .b_wren_i(b_wren_i & b_hit),
            .b_rden_i(b_rden_i & b_hit),
            .b_dout_o(b_dout_o_bank[b])
        );
      end
    end
  endgenerate

  /*!
  * Map the per-bank 40-bit outputs to 32-bit external data using the
  * registered bank select (matches 1-cycle read latency).
  */
  assign a_dout_o = unpack32(a_dout_o_bank[a_bank_sel_q]);

  /*!
  * Map the per-bank 40-bit outputs to 32-bit external data using the
  * registered bank select (matches 1-cycle read latency).
  */
  assign b_dout_o = unpack32(b_dout_o_bank[b_bank_sel_q]);

`ifdef SIM
  /*!
   * Public memory exposure for simulation:
   * - `bank_mem` exposes each vendor bank as 40-bit words.
   * - `mem_o` repacks those words into a flat 32-bit array to match
   *   the logical external view (bank-major → linear address).
   */
  genvar gi, gj;
  for (gi = 0; gi < NB_BANKS; gi++) begin : g_pub_bank
    for (gj = 0; gj < BANK_DEPTH; gj++) begin : g_pub_row
      assign mem_o[gi*BANK_DEPTH+gj] = unpack32(bank_mem[gi][gj]);
    end
  end
`endif

endmodule

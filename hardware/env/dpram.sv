// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       dpram.sv
\brief      Dual-Port RAM (simulation model + vendor-backed instantiation)

\author     Kawanami
\date       19/12/2025
\version    1.0

\details
  Educational dual-port RAM with two operating modes:

  - Simulation: a simple behavioral true dual-port RAM is used to mimic
    a real dual-port memory. The full memory array is exposed at the top
    SystemVerilog level (`mem_o`) for direct access from C++ testbenches
    (DPI / Verilator). This model favors clarity and simulation speed over strict
    hardware semantics and may exhibit multi-driver behavior in corner cases,
    so it is not suitable for synthesis.

  - Synthesis (MPFS Discovery Kit): this module instantiates either
    `dpram_64w.sv` or `dpram_32w.sv` to build a dual-port RAM from Microchip IPs,
    depending on `DataWidth`.

\section dpram_scope Scope and limitations
  - No collision handling is enforced between ports in the simulation variant; the
    vendor-backed variant should be used for implementation on FPGA.
  - Read and write latency is one cycle.
  - Byte-enable writes are supported on both ports.

\remarks
  - TODO: Improve the simulation variant to optionally instantiate a Microchip-like
          dual-port RAM wrapper (currently removed to speed up simulation).

\section dpram_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/06/2025 | Kawanami   | Initial version of the module.            |
********************************************************************************
*/

module dpram #(
    /// Number of bits in a byte
    parameter int unsigned ByteLength = 8,
    /// Data bus width in bits (applies to core and AXI)
    parameter int unsigned DataWidth  = 32,
    /* verilator lint_off UNUSEDPARAM */
    /// Byte-Enable width
    parameter int unsigned BeWidth    = DataWidth / ByteLength,
    /* verilator lint_on UNUSEDPARAM */
    /// Number of `DataWidth` word storable in the RAM.
    parameter int unsigned Depth      = 1280,
    /// Address bus width in bits (applies to core and AXI)
    parameter int unsigned AddrWidth  = $clog2(Depth)

) (
`ifdef SIM
    /// (Simulation only) Exposes the RAM contents for testbenches
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

`ifdef SIM

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* machine states */

  /* functions */

  /* wires */

  /* registers */
  /// Registered read address for port A (held when `a_rden_i`=`0`)
  reg   [AddrWidth -1:0] a_addr_i_q;
  /// Registered read address for port B (held when `b_rden_i`=`0`)
  reg   [AddrWidth -1:0] b_addr_i_q;
  /* verilator lint_off MULTIDRIVEN */
  /// memory array
  logic [ DataWidth-1:0] mem        [Depth];
  /* verilator lint_on MULTIDRIVEN */

  /********************             ********************/

  /// Port A memory access logic.
  /*!
  * - Writes: per-byte using `a_be_i`; active when `a_wren_i`=`1`.
  * - Reads : capture address when `a_rden_i`=`1`; output is `mem[a_addr_i_q]`.
  */
  always_ff @(posedge a_clk_i) begin : port_a_ctrl
    if (a_wren_i) begin
      for (int i = 0; i < BeWidth; i++) begin
        if (a_be_i[i]) mem[a_addr_i][i*ByteLength+:ByteLength] <= a_din_i[i*ByteLength+:ByteLength];
      end
    end
    else if (a_rden_i) begin
      a_addr_i_q <= a_addr_i;
    end
  end

  /// Output driven by port_a_ctrl
  assign a_dout_o = mem[a_addr_i_q];



  /// Port B memory access logic.
  /*!
  * - Writes: per-byte using `b_be_i`; active when `b_wren_i`=`1`.
  * - Reads : capture address when `b_rden_i`=`1`; output is `mem[b_addr_i_q]`.
  */
  always_ff @(posedge b_clk_i) begin : port_b_ctrl
    if (b_wren_i) begin
      for (int i = 0; i < BeWidth; i++) begin
        if (b_be_i[i]) mem[b_addr_i][i*ByteLength+:ByteLength] <= b_din_i[i*ByteLength+:ByteLength];
      end
    end
    else if (b_rden_i) begin
      b_addr_i_q <= b_addr_i;
    end
  end

  /// Output driven by port_a_ctrl
  assign b_dout_o = mem[b_addr_i_q];


  /// memory exposure for simulation (DPI/Verilator access).
  assign mem_o    = mem;


`else

  /// MPFS DISCOVERY KIT memory generation
  /*!
  * This block generates either a 32-bit or a 64-bit Depth
  * memory depending on `DataWidth`.
  * To generate the a 32-bit memory, the `dpram_32w` module
  * is instanciated.
  * To generate the a 64-bit memory, the `dpram_64w` module
  * is instanciated.
  */
  generate
    if (DataWidth == 32) begin : gen_32
      dpram_32w #(
          .Depth(Depth)
      ) ram (
`ifdef SIM
          .mem_o   (mem_o),
`endif
          .a_clk_i (a_clk_i),
          .a_addr_i(a_addr_i),
          .a_din_i (a_din_i),
          .a_be_i  (a_be_i),
          .a_wren_i(a_wren_i),
          .a_rden_i(a_rden_i),
          .a_dout_o(a_dout_o),
          .b_clk_i (b_clk_i),
          .b_addr_i(b_addr_i),
          .b_din_i (b_din_i),
          .b_be_i  (b_be_i),
          .b_wren_i(b_wren_i),
          .b_rden_i(b_rden_i),
          .b_dout_o(b_dout_o)
      );
    end
    else begin : gen_64
      dpram_64w #(
          .Depth(Depth)
      ) ram (
`ifdef SIM
          .mem_o   (mem_o),
`endif
          .a_clk_i (a_clk_i),
          .a_addr_i(a_addr_i),
          .a_din_i (a_din_i),
          .a_be_i  (a_be_i),
          .a_wren_i(a_wren_i),
          .a_rden_i(a_rden_i),
          .a_dout_o(a_dout_o),
          .b_clk_i (b_clk_i),
          .b_addr_i(b_addr_i),
          .b_din_i (b_din_i),
          .b_be_i  (b_be_i),
          .b_wren_i(b_wren_i),
          .b_rden_i(b_rden_i),
          .b_dout_o(b_dout_o)
      );
    end
  endgenerate

`endif


endmodule

// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       dpram_20x1024.sv
\brief      20-bit × 1024 true Dual-Port RAM (Microchip-backed or simulation model)

\author     Kawanami
\date       17/10/2025
\version    1.0

\details
  Leaf-level dual-port RAM used as a Microchip-backed macro wrapper or as a simple
  behavioral model in simulation:

  - Synthesis (Libero / PolarFire SoC/FPGA):
    Instantiates the Microchip large SRAM macro `DP_LSRAM_20x1024` directly.

  - Simulation (Verilator/DPI):
    Implements a minimal behavioral true dual-port RAM with per-lane write
    enable and synchronous, 1-cycle read latency. The full memory array can be
    exposed to testbenches via `mem_o` (enabled with `SIM`).

  Each port supports independent read/write operations. Per-lane write enables
  are expressed over **BeWidth = 2** lanes (two 10-bit lanes per 20-bit word).

\section dpram20x1024_scope Scope and behavior
  - Latency: Synchronous read, 1 cycle. When `*_rden_i` is asserted,
    the address is captured; data becomes visible on `*_dout_o` after the next
    rising edge of the corresponding clock.
  - Write priority: If `*_wren_i=1` in a cycle, the port performs a write
    and does not capture a new read address in that same cycle (write takes
    priority over read).
  - Read-during-write (same port, same address, same cycle): Not defined
    by this wrapper; avoid issuing read and write concurrently on the same port.
  - Cross-port concurrency: Ports A and B operate independently.
    Write/Write to the same address in the same cycle is undefined and must be
    prevented by design (arbiter or address partitioning). Write/Read to the same
    address in the same cycle returns the old value on the read port; newly
    written data are visible on subsequent reads.

\remarks
  - The vendor macro uses UPPERCASE port names (`A_CLK`,
    `A_WBYTE_EN`, etc.); external SCHOLAR RISC-V ports remain in `snake_case`.
  - For precise corner-case behavior, consult the official `Dual Port Large SRAM`
    documentation from Microchip.

\section dpram20x1024_version_history Version history
| Version | Date       | Author   | Description                                 |
|:-------:|:----------:|:---------|:--------------------------------------------|
| 1.0     | 17/10/2025 | Kawanami | Initial version of the module               |
| 1.1     | xx/xx/xxxx | Name     |                                             |
********************************************************************************
*/
module dpram_20x1024 #(
    /// Data width in bits (kept as a parameter for clarity; expected 20)
    parameter int unsigned DataWidth = 20,
    /// Number of addressable words (expected 1024)
    parameter int unsigned Depth     = 1024,
    /// Address width in bits (derived from Depth)
    parameter int unsigned AddrWidth = $clog2(Depth),
    /// Number of write-enable lanes (2 lanes × 10 bits per lane)
    parameter int unsigned BeWidth   = 2
) (
`ifdef SIM
    /// (Simulation only) Exposes the full memory to testbenches (DPI/Verilator)
    output logic [DataWidth-1:0] mem_o   [Depth],
`endif
    /// Port A clock
    input  logic                 a_clk_i,
    /// Port A address
    input  logic [AddrWidth-1:0] a_addr_i,
    /// Port A write data (20-bit)
    input  logic [DataWidth-1:0] a_din_i,
    /// Port A write enables by lane (2 lanes; each lane covers 10 bits)
    input  logic [BeWidth  -1:0] a_be_i,
    /// Port A write enable (1 = write)
    input  logic                 a_wren_i,
    /// Port A read  enable (1 = sample address for a read)
    input  logic                 a_rden_i,
    /// Port A read data (registered; 1-cycle latency)
    output logic [DataWidth-1:0] a_dout_o,
    /// Port B clock
    input  logic                 b_clk_i,
    /// Port B address
    input  logic [AddrWidth-1:0] b_addr_i,
    /// Port B write data (20-bit)
    input  logic [DataWidth-1:0] b_din_i,
    /// Port B write enables by lane (2 lanes; each lane covers 10 bits)
    input  logic [BeWidth  -1:0] b_be_i,
    /// Port B write enable (1 = write)
    input  logic                 b_wren_i,
    /// Port B read  enable (1 = sample address for a read)
    input  logic                 b_rden_i,
    /// Port B read data (registered; 1-cycle latency)
    output logic [DataWidth-1:0] b_dout_o
);

`ifdef SIM

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* machine states */

  /* functions */

  /* wires */

  /* registers */
  /// Registered read address for port A (held when `a_rden_i=0`)
  reg   [AddrWidth -1:0] a_addr_reg;
  /// Registered read address for port B (held when `b_rden_i=0`)
  reg   [AddrWidth -1:0] b_addr_reg;
  /* verilator lint_off MULTIDRIVEN */
  /// Memory array (behavioral). Multi-driver warnings are suppressed intentionally.
  logic [ DataWidth-1:0] mem        [Depth];
  /* verilator lint_on  MULTIDRIVEN */
  /********************             ********************/


  /// Port A memory access logic.
  /*!
   * - Write: When `a_wren_i=1`, each enabled lane writes 10 bits:
   *     lane 0 → bits `[9:0]`, lane 1 → bits `[19:10]`.
   * - Read: When `a_rden_i=1`, capture the address; `a_dout_o` updates on
   *   the next rising edge from `mem[a_addr_reg]`.
   * - Priority: Write has priority over read if both are asserted.
   */
  always_ff @(posedge a_clk_i) begin
    if (a_wren_i) begin
      for (int i = 0; i < BeWidth; i++) begin
        if (a_be_i[i]) mem[a_addr_i][i*10+:10] <= a_din_i[i*10+:10];
      end
    end
    else if (a_rden_i) begin
      a_addr_reg <= a_addr_i;
    end
  end

  /// Port A read data (1-cycle latency)
  assign a_dout_o = mem[a_addr_reg];

  /// Port B memory access logic.
  /*!
   * - Write: When `b_wren_i=1`, each enabled lane writes 10 bits:
   *     lane 0 → bits `[9:0]`, lane 1 → bits `[19:10]`.
   * - Read: When `b_rden_i=1`, capture the address; `b_dout_o` updates on
   *   the next rising edge from `mem[b_addr_reg]`.
   * - Priority: Write has priority over read if both are asserted.
   */
  always_ff @(posedge b_clk_i) begin
    if (b_wren_i) begin
      for (int i = 0; i < BeWidth; i++) begin
        if (b_be_i[i]) mem[b_addr_i][i*10+:10] <= b_din_i[i*10+:10];
      end
    end
    else if (b_rden_i) begin
      b_addr_reg <= b_addr_i;
    end
  end

  /// Port B read data (1-cycle latency)
  assign b_dout_o = mem[b_addr_reg];

  /// Public memory exposure for simulation (DPI/Verilator)
  assign mem_o    = mem;

`else

  /// Microchip Large DPRAM
  DP_LSRAM_20x1024 ram (
      .A_CLK     (a_clk_i),
      .A_ADDR    (a_addr_i),
      .A_DIN     (a_din_i),
      .A_WBYTE_EN(a_be_i),
      .A_WEN     (a_wren_i),
      .A_REN     (a_rden_i),
      .A_DOUT    (a_dout_o),
      .B_CLK     (b_clk_i),
      .B_ADDR    (b_addr_i),
      .B_DIN     (b_din_i),
      .B_WBYTE_EN(b_be_i),
      .B_WEN     (b_wren_i),
      .B_REN     (b_rden_i),
      .B_DOUT    (b_dout_o)
  );

`endif

endmodule

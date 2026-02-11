// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       raxi_dpram.sv
\brief      Dual-Port RAM (AXI read-only / Core read/write)

\author     Kawanami
\date       03/02/2026
\version    1.2

\details
  Educational dual-port RAM used to share data from the SCHOLAR RISC-V core
  to the platform via an AXI read-only interface.

  - The core side supports both reads and writes using a simple,
    synchronous, single-cycle-latency protocol with byte write enables.
  - The AXI side implements the Read Address (AR) and Read Data (R) channels
    needed to fetch data from the RAM. Only reads are supported.

  \note This is a didactic component designed for clarity over feature
        completeness. The AXI behavior is a simplified subset sufficient for
        memory inspection, firmware injection, and platform-to-core data
        movement demonstrations.

\section raxi_dpram_scope Scope and limitations (by design)
  - AXI write channels are not present.
  - Bursts are not intended to be used; single-beat accesses are the nominal case.
  - ID/PROT/CACHE/LOCK fields are accepted for completeness but are not functionally
    required by the use-case.

\remarks
  - TODO: Completely handle the AXI4 protocol.

\section raxi_dpram_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 21/01/2026 | Kawanami   | Add the possibility to emulate non-perfect memory. |
| 1.2     | 03/02/2026 | Kawanami   | Remove unused imported package. |
********************************************************************************
*/

module raxi_dpram #(
    ///
    parameter  bit          NoPerfectMemory = 0,
    /// Number of bits in a byte
    parameter  int unsigned ByteLength      = 8,
    /// Address bus width in bits (applies to core and AXI)
    parameter  int unsigned AddrWidth       = 32,
    /// Data bus width in bits (applies to core and AXI)
    parameter  int unsigned DataWidth       = 32,
    /// Address granularity in bytes (e.g., 4 bytes for 32-bit, 8 for 64-bit)
    localparam int unsigned AddrOffset      = DataWidth / ByteLength,
    /// Number of bits needed to encode byte offset within a word
    localparam int unsigned AddrOffsetWidth = $clog2(AddrOffset),
    /// Dual Port RAM size in bytes
    parameter  int unsigned Size            = 2048,
    /// AXI transaction ID width
    parameter  int unsigned IdWidth         = 8
) (

`ifdef SIM
    /// (Simulation only) Exposes the RAM contents for testbenches
    output logic [DataWidth-1:0] mem_o[(Size / (DataWidth / ByteLength))],
`endif
    /* Global signals */
    /// Core domain clock (drives the core-side port of the RAM)
    input wire core_clk_i,
    /// AXI domain clock (drives the AXI-side port of the RAM and AXI control)
    input wire axi_clk_i,
    /// Global active-low reset for AXI control logic (memory contents unchanged)
    input wire rstn_i,
    /* Core signals */
    /* verilator lint_off UNUSEDSIGNAL */
    /// Core address (byte address). Upper bits beyond the RAM depth are ignored.
    input wire [AddrWidth-1:0] core_m_addr_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// Core write enable (1 = write)
    input wire core_m_wren_i,
    /// Core write data (to memory)
    input wire [DataWidth     - 1 : 0] core_m_wdata_i,
    /// Core byte-enable mask (one bit per byte)
    input wire [(DataWidth/ByteLength) - 1 : 0] core_m_wmask_i,
    /// Core read enable (1 = read)
    input wire core_m_rden_i,
    /// Core read data (from memory)
    output wire [DataWidth     - 1 : 0] core_m_rdata_o,
    /// Core hit/acknowledge: combinational “accept” (read or write issued)
    output wire core_m_hit_o,
    /* AXI signals */
    /// ARID: Read address transaction ID
    input wire [IdWidth       - 1 : 0] s_axi_arid_i,
    /// ARADDR: Start byte address for read transaction
    input wire [AddrWidth     - 1 : 0] s_axi_araddr_i,
    /// ARLEN: Number of beats minus 1 (nominally 0 for single-beat)
    input wire [7 : 0] s_axi_arlen_i,
    /// ARSIZE: Bytes per beat = 2**ARSIZE (should match DataWidth/ByteLength)
    input wire [2 : 0] s_axi_arsize_i,
    /// ARBURST: Burst type (FIXED/INCR/WRAP)
    input wire [1 : 0] s_axi_arburst_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// ARLOCK: Lock (unused)
    input wire [1 : 0] s_axi_arlock_i,
    /// ARCACHE: Cache hints (unused)
    input wire [3 : 0] s_axi_arcache_i,
    /// ARPROT: Protection type (unused)
    input wire [2 : 0] s_axi_arprot_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// ARVALID: Read address valid
    input wire s_axi_arvalid_i,
    /// ARREADY: Read address ready
    output wire s_axi_arready_o,
    /// RID: Read data transaction ID
    output wire [IdWidth       - 1 : 0] s_axi_rid_o,
    /// RDATA: Read data
    output wire [DataWidth     - 1 : 0] s_axi_rdata_o,
    /// RRESP: Read response (OKAY/SLVERR/DECERR)
    output wire [1 : 0] s_axi_rresp_o,
    /// RLAST: Last beat of burst
    output wire s_axi_rlast_o,
    /// RVALID: Read data valid
    output wire s_axi_rvalid_o,
    /// RREADY: Read data ready
    input wire s_axi_rready_i
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  /// Memory depth
  localparam int unsigned DEPTH = Size / (DataWidth / ByteLength);
  /// Useful number of bits to address the whole memory
  localparam int unsigned USED_ADDR_WIDTH = $clog2(DEPTH);

  /* machine states */

  /// AXI read Finite State Machine states.
  typedef enum reg [0:0] {
    /// No transaction
    RD_IDLE,
    /// Transaction on going
    RD_BURST
  } read_states_e;

  /// AXI read Finite State Machine state register
  read_states_e                 read_state_d;

  /* functions */

  /* wires */

  /* registers */
  /// Registered ARID from AXI read address channel (transaction ID)
  reg           [  IdWidth-1:0] s_axi_arid_q;
  /// Registered read address from AXI master
  reg           [AddrWidth-1:0] s_axi_araddr_q;
  /// Registered burst length (number of data beats - 1)
  reg           [          7:0] s_axi_arlen_q;
  /// Registered size of each transfer in the burst (log2(bytes))
  reg           [          2:0] s_axi_arsize_q;
  /// Registered burst type (e.g., INCR, FIXED)
  reg           [          1:0] s_axi_arburst_q;
  /// Indicates if the slave can accept a new read address
  reg                           s_axi_arready_q;
  /// Response code for read transaction (OKAY, SLVERR, etc.)
  reg           [          1:0] s_axi_rresp_q;
  /// Indicates the last data beat in a burst
  reg                           s_axi_rlast_q;
  /// Indicates valid read data is available on the bus
  reg                           s_axi_rvalid_q;
  /********************             ********************/


  /// AXI machine read FSM.
  /*!
  * This state machine governs the AXI read transaction lifecycle.
  * It manages the transition between idle and active burst states,
  * ensuring proper handshaking.
  *
  * - RD_IDLE: Waits for a valid read address phase (`s_axi_arvalid_i`).
  *            Once received, transitions to `RD_BURST`.
  *
  * - RD_BURST: Actively sends read data beats to the AXI master.
  *             Transitions back to `RD_IDLE` when
  *             the last beat is sent (`s_axi_rlast_q`).
  *
  * The state is updated on the rising edge of the AXI clock (`axi_clk_i`),
  * and is reset to `RD_IDLE` when `rstn_i` is asserted low.
  */
  always_ff @(posedge axi_clk_i) begin : axi_read_fsm
    if (!rstn_i) read_state_d <= RD_IDLE;
    else begin
      case (read_state_d)
        RD_IDLE:  if (s_axi_arvalid_i) read_state_d <= RD_BURST;
        RD_BURST: if (s_axi_rlast_q) read_state_d <= RD_IDLE;
        default:  read_state_d <= RD_IDLE;
      endcase
    end
  end
  /**/

  /// AXI read control logic
  /*!
  * This block manages the control path for AXI read transactions.
  * It registers the AXI address channel information and
  * controls the response channel behavior.
  *
  * On reset:
  * - All internal control registers are cleared.
  *
  * In `RD_IDLE` state:
  * - Waits for a valid address phase (`s_axi_arvalid_i`).
  * - Captures the transaction metadata:
  *     - Transaction ID, address, burst length, burst type, and size.
  * - Asserts `ARREADY` to acknowledge the transaction.
  *
  * In `RD_BURST` state:
  * - Clears `ARREADY` to prevent accepting new addresses.
  * - If `RREADY` is asserted by the master:
  *     - Asserts `RVALID` to return data.
  *     - Updates the address for the next beat in case of burst (`INCR` mode).
  *     - Decrements the burst counter (`ARLEN`) to track progress.
  *     - Sets `RLAST` when the last beat of the burst is reached.
  *
  * AXI response signals (`RID`, `RRESP`, `RLAST`, `RVALID`)
  * are driven combinatorially from the registered control fields
  * to maintain timing consistency.
  */
  always_ff @(posedge axi_clk_i) begin : axi_read_ctrl
    if (!rstn_i) begin
      s_axi_arid_q    <= {IdWidth{1'b0}};
      s_axi_araddr_q  <= {AddrWidth{1'b0}};
      s_axi_arlen_q   <= 8'b00000000;
      s_axi_arsize_q  <= 3'b000;
      s_axi_arburst_q <= 2'b00;
      s_axi_arready_q <= 1'b0;
      s_axi_rresp_q   <= 2'b00;
      s_axi_rlast_q   <= 1'b0;
      s_axi_rvalid_q  <= 1'b0;
    end
    else begin
      case (read_state_d)
        RD_IDLE: begin
          s_axi_rlast_q  <= 1'b0;
          s_axi_rvalid_q <= 1'b0;

          if (s_axi_arvalid_i) begin
            s_axi_arid_q    <= s_axi_arid_i;
            s_axi_araddr_q  <= s_axi_araddr_i;
            s_axi_arlen_q   <= s_axi_arlen_i;
            s_axi_arsize_q  <= s_axi_arsize_i;
            s_axi_arburst_q <= s_axi_arburst_i;
            s_axi_arready_q <= 1'b1;
          end
        end

        RD_BURST: begin
          s_axi_arready_q <= 1'b0;

          if (s_axi_rready_i) begin
            s_axi_rvalid_q <= 1'b1;
            s_axi_arlen_q  <= s_axi_arlen_q - 1;
            if (s_axi_arburst_q != 2'b00) s_axi_araddr_q <= s_axi_araddr_q + (1 << s_axi_arsize_q);
            if (s_axi_arlen_q == 0) s_axi_rlast_q <= 1'b1;

          end
          else s_axi_rvalid_q <= 1'b0;
        end

        default: ;
      endcase
    end
  end

  /// Output driven by axi_read_ctrl
  assign s_axi_arready_o = s_axi_arready_q;
  /// Output driven by axi_read_ctrl
  assign s_axi_rid_o     = s_axi_arid_q;
  /// Output driven by axi_read_ctrl
  assign s_axi_rresp_o   = s_axi_rresp_q;
  /// Output driven by axi_read_ctrl
  assign s_axi_rlast_o   = s_axi_rlast_q;
  /// Output driven by axi_read_ctrl
  assign s_axi_rvalid_o  = s_axi_rvalid_q;
  /**/

  /// Core-side memory hit signal
  /*!
  * Since the dual-port RAM provides single-cycle access
  * and is always available, the `core_m_hit_o` signal can directly
  * reflect the validity of the core's request.
  *
  * - If either a read (`core_m_rden_i`) or
  *   a write (`core_m_wren_i`) is requested, the memory is assumed
  *   to complete the operation without wait states.
  *
  * This simplifies handshaking by eliminating the need for an explicit memory
  * ready/acknowledge protocol.
  *
  * For non-perfect memory test, a latency is added to `core_m_hit_o` to emulate
  * a memory latency (even if the data is ready, the core will not capture it if
  * the m_hit signal is not asserted).
  * The latency depends on the address. This ensure a non-constant latency.
  */
  generate
    if (NoPerfectMemory) begin : gen_not_perfect_memory

      localparam int unsigned MAX_LAT = 3;  // 0..MAX_LAT
      localparam int unsigned ADDR_LAT_LSB = (DataWidth == 64) ? 3 : 2;

      localparam int unsigned LAT_W = (MAX_LAT < 1) ? 1 : $clog2(MAX_LAT + 1);
      localparam int unsigned LAT_MAX_REPR = (1 << LAT_W) - 1;
      localparam bit NEED_CLAMP = (MAX_LAT != LAT_MAX_REPR);

      logic             req_now;
      logic             busy_q;
      logic [LAT_W-1:0] wait_q;
      logic [LAT_W-1:0] lat_raw;
      logic [LAT_W-1:0] lat_sel;

      assign req_now = core_m_rden_i || core_m_wren_i;

      // derive a deterministic latency from address bits (ignore alignment by default).
      // Uses bits [ADDR_LAT_LSB + LAT_W - 1 : ADDR_LAT_LSB].
      assign lat_raw = core_m_addr_i[ADDR_LAT_LSB+:LAT_W];

      if (NEED_CLAMP) begin : gen_clamp
        // Clamp to MAX_LAT to keep latency in 0..MAX_LAT without using modulo.
        assign lat_sel = (lat_raw > MAX_LAT[LAT_W-1:0]) ? MAX_LAT[LAT_W-1:0] : lat_raw;
      end
      else begin : gen_noclamp
        assign lat_sel = lat_raw;
      end

      // Hit is high when the request is active and the wait counter reached zero.
      // Deasserts combinationally when req_now drops.
      assign core_m_hit_o = req_now && busy_q && (wait_q == '0);

      always_ff @(posedge core_clk_i) begin
        if (!rstn_i) begin
          busy_q <= 1'b0;
          wait_q <= '0;
        end
        else begin
          if (!busy_q) begin
            if (req_now) begin
              busy_q <= 1'b1;
              wait_q <= (MAX_LAT == 0) ? '0 : lat_sel;  // sample latency at request start
            end
          end
          else begin
            if (!req_now) begin
              busy_q <= 1'b0;
              wait_q <= '0;
            end
            else if (wait_q != '0) begin
              wait_q <= wait_q - 1'b1;
            end
          end
        end
      end

    end
    else begin : gen_perfect_memory
      assign core_m_hit_o = core_m_rden_i || core_m_wren_i;
    end
  endgenerate
  /**/

  /// Dual-Port RAM instantiation
  /*!
  * This block instantiates the RAM itself.
  *
  * In simulation (`SIM` defined), the full memory (`mem_o`) is exposed
  * for inspection from C++ testbenches.
  */
  dpram #(
      .DataWidth(DataWidth),
      .Depth    (DEPTH)
  ) dpram (
`ifdef SIM
      .mem_o   (mem_o),
`endif
      .a_addr_i(s_axi_araddr_q[USED_ADDR_WIDTH+AddrOffsetWidth-1 : AddrOffsetWidth]),
      .a_clk_i (axi_clk_i),
      .a_din_i ({DataWidth{1'b0}}),
      .a_be_i  ({DataWidth / 8{1'b0}}),
      .a_wren_i(1'b0),
      .a_rden_i(s_axi_rready_i),
      .b_clk_i (core_clk_i),
      .b_addr_i(core_m_addr_i[USED_ADDR_WIDTH+AddrOffsetWidth-1 : AddrOffsetWidth]),
      .b_din_i (core_m_wdata_i),
      .b_be_i  (core_m_wmask_i),
      .b_wren_i(core_m_wren_i),
      .b_rden_i(core_m_rden_i),
      .a_dout_o(s_axi_rdata_o),
      .b_dout_o(core_m_rdata_o)
  );


endmodule

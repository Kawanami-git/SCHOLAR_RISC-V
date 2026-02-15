// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       waxi_dpram.sv
\brief      Dual-Port RAM (AXI write-only / Core write/read)

\author     Kawanami
\date       15/02/2026
\version    1.3

\details
  Educational dual-port RAM used to store the SCHOLAR RISC-V core
  applicative instructions/data and to share data from the platform
  to the core, via an AXI write-only interface.

  - The core side supports both reads and writes using a simple,
    synchronous, single-cycle-latency protocol with byte write enables.
  - The AXI side implements the Write Address (AW), Write Data (W) and
    Write Response (B) channels needed to write data to the RAM.
    Only writes are supported.

  \note This is a didactic component designed for clarity over feature
        completeness. The AXI behavior is a simplified subset sufficient for
        memory inspection, firmware injection, and platform-to-core data
        movement demonstrations.

  \section waxi_dpram_scope Scope and limitations (by design)
  - AXI read channels are not present.
  - Bursts are not intended to be used; single-beat accesses are the nominal case.
  - ID/PROT/CACHE/LOCK fields are accepted for completeness but are not functionally
    required by the use-case.

\remarks
  - TODO: Completely handle the AXI4 protocol.

\section waxi_dpram_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 21/01/2026 | Kawanami   | Add the possibility to emulate non-perfect memory. |
| 1.2     | 03/02/2026 | Kawanami   | Remove unused imported package. |
| 1.3     | 15/02/2026 | Kawanami   | Replace custom interface with OBI standard. |
********************************************************************************
*/

module waxi_dpram #(
    /// Use non-perfect memories
    parameter  bit          NoPerfectMemory = 0,
    /// Number of bits in a byte
    parameter  int          ByteLength      = 8,
    /// Address bus width in bits (applies to core and AXI)
    parameter  int unsigned AddrWidth       = 32,
    /// Data bus width in bits (applies to core and AXI)
    parameter  int unsigned DataWidth       = 32,
    /// Address granularity in bytes (e.g., 4 bytes for 32-bit, 8 for 64-bit)
    localparam int unsigned AddrOffset      = DataWidth / ByteLength,
    /// Number of bits needed to encode byte offset within a word
    localparam int unsigned AddrOffsetWidth = $clog2(AddrOffset),
    /// Dual Port RAM size in bytes
    parameter  int unsigned Size            = 16384,
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
    /// Address transfer request
    input wire req_i,
    /// Grant: Ready to accept address transfert
    output wire gnt_o,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Address for memory access
    input wire [AddrWidth  - 1 : 0] addr_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// Write enable (1: write - 0: read)
    input wire we_i,
    /// Write data
    input wire [DataWidth - 1 : 0] wdata_i,
    /// Byte enable
    input wire [(DataWidth/8) - 1 : 0] be_i,
    /// Response transfer valid
    output wire rvalid_o,
    /// Read data
    output wire [DataWidth - 1 : 0] rdata_o,
    /// Error response
    output wire err_o,
    /* AXI signals */
    /// AWID: Write address transaction ID
    input wire [IdWidth       - 1 : 0] s_axi_awid_i,
    /// AWADDR: Start byte address for write transaction
    input wire [AddrWidth     - 1 : 0] s_axi_awaddr_i,
    /// AWSIZE: Bytes per beat = 2**AWSIZE (should match DataWidth/ByteLength)
    input wire [2 : 0] s_axi_awsize_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// AWLEN: Number of beats minus 1 (nominally 0 for single-beat)
    input wire [7 : 0] s_axi_awlen_i,
    /// AWBURST: Burst type (FIXED/INCR/WRAP)
    input wire [1 : 0] s_axi_awburst_i,
    /// AWLOCK: Lock (unused)
    input wire [1 : 0] s_axi_awlock_i,
    /// AWCACHE: Cache hints (unused)
    input wire [3 : 0] s_axi_awcache_i,
    /// AWPROT: Protection type (unused)
    input wire [2 : 0] s_axi_awprot_i,
    /// AWVALID: Write address valid
    input wire s_axi_awvalid_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// AWREADY: Write address ready
    output wire s_axi_awready_o,
    /// WDATA: Write data
    input wire [DataWidth     - 1 : 0] s_axi_wdata_i,
    /// WSTRB: Byte write strobes (one bit per byte)
    input wire [(DataWidth/ByteLength) - 1 : 0] s_axi_wstrb_i,
    /// WLAST: Last beat of burst
    input wire s_axi_wlast_i,
    /// WVALID: Write data valid
    input wire s_axi_wvalid_i,
    /// WREADY: Write data ready
    output wire s_axi_wready_o,
    /// BID: Write transaction response ID
    output wire [IdWidth       - 1 : 0] s_axi_bid_o,
    /// BRESP: Write response (OKAY/SLVERR/DECERR)
    output wire [1 : 0] s_axi_bresp_o,
    /// BVALID: Write transaction response valid
    output wire s_axi_bvalid_o,
    /// BREADY: Write transaction response ready
    input wire s_axi_bready_i
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  /// Memory depth
  localparam int unsigned DEPTH = Size / (DataWidth / ByteLength);
  /// Useful number of bits to address the whole memory
  localparam int unsigned USED_ADDR_WIDTH = $clog2(DEPTH);

  /* machine states */

  /// AXI write Finite State Machine states.
  typedef enum reg [1:0] {
    /// No transaction
    WR_IDLE,
    /// Transaction in progress (write data beats)
    WR_BURST,
    /// Write response phase
    WR_RESP
  } write_states_e;

  /// AXI write Finite State Machine state register
  write_states_e                     write_state_d;

  /* functions */

  /* wires */

  /* registers */
  /// Registered AWID from AXI write address channel (transaction ID)
  reg            [IdWidth   - 1 : 0] s_axi_awid_q;
  /* verilator lint_off UNUSEDSIGNAL */
  /// Registered write address from AXI master
  reg            [AddrWidth - 1 : 0] s_axi_awaddr_q;
  /// Registered size of each transfer in the burst (log2(bytes))
  reg            [            2 : 0] s_axi_awsize_q;
  /// Registered burst type (e.g., INCR, FIXED)
  reg            [            1 : 0] s_axi_awburst_q;
  /* verilator lint_on UNUSEDSIGNAL */
  /// Indicates if the slave can accept a new write address
  reg                                s_axi_awready_q;
  /// Controls handshake with master for write data channel
  reg                                s_axi_wready_q;
  /// Stores the ID to return in write response
  reg            [IdWidth   - 1 : 0] s_axi_bid_q;
  /// Response code for write transaction (OKAY, SLVERR, etc.)
  reg            [            1 : 0] s_axi_bresp_q;
  /// Controls handshake for write response channel
  reg                                s_axi_bvalid_q;
  /********************             ********************/

  /// AXI machine write FSM.
  /*!
  * This finite state machine (FSM) handles the AXI write transaction flow.
  *
  * - WR_IDLE:      Waits for a valid AXI write address (`s_axi_awvalid_i`). Upon assertion,
  *                 it captures the write parameters and moves to WR_BURST.
  *
  * - WR_BURST:     Handles incoming write data beats. Transition to WR_RESP occurs
  *                 when the last write data beat (`s_axi_wlast_i`) is valid.
  *
  * - WR_RESP:      Sends the write response (`s_axi_bvalid_o`). Once the master acknowledges
  *                 by asserting `s_axi_bready_i`, the FSM returns to WR_IDLE.
  *
  * This ensures correct sequencing of the write address, data, and response phases.
  */
  always_ff @(posedge axi_clk_i) begin : axi_write_fsm
    if (!rstn_i) write_state_d <= WR_IDLE;
    else begin
      case (write_state_d)
        WR_IDLE:  if (s_axi_awvalid_i) write_state_d <= WR_BURST;
        WR_BURST: if (s_axi_wlast_i && s_axi_wvalid_i) write_state_d <= WR_RESP;
        WR_RESP:  if (s_axi_bready_i) write_state_d <= WR_IDLE;
        default:  write_state_d <= WR_IDLE;
      endcase
    end
  end
  /**/

  /// AXI write control logic
  /*!
  * This block manages the internal control and handshake signals for the AXI write channels:
  * - Write address (AW)
  * - Write data (W)
  * - Write response (B)
  *
  * Behavior:
  * - In `WR_IDLE`, the module latches the incoming address channel signals if `s_axi_awvalid_i` is high,
  *   and asserts `s_axi_awready_o` to accept the transaction.
  *
  * - In `WR_BURST`, the module accepts write data when `s_axi_wvalid_i`
  *   is asserted and raises `s_axi_wready_o`.
  *   The burst increment logic is commented out here, as burst transfers are not supported
  *   due to PolarFire interconnect compatibility issues.
  *
  * - In WR_RESP:   Sends the write response (`s_axi_bvalid_o`) and echoes the
  *                 transaction ID. When the master acknowledges by asserting
  *                 `s_axi_bready_i`, the FSM returns to WR_IDLE.
  *
  * All control signals are reset to default values upon reset.
  */
  always_ff @(posedge axi_clk_i) begin : axi_write_ctrl
    if (!rstn_i) begin
      s_axi_awid_q    <= {IdWidth{1'b0}};
      s_axi_awaddr_q  <= {AddrWidth{1'b0}};
      s_axi_awsize_q  <= 3'b000;
      s_axi_awburst_q <= 2'b00;
      s_axi_awready_q <= 1'b0;
      s_axi_wready_q  <= 1'b0;
      s_axi_bid_q     <= {IdWidth{1'b0}};
      s_axi_bresp_q   <= 2'b0;
      s_axi_bvalid_q  <= 1'b0;
    end
    else begin
      case (write_state_d)
        WR_IDLE: begin
          s_axi_bvalid_q <= 1'b0;

          if (s_axi_awvalid_i) begin
            s_axi_awid_q    <= s_axi_awid_i;
            s_axi_awaddr_q  <= s_axi_awaddr_i;
            s_axi_awsize_q  <= s_axi_awsize_i;
            s_axi_awburst_q <= s_axi_awburst_i;
            s_axi_awready_q <= 1'b1;
          end
        end

        WR_BURST: begin
          s_axi_awready_q <= 1'b0;
          s_axi_wready_q  <= s_axi_wvalid_i;
          // if (s_axi_wvalid_i && s_axi_awburst_q != 2'b00) s_axi_awaddr_q <= s_axi_awaddr_q + (1 << s_axi_awsize_q);
        end

        WR_RESP: begin
          s_axi_wready_q <= 1'b0;
          s_axi_bid_q    <= s_axi_awid_q;
          s_axi_bresp_q  <= 2'b00;
          s_axi_bvalid_q <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  /// Output driven by axi_write_ctrl
  assign s_axi_awready_o = s_axi_awready_q;
  /// Output driven by axi_write_ctrl
  assign s_axi_wready_o  = s_axi_wready_q;
  /// Output driven by axi_write_ctrl
  assign s_axi_bid_o     = s_axi_bid_q;
  /// Output driven by axi_write_ctrl
  assign s_axi_bresp_o   = s_axi_bresp_q;
  /// Output driven by axi_write_ctrl
  assign s_axi_bvalid_o  = s_axi_bvalid_q;
  /**/

  /// The RAM is always available to the core
  assign gnt_o           = req_i;
  /// No error handling
  assign err_o           = '0;

  /// Core-side memory hit signal.
  /*!
  * Since the dual-port RAM provides single-cycle access and is always available,
  * the `rvalid_o` signal can directly reflect the validity of the core's request.
  *
  * - If either a read a write is requested (`req`),
  *   the memory is assumed to complete the operation without wait states.
  *
  * This simplifies handshaking by eliminating the need for an explicit memory
  * ready/acknowledge protocol.
  *
  * For non-perfect memory test, a latency is added to `rvalid_o` to emulate
  * a memory latency (even if the data is ready, the core will not capture it if
  * the rvalid signal is not asserted).
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

      assign req_now = req_i;

      // Derive a deterministic latency from address bits (ignore alignment by default).
      // Uses bits [ADDR_LAT_LSB + LAT_W - 1 : ADDR_LAT_LSB].
      assign lat_raw = addr_i[ADDR_LAT_LSB+:LAT_W];

      if (NEED_CLAMP) begin : gen_clamp
        // Clamp to MAX_LAT to keep latency in 0..MAX_LAT without using modulo.
        assign lat_sel = (lat_raw > MAX_LAT[LAT_W-1:0]) ? MAX_LAT[LAT_W-1:0] : lat_raw;
      end
      else begin : gen_noclamp
        assign lat_sel = lat_raw;
      end

      // Hit is high when the request is active and the wait counter reached zero.
      // Deasserts combinationally when req_now drops.
      assign rvalid_o = req_now && busy_q && (wait_q == '0);

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
      assign rvalid_o = req_i;
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
      .a_addr_i(s_axi_awaddr_q[USED_ADDR_WIDTH+AddrOffsetWidth-1 : AddrOffsetWidth]),
      .a_clk_i (axi_clk_i),
      .a_din_i (s_axi_wdata_i),
      .a_be_i  (s_axi_wstrb_i),
      .a_wren_i(s_axi_wvalid_i),
      .a_rden_i(1'b0),
      /* verilator lint_off PINCONNECTEMPTY */
      .a_dout_o(),
      /* verilator lint_on PINCONNECTEMPTY */
      .b_clk_i (core_clk_i),
      .b_addr_i(addr_i[USED_ADDR_WIDTH+AddrOffsetWidth-1 : AddrOffsetWidth]),
      .b_din_i (wdata_i),
      .b_be_i  (be_i),
      .b_wren_i(req_i && we_i),
      .b_rden_i(req_i && !we_i),
      .b_dout_o(rdata_o)
  );

endmodule

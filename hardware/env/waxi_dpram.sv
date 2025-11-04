// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       waxi_dpram.sv
\brief      Dual-Port RAM (AXI write-only / Core write/read)

\author     Kawanami
\date       15/10/2025
\version    1.1

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
| 1.0     | 02/07/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 15/10/2025 | Kawanami   | Change module name from data_dpram to waxi_dpram.<br>Add RV64 support.<br>Update the whole file for coding style compliance.<br>Update the whole file comments for doxygen support. |
********************************************************************************
*/

module waxi_dpram #(
    /// Number of bits in a byte
    parameter int          ByteLength = 8,
    /// Address bus width in bits (applies to core and AXI)
    parameter int unsigned AddrWidth  = 32,
    /// Data bus width in bits (applies to core and AXI)
    parameter int unsigned DataWidth  = 32,
    /// Dual Port RAM size in bytes
    parameter int unsigned Size       = 16384,
    /// AXI transaction ID width
    parameter int unsigned IdWidth    = 8
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
  /// Address granularity in bytes (e.g., 4 bytes for 32-bit, 8 for 64-bit)
  localparam int unsigned ADDR_OFFSET = DataWidth / ByteLength;
  /// Number of bits needed to encode byte offset within a word
  localparam int unsigned ADDR_OFFSET_WIDTH = $clog2(ADDR_OFFSET);
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


  /// Core-side memory hit signal.
  /*!
  * Since the dual-port RAM provides single-cycle access and is always available,
  * the `core_m_hit_o` signal can directly reflect the validity of the core's request.
  *
  * - If either a read (`core_m_rden_i`) or a write (`core_m_wren_i`) is requested,
  *   the memory is assumed to complete the operation without wait states.
  *
  * This simplifies handshaking by eliminating the need for an explicit memory
  * ready/acknowledge protocol.
  */
  assign core_m_hit_o    = core_m_rden_i || core_m_wren_i;
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
      .a_addr_i(s_axi_awaddr_q[USED_ADDR_WIDTH+ADDR_OFFSET_WIDTH-1 : ADDR_OFFSET_WIDTH]),
      .a_clk_i (axi_clk_i),
      .a_din_i (s_axi_wdata_i),
      .a_be_i  (s_axi_wstrb_i),
      .a_wren_i(s_axi_wvalid_i),
      .a_rden_i(1'b0),
      .b_clk_i (core_clk_i),
      .b_addr_i(core_m_addr_i[USED_ADDR_WIDTH+ADDR_OFFSET_WIDTH-1 : ADDR_OFFSET_WIDTH]),
      .b_din_i (core_m_wdata_i),
      .b_be_i  (core_m_wmask_i),
      .b_wren_i(core_m_wren_i),
      .b_rden_i(core_m_rden_i),
      /* verilator lint_off PINCONNECTEMPTY */
      .a_dout_o(),
      /* verilator lint_on PINCONNECTEMPTY */
      .b_dout_o(core_m_rdata_o)
  );

endmodule

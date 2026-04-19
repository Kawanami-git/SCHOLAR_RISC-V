// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       sys_reset.sv
\brief      AXI write-only system reset register

\author     Kawanami
\date       17/04/2026
\version    1.0

\details
  This module exposes a simple AXI write-only register used to drive reset
  outputs inside the FPGA design.

  In its current form, only bit 0 of the internal register is exported through
  `reset0_o`. The internal storage width matches `DataWidth`, which allows this
  module to be extended later to control additional reset outputs if needed.

  \note This is a didactic component designed for clarity over feature
        completeness. The AXI behavior is intentionally simplified and only
        implements the subset required for the intended use-case.

  \section sys_reset_scope Scope and limitations (by design)
  - AXI read channels are not implemented.
  - Bursts are not intended to be used; single-beat accesses are the nominal case.
  - ID/PROT/CACHE/LOCK fields are accepted for completeness but are not
    functionally required by the use-case.

\remarks
  - TODO: implement fuller AXI4 write-channel compliance if needed.

\section sys_reset_version_history Version history
| Version | Date       | Author   | Description                    |
|:-------:|:----------:|:---------|:-------------------------------|
| 1.0     | 17/04/2026 | Kawanami | Initial version of the module. |
********************************************************************************
*/

module sys_reset

  import target_pkg::TARGET_RTL;

#(
    /// Number of bits in a byte
    parameter int          ByteLength      = 8,
    /// Address bus width in bits (applies to core and AXI)
    parameter int unsigned AddrWidth       = 32,
    /// Data bus width in bits (applies to core and AXI)
    parameter int unsigned DataWidth       = 32,
    /// Number of bits of bytes enable
    parameter int unsigned BeWidth         = DataWidth / ByteLength,
    /// Address granularity in bytes (e.g., 4 bytes for 32-bit, 8 for 64-bit)
    parameter int unsigned AddrOffset      = DataWidth / ByteLength,
    /// Number of bits needed to encode byte offset within a word
    parameter int unsigned AddrOffsetWidth = $clog2(AddrOffset),
    /// Number of internal reset register words
    parameter int unsigned Depth           = 1
) (
`ifdef SIM
    /// (Simulation only) Exposes the internal register storage to the testbench
    output logic [DataWidth-1:0] mem_o [Depth],
`endif
    /* Global signals */
    /// AXI domain clock (drives the AXI-side port of the RAM and AXI control)
    input  wire                          axi_clk_i,
    /// Global active-low reset for AXI control logic (memory contents unchanged)
    input  wire                          rstn_i,
    /* AXI signals */
    /// AWID: Write address transaction ID
    input  wire  [                7 : 0] s_axi_awid_i,
    /// AWADDR: Start byte address for write transaction
    input  wire  [AddrWidth     - 1 : 0] s_axi_awaddr_i,
    /// AWSIZE: Bytes per beat = 2**AWSIZE (should match DataWidth/ByteLength)
    input  wire  [                2 : 0] s_axi_awsize_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// AWLEN: Number of beats minus 1 (nominally 0 for single-beat)
    input  wire  [                7 : 0] s_axi_awlen_i,
    /// AWBURST: Burst type (FIXED/INCR/WRAP)
    input  wire  [                1 : 0] s_axi_awburst_i,
    /// AWLOCK: Lock (unused)
    input  wire  [                1 : 0] s_axi_awlock_i,
    /// AWCACHE: Cache hints (unused)
    input  wire  [                3 : 0] s_axi_awcache_i,
    /// AWPROT: Protection type (unused)
    input  wire  [                2 : 0] s_axi_awprot_i,
    /// AWVALID: Write address valid
    input  wire                          s_axi_awvalid_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// AWREADY: Write address ready
    output wire                          s_axi_awready_o,
    /// WDATA: Write data
    input  wire  [DataWidth     - 1 : 0] s_axi_wdata_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// WSTRB: Byte write strobes (one bit per byte)
    input  wire  [      BeWidth - 1 : 0] s_axi_wstrb_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// WLAST: Last beat of burst
    input  wire                          s_axi_wlast_i,
    /// WVALID: Write data valid
    input  wire                          s_axi_wvalid_i,
    /// WREADY: Write data ready
    output wire                          s_axi_wready_o,
    /// BID: Write transaction response ID
    output wire  [                7 : 0] s_axi_bid_o,
    /// BRESP: Write response (OKAY/SLVERR/DECERR)
    output wire  [                1 : 0] s_axi_bresp_o,
    /// BVALID: Write transaction response valid
    output wire                          s_axi_bvalid_o,
    /// BREADY: Write transaction response ready
    input  wire                          s_axi_bready_i,
    /// Reset output driven by bit 0 of the internal register
    output wire                          reset0_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  /// Useful number of bits to address the whole memory
  localparam int unsigned USED_ADDR_WIDTH = Depth == 1 ? 1 : $clog2(Depth);

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
  ///
  reg            [DataWidth - 1 : 0] mem             [Depth];
  /// Registered AWID from AXI write address channel (transaction ID)
  reg            [            7 : 0] s_axi_awid_q;
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
  reg            [            7 : 0] s_axi_bid_q;
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
      s_axi_awid_q    <= '0;
      s_axi_awaddr_q  <= '0;
      s_axi_awsize_q  <= '0;
      s_axi_awburst_q <= '0;
      s_axi_awready_q <= '0;
      s_axi_wready_q  <= '0;
      s_axi_bid_q     <= '0;
      s_axi_bresp_q   <= '0;
      s_axi_bvalid_q  <= '0;
      mem[0]          <= '0;
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
          if (s_axi_wvalid_i)
            for (int i = 0; i < BeWidth; i++) begin
              if (s_axi_wstrb_i[i])
                mem[s_axi_awaddr_q[USED_ADDR_WIDTH+AddrOffsetWidth-1:AddrOffsetWidth]][
                    i*ByteLength+:ByteLength] <= s_axi_wdata_i[i*ByteLength+:ByteLength];
            end
          // mem[s_axi_awaddr_q[USED_ADDR_WIDTH+AddrOffsetWidth-1:AddrOffsetWidth]] <= s_axi_wdata_i;
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

  /// Output driven by mem
  assign reset0_o        = mem[0][0];

`ifdef SIM
  /// Output driven by mem
  assign mem_o = mem;
`endif

endmodule

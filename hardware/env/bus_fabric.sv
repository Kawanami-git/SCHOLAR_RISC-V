// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       bus_fabric.sv
\brief      Interconnect fabric between SCHOLAR RISC-V core / AXI and memories
\author     Kawanami
\date       15/02/2026
\version    1.1

\details
  Interconnect fabric that routes memory-mapped transactions from:
    - the SCHOLAR RISC-V core (simple valid/enable style),
    - an AXI4 slave interface (e.g., CPU/DMA as AXI master upstream),
  to several target memory blocks.

  Address decoding uses configurable "address tags" extracted from
  bits TagMsb:TagLsb of the address to select the target:
    - Data RAM
    - Shared RAM (platform-to-core path, i.e. AXI write domain)
    - Shared RAM (core-to-platform path, i.e. AXI read domain)

  Assumptions:
    - No contention between different masters targeting the *same* memory
      within a single cycle (one-master-per-path model).
    - AXI side follows AMBA AXI4 rules (aligned bursts, no crossing of
      4KB boundaries, WLAST/RLAST mark end of burst).

\remarks
  - TODO: Improve comments.
  - TODO: Handle  channels fully in parallel (independent FSMs).

\section bus_fabric_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 15/02/2026 | Kawanami   | Replace core custom interface with OBI standard. |
********************************************************************************
*/

module bus_fabric #(
    /// Address bus width in bits (applies to core and AXI)
    parameter int unsigned                   AddrWidth           = 32,
    /// Data bus width in bits (applies to core and AXI)
    parameter int unsigned                   DataWidth           = 32,
    /// Most-significant bit used to extract the address tag (inclusive)
    parameter int unsigned                   TagMsb              = 19,
    /// Least-significant bit used to extract the address tag (inclusive)
    parameter int unsigned                   TagLsb              = 16,
    /// Tag identifying the Data RAM region (TAG_MSB:TAG_LSB)
    parameter logic        [TagMsb-TagLsb:0] DataRamAddrTag,
    /// Tag for platform-to-core shared RAM (AXI write -> core read)
    parameter logic        [TagMsb-TagLsb:0] PtcSharedRamAddrTag,
    /// Tag for core-to-platform shared RAM (core write -> AXI read)
    parameter logic        [TagMsb-TagLsb:0] CtpSharedRamAddrTag,
    /// AXI transaction ID width
    parameter int unsigned                   IdWidth             = 8
) (
    /* Global signals */
    /// AXI clock
    input  wire                     axi_clk_i,
    /// core clock
    input  wire                     core_clk_i,
    /// AXI reset, active low
    input  wire                     axi_rstn_i,
    /// core reset, active low
    input  wire                     core_rstn_i,
    /* Core signals */
    /// Address transfer request
    input  wire                     core_req_i,
    /// Grant: Ready to accept address transfert
    output wire                     core_gnt_o,
    /// Address for memory access
    input  wire [    AddrWidth-1:0] core_addr_i,
    /// Write enable (1: write - 0: read)
    input  wire                     core_we_i,
    /// Response transfer valid
    output wire                     core_rvalid_o,
    /// Read data
    output wire [DataWidth - 1 : 0] core_rdata_o,
    /// Error response
    output wire                     core_err_o,
    /* Data RAM signals */
    /// Address transfer request
    output wire                     dmem_req_o,
    /// Grant: Ready to accept address transfert
    input  wire                     dmem_gnt_i,
    /// Write enable (1: write - 0: read)
    output wire                     dmem_we_o,
    /// Response transfer valid
    input  wire                     dmem_rvalid_i,
    /// Read data
    input  wire [DataWidth - 1 : 0] dmem_rdata_i,
    /// Error response
    input  wire                     dmem_err_i,
    /* PTC Shared RAM */
    /// Address transfer request
    output wire                     ptc_req_o,
    /// Grant: Ready to accept address transfert
    input  wire                     ptc_gnt_i,
    /// Write enable (1: write - 0: read)
    output wire                     ptc_we_o,
    /// Response transfer valid
    input  wire                     ptc_rvalid_i,
    /// Read data
    input  wire [DataWidth - 1 : 0] ptc_rdata_i,
    /// Error response
    input  wire                     ptc_err_i,
    /* CTP Shared RAM */
    /// Address transfer request
    output wire                     ctp_req_o,
    /// Grant: Ready to accept address transfert
    input  wire                     ctp_gnt_i,
    /// Write enable (1: write - 0: read)
    output wire                     ctp_we_o,
    /// Response transfer valid
    input  wire                     ctp_rvalid_i,
    /// Read data
    input  wire [DataWidth - 1 : 0] ctp_rdata_i,
    /// Error response
    input  wire                     ctp_err_i,
    /* AXI4 Slave (connected to the master) */
    // Address Write (AW)
    /// AWID: Write address transaction ID
    input  wire [      IdWidth-1:0] s_axi_awid_i,
    /// AWADDR: Start byte address for write burst
    input  wire [    AddrWidth-1:0] s_axi_awaddr_i,
    /// AWLEN: Number of beats in burst minus 1 (0..255)
    input  wire [              7:0] s_axi_awlen_i,
    /// AWSIZE: Bytes per beat as 2**AWSIZE
    input  wire [              2:0] s_axi_awsize_i,
    /// AWBURST: Burst type (FIXED/INCR/WRAP)
    input  wire [              1:0] s_axi_awburst_i,
    /// AWLOCK: Lock (unused)
    input  wire [              1:0] s_axi_awlock_i,
    /// AWCACHE: Cache hints (unused)
    input  wire [              3:0] s_axi_awcache_i,
    /// AWPROT: Protection type (unused)
    input  wire [              2:0] s_axi_awprot_i,
    /// AWVALID: Write address valid
    input  wire                     s_axi_awvalid_i,
    /// AWREADY: Write address ready
    output wire                     s_axi_awready_o,
    /// WDATA: Write data
    input  wire [    DataWidth-1:0] s_axi_wdata_i,
    /// WSTRB: Byte write strobes
    input  wire [(DataWidth/8)-1:0] s_axi_wstrb_i,
    /// WLAST: Last beat of burst
    input  wire                     s_axi_wlast_i,
    /// WVALID: Write data valid
    input  wire                     s_axi_wvalid_i,
    /// WREADY: Write data ready
    output wire                     s_axi_wready_o,
    /// BID: Write response transaction ID
    output wire [      IdWidth-1:0] s_axi_bid_o,
    /// BRESP: Write response (OKAY/SLVERR/DECERR)
    output wire [              1:0] s_axi_bresp_o,
    /// BVALID: Write response valid
    output wire                     s_axi_bvalid_o,
    /// BREADY: Write response ready
    input  wire                     s_axi_bready_i,
    /// ARID: Read address transaction ID
    input  wire [      IdWidth-1:0] s_axi_arid_i,
    /// ARADDR: Start byte address for read burst
    input  wire [    AddrWidth-1:0] s_axi_araddr_i,
    /// ARLEN: Number of beats in burst minus 1 (0..255)
    input  wire [              7:0] s_axi_arlen_i,
    /// ARSIZE: Bytes per beat as 2**ARSIZE
    input  wire [              2:0] s_axi_arsize_i,
    /// ARBURST: Burst type (FIXED/INCR/WRAP)
    input  wire [              1:0] s_axi_arburst_i,
    /// ARLOCK: Lock
    input  wire [              1:0] s_axi_arlock_i,
    /// ARCACHE: Cache hints
    input  wire [              3:0] s_axi_arcache_i,
    /// ARPROT: Protection type
    input  wire [              2:0] s_axi_arprot_i,
    /// ARVALID: Read address valid
    input  wire                     s_axi_arvalid_i,
    /// ARREADY: Read address ready
    output wire                     s_axi_arready_o,
    /// RID: Read data transaction ID
    output wire [      IdWidth-1:0] s_axi_rid_o,
    /// RDATA: Read data
    output wire [    DataWidth-1:0] s_axi_rdata_o,
    /// RRESP: Read response (OKAY/SLVERR/DECERR)
    output wire [              1:0] s_axi_rresp_o,
    /// RLAST: Last beat of burst
    output wire                     s_axi_rlast_o,
    /// RVALID: Read data valid
    output wire                     s_axi_rvalid_o,
    /// RREADY: Read data ready
    input  wire                     s_axi_rready_i,
    /* AXI → Data RAM (target) */
    /// AWID toward Data RAM target
    output wire [      IdWidth-1:0] axi_data_ram_awid_o,
    /// AWADDR toward Data RAM target
    output wire [    AddrWidth-1:0] axi_data_ram_awaddr_o,
    /// AWLEN toward Data RAM target
    output wire [              7:0] axi_data_ram_awlen_o,
    /// AWSIZE toward Data RAM target
    output wire [              2:0] axi_data_ram_awsize_o,
    /// AWBURST toward Data RAM target
    output wire [              1:0] axi_data_ram_awburst_o,
    /// AWLOCK toward Data RAM target
    output wire [              1:0] axi_data_ram_awlock_o,
    /// AWCACHE toward Data RAM target
    output wire [              3:0] axi_data_ram_awcache_o,
    /// AWPROT toward Data RAM target
    output wire [              2:0] axi_data_ram_awprot_o,
    /// AWVALID toward Data RAM target
    output wire                     axi_data_ram_awvalid_o,
    /// AWREADY from Data RAM target
    input  wire                     axi_data_ram_awready_i,
    /// WDATA toward Data RAM target
    output wire [    DataWidth-1:0] axi_data_ram_wdata_o,
    /// WSTRB toward Data RAM target
    output wire [(DataWidth/8)-1:0] axi_data_ram_wstrb_o,
    /// WLAST toward Data RAM target
    output wire                     axi_data_ram_wlast_o,
    /// WVALID toward Data RAM target
    output wire                     axi_data_ram_wvalid_o,
    /// WREADY from Data RAM target
    input  wire                     axi_data_ram_wready_i,
    /// BID from Data RAM target
    input  wire [      IdWidth-1:0] axi_data_ram_bid_i,
    /// BRESP from Data RAM target
    input  wire [              1:0] axi_data_ram_bresp_i,
    /// BVALID from Data RAM target
    input  wire                     axi_data_ram_bvalid_i,
    /// BREADY toward Data RAM target
    output wire                     axi_data_ram_bready_o,
    /* AXI → Shared RAM (write path) */
    /// AWID toward Shared RAM (write path)
    output wire [      IdWidth-1:0] axi_shared_ram_awid_o,
    /// AWADDR toward Shared RAM (write path)
    output wire [    AddrWidth-1:0] axi_shared_ram_awaddr_o,
    /// AWLEN toward Shared RAM (write path)
    output wire [              7:0] axi_shared_ram_awlen_o,
    /// AWSIZE toward Shared RAM (write path)
    output wire [              2:0] axi_shared_ram_awsize_o,
    /// AWBURST toward Shared RAM (write path)
    output wire [              1:0] axi_shared_ram_awburst_o,
    /// AWLOCK toward Shared RAM (write path)
    output wire [              1:0] axi_shared_ram_awlock_o,
    /// AWCACHE toward Shared RAM (write path)
    output wire [              3:0] axi_shared_ram_awcache_o,
    /// AWPROT toward Shared RAM (write path)
    output wire [              2:0] axi_shared_ram_awprot_o,
    /// AWVALID toward Shared RAM (write path)
    output wire                     axi_shared_ram_awvalid_o,
    /// AWREADY from Shared RAM (write path)
    input  wire                     axi_shared_ram_awready_i,
    /// WDATA toward Shared RAM (write path)
    output wire [    DataWidth-1:0] axi_shared_ram_wdata_o,
    /// WSTRB toward Shared RAM (write path)
    output wire [(DataWidth/8)-1:0] axi_shared_ram_wstrb_o,
    /// WLAST toward Shared RAM (write path)
    output wire                     axi_shared_ram_wlast_o,
    /// WVALID toward Shared RAM (write path)
    output wire                     axi_shared_ram_wvalid_o,
    /// WREADY from Shared RAM (write path)
    input  wire                     axi_shared_ram_wready_i,
    /// BID from Shared RAM (write path)
    input  wire [      IdWidth-1:0] axi_shared_ram_bid_i,
    /// BRESP from Shared RAM (write path)
    input  wire [              1:0] axi_shared_ram_bresp_i,
    /// BVALID from Shared RAM (write path)
    input  wire                     axi_shared_ram_bvalid_i,
    /// BREADY toward Shared RAM (write path)
    output wire                     axi_shared_ram_bready_o,
    /* AXI → Shared RAM (read path) */
    /// ARID toward Shared RAM (read path)
    output wire [      IdWidth-1:0] axi_shared_ram_arid_o,
    /// ARADDR toward Shared RAM (read path)
    output wire [    AddrWidth-1:0] axi_shared_ram_araddr_o,
    /// ARLEN toward Shared RAM (read path)
    output wire [              7:0] axi_shared_ram_arlen_o,
    /// ARSIZE toward Shared RAM (read path)
    output wire [              2:0] axi_shared_ram_arsize_o,
    /// ARBURST toward Shared RAM (read path)
    output wire [              1:0] axi_shared_ram_arburst_o,
    /// ARLOCK toward Shared RAM (read path)
    output wire [              1:0] axi_shared_ram_arlock_o,
    /// ARCACHE toward Shared RAM (read path)
    output wire [              3:0] axi_shared_ram_arcache_o,
    /// ARPROT toward Shared RAM (read path)
    output wire [              2:0] axi_shared_ram_arprot_o,
    /// ARVALID toward Shared RAM (read path)
    output wire                     axi_shared_ram_arvalid_o,
    /// ARREADY from Shared RAM (read path)
    input  wire                     axi_shared_ram_arready_i,
    /// RID from Shared RAM (read path)
    input  wire [      IdWidth-1:0] axi_shared_ram_rid_i,
    /// RDATA from Shared RAM (read path)
    input  wire [    DataWidth-1:0] axi_shared_ram_rdata_i,
    /// RRESP from Shared RAM (read path)
    input  wire [              1:0] axi_shared_ram_rresp_i,
    /// RLAST from Shared RAM (read path)
    input  wire                     axi_shared_ram_rlast_i,
    /// RVALID from Shared RAM (read path)
    input  wire                     axi_shared_ram_rvalid_i,
    /// RREADY toward Shared RAM (read path)
    output wire                     axi_shared_ram_rready_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* machine states */
  /*!
  * AXI router Finite State Machine states.
  * IDLE                  -> no transaction.
  * AXI_DATA_RAM_BURST    -> AXI to data RAM write request.
  * WAXI_SHARED_RAM_BURST -> AXI to PTC shared RAM write request.
  * RAXI_SHARED_RAM_BURST -> AXI to CTP shared RAM read request.
  */
  typedef enum reg [2:0] {
    AXI_IDLE,
    AXI_DATA_RAM_BURST,
    WAXI_SHARED_RAM_BURST,
    RAXI_SHARED_RAM_BURST
  } axi_read_states_e;

  /// AXI router Finite State Machine state register
  axi_read_states_e                     axi_state_q;
  /// Core memory request address register
  reg               [AddrWidth - 1 : 0] core_addr_q;

  /* functions */
  /* verilator lint_off UNUSEDSIGNAL */
  /*!
  * This function returns '1' if the input address match the provided tag, otherwise '0'.
  * It allows to select a slave according an input address.
  */
  function automatic logic is_matching_tag(input logic [AddrWidth-1:0] addr,
                                           input logic [TagMsb:TagLsb] tag);
    return addr[TagMsb:TagLsb] == tag;
  endfunction
  /* verilator lint_on UNUSEDSIGNAL */

  /* wires */

  /* registers */

  /********************             ********************/

  /// AXI router Finite State Machine (FSM)
  /*!
  * Finite State Machine (FSM) controlling the AXI access routing.
  *
  * This FSM tracks the active AXI transaction and
  * determines which target memory
  * (data RAM, or shared RAM)
  * should receive the AXI request.
  * It transitions through predefined burst handling states and
  * returns to IDLE once the transaction completes.
  *
  * - In the `IDLE` state:
  *     • If a write address (`AWADDR`) matches a specific memory region and
  *       is valid, the FSM transitions to the corresponding write burst state.
  *     • If a read address (`ARADDR`) matches the shared memory region and
  *       is valid, it transitions to the read burst state for shared memory.
  *
  * - Each *_BURST state remains active until the AXI transaction completes:
  *     • For write transactions, completion is detected
  *       via `s_axi_bvalid_o && s_axi_bready_i`.
  *     • For read transactions, completion is detected
  *       via `axi_shared_ram_rlast_i`.
  *
  * This design ensures that only one AXI transaction is processed at a time,
  * avoiding collisions and guaranteeing proper memory access routing.
  */
  always_ff @(posedge axi_clk_i) begin : axi_fsm
    if (!axi_rstn_i) axi_state_q <= AXI_IDLE;
    else begin
      case (axi_state_q)

        AXI_IDLE: begin
          if (is_matching_tag(s_axi_awaddr_i, DataRamAddrTag) && s_axi_awvalid_i)
            axi_state_q <= AXI_DATA_RAM_BURST;
          else if (is_matching_tag(s_axi_awaddr_i, PtcSharedRamAddrTag) && s_axi_awvalid_i)
            axi_state_q <= WAXI_SHARED_RAM_BURST;
          else if (is_matching_tag(s_axi_araddr_i, CtpSharedRamAddrTag) && s_axi_arvalid_i)
            axi_state_q <= RAXI_SHARED_RAM_BURST;
        end

        AXI_DATA_RAM_BURST: if (s_axi_bready_i && s_axi_bvalid_o) axi_state_q <= AXI_IDLE;

        WAXI_SHARED_RAM_BURST: if (s_axi_bready_i && s_axi_bvalid_o) axi_state_q <= AXI_IDLE;

        RAXI_SHARED_RAM_BURST: if (axi_shared_ram_rlast_i) axi_state_q <= AXI_IDLE;

        default: axi_state_q <= AXI_IDLE;

      endcase
    end

  end

  /*!
  * When a core read request occurs, the data is
  * provided by the memory at the next cycle.
  *
  * However, as the core is pipelined, the core
  * address will also change at the next cycle.
  * This means that the mux used to redirect the
  * memory output (according to the address) may
  * not redirect the memory data to the core.
  *
  * To avoid this behavior, the address is registered
  * and used for the mux to properly provide to the
  * core with the data.
  */
  always_ff @(posedge core_clk_i) begin : core_address
    if (!core_rstn_i) begin
      core_addr_q <= '0;
    end
    else begin
      core_addr_q <= core_addr_i;
    end
  end

  assign dmem_req_o = is_matching_tag(core_addr_i, DataRamAddrTag) ? core_req_i : {1{1'b0}};
  assign dmem_we_o = is_matching_tag(core_addr_i, DataRamAddrTag) ? core_we_i : {1{1'b0}};



  assign ptc_req_o = is_matching_tag(core_addr_i, PtcSharedRamAddrTag) ? core_req_i : {1{1'b0}};
  assign ptc_we_o = is_matching_tag(core_addr_i, PtcSharedRamAddrTag) ? core_we_i : {1{1'b0}};



  assign ctp_req_o = is_matching_tag(core_addr_i, CtpSharedRamAddrTag) ? core_req_i : {1{1'b0}};
  assign ctp_we_o = is_matching_tag(core_addr_i, CtpSharedRamAddrTag) ? core_we_i : {1{1'b0}};



  assign core_rdata_o = is_matching_tag(
      core_addr_q, DataRamAddrTag
  ) ? dmem_rdata_i : is_matching_tag(
      core_addr_q, PtcSharedRamAddrTag
  ) ? ptc_rdata_i : is_matching_tag(
      core_addr_q, CtpSharedRamAddrTag
  ) ? ctp_rdata_i : {DataWidth{1'b0}};

  assign core_gnt_o = is_matching_tag(
      core_addr_i, DataRamAddrTag
  ) ? dmem_gnt_i : is_matching_tag(
      core_addr_i, PtcSharedRamAddrTag
  ) ? ptc_gnt_i : is_matching_tag(
      core_addr_i, CtpSharedRamAddrTag
  ) ? ctp_gnt_i : 1'b0;

  assign core_rvalid_o = is_matching_tag(
      core_addr_i, DataRamAddrTag
  ) ? dmem_rvalid_i : is_matching_tag(
      core_addr_i, PtcSharedRamAddrTag
  ) ? ptc_rvalid_i : is_matching_tag(
      core_addr_i, CtpSharedRamAddrTag
  ) ? ctp_rvalid_i : 'b0;

  assign core_err_o = is_matching_tag(
      core_addr_i, DataRamAddrTag
  ) ? dmem_err_i : is_matching_tag(
      core_addr_i, PtcSharedRamAddrTag
  ) ? ptc_err_i : is_matching_tag(
      core_addr_i, CtpSharedRamAddrTag
  ) ? ctp_err_i : 'b0;




  assign axi_data_ram_awid_o = is_matching_tag(
      s_axi_awaddr_i, DataRamAddrTag
  ) ? s_axi_awid_i : {IdWidth{1'b0}};
  assign axi_data_ram_awaddr_o = is_matching_tag(
      s_axi_awaddr_i, DataRamAddrTag
  ) ? s_axi_awaddr_i : {AddrWidth{1'b0}};
  assign axi_data_ram_awlen_o = is_matching_tag(
      s_axi_awaddr_i, DataRamAddrTag
  ) ? s_axi_awlen_i : {8{1'b0}};
  assign axi_data_ram_awsize_o = is_matching_tag(
      s_axi_awaddr_i, DataRamAddrTag
  ) ? s_axi_awsize_i : {3{1'b0}};
  assign axi_data_ram_awburst_o = is_matching_tag(
      s_axi_awaddr_i, DataRamAddrTag
  ) ? s_axi_awburst_i : {2{1'b0}};
  assign axi_data_ram_awlock_o = is_matching_tag(
      s_axi_awaddr_i, DataRamAddrTag
  ) ? s_axi_awlock_i : {2{1'b0}};
  assign axi_data_ram_awcache_o = is_matching_tag(
      s_axi_awaddr_i, DataRamAddrTag
  ) ? s_axi_awcache_i : {4{1'b0}};
  assign axi_data_ram_awprot_o = is_matching_tag(
      s_axi_awaddr_i, DataRamAddrTag
  ) ? s_axi_awprot_i : {3{1'b0}};
  assign axi_data_ram_awvalid_o = is_matching_tag(
      s_axi_awaddr_i, DataRamAddrTag
  ) ? s_axi_awvalid_i : {1{1'b0}};
  assign
      axi_data_ram_wdata_o = axi_state_q == AXI_DATA_RAM_BURST ? s_axi_wdata_i : {DataWidth{1'b0}};
  assign axi_data_ram_wstrb_o = axi_state_q == AXI_DATA_RAM_BURST ?
      s_axi_wstrb_i : {DataWidth / 8{1'b0}};
  assign axi_data_ram_wlast_o = axi_state_q == AXI_DATA_RAM_BURST ? s_axi_wlast_i : {1{1'b0}};
  assign axi_data_ram_wvalid_o = axi_state_q == AXI_DATA_RAM_BURST ? s_axi_wvalid_i : {1{1'b0}};
  assign axi_data_ram_bready_o = axi_state_q == AXI_DATA_RAM_BURST ? s_axi_bready_i : {1{1'b0}};



  assign axi_shared_ram_awid_o = is_matching_tag(
      s_axi_awaddr_i, PtcSharedRamAddrTag
  ) ? s_axi_awid_i : {IdWidth{1'b0}};
  assign axi_shared_ram_awaddr_o = is_matching_tag(
      s_axi_awaddr_i, PtcSharedRamAddrTag
  ) ? s_axi_awaddr_i : {AddrWidth{1'b0}};
  assign axi_shared_ram_awlen_o = is_matching_tag(
      s_axi_awaddr_i, PtcSharedRamAddrTag
  ) ? s_axi_awlen_i : {8{1'b0}};
  assign axi_shared_ram_awsize_o = is_matching_tag(
      s_axi_awaddr_i, PtcSharedRamAddrTag
  ) ? s_axi_awsize_i : {3{1'b0}};
  assign axi_shared_ram_awburst_o = is_matching_tag(
      s_axi_awaddr_i, PtcSharedRamAddrTag
  ) ? s_axi_awburst_i : {2{1'b0}};
  assign axi_shared_ram_awlock_o = is_matching_tag(
      s_axi_awaddr_i, PtcSharedRamAddrTag
  ) ? s_axi_awlock_i : {2{1'b0}};
  assign axi_shared_ram_awcache_o = is_matching_tag(
      s_axi_awaddr_i, PtcSharedRamAddrTag
  ) ? s_axi_awcache_i : {4{1'b0}};
  assign axi_shared_ram_awprot_o = is_matching_tag(
      s_axi_awaddr_i, PtcSharedRamAddrTag
  ) ? s_axi_awprot_i : {3{1'b0}};
  assign axi_shared_ram_awvalid_o = is_matching_tag(
      s_axi_awaddr_i, PtcSharedRamAddrTag
  ) ? s_axi_awvalid_i : {1{1'b0}};
  assign axi_shared_ram_wdata_o = axi_state_q == WAXI_SHARED_RAM_BURST ?
      s_axi_wdata_i : {DataWidth{1'b0}};
  assign axi_shared_ram_wstrb_o = axi_state_q == WAXI_SHARED_RAM_BURST ?
      s_axi_wstrb_i : {DataWidth / 8{1'b0}};
  assign axi_shared_ram_wlast_o = axi_state_q == WAXI_SHARED_RAM_BURST ? s_axi_wlast_i : {1{1'b0}};
  assign
      axi_shared_ram_wvalid_o = axi_state_q == WAXI_SHARED_RAM_BURST ? s_axi_wvalid_i : {1{1'b0}};
  assign
      axi_shared_ram_bready_o = axi_state_q == WAXI_SHARED_RAM_BURST ? s_axi_bready_i : {1{1'b0}};




  assign s_axi_awready_o = axi_state_q == AXI_DATA_RAM_BURST ? axi_data_ram_awready_i :
      axi_state_q == WAXI_SHARED_RAM_BURST ? axi_shared_ram_awready_i : {1{1'b0}};

  assign s_axi_wready_o = axi_state_q == AXI_DATA_RAM_BURST ? axi_data_ram_wready_i :
      axi_state_q == WAXI_SHARED_RAM_BURST ? axi_shared_ram_wready_i : {1{1'b0}};

  assign s_axi_bid_o = axi_state_q == AXI_DATA_RAM_BURST ? axi_data_ram_bid_i :
      axi_state_q == WAXI_SHARED_RAM_BURST ? axi_shared_ram_bid_i : {8{1'b0}};

  assign s_axi_bresp_o = axi_state_q == AXI_DATA_RAM_BURST ? axi_data_ram_bresp_i :
      axi_state_q == WAXI_SHARED_RAM_BURST ? axi_shared_ram_bresp_i : {2{1'b0}};

  assign s_axi_bvalid_o = axi_state_q == AXI_DATA_RAM_BURST ? axi_data_ram_bvalid_i :
      axi_state_q == WAXI_SHARED_RAM_BURST ? axi_shared_ram_bvalid_i : {1{1'b0}};




  assign axi_shared_ram_arid_o = is_matching_tag(
      s_axi_araddr_i, CtpSharedRamAddrTag
  ) ? s_axi_arid_i : {IdWidth{1'b0}};
  assign axi_shared_ram_araddr_o = is_matching_tag(
      s_axi_araddr_i, CtpSharedRamAddrTag
  ) ? s_axi_araddr_i : {AddrWidth{1'b0}};
  assign axi_shared_ram_arlen_o = is_matching_tag(
      s_axi_araddr_i, CtpSharedRamAddrTag
  ) ? s_axi_arlen_i : {8{1'b0}};
  assign axi_shared_ram_arsize_o = is_matching_tag(
      s_axi_araddr_i, CtpSharedRamAddrTag
  ) ? s_axi_arsize_i : {3{1'b0}};
  assign axi_shared_ram_arburst_o = is_matching_tag(
      s_axi_araddr_i, CtpSharedRamAddrTag
  ) ? s_axi_arburst_i : {2{1'b0}};
  assign axi_shared_ram_arlock_o = is_matching_tag(
      s_axi_araddr_i, CtpSharedRamAddrTag
  ) ? s_axi_arlock_i : {2{1'b0}};
  assign axi_shared_ram_arcache_o = is_matching_tag(
      s_axi_araddr_i, CtpSharedRamAddrTag
  ) ? s_axi_arcache_i : {4{1'b0}};
  assign axi_shared_ram_arprot_o = is_matching_tag(
      s_axi_araddr_i, CtpSharedRamAddrTag
  ) ? s_axi_arprot_i : {3{1'b0}};
  assign axi_shared_ram_arvalid_o = is_matching_tag(
      s_axi_araddr_i, CtpSharedRamAddrTag
  ) ? s_axi_arvalid_i : {1{1'b0}};
  assign s_axi_arready_o = is_matching_tag(
      s_axi_araddr_i, CtpSharedRamAddrTag
  ) ? axi_shared_ram_arready_i : {1{1'b0}};

  assign
      s_axi_rid_o = axi_state_q == RAXI_SHARED_RAM_BURST ? axi_shared_ram_rid_i : {IdWidth{1'b0}};
  assign s_axi_rdata_o = axi_state_q == RAXI_SHARED_RAM_BURST ?
      axi_shared_ram_rdata_i : {DataWidth{1'b0}};
  assign s_axi_rresp_o = axi_state_q == RAXI_SHARED_RAM_BURST ? axi_shared_ram_rresp_i : {2{1'b0}};
  assign s_axi_rlast_o = axi_state_q == RAXI_SHARED_RAM_BURST ? axi_shared_ram_rlast_i : {1{1'b0}};
  assign
      s_axi_rvalid_o = axi_state_q == RAXI_SHARED_RAM_BURST ? axi_shared_ram_rvalid_i : {1{1'b0}};
  assign
      axi_shared_ram_rready_o = axi_state_q == RAXI_SHARED_RAM_BURST ? s_axi_rready_i : {1{1'b0}};

endmodule

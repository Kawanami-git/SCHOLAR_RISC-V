// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       riscv_env.sv
\brief      SCHOLAR RISC-V Integration Environment (core + RAMs + AXI fabric)

\author     Kawanami
\date       19/12/2025
\version    1.0

\details
  Top-level integration for the SCHOLAR RISC-V core with:
  - Instruction/Data memories
  - Platform↔Core shared memories (PTC / CTP)
  - AXI4-Full slave interface (subset used)
  - Address-tag–based interconnect (bus_fabric)

  AXI scope (subset):
  - Designed for simple, single-beat bursts for simplicity.
  - Several AXI fields (IDs/PROT/CACHE/LOCK) are wired but unused in
    the educational flow.
  - Sufficient for AXI writes to instr/data/PTC RAM and AXI reads from CTP RAM.
  - Will be improved in the future.

  Memory map (conceptual):
  - INSTR RAM : core fetch read-only, AXI write (firmware instructions load)
  - DATA  RAM : core read/write, AXI write (firmware data load)
  - PTC   RAM : platform→core shared (AXI write, core read/write as designed)
  - CTP   RAM : core→platform shared (core write/read as designed, AXI read)

  In simulation (`SIM`), internal state (GPRs/PC/CSR) and RAM contents are
  exposed for DPI / Verilator testbenches.

\section riscv_env_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami   | Initial version of the module.            |
********************************************************************************
*/



`ifdef XLEN64
`define ARCHI 64
`define START_ADDR 64'h0000000080000000
`else
`define ARCHI 32
`define START_ADDR 32'h80000000
`endif

module riscv_env #(
    /// Number of bits in a byte
    parameter int unsigned             ByteLength = 8,
    /// Address bus width
    parameter int unsigned             Archi      = `ARCHI,
    /// Core reset vector (byte address)
    parameter logic        [Archi-1:0] StartAddr  = `START_ADDR,
    /// AXI transaction ID width
    parameter int unsigned             IdWidth    = 8
) (
`ifdef SIM
    /// Write-enable for GPR poke (testbench)
    input  wire                                    GprEn,
    /// GPR index to write (testbench)
    input  wire  [   RISCV_RF_ADDR_WIDTH  - 1 : 0] GprAddr,
    /// GPR value to write (testbench)
    input  wire  [         Archi          - 1 : 0] GprData,
    /// Full GPR file view (read-only mirror)
    output wire  [         Archi          - 1 : 0] GprMemory            [        NB_GPR],
    /// CSR mhpmcounter0 register
    output wire  [             DATA_WIDTH - 1 : 0] mhpmcounter0_q,
    /// CSR mhpmcounter3 register
    output wire  [             DATA_WIDTH - 1 : 0] mhpmcounter3_q,
    /// CSR mhpmcounter4 register
    output wire  [             DATA_WIDTH - 1 : 0] mhpmcounter4_q,
    /// Data RAM contents (exposed to TB)
    output logic [          Archi         - 1 : 0] DataDpramMem         [DATA_RAM_DEPTH],
    /// Writeback to GPR write enable
    output wire                                    wb_valid,
`endif
    /* Global signals*/
    /// Core clock
    input  wire                                    core_clk_i,
    /// AXI clock
    input  wire                                    axi_clk_i,
    /// Core active-low reset
    input  wire                                    core_rstn_i,
    /// AXI active-low reset
    input  wire                                    axi_rstn_i,
    /* Instructions AXI signals */
    /// AWID (INSTR)
    input  wire  [          IdWidth       - 1 : 0] s_instr_axi_awid_i,
    /// AWADDR (INSTR)
    input  wire  [         Archi          - 1 : 0] s_instr_axi_awaddr_i,
    /// AWLEN (INSTR)
    input  wire  [                          7 : 0] s_instr_axi_awlen_i,
    /// AWSIZE (INSTR)
    input  wire  [                          2 : 0] s_instr_axi_awsize_i,
    /// AWBURST (INSTR)
    input  wire  [                          1 : 0] s_instr_axi_awburst_i,
    /// AWLOCK (unused, INSTR)
    input  wire  [                          1 : 0] s_instr_axi_awlock_i,
    /// AWCACHE (unused, INSTR)
    input  wire  [                          3 : 0] s_instr_axi_awcache_i,
    /// AWPROT (unused, INSTR)
    input  wire  [                          2 : 0] s_instr_axi_awprot_i,
    /// AWVALID (INSTR)
    input  wire                                    s_instr_axi_awvalid_i,
    /// AWREADY (INSTR)
    output wire                                    s_instr_axi_awready_o,
    /// WDATA (INSTR) — fixed 32b words even if Archi=64
    input  wire  [         32             - 1 : 0] s_instr_axi_wdata_i,
    /// WSTRB (INSTR)
    input  wire  [         4              - 1 : 0] s_instr_axi_wstrb_i,
    /// WLAST (INSTR)
    input  wire                                    s_instr_axi_wlast_i,
    /// WVALID (INSTR)
    input  wire                                    s_instr_axi_wvalid_i,
    /// WREADY (INSTR)
    output wire                                    s_instr_axi_wready_o,
    /// BID (INSTR)
    output wire  [          IdWidth       - 1 : 0] s_instr_axi_bid_o,
    /// BRESP (INSTR)
    output wire  [                          1 : 0] s_instr_axi_bresp_o,
    /// BVALID (INSTR)
    output wire                                    s_instr_axi_bvalid_o,
    /// BREADY (INSTR)
    input  wire                                    s_instr_axi_bready_i,
    /* Data AXI signals */
    /// AWID (DATA)
    input  wire  [          IdWidth       - 1 : 0] s_axi_awid_i,
    /// AWADDR (DATA)
    input  wire  [         Archi          - 1 : 0] s_axi_awaddr_i,
    /// AWLEN (DATA)
    input  wire  [                          7 : 0] s_axi_awlen_i,
    /// AWSIZE (DATA)
    input  wire  [                          2 : 0] s_axi_awsize_i,
    /// AWBURST (DATA)
    input  wire  [                          1 : 0] s_axi_awburst_i,
    /// AWLOCK (unused, DATA)
    input  wire  [                          1 : 0] s_axi_awlock_i,
    /// AWCACHE (unused, DATA)
    input  wire  [                          3 : 0] s_axi_awcache_i,
    /// AWPROT (unused, DATA)
    input  wire  [                          2 : 0] s_axi_awprot_i,
    /// AWVALID (DATA)
    input  wire                                    s_axi_awvalid_i,
    /// AWREADY (DATA)
    output wire                                    s_axi_awready_o,
    /// WDATA (DATA)
    input  wire  [         Archi          - 1 : 0] s_axi_wdata_i,
    /// WSTRB (DATA)
    input  wire  [(Archi/ByteLength)      - 1 : 0] s_axi_wstrb_i,
    /// WLAST (DATA)
    input  wire                                    s_axi_wlast_i,
    /// WVALID (DATA)
    input  wire                                    s_axi_wvalid_i,
    /// WREADY (DATA)
    output wire                                    s_axi_wready_o,
    /// BID (DATA)
    output wire  [          IdWidth       - 1 : 0] s_axi_bid_o,
    /// BRESP (DATA)
    output wire  [                          1 : 0] s_axi_bresp_o,
    /// BVALID (DATA)
    output wire                                    s_axi_bvalid_o,
    /// BREADY (DATA)
    input  wire                                    s_axi_bready_i,
    /// ARID
    input  wire  [          IdWidth       - 1 : 0] s_axi_arid_i,
    /// ARADDR
    input  wire  [         Archi          - 1 : 0] s_axi_araddr_i,
    /// ARLEN
    input  wire  [                          7 : 0] s_axi_arlen_i,
    /// ARSIZE
    input  wire  [                          2 : 0] s_axi_arsize_i,
    /// ARBURST
    input  wire  [                          1 : 0] s_axi_arburst_i,
    /// ARLOCK (unused)
    input  wire  [                          1 : 0] s_axi_arlock_i,
    /// ARCACHE (unused)
    input  wire  [                          3 : 0] s_axi_arcache_i,
    /// ARPROT (unused)
    input  wire  [                          2 : 0] s_axi_arprot_i,
    /// ARVALID
    input  wire                                    s_axi_arvalid_i,
    /// ARREADY
    output wire                                    s_axi_arready_o,
    /// RID
    output wire  [          IdWidth       - 1 : 0] s_axi_rid_o,
    /// RDATA
    output wire  [         Archi          - 1 : 0] s_axi_rdata_o,
    /// RRESP
    output wire  [                          1 : 0] s_axi_rresp_o,
    /// RLAST
    output wire                                    s_axi_rlast_o,
    /// RVALID
    output wire                                    s_axi_rvalid_o,
    /// RREADY
    input  wire                                    s_axi_rready_i
);

  /******************** DECLARATION ********************/
  /* parameters verification */
  /// Ensure XLEN is supported by the build (32 or 64)
  if (Archi != 32 && Archi != 64) begin : gen_DATA_WIDTH_check
    $fatal("FATAL ERROR: Only 32-bit and 64-bit DATA_WIDTHtectures are supported.");
  end

  /* local parameters */
  /// Number of general-purpose registers
  localparam int RISCV_NB_GPR = 32;
  /// Address width of the general-purpose register file
  localparam int RISCV_RF_ADDR_WIDTH = $clog2(RISCV_NB_GPR);
  /// Instruction width (in bits, usually 32)
  localparam int RISCV_INSTR_WIDTH = 32;
  /// Address tag most significant bit position (TagMsb)
  localparam int unsigned TAG_MSB = 19;
  /// Address tag least significant bit position (TagMsb)
  localparam int unsigned TAG_LSB = 16;
  /// Instructions ram depth (word)
  localparam int unsigned INSTR_RAM_DEPTH = 4096;
  /// Instructions ram size (bytes)
  localparam int unsigned INSTR_RAM_SIZE = INSTR_RAM_DEPTH * (RISCV_INSTR_WIDTH / ByteLength);
  /// Data ram depth (word)
  localparam int unsigned DATA_RAM_DEPTH = 4096;
  /// Data ram size (bytes)
  localparam int unsigned DATA_RAM_SIZE = DATA_RAM_DEPTH * (Archi / ByteLength);
  /// Data ram tag (s_axi_axaddr_i[19:16] = 4'b0001)
  localparam logic [TAG_MSB-TAG_LSB:0] DATA_RAM_ADDR_TAG = 4'b0001;
  /// Platform-to-core shared ram depth (word)
  localparam int unsigned PTC_SHARED_RAM_DEPTH = 1024;
  /// Platform-to-core shared ram size (bytes)
  localparam int unsigned PTC_SHARED_RAM_SIZE = PTC_SHARED_RAM_DEPTH * (Archi / ByteLength);
  /// Platform-to-core shared ram tag (s_axi_axaddr_i[19:16] = 4'b0010)
  localparam logic [TAG_MSB-TAG_LSB:0] PTC_SHARED_RAM_ADDR_TAG = 4'b0010;
  /// Core-to-platform shared ram depth (word)
  localparam int unsigned CTP_SHARED_RAM_DEPTH = 1024;
  /// Core-to-platform shared ram size (bytes)
  localparam int unsigned CTP_SHARED_RAM_SIZE = CTP_SHARED_RAM_DEPTH * (Archi / ByteLength);
  /// Core-to-platform shared ram tag (s_axi_axaddr_i[19:16] = 4'b0011)
  localparam logic [TAG_MSB-TAG_LSB:0] CTP_SHARED_RAM_ADDR_TAG = 4'b0011;

  /* machine states */

  /* functions */

  /* wires */
  /// Core instruction address (byte address)
  wire [           Archi - 1 : 0] core_i_m_addr;
  /// Core instruction read enable
  wire                            core_i_m_rden;
  /// Core instruction fetch data
  wire [   RISCV_INSTR_WIDTH-1:0] core_i_m_dout;
  /// Core instruction hit/ack
  wire                            core_i_m_hit;
  /// Core data address (byte address)
  wire [           Archi - 1 : 0] core_d_m_addr;
  /// Core data write enable
  wire                            core_d_m_wren;
  /// Core data write data
  wire [           Archi - 1 : 0] core_d_m_din;
  /// Core data byte mask
  wire [  (Archi/ByteLength)-1:0] core_d_m_wmask;
  /// Core data read enable
  wire                            core_d_m_rden;
  /// Core data read data
  wire [           Archi - 1 : 0] core_d_m_dout;
  /// Core data hit/ack
  wire                            core_d_m_hit;
  /// Byte address seen by the DATA RAM (selected by the fabric)
  wire [           Archi - 1 : 0] data_ram_addr;
  /// Write enable toward DATA RAM (1 = write this cycle)
  wire                            data_ram_wren;
  /// Write data toward DATA RAM (XLEN-wide)
  wire [           Archi - 1 : 0] data_ram_wdata;
  /// Byte write mask toward DATA RAM (1 bit per byte)
  wire [(Archi/ByteLength)-1 : 0] data_ram_wmask;
  /// Read enable toward DATA RAM (1 = capture address this cycle)
  wire                            data_ram_rden;
  /// Read data returned by DATA RAM
  wire [           Archi - 1 : 0] data_ram_rdata;
  /// Combinational “accept/hit” from DATA RAM (no wait-states model)
  wire                            data_ram_hit;
  /// Byte address seen by the PTC shared RAM (fabric-decoded)
  wire [           Archi - 1 : 0] ptc_shared_ram_addr;
  /// Write enable toward PTC shared RAM
  wire                            ptc_shared_ram_wren;
  /// Write data toward PTC shared RAM
  wire [           Archi - 1 : 0] ptc_shared_ram_wdata;
  /// Byte write mask toward PTC shared RAM
  wire [(Archi/ByteLength)-1 : 0] ptc_shared_ram_wmask;
  /// Read enable toward PTC shared RAM
  wire                            ptc_shared_ram_rden;
  /// Read data returned by PTC shared RAM
  wire [           Archi - 1 : 0] ptc_shared_ram_rdata;
  /// Combinational “accept/hit” from PTC shared RAM
  wire                            ptc_shared_ram_hit;
  /// Byte address seen by the CTP shared RAM (fabric-decoded)
  wire [           Archi - 1 : 0] ctp_shared_ram_addr;
  /// Write enable toward CTP shared RAM
  wire                            ctp_shared_ram_wren;
  /// Write data toward CTP shared RAM
  wire [           Archi - 1 : 0] ctp_shared_ram_wdata;
  /// Byte write mask toward CTP shared RAM
  wire [(Archi/ByteLength)-1 : 0] ctp_shared_ram_wmask;
  /// Read enable toward CTP shared RAM
  wire                            ctp_shared_ram_rden;
  /// Read data returned by CTP shared RAM
  wire [           Archi - 1 : 0] ctp_shared_ram_rdata;
  /// Combinational “accept/hit” from CTP shared RAM
  wire                            ctp_shared_ram_hit;
  /// AXI AWID routed to DATA RAM write path
  wire [         IdWidth - 1 : 0] axi_data_ram_awid;
  /// AXI AWADDR routed to DATA RAM write path (byte address)
  wire [         Archi   - 1 : 0] axi_data_ram_awaddr;
  /// AXI AWLEN routed to DATA RAM (beats-1; nominally 0)
  wire [                     7:0] axi_data_ram_awlen;
  /// AXI AWSIZE routed to DATA RAM (log2(bytes/beat))
  wire [                     2:0] axi_data_ram_awsize;
  /// AXI AWBURST routed to DATA RAM (type; typically INCR/FIXED)
  wire [                     1:0] axi_data_ram_awburst;
  /// AXI AWLOCK routed to DATA RAM (unused in this design)
  wire [                     1:0] axi_data_ram_awlock;
  /// AXI AWCACHE routed to DATA RAM (unused in this design)
  wire [                     3:0] axi_data_ram_awcache;
  /// AXI AWPROT routed to DATA RAM (unused in this design)
  wire [                     2:0] axi_data_ram_awprot;
  /// AXI AWVALID routed to DATA RAM (address valid handshake)
  wire                            axi_data_ram_awvalid;
  /// AXI AWREADY from DATA RAM (address ready handshake)
  wire                            axi_data_ram_awready;
  /// AXI WDATA routed to DATA RAM (write payload)
  wire [           Archi - 1 : 0] axi_data_ram_wdata;
  /// AXI WSTRB routed to DATA RAM (byte strobes)
  wire [  (Archi/ByteLength)-1:0] axi_data_ram_wstrb;
  /// AXI WLAST routed to DATA RAM (last beat indicator)
  wire                            axi_data_ram_wlast;
  /// AXI WVALID routed to DATA RAM (write data valid)
  wire                            axi_data_ram_wvalid;
  /// AXI WREADY from DATA RAM (write data ready)
  wire                            axi_data_ram_wready;
  /// AXI BID from DATA RAM (write response ID)
  wire [         IdWidth - 1 : 0] axi_data_ram_bid;
  /// AXI BRESP from DATA RAM (write response code)
  wire [                     1:0] axi_data_ram_bresp;
  /// AXI BVALID from DATA RAM (write response valid)
  wire                            axi_data_ram_bvalid;
  /// AXI BREADY routed to DATA RAM (write response ready)
  wire                            axi_data_ram_bready;
  /// AXI AWID routed to PTC RAM write path
  wire [         IdWidth - 1 : 0] axi_shared_ram_awid;
  /// AXI AWADDR routed to PTC RAM write path (byte address)
  wire [         Archi   - 1 : 0] axi_shared_ram_awaddr;
  /// AXI AWLEN routed to PTC RAM (beats-1; nominally 0)
  wire [                     7:0] axi_shared_ram_awlen;
  /// AXI AWSIZE routed to PTC RAM (log2(bytes/beat))
  wire [                     2:0] axi_shared_ram_awsize;
  /// AXI AWBURST routed to PTC RAM (type; typically INCR/FIXED)
  wire [                     1:0] axi_shared_ram_awburst;
  /// AXI AWLOCK routed to PTC RAM (unused in this design)
  wire [                     1:0] axi_shared_ram_awlock;
  /// AXI AWCACHE routed to PTC RAM (unused in this design)
  wire [                     3:0] axi_shared_ram_awcache;
  /// AXI AWPROT routed to PTC RAM (unused in this design)
  wire [                     2:0] axi_shared_ram_awprot;
  /// AXI AWVALID routed to PTC RAM (address valid handshake)
  wire                            axi_shared_ram_awvalid;
  /// AXI AWREADY from PTC RAM (address ready handshake)
  wire                            axi_shared_ram_awready;
  /// AXI WDATA routed to PTC RAM (write payload)
  wire [           Archi - 1 : 0] axi_shared_ram_wdata;
  /// AXI WSTRB routed to PTC RAM (byte strobes)
  wire [  (Archi/ByteLength)-1:0] axi_shared_ram_wstrb;
  /// AXI WLAST routed to PTC RAM (last beat indicator)
  wire                            axi_shared_ram_wlast;
  /// AXI WVALID routed to PTC RAM (write data valid)
  wire                            axi_shared_ram_wvalid;
  /// AXI WREADY from PTC RAM (write data ready)
  wire                            axi_shared_ram_wready;
  /// AXI BID from PTC RAM (write response ID)
  wire [         IdWidth - 1 : 0] axi_shared_ram_bid;
  /// AXI BRESP from PTC RAM (write response code)
  wire [                     1:0] axi_shared_ram_bresp;
  /// AXI BVALID from PTC RAM (write response valid)
  wire                            axi_shared_ram_bvalid;
  /// AXI BREADY routed to PTC RAM (write response ready)
  wire                            axi_shared_ram_bready;
  /// AXI ARID routed to CTP RAM read path
  wire [         IdWidth - 1 : 0] axi_shared_ram_arid;
  /// AXI ARADDR routed to CTP RAM read path (byte address)
  wire [         Archi   - 1 : 0] axi_shared_ram_araddr;
  /// AXI ARLEN routed from fabric to CTP RAM (beats-1; nominally 0)
  wire [                     7:0] axi_shared_ram_arlen;
  /// AXI ARSIZE routed to CTP RAM (log2(bytes/beat))
  wire [                     2:0] axi_shared_ram_arsize;
  /// AXI ARBURST routed to CTP RAM (type; typically INCR/FIXED)
  wire [                     1:0] axi_shared_ram_arburst;
  /// AXI ARLOCK routed to CTP RAM (unused in this design)
  wire [                     1:0] axi_shared_ram_arlock;
  /// AXI ARCACHE routed to CTP RAM (unused in this design)
  wire [                     3:0] axi_shared_ram_arcache;
  /// AXI ARPROT routed to CTP RAM (unused in this design)
  wire [                     2:0] axi_shared_ram_arprot;
  /// AXI ARVALID routed to CTP RAM (address valid handshake)
  wire                            axi_shared_ram_arvalid;
  /// AXI ARREADY from CTP RAM (address ready handshake)
  wire                            axi_shared_ram_arready;
  /// AXI RID from CTP RAM (read response ID)
  wire [         IdWidth - 1 : 0] axi_shared_ram_rid;
  /// AXI RDATA from CTP RAM (read payload)
  wire [         Archi   - 1 : 0] axi_shared_ram_rdata;
  /// AXI RRESP from CTP RAM (read response code)
  wire [                     1:0] axi_shared_ram_rresp;
  /// AXI RLAST from CTP RAM (last beat indicator)
  wire                            axi_shared_ram_rlast;
  /// AXI RVALID from CTP RAM (read data valid)
  wire                            axi_shared_ram_rvalid;
  /// AXI RREADY routed to CTP RAM (read data ready)
  wire                            axi_shared_ram_rready;


  /* registers */


  /********************             ********************/

  /// RISC-V core instance
  scholar_riscv_core #(
      .StartAddress(StartAddr)
  ) scholar_riscv_core (
`ifdef SIM
      .gpr_en_i        (GprEn),
      .gpr_addr_i      (GprAddr),
      .gpr_data_i      (GprData),
      .gpr_memory_o    (GprMemory),
      .mhpmcounter0_q_o(mhpmcounter0_q),
      .mhpmcounter3_q_o(mhpmcounter3_q),
      .mhpmcounter4_q_o(mhpmcounter4_q),
      .wb_valid_o      (wb_valid),
`endif
      .clk_i           (core_clk_i),
      .rstn_i          (core_rstn_i),
      // IF
      .i_m_rdata_i     (core_i_m_dout),
      .i_m_hit_i       (core_i_m_hit),
      .i_m_addr_o      (core_i_m_addr),
      .i_m_rden_o      (core_i_m_rden),
      // DF
      .d_m_rdata_i     (core_d_m_dout),
      .d_m_hit_i       (core_d_m_hit),
      .d_m_addr_o      (core_d_m_addr),
      .d_m_rden_o      (core_d_m_rden),
      .d_m_wren_o      (core_d_m_wren),
      .d_m_wmask_o     (core_d_m_wmask),
      .d_m_wdata_o     (core_d_m_din)
  );

  /// data RAM: core R/W, AXI write (firmware data loader)
  waxi_dpram #(
      .AddrWidth(Archi),
      .DataWidth(Archi),
      .Size     (DATA_RAM_SIZE)
  ) data_ram (
`ifdef SIM
      .mem_o          (DataDpramMem),
`endif
      .core_clk_i     (core_clk_i),
      .axi_clk_i      (axi_clk_i),
      .rstn_i         (axi_rstn_i),
      // Core
      .core_m_addr_i  (data_ram_addr),
      .core_m_wren_i  (data_ram_wren),
      .core_m_wdata_i (data_ram_wdata),
      .core_m_wmask_i (data_ram_wmask),
      .core_m_rden_i  (data_ram_rden),
      .core_m_rdata_o (data_ram_rdata),
      .core_m_hit_o   (data_ram_hit),
      // AXI (DATA)
      .s_axi_awid_i   (axi_data_ram_awid),
      .s_axi_awaddr_i (axi_data_ram_awaddr),
      .s_axi_awlen_i  (axi_data_ram_awlen),
      .s_axi_awsize_i (axi_data_ram_awsize),
      .s_axi_awburst_i(axi_data_ram_awburst),
      .s_axi_awlock_i (axi_data_ram_awlock),
      .s_axi_awcache_i(axi_data_ram_awcache),
      .s_axi_awprot_i (axi_data_ram_awprot),
      .s_axi_awvalid_i(axi_data_ram_awvalid),
      .s_axi_awready_o(axi_data_ram_awready),
      .s_axi_wdata_i  (axi_data_ram_wdata),
      .s_axi_wstrb_i  (axi_data_ram_wstrb),
      .s_axi_wlast_i  (axi_data_ram_wlast),
      .s_axi_wvalid_i (axi_data_ram_wvalid),
      .s_axi_wready_o (axi_data_ram_wready),
      .s_axi_bid_o    (axi_data_ram_bid),
      .s_axi_bresp_o  (axi_data_ram_bresp),
      .s_axi_bvalid_o (axi_data_ram_bvalid),
      .s_axi_bready_i (axi_data_ram_bready)
  );


`ifdef SIM
  /* verilator lint_off PINMISSING */
`endif

  /// Instructions RAM: core read-only, AXI write (firmware instructions loader)
  waxi_dpram #(
      .AddrWidth(Archi),
      .DataWidth(RISCV_INSTR_WIDTH),
      .Size     (INSTR_RAM_SIZE)
  ) instr_dpram (
      .core_clk_i     (core_clk_i),
      .axi_clk_i      (axi_clk_i),
      .rstn_i         (axi_rstn_i),
      // Core
      .core_m_addr_i  (core_i_m_addr),
      .core_m_wren_i  ('0),
      .core_m_wdata_i ('0),
      .core_m_wmask_i ('0),
      .core_m_rden_i  (core_i_m_rden),
      .core_m_rdata_o (core_i_m_dout),
      .core_m_hit_o   (core_i_m_hit),
      // AXI (INSTR)
      .s_axi_awid_i   (s_instr_axi_awid_i),
      .s_axi_awaddr_i (s_instr_axi_awaddr_i),
      .s_axi_awlen_i  (s_instr_axi_awlen_i),
      .s_axi_awsize_i (s_instr_axi_awsize_i),
      .s_axi_awburst_i(s_instr_axi_awburst_i),
      .s_axi_awlock_i (s_instr_axi_awlock_i),
      .s_axi_awcache_i(s_instr_axi_awcache_i),
      .s_axi_awprot_i (s_instr_axi_awprot_i),
      .s_axi_awvalid_i(s_instr_axi_awvalid_i),
      .s_axi_awready_o(s_instr_axi_awready_o),
      .s_axi_wdata_i  (s_instr_axi_wdata_i),
      .s_axi_wstrb_i  (s_instr_axi_wstrb_i),
      .s_axi_wlast_i  (s_instr_axi_wlast_i),
      .s_axi_wvalid_i (s_instr_axi_wvalid_i),
      .s_axi_wready_o (s_instr_axi_wready_o),
      .s_axi_bid_o    (s_instr_axi_bid_o),
      .s_axi_bresp_o  (s_instr_axi_bresp_o),
      .s_axi_bvalid_o (s_instr_axi_bvalid_o),
      .s_axi_bready_i (s_instr_axi_bready_i)
  );




  /// PTC RAM: platform→core shared, AXI write path
  waxi_dpram #(
      .AddrWidth(Archi),
      .DataWidth(Archi),
      .Size     (PTC_SHARED_RAM_SIZE)
  ) w_axi_shared_ram (
      .core_clk_i     (core_clk_i),
      .axi_clk_i      (axi_clk_i),
      .rstn_i         (axi_rstn_i),
      // Core
      .core_m_addr_i  (ptc_shared_ram_addr),
      .core_m_wren_i  (ptc_shared_ram_wren),
      .core_m_wdata_i (ptc_shared_ram_wdata),
      .core_m_wmask_i (ptc_shared_ram_wmask),
      .core_m_rden_i  (ptc_shared_ram_rden),
      .core_m_rdata_o (ptc_shared_ram_rdata),
      .core_m_hit_o   (ptc_shared_ram_hit),
      // AXI (PTC write)
      .s_axi_awid_i   (axi_shared_ram_awid),
      .s_axi_awaddr_i (axi_shared_ram_awaddr),
      .s_axi_awlen_i  (axi_shared_ram_awlen),
      .s_axi_awsize_i (axi_shared_ram_awsize),
      .s_axi_awburst_i(axi_shared_ram_awburst),
      .s_axi_awlock_i (axi_shared_ram_awlock),
      .s_axi_awcache_i(axi_shared_ram_awcache),
      .s_axi_awprot_i (axi_shared_ram_awprot),
      .s_axi_awvalid_i(axi_shared_ram_awvalid),
      .s_axi_awready_o(axi_shared_ram_awready),
      .s_axi_wdata_i  (axi_shared_ram_wdata),
      .s_axi_wstrb_i  (axi_shared_ram_wstrb),
      .s_axi_wlast_i  (axi_shared_ram_wlast),
      .s_axi_wvalid_i (axi_shared_ram_wvalid),
      .s_axi_wready_o (axi_shared_ram_wready),
      .s_axi_bid_o    (axi_shared_ram_bid),
      .s_axi_bresp_o  (axi_shared_ram_bresp),
      .s_axi_bvalid_o (axi_shared_ram_bvalid),
      .s_axi_bready_i (axi_shared_ram_bready)
  );

  /// CTP RAM: core→platform shared, AXI read path
  raxi_dpram #(
      .AddrWidth(Archi),
      .DataWidth(Archi),
      .Size     (CTP_SHARED_RAM_SIZE)
  ) r_axi_shared_ram (
      .core_clk_i     (core_clk_i),
      .axi_clk_i      (axi_clk_i),
      .rstn_i         (axi_rstn_i),
      // Core
      .core_m_addr_i  (ctp_shared_ram_addr),
      .core_m_wren_i  (ctp_shared_ram_wren),
      .core_m_wdata_i (ctp_shared_ram_wdata),
      .core_m_wmask_i (ctp_shared_ram_wmask),
      .core_m_rden_i  (ctp_shared_ram_rden),
      .core_m_rdata_o (ctp_shared_ram_rdata),
      .core_m_hit_o   (ctp_shared_ram_hit),
      // AXI (CTP read)
      .s_axi_arid_i   (axi_shared_ram_arid),
      .s_axi_araddr_i (axi_shared_ram_araddr),
      .s_axi_arlen_i  (axi_shared_ram_arlen),
      .s_axi_arsize_i (axi_shared_ram_arsize),
      .s_axi_arburst_i(axi_shared_ram_arburst),
      .s_axi_arlock_i (axi_shared_ram_arlock),
      .s_axi_arcache_i(axi_shared_ram_arcache),
      .s_axi_arprot_i (axi_shared_ram_arprot),
      .s_axi_arvalid_i(axi_shared_ram_arvalid),
      .s_axi_arready_o(axi_shared_ram_arready),
      .s_axi_rid_o    (axi_shared_ram_rid),
      .s_axi_rdata_o  (axi_shared_ram_rdata),
      .s_axi_rresp_o  (axi_shared_ram_rresp),
      .s_axi_rlast_o  (axi_shared_ram_rlast),
      .s_axi_rvalid_o (axi_shared_ram_rvalid),
      .s_axi_rready_i (axi_shared_ram_rready)
  );

`ifdef SIM
  /* verilator lint_on PINMISSING */
`endif

  /// Interconnect: decodes (TagMsb:TagLsb) and routes core & AXI to the target RAMs
  bus_fabric #(
      .AddrWidth          (Archi),
      .DataWidth          (Archi),
      .TagMsb             (TAG_MSB),
      .TagLsb             (TAG_LSB),
      .DataRamAddrTag     (DATA_RAM_ADDR_TAG),
      .PtcSharedRamAddrTag(PTC_SHARED_RAM_ADDR_TAG),
      .CtpSharedRamAddrTag(CTP_SHARED_RAM_ADDR_TAG),
      .IdWidth            (IdWidth)
  ) bus_fabric (
      .axi_clk_i               (axi_clk_i),
      .core_clk_i              (core_clk_i),
      .axi_rstn_i              (axi_rstn_i),
      .core_rstn_i             (core_rstn_i),
      // Core data path → fabric
      .core_d_m_addr_i         (core_d_m_addr),
      .core_d_m_rden_i         (core_d_m_rden),
      .core_d_m_wren_i         (core_d_m_wren),
      .core_d_m_wmask_i        (core_d_m_wmask),
      .core_d_m_din_i          (core_d_m_din),
      .core_d_m_dout_o         (core_d_m_dout),
      .core_d_m_hit_o          (core_d_m_hit),
      // Fabric → DATA RAM
      .data_ram_addr_o         (data_ram_addr),
      .data_ram_wren_o         (data_ram_wren),
      .data_ram_wdata_o        (data_ram_wdata),
      .data_ram_wmask_o        (data_ram_wmask),
      .data_ram_rden_o         (data_ram_rden),
      .data_ram_rdata_i        (data_ram_rdata),
      .data_ram_hit_i          (data_ram_hit),
      // Fabric → PTC RAM (AXI write)
      .ptc_shared_ram_addr_o   (ptc_shared_ram_addr),
      .ptc_shared_ram_wren_o   (ptc_shared_ram_wren),
      .ptc_shared_ram_wdata_o  (ptc_shared_ram_wdata),
      .ptc_shared_ram_wmask_o  (ptc_shared_ram_wmask),
      .ptc_shared_ram_rden_o   (ptc_shared_ram_rden),
      .ptc_shared_ram_rdata_i  (ptc_shared_ram_rdata),
      .ptc_shared_ram_hit_i    (ptc_shared_ram_hit),
      // Fabric → CTP RAM (AXI read)
      .ctp_shared_ram_addr_o   (ctp_shared_ram_addr),
      .ctp_shared_ram_wren_o   (ctp_shared_ram_wren),
      .ctp_shared_ram_wdata_o  (ctp_shared_ram_wdata),
      .ctp_shared_ram_wmask_o  (ctp_shared_ram_wmask),
      .ctp_shared_ram_rden_o   (ctp_shared_ram_rden),
      .ctp_shared_ram_rdata_i  (ctp_shared_ram_rdata),
      .ctp_shared_ram_hit_i    (ctp_shared_ram_hit),
      // AXI (from top) → write-splits (DATA / PTC)
      .s_axi_awid_i            (s_axi_awid_i),
      .s_axi_awaddr_i          (s_axi_awaddr_i),
      .s_axi_awlen_i           (s_axi_awlen_i),
      .s_axi_awsize_i          (s_axi_awsize_i),
      .s_axi_awburst_i         (s_axi_awburst_i),
      .s_axi_awlock_i          (s_axi_awlock_i),
      .s_axi_awcache_i         (s_axi_awcache_i),
      .s_axi_awprot_i          (s_axi_awprot_i),
      .s_axi_awvalid_i         (s_axi_awvalid_i),
      .s_axi_awready_o         (s_axi_awready_o),
      .s_axi_wdata_i           (s_axi_wdata_i),
      .s_axi_wstrb_i           (s_axi_wstrb_i),
      .s_axi_wlast_i           (s_axi_wlast_i),
      .s_axi_wvalid_i          (s_axi_wvalid_i),
      .s_axi_wready_o          (s_axi_wready_o),
      .s_axi_bid_o             (s_axi_bid_o),
      .s_axi_bresp_o           (s_axi_bresp_o),
      .s_axi_bvalid_o          (s_axi_bvalid_o),
      .s_axi_bready_i          (s_axi_bready_i),
      // AXI (from top) → read-split (CTP)
      .s_axi_arid_i            (s_axi_arid_i),
      .s_axi_araddr_i          (s_axi_araddr_i),
      .s_axi_arlen_i           (s_axi_arlen_i),
      .s_axi_arsize_i          (s_axi_arsize_i),
      .s_axi_arburst_i         (s_axi_arburst_i),
      .s_axi_arlock_i          (s_axi_arlock_i),
      .s_axi_arcache_i         (s_axi_arcache_i),
      .s_axi_arprot_i          (s_axi_arprot_i),
      .s_axi_arvalid_i         (s_axi_arvalid_i),
      .s_axi_arready_o         (s_axi_arready_o),
      .s_axi_rid_o             (s_axi_rid_o),
      .s_axi_rdata_o           (s_axi_rdata_o),
      .s_axi_rresp_o           (s_axi_rresp_o),
      .s_axi_rlast_o           (s_axi_rlast_o),
      .s_axi_rvalid_o          (s_axi_rvalid_o),
      .s_axi_rready_i          (s_axi_rready_i),
      // Fabric → DATA RAM (AXI write channel bundle)
      .axi_data_ram_awid_o     (axi_data_ram_awid),
      .axi_data_ram_awaddr_o   (axi_data_ram_awaddr),
      .axi_data_ram_awlen_o    (axi_data_ram_awlen),
      .axi_data_ram_awsize_o   (axi_data_ram_awsize),
      .axi_data_ram_awburst_o  (axi_data_ram_awburst),
      .axi_data_ram_awlock_o   (axi_data_ram_awlock),
      .axi_data_ram_awcache_o  (axi_data_ram_awcache),
      .axi_data_ram_awprot_o   (axi_data_ram_awprot),
      .axi_data_ram_awvalid_o  (axi_data_ram_awvalid),
      .axi_data_ram_awready_i  (axi_data_ram_awready),
      .axi_data_ram_wdata_o    (axi_data_ram_wdata),
      .axi_data_ram_wstrb_o    (axi_data_ram_wstrb),
      .axi_data_ram_wlast_o    (axi_data_ram_wlast),
      .axi_data_ram_wvalid_o   (axi_data_ram_wvalid),
      .axi_data_ram_wready_i   (axi_data_ram_wready),
      .axi_data_ram_bid_i      (axi_data_ram_bid),
      .axi_data_ram_bresp_i    (axi_data_ram_bresp),
      .axi_data_ram_bvalid_i   (axi_data_ram_bvalid),
      .axi_data_ram_bready_o   (axi_data_ram_bready),
      // Fabric → PTC RAM (AXI write channel bundle)
      .axi_shared_ram_awid_o   (axi_shared_ram_awid),
      .axi_shared_ram_awaddr_o (axi_shared_ram_awaddr),
      .axi_shared_ram_awlen_o  (axi_shared_ram_awlen),
      .axi_shared_ram_awsize_o (axi_shared_ram_awsize),
      .axi_shared_ram_awburst_o(axi_shared_ram_awburst),
      .axi_shared_ram_awlock_o (axi_shared_ram_awlock),
      .axi_shared_ram_awcache_o(axi_shared_ram_awcache),
      .axi_shared_ram_awprot_o (axi_shared_ram_awprot),
      .axi_shared_ram_awvalid_o(axi_shared_ram_awvalid),
      .axi_shared_ram_awready_i(axi_shared_ram_awready),
      .axi_shared_ram_wdata_o  (axi_shared_ram_wdata),
      .axi_shared_ram_wstrb_o  (axi_shared_ram_wstrb),
      .axi_shared_ram_wlast_o  (axi_shared_ram_wlast),
      .axi_shared_ram_wvalid_o (axi_shared_ram_wvalid),
      .axi_shared_ram_wready_i (axi_shared_ram_wready),
      .axi_shared_ram_bid_i    (axi_shared_ram_bid),
      .axi_shared_ram_bresp_i  (axi_shared_ram_bresp),
      .axi_shared_ram_bvalid_i (axi_shared_ram_bvalid),
      .axi_shared_ram_bready_o (axi_shared_ram_bready),
      // Fabric ← CTP RAM (AXI read channel bundle)
      .axi_shared_ram_arid_o   (axi_shared_ram_arid),
      .axi_shared_ram_araddr_o (axi_shared_ram_araddr),
      .axi_shared_ram_arlen_o  (axi_shared_ram_arlen),
      .axi_shared_ram_arsize_o (axi_shared_ram_arsize),
      .axi_shared_ram_arburst_o(axi_shared_ram_arburst),
      .axi_shared_ram_arlock_o (axi_shared_ram_arlock),
      .axi_shared_ram_arcache_o(axi_shared_ram_arcache),
      .axi_shared_ram_arprot_o (axi_shared_ram_arprot),
      .axi_shared_ram_arvalid_o(axi_shared_ram_arvalid),
      .axi_shared_ram_arready_i(axi_shared_ram_arready),
      .axi_shared_ram_rid_i    (axi_shared_ram_rid),
      .axi_shared_ram_rdata_i  (axi_shared_ram_rdata),
      .axi_shared_ram_rresp_i  (axi_shared_ram_rresp),
      .axi_shared_ram_rlast_i  (axi_shared_ram_rlast),
      .axi_shared_ram_rvalid_i (axi_shared_ram_rvalid),
      .axi_shared_ram_rready_o (axi_shared_ram_rready)
  );

endmodule

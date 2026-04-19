// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       riscv_env.sv
\brief      SCHOLAR RISC-V Integration Environment (core + RAMs + AXI fabric)

\author     Kawanami
\date       16/04/2026
\version    1.5

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
| 1.0     | 02/06/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 17/10/2025 | Kawanami   | Add RV64 support.<br>Update the whole file for coding style compliance.<br>Update the whole file comments for doxygen support.              |
| 1.2     | 12/02/2026 | Kawanami   | Add non-perfect memory support.           |
| 1.3     | 13/02/2026 | Kawanami   | Replace core custom interface with OBI standard. |
| 1.4     | 28/03/2026 | Kawanami   | Improve spike compatibility.              |
| 1.5     | 16/04/2026 | Kawanami   | Add a `Target` parameter to select between the RTL implementation and vendor-specific implementations.<br>Replace the external core reset with the `sys_reset` IP.<br>Update the memory base addresses to prepare support for the Cora Z7-07S. |********************************************************************************
*/

module riscv_env

  import target_pkg::TARGET_RTL;
  import target_pkg::TARGET_MPFS_DISCOVERY_KIT;
  import target_pkg::TARGET_CORA_Z7_07S;

#(
    /// Implementation target
    parameter int unsigned             Target          = TARGET_RTL,
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned             Archi           = 32,
    /// Number of bits in a byte
    parameter int unsigned             ByteLength      = 8,
    /// Number of bits of bytes enable
    parameter int unsigned             BeWidth         = Archi / ByteLength,
    /// Instructions width
    parameter int unsigned             InstrWidth      = 32,
    /// Number of bits of bytes enable for instructions
    parameter int unsigned             InstrBeWidth    = InstrWidth / ByteLength,
    /// Use non-perfect memories
    parameter bit                      NoPerfectMemory = 0,
    /// Core reset vector (byte address)
    parameter logic        [Archi-1:0] StartAddr       = 'h00100000
) (
`ifdef SIM
    /// Simulation CSR overwrite enable
    input  wire                           csr_en,
    /// Simulation CSR overwrite data
    input  wire  [Archi          - 1 : 0] csr_data,
    /// Decode to CSR raddr
    output wire  [                11 : 0] decode_csr_raddr,
    /// Full GPR file view (read-only mirror)
    output wire  [Archi          - 1 : 0] gpr_memory      [              NB_GPR],
    /// Program counter mirror
    output wire  [Archi          - 1 : 0] gpr_pc_reg,
    /// CSR mcycle mirror
    output wire  [Archi          - 1 : 0] csr_mcycle,
    /// System reset RAM contents (exposed to TB)
    output wire  [         Archi - 1 : 0] sys_reset_mem   [     SYS_RESET_DEPTH],
    /// Instruction RAM contents (exposed to TB)
    output logic [  InstrWidth   - 1 : 0] instr_dpram_mem [     INSTR_RAM_DEPTH],
    /// Data RAM contents (exposed to TB)
    output logic [ Archi         - 1 : 0] data_dpram_mem  [      DATA_RAM_DEPTH],
    /// CTP shared RAM contents (exposed to TB)
    output logic [ Archi         - 1 : 0] ctp_dpram_mem   [CTP_SHARED_RAM_DEPTH],
    /// PTC shared RAM contents (exposed to TB)
    output logic [ Archi         - 1 : 0] ptc_dpram_mem   [PTC_SHARED_RAM_DEPTH],
    /// Writeback to GPR write enable
    output wire                           instr_committed,
`endif

    /* Global signals*/
    /// Core clock
    input  wire                                     core_clk_i,
    /// AXI clock
    input  wire                                     axi_clk_i,
    /// AXI active-low reset
    input  wire                                     axi_rstn_i,
    /* Sys reset AXI signals */
    /// AWID (sys reset)
    input  wire [                            7 : 0] sys_reset_axi_awid_i,
    /// AWADDR (sys reset)
    input  wire [           Archi          - 1 : 0] sys_reset_axi_awaddr_i,
    /// AWLEN (sys reset)
    input  wire [                            7 : 0] sys_reset_axi_awlen_i,
    /// AWSIZE (sys reset)
    input  wire [                            2 : 0] sys_reset_axi_awsize_i,
    /// AWBURST (sys reset)
    input  wire [                            1 : 0] sys_reset_axi_awburst_i,
    /// AWLOCK (unused, sys reset)
    input  wire [                            1 : 0] sys_reset_axi_awlock_i,
    /// AWCACHE (unused, sys reset)
    input  wire [                            3 : 0] sys_reset_axi_awcache_i,
    /// AWPROT (unused, sys reset)
    input  wire [                            2 : 0] sys_reset_axi_awprot_i,
    /// AWVALID (sys reset)
    input  wire                                     sys_reset_axi_awvalid_i,
    /// AWREADY (sys reset)
    output wire                                     sys_reset_axi_awready_o,
    /// WDATA (sys reset) — fixed 32b words even if Archi=64
    input  wire [        Archi             - 1 : 0] sys_reset_axi_wdata_i,
    /// WSTRB (sys reset)
    input  wire [     BeWidth              - 1 : 0] sys_reset_axi_wstrb_i,
    /// WLAST (sys reset)
    input  wire                                     sys_reset_axi_wlast_i,
    /// WVALID (sys reset)
    input  wire                                     sys_reset_axi_wvalid_i,
    /// WREADY (sys reset)
    output wire                                     sys_reset_axi_wready_o,
    /// BID (sys reset)
    output wire [                              7:0] sys_reset_axi_bid_o,
    /// BRESP (sys reset)
    output wire [                            1 : 0] sys_reset_axi_bresp_o,
    /// BVALID (sys reset)
    output wire                                     sys_reset_axi_bvalid_o,
    /// BREADY (sys reset)
    input  wire                                     sys_reset_axi_bready_i,
    /// AWID (INSTR)
    input  wire [                            7 : 0] s_instr_axi_awid_i,
    /// AWADDR (INSTR)
    input  wire [           Archi          - 1 : 0] s_instr_axi_awaddr_i,
    /// AWLEN (INSTR)
    input  wire [                            7 : 0] s_instr_axi_awlen_i,
    /// AWSIZE (INSTR)
    input  wire [                            2 : 0] s_instr_axi_awsize_i,
    /// AWBURST (INSTR)
    input  wire [                            1 : 0] s_instr_axi_awburst_i,
    /// AWLOCK (unused, INSTR)
    input  wire [                            1 : 0] s_instr_axi_awlock_i,
    /// AWCACHE (unused, INSTR)
    input  wire [                            3 : 0] s_instr_axi_awcache_i,
    /// AWPROT (unused, INSTR)
    input  wire [                            2 : 0] s_instr_axi_awprot_i,
    /// AWVALID (INSTR)
    input  wire                                     s_instr_axi_awvalid_i,
    /// AWREADY (INSTR)
    output wire                                     s_instr_axi_awready_o,
    /// WDATA (INSTR) — fixed 32b words even if Archi=64
    input  wire [   InstrWidth             - 1 : 0] s_instr_axi_wdata_i,
    /// WSTRB (INSTR)
    input  wire [InstrBeWidth              - 1 : 0] s_instr_axi_wstrb_i,
    /// WLAST (INSTR)
    input  wire                                     s_instr_axi_wlast_i,
    /// WVALID (INSTR)
    input  wire                                     s_instr_axi_wvalid_i,
    /// WREADY (INSTR)
    output wire                                     s_instr_axi_wready_o,
    /// BID (INSTR)
    output wire [                              7:0] s_instr_axi_bid_o,
    /// BRESP (INSTR)
    output wire [                            1 : 0] s_instr_axi_bresp_o,
    /// BVALID (INSTR)
    output wire                                     s_instr_axi_bvalid_o,
    /// BREADY (INSTR)
    input  wire                                     s_instr_axi_bready_i,
    /* Data AXI signals */
    /// AWID (DATA)
    input  wire [                            7 : 0] s_axi_awid_i,
    /// AWADDR (DATA)
    input  wire [           Archi          - 1 : 0] s_axi_awaddr_i,
    /// AWLEN (DATA)
    input  wire [                            7 : 0] s_axi_awlen_i,
    /// AWSIZE (DATA)
    input  wire [                            2 : 0] s_axi_awsize_i,
    /// AWBURST (DATA)
    input  wire [                            1 : 0] s_axi_awburst_i,
    /// AWLOCK (unused, DATA)
    input  wire [                            1 : 0] s_axi_awlock_i,
    /// AWCACHE (unused, DATA)
    input  wire [                            3 : 0] s_axi_awcache_i,
    /// AWPROT (unused, DATA)
    input  wire [                            2 : 0] s_axi_awprot_i,
    /// AWVALID (DATA)
    input  wire                                     s_axi_awvalid_i,
    /// AWREADY (DATA)
    output wire                                     s_axi_awready_o,
    /// WDATA (DATA)
    input  wire [           Archi          - 1 : 0] s_axi_wdata_i,
    /// WSTRB (DATA)
    input  wire [              BeWidth     - 1 : 0] s_axi_wstrb_i,
    /// WLAST (DATA)
    input  wire                                     s_axi_wlast_i,
    /// WVALID (DATA)
    input  wire                                     s_axi_wvalid_i,
    /// WREADY (DATA)
    output wire                                     s_axi_wready_o,
    /// BID (DATA)
    output wire [                            7 : 0] s_axi_bid_o,
    /// BRESP (DATA)
    output wire [                            1 : 0] s_axi_bresp_o,
    /// BVALID (DATA)
    output wire                                     s_axi_bvalid_o,
    /// BREADY (DATA)
    input  wire                                     s_axi_bready_i,
    /// ARID
    input  wire [                            7 : 0] s_axi_arid_i,
    /// ARADDR
    input  wire [           Archi          - 1 : 0] s_axi_araddr_i,
    /// ARLEN
    input  wire [                            7 : 0] s_axi_arlen_i,
    /// ARSIZE
    input  wire [                            2 : 0] s_axi_arsize_i,
    /// ARBURST
    input  wire [                            1 : 0] s_axi_arburst_i,
    /// ARLOCK (unused)
    input  wire [                            1 : 0] s_axi_arlock_i,
    /// ARCACHE (unused)
    input  wire [                            3 : 0] s_axi_arcache_i,
    /// ARPROT (unused)
    input  wire [                            2 : 0] s_axi_arprot_i,
    /// ARVALID
    input  wire                                     s_axi_arvalid_i,
    /// ARREADY
    output wire                                     s_axi_arready_o,
    /// RID
    output wire [                            7 : 0] s_axi_rid_o,
    /// RDATA
    output wire [           Archi          - 1 : 0] s_axi_rdata_o,
    /// RRESP
    output wire [                            1 : 0] s_axi_rresp_o,
    /// RLAST
    output wire                                     s_axi_rlast_o,
    /// RVALID
    output wire                                     s_axi_rvalid_o,
    /// RREADY
    input  wire                                     s_axi_rready_i
);

  /******************** DECLARATION ********************/
  /* parameters verification */
  /// Ensure XLEN is supported by the build (32 or 64)
  if (Archi != 32 && Archi != 64) begin : gen_architecture_check
    $fatal("FATAL ERROR: Only 32-bit and 64-bit architectures are supported.");
  end

  /* local parameters */
`ifdef SIM
  /// Number of integer registers
  localparam int unsigned NB_GPR = 32;
`endif
  /// Address tag most significant bit position (TagMsb)
  localparam int unsigned TAG_MSB = 19;
  /// Address tag least significant bit position (TagMsb)
  localparam int unsigned TAG_LSB = 16;
  /// System Reset ram deptch (word)
  localparam int unsigned SYS_RESET_DEPTH = 1;
  /// Instructions ram depth (word)
  localparam int unsigned INSTR_RAM_DEPTH = 4096;
  /// Data ram depth (word)
  localparam int unsigned DATA_RAM_DEPTH = 4096;
  /// Data ram tag
  localparam logic [TAG_MSB-TAG_LSB:0] DATA_RAM_ADDR_TAG = 4'b0100;
  /// Platform-to-core shared ram depth (word)
  localparam int unsigned PTC_SHARED_RAM_DEPTH = 4096;
  /// Platform-to-core shared ram tag
  localparam logic [TAG_MSB-TAG_LSB:0] PTC_SHARED_RAM_ADDR_TAG = 4'b0101;
  /// Core-to-platform shared ram depth (word)
  localparam int unsigned CTP_SHARED_RAM_DEPTH = 4096;
  /// Core-to-platform shared ram tag
  localparam logic [TAG_MSB-TAG_LSB:0] CTP_SHARED_RAM_ADDR_TAG = 4'b0110;

  /* machine states */

  /* functions */

  /* wires */
  ///
  wire                      core_rstn;
  /// Address transfer request
  wire                      core_imem_req;
  /// Grant: Ready to accept address transfert
  wire                      core_imem_gnt;
  /// Address for memory access
  wire [     Archi - 1 : 0] core_imem_addr;
  /// Response transfer valid
  wire                      core_imem_rvalid;
  /// Read data
  wire [InstrWidth - 1 : 0] core_imem_rdata;
  /// Error response
  wire                      core_imem_err;
  /// Address transfer request
  wire                      core_dmem_req;
  /// Grant: Ready to accept address transfert
  wire                      core_dmem_gnt;
  /// Address for memory access
  wire [     Archi - 1 : 0] core_dmem_addr;
  /// Write enable (1: write - 0: read)
  wire                      core_dmem_we;
  /// Write data
  wire [     Archi - 1 : 0] core_dmem_wdata;
  /// Byte enable
  wire [   BeWidth - 1 : 0] core_dmem_be;
  /// Response transfer valid
  wire                      core_dmem_rvalid;
  /// Read data
  wire [     Archi - 1 : 0] core_dmem_rdata;
  /// Error response
  wire                      core_dmem_err;
  /// Address transfer request
  wire                      dmem_req;
  /// Grant: Ready to accept address transfert
  wire                      dmem_gnt;
  /// Write enable (1: write - 0: read)
  wire                      dmem_we;
  /// Response transfer valid
  wire                      dmem_rvalid;
  /// Read data
  wire [     Archi - 1 : 0] dmem_rdata;
  /// Error response
  wire                      dmem_err;
  /// Address transfer request
  wire                      ptc_req;
  /// Grant: Ready to accept address transfert
  wire                      ptc_gnt;
  /// Write enable (1: write - 0: read)
  wire                      ptc_we;
  /// Response transfer valid
  wire                      ptc_rvalid;
  /// Read data
  wire [     Archi - 1 : 0] ptc_rdata;
  /// Error response
  wire                      ptc_err;
  /// Address transfer request
  wire                      ctp_req;
  /// Grant: Ready to accept address transfert
  wire                      ctp_gnt;
  /// Write enable (1: write - 0: read)
  wire                      ctp_we;
  /// Response transfer valid
  wire                      ctp_rvalid;
  /// Read data
  wire [     Archi - 1 : 0] ctp_rdata;
  /// Error response
  wire                      ctp_err;
  /// AXI AWID routed to DATA RAM write path
  wire [             7 : 0] axi_data_ram_awid;
  /// AXI AWADDR routed to DATA RAM write path (byte address)
  wire [   Archi   - 1 : 0] axi_data_ram_awaddr;
  /// AXI AWLEN routed to DATA RAM (beats-1; nominally 0)
  wire [               7:0] axi_data_ram_awlen;
  /// AXI AWSIZE routed to DATA RAM (log2(bytes/beat))
  wire [               2:0] axi_data_ram_awsize;
  /// AXI AWBURST routed to DATA RAM (type; typically INCR/FIXED)
  wire [               1:0] axi_data_ram_awburst;
  /// AXI AWLOCK routed to DATA RAM (unused in this design)
  wire [               1:0] axi_data_ram_awlock;
  /// AXI AWCACHE routed to DATA RAM (unused in this design)
  wire [               3:0] axi_data_ram_awcache;
  /// AXI AWPROT routed to DATA RAM (unused in this design)
  wire [               2:0] axi_data_ram_awprot;
  /// AXI AWVALID routed to DATA RAM (address valid handshake)
  wire                      axi_data_ram_awvalid;
  /// AXI AWREADY from DATA RAM (address ready handshake)
  wire                      axi_data_ram_awready;
  /// AXI WDATA routed to DATA RAM (write payload)
  wire [     Archi - 1 : 0] axi_data_ram_wdata;
  /// AXI WSTRB routed to DATA RAM (byte strobes)
  wire [       BeWidth-1:0] axi_data_ram_wstrb;
  /// AXI WLAST routed to DATA RAM (last beat indicator)
  wire                      axi_data_ram_wlast;
  /// AXI WVALID routed to DATA RAM (write data valid)
  wire                      axi_data_ram_wvalid;
  /// AXI WREADY from DATA RAM (write data ready)
  wire                      axi_data_ram_wready;
  /// AXI BID from DATA RAM (write response ID)
  wire [             7 : 0] axi_data_ram_bid;
  /// AXI BRESP from DATA RAM (write response code)
  wire [               1:0] axi_data_ram_bresp;
  /// AXI BVALID from DATA RAM (write response valid)
  wire                      axi_data_ram_bvalid;
  /// AXI BREADY routed to DATA RAM (write response ready)
  wire                      axi_data_ram_bready;
  /// AXI AWID routed to PTC RAM write path
  wire [             7 : 0] axi_shared_ram_awid;
  /// AXI AWADDR routed to PTC RAM write path (byte address)
  wire [   Archi   - 1 : 0] axi_shared_ram_awaddr;
  /// AXI AWLEN routed to PTC RAM (beats-1; nominally 0)
  wire [               7:0] axi_shared_ram_awlen;
  /// AXI AWSIZE routed to PTC RAM (log2(bytes/beat))
  wire [               2:0] axi_shared_ram_awsize;
  /// AXI AWBURST routed to PTC RAM (type; typically INCR/FIXED)
  wire [               1:0] axi_shared_ram_awburst;
  /// AXI AWLOCK routed to PTC RAM (unused in this design)
  wire [               1:0] axi_shared_ram_awlock;
  /// AXI AWCACHE routed to PTC RAM (unused in this design)
  wire [               3:0] axi_shared_ram_awcache;
  /// AXI AWPROT routed to PTC RAM (unused in this design)
  wire [               2:0] axi_shared_ram_awprot;
  /// AXI AWVALID routed to PTC RAM (address valid handshake)
  wire                      axi_shared_ram_awvalid;
  /// AXI AWREADY from PTC RAM (address ready handshake)
  wire                      axi_shared_ram_awready;
  /// AXI WDATA routed to PTC RAM (write payload)
  wire [     Archi - 1 : 0] axi_shared_ram_wdata;
  /// AXI WSTRB routed to PTC RAM (byte strobes)
  wire [       BeWidth-1:0] axi_shared_ram_wstrb;
  /// AXI WLAST routed to PTC RAM (last beat indicator)
  wire                      axi_shared_ram_wlast;
  /// AXI WVALID routed to PTC RAM (write data valid)
  wire                      axi_shared_ram_wvalid;
  /// AXI WREADY from PTC RAM (write data ready)
  wire                      axi_shared_ram_wready;
  /// AXI BID from PTC RAM (write response ID)
  wire [             7 : 0] axi_shared_ram_bid;
  /// AXI BRESP from PTC RAM (write response code)
  wire [               1:0] axi_shared_ram_bresp;
  /// AXI BVALID from PTC RAM (write response valid)
  wire                      axi_shared_ram_bvalid;
  /// AXI BREADY routed to PTC RAM (write response ready)
  wire                      axi_shared_ram_bready;
  /// AXI ARID routed to CTP RAM read path
  wire [             7 : 0] axi_shared_ram_arid;
  /// AXI ARADDR routed to CTP RAM read path (byte address)
  wire [   Archi   - 1 : 0] axi_shared_ram_araddr;
  /// AXI ARLEN routed from fabric to CTP RAM (beats-1; nominally 0)
  wire [               7:0] axi_shared_ram_arlen;
  /// AXI ARSIZE routed to CTP RAM (log2(bytes/beat))
  wire [               2:0] axi_shared_ram_arsize;
  /// AXI ARBURST routed to CTP RAM (type; typically INCR/FIXED)
  wire [               1:0] axi_shared_ram_arburst;
  /// AXI ARLOCK routed to CTP RAM (unused in this design)
  wire [               1:0] axi_shared_ram_arlock;
  /// AXI ARCACHE routed to CTP RAM (unused in this design)
  wire [               3:0] axi_shared_ram_arcache;
  /// AXI ARPROT routed to CTP RAM (unused in this design)
  wire [               2:0] axi_shared_ram_arprot;
  /// AXI ARVALID routed to CTP RAM (address valid handshake)
  wire                      axi_shared_ram_arvalid;
  /// AXI ARREADY from CTP RAM (address ready handshake)
  wire                      axi_shared_ram_arready;
  /// AXI RID from CTP RAM (read response ID)
  wire [             7 : 0] axi_shared_ram_rid;
  /// AXI RDATA from CTP RAM (read payload)
  wire [   Archi   - 1 : 0] axi_shared_ram_rdata;
  /// AXI RRESP from CTP RAM (read response code)
  wire [               1:0] axi_shared_ram_rresp;
  /// AXI RLAST from CTP RAM (last beat indicator)
  wire                      axi_shared_ram_rlast;
  /// AXI RVALID from CTP RAM (read data valid)
  wire                      axi_shared_ram_rvalid;
  /// AXI RREADY routed to CTP RAM (read data ready)
  wire                      axi_shared_ram_rready;


  /* registers */


  /********************             ********************/



  /// RISC-V core instance
  scholar_riscv_core #(
      .Archi       (Archi),
      .StartAddress(StartAddr)
  ) scholar_riscv_core (
`ifdef SIM
      .csr_en_i          (csr_en),
      .csr_data_i        (csr_data),
      .decode_csr_raddr_o(decode_csr_raddr),
      .gpr_memory_o      (gpr_memory),
      .gpr_pc_q_o        (gpr_pc_reg),
      .csr_mcycle_q_o    (csr_mcycle),
      .instr_committed_o (instr_committed),
`endif
      .clk_i             (core_clk_i),
      .rstn_i            (core_rstn),
      // IF
      .imem_req_o        (core_imem_req),
      .imem_gnt_i        (core_imem_gnt),
      .imem_addr_o       (core_imem_addr),
      .imem_rvalid_i     (core_imem_rvalid),
      .imem_rdata_i      (core_imem_rdata),
      .imem_err_i        (core_imem_err),
      // DF
      .dmem_req_o        (core_dmem_req),
      .dmem_gnt_i        (core_dmem_gnt),
      .dmem_addr_o       (core_dmem_addr),
      .dmem_we_o         (core_dmem_we),
      .dmem_wdata_o      (core_dmem_wdata),
      .dmem_be_o         (core_dmem_be),
      .dmem_rvalid_i     (core_dmem_rvalid),
      .dmem_rdata_i      (core_dmem_rdata),
      .dmem_err_i        (core_dmem_err)
  );

  /// System reset instance
  sys_reset #(
      .AddrWidth(Archi),
      .DataWidth(Archi),
      .Depth    (1)
  ) sys_reset (
`ifdef SIM
      .mem_o          (sys_reset_mem),
`endif
      .axi_clk_i      (axi_clk_i),
      .rstn_i         (axi_rstn_i),
      // AXI (INSTR)
      .s_axi_awid_i   (sys_reset_axi_awid_i),
      .s_axi_awaddr_i (sys_reset_axi_awaddr_i),
      .s_axi_awlen_i  (sys_reset_axi_awlen_i),
      .s_axi_awsize_i (sys_reset_axi_awsize_i),
      .s_axi_awburst_i(sys_reset_axi_awburst_i),
      .s_axi_awlock_i (sys_reset_axi_awlock_i),
      .s_axi_awcache_i(sys_reset_axi_awcache_i),
      .s_axi_awprot_i (sys_reset_axi_awprot_i),
      .s_axi_awvalid_i(sys_reset_axi_awvalid_i),
      .s_axi_awready_o(sys_reset_axi_awready_o),
      .s_axi_wdata_i  (sys_reset_axi_wdata_i),
      .s_axi_wstrb_i  (sys_reset_axi_wstrb_i),
      .s_axi_wlast_i  (sys_reset_axi_wlast_i),
      .s_axi_wvalid_i (sys_reset_axi_wvalid_i),
      .s_axi_wready_o (sys_reset_axi_wready_o),
      .s_axi_bid_o    (sys_reset_axi_bid_o),
      .s_axi_bresp_o  (sys_reset_axi_bresp_o),
      .s_axi_bvalid_o (sys_reset_axi_bvalid_o),
      .s_axi_bready_i (sys_reset_axi_bready_i),
      .reset0_o       (core_rstn)
  );

  /// Instructions RAM: core read-only, AXI write (firmware instructions loader)
  waxi_dpram #(
      .Target         (Target),
      .NoPerfectMemory(NoPerfectMemory),
      .AddrWidth      (Archi),
      .DataWidth      (InstrWidth),
      .Depth          (INSTR_RAM_DEPTH)
  ) instr_dpram (
`ifdef SIM
      .mem_o          (instr_dpram_mem),
`endif
      .core_clk_i     (core_clk_i),
      .axi_clk_i      (axi_clk_i),
      .rstn_i         (axi_rstn_i),
      // Core
      .req_i          (core_imem_req),
      .gnt_o          (core_imem_gnt),
      .addr_i         (core_imem_addr),
      .we_i           ('0),
      .wdata_i        ('0),
      .be_i           ('0),
      .rvalid_o       (core_imem_rvalid),
      .rdata_o        (core_imem_rdata),
      .err_o          (core_imem_err),
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

  /// data RAM: core R/W, AXI write (firmware data loader)
  waxi_dpram #(
      .Target         (Target),
      .NoPerfectMemory(NoPerfectMemory),
      .AddrWidth      (Archi),
      .DataWidth      (Archi),
      .Depth          (DATA_RAM_DEPTH)
  ) data_ram (
`ifdef SIM
      .mem_o          (data_dpram_mem),
`endif
      .core_clk_i     (core_clk_i),
      .axi_clk_i      (axi_clk_i),
      .rstn_i         (axi_rstn_i),
      // Core
      .req_i          (dmem_req),
      .gnt_o          (dmem_gnt),
      .addr_i         (core_dmem_addr),
      .we_i           (dmem_we),
      .wdata_i        (core_dmem_wdata),
      .be_i           (core_dmem_be),
      .rvalid_o       (dmem_rvalid),
      .rdata_o        (dmem_rdata),
      .err_o          (dmem_err),
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

  /// PTC RAM: platform→core shared, AXI write path
  waxi_dpram #(
      .Target         (Target),
      .NoPerfectMemory(NoPerfectMemory),
      .AddrWidth      (Archi),
      .DataWidth      (Archi),
      .Depth          (PTC_SHARED_RAM_DEPTH)
  ) w_axi_shared_ram (
`ifdef SIM
      .mem_o          (ptc_dpram_mem),
`endif
      .core_clk_i     (core_clk_i),
      .axi_clk_i      (axi_clk_i),
      .rstn_i         (axi_rstn_i),
      // Core
      .req_i          (ptc_req),
      .gnt_o          (ptc_gnt),
      .addr_i         (core_dmem_addr),
      .we_i           (ptc_we),
      .wdata_i        (core_dmem_wdata),
      .be_i           (core_dmem_be),
      .rvalid_o       (ptc_rvalid),
      .rdata_o        (ptc_rdata),
      .err_o          (ptc_err),
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
      .Target         (Target),
      .NoPerfectMemory(NoPerfectMemory),
      .AddrWidth      (Archi),
      .DataWidth      (Archi),
      .Depth          (CTP_SHARED_RAM_DEPTH)
  ) r_axi_shared_ram (
`ifdef SIM
      .mem_o          (ctp_dpram_mem),
`endif
      .core_clk_i     (core_clk_i),
      .axi_clk_i      (axi_clk_i),
      .rstn_i         (axi_rstn_i),
      // Core
      .req_i          (ctp_req),
      .gnt_o          (ctp_gnt),
      .addr_i         (core_dmem_addr),
      .we_i           (ctp_we),
      .wdata_i        (core_dmem_wdata),
      .be_i           (core_dmem_be),
      .rvalid_o       (ctp_rvalid),
      .rdata_o        (ctp_rdata),
      .err_o          (ctp_err),
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


  /// Interconnect: decodes (TagMsb:TagLsb) and routes core & AXI to the target RAMs
  bus_fabric #(
      .Archi              (Archi),
      .TagMsb             (TAG_MSB),
      .TagLsb             (TAG_LSB),
      .DataRamAddrTag     (DATA_RAM_ADDR_TAG),
      .PtcSharedRamAddrTag(PTC_SHARED_RAM_ADDR_TAG),
      .CtpSharedRamAddrTag(CTP_SHARED_RAM_ADDR_TAG)
  ) bus_fabric (
      .clk_i                   (axi_clk_i),
      .rstn_i                  (axi_rstn_i),
      // Core data path → fabric
      .core_req_i              (core_dmem_req),
      .core_gnt_o              (core_dmem_gnt),
      .core_addr_i             (core_dmem_addr),
      .core_we_i               (core_dmem_we),
      .core_rvalid_o           (core_dmem_rvalid),
      .core_rdata_o            (core_dmem_rdata),
      .core_err_o              (core_dmem_err),
      // Fabric → DATA RAM
      .dmem_req_o              (dmem_req),
      .dmem_gnt_i              (dmem_gnt),
      .dmem_we_o               (dmem_we),
      .dmem_rvalid_i           (dmem_rvalid),
      .dmem_rdata_i            (dmem_rdata),
      .dmem_err_i              (dmem_err),
      // Fabric → PTC RAM (AXI write)
      .ptc_req_o               (ptc_req),
      .ptc_gnt_i               (ptc_gnt),
      .ptc_we_o                (ptc_we),
      .ptc_rvalid_i            (ptc_rvalid),
      .ptc_rdata_i             (ptc_rdata),
      .ptc_err_i               (ptc_err),
      // Fabric → CTP RAM (AXI read)
      .ctp_req_o               (ctp_req),
      .ctp_gnt_i               (ctp_gnt),
      .ctp_we_o                (ctp_we),
      .ctp_rvalid_i            (ctp_rvalid),
      .ctp_rdata_i             (ctp_rdata),
      .ctp_err_i               (ctp_err),
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

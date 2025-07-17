/*!
********************************************************************************
*  \file      riscv_env.sv
*  \module    riscv_env
*  \brief     SCHOLAR RISC-V Integration Environment
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/06/2025
*
********************************************************************************
*  \details
*  This module defines the complete integration environment for the SCHOLAR RISC-V core.
*  It includes all necessary memory and interconnect components to execute and simulate
*  embedded firmware using both the RISC-V core and an AXI interface.
*
*  The AXI interface implements AXI4-Full. However, only a basic subset is supported:
*  a single transaction per burst is allowed, due to incompatibilities with the PolarFire
*  AXI interconnect. Additionally, several signals—such as AXI IDs, PROT, etc.—are unused.
*  Despite these limitations, the interface is sufficient for performing reads and writes
*  to dual-port RAMs, which is the main objective of this educational platform focused on
*  RISC-V processor exploration.
*
*  Four distinct dual-port RAM blocks are instantiated:
*    - INSTR RAM  : Instruction memory (read-only for the core, write-only via AXI)
*    - DATA RAM   : Core data memory (read/write for the core, write-only via AXI)
*    - PTC RAM    : Shared memory from Platform to Core (AXI write, core read)
*    - CTP RAM    : Shared memory from Core to Platform (core write, AXI read)
*
*  The system supports memory-mapped access to all blocks via AXI,
*  and full memory visibility in simulation mode via Verilator DPI tracing or C++ DPI access.
*
*  This module is designed primarily for simulation but mirrors the intended structure
*  for implementation on Microchip PolarFire SoC-FPGAs.
*
*  The `ifdef DUT` macro enables internal signal visibility for simulation and debug,
*  including register file contents, CSRs, and memory arrays.
********************************************************************************
*  \parameters
*    - ARCHI             : Architecture (currently, only 32-bit version is supported)
*    - ID_WIDTH          : Width of AXI transaction ID fields
*
*  \inputs
*    - CORE_CLK          : Clock signal for RISC-V core
*    - AXI_CLK           : Clock signal for AXI subsystem
*    - CORE_RSTN         : Active-low reset for RISC-V core
*    - AXI_RSTN          : Active-low reset for AXI system
*
*    - S_AXI_*           : AXI4 slave interface for instruction, data, and shared memory access
*
*    - GPR_EN            : General-purpose register write enable (simulation only)
*    - GPR_ADDR          : Address of GPR to write (simulation only)
*    - GPR_DATA          : Value to write into a GPR (simulation only)
*
*  \outputs
*    - GPR_MEM           : General-purpose register file view (simulation only)
*    - GPR_PC_REG        : Current program counter of core (simulation only)
*    - CSR_MCYCLE        : Cycle counter CSR (simulation only)
*
*    - *_DPRAM_MEM       : Contents of instantiated DPRAMs (simulation only)
*                          Exposed for DPI-C access in Verilator testbenches
*
*    - S_AXI_*           : AXI4 slave interface for instruction, data, and shared memory access
*
*  \inouts
*    - None.
********************************************************************************
*  \versioning
*
*  Version   Date          Author          Description
*  -------   ----------    ------------    --------------------------------------
*  1.0       02/06/2025    Kawanami        Initial version of the module
*  1.1       [Date]        [Author]        Description
*  1.2       [Date]        [Author]        Description
*
********************************************************************************
*  \remarks
*  - This implementation complies with [reference or standard].
*  - TODO: [possible improvements or future features]
********************************************************************************
*/


`include "packages.sv"

module riscv_env
    import archi_pkg::*;
#(
    parameter ARCHI      	    = 32,
    parameter ID_WIDTH          = 8
)
(
`ifdef DUT
    input  wire                                 GPR_EN                                          ,
    input  wire [RF_ADDR_WIDTH  - 1 : 0]        GPR_ADDR                                        ,
    input  wire [ARCHI          - 1 : 0]        GPR_DATA                                        ,
    output wire [ARCHI          - 1 : 0]        GPR_MEMORY           [0:NB_GPR-1]               ,
    output wire [ARCHI          - 1 : 0]        GPR_PC_REG                                      ,
    output wire [ARCHI          - 1 : 0]        CSR_MCYCLE                                      ,

    output logic [ARCHI         - 1 : 0]        INSTR_DPRAM_MEM      [0:INSTR_RAM_DEPTH-1]      ,
    output logic [ARCHI         - 1 : 0]        DATA_DPRAM_MEM       [0:DATA_RAM_DEPTH-1]       ,
    output logic [ARCHI         - 1 : 0]        PTC_SHARED_DPRAM_MEM [0:PTC_SHARED_RAM_DEPTH-1] ,
    output logic [ARCHI         - 1 : 0]        CTP_SHARED_DPRAM_MEM [0:CTP_SHARED_RAM_DEPTH-1] ,
`endif

    input  wire                                 CORE_CLK                                        ,
    input  wire                                 AXI_CLK                                         ,
    input  wire                                 CORE_RSTN                                       ,
    input  wire                                 AXI_RSTN                                        ,

    // AXI
    input  wire [ID_WIDTH       - 1 : 0]        S_AXI_AWID                                      ,
    input  wire [ARCHI          - 1 : 0]        S_AXI_AWADDR                                    ,
    input  wire [                 7 : 0]        S_AXI_AWLEN                                     ,
    input  wire [                 2 : 0]        S_AXI_AWSIZE                                    ,
    input  wire [                 1 : 0]        S_AXI_AWBURST                                   ,
    input  wire [                 1 : 0]        S_AXI_AWLOCK                                    ,
    input  wire [                 3 : 0]        S_AXI_AWCACHE                                   ,
    input  wire [                 2 : 0]        S_AXI_AWPROT                                    ,
    input  wire                                 S_AXI_AWVALID                                   ,
    output wire                                 S_AXI_AWREADY                                   ,

    input  wire [ARCHI          - 1 : 0]        S_AXI_WDATA                                     ,
    input  wire [(ARCHI/8)      - 1 : 0]        S_AXI_WSTRB                                     ,
    input  wire                                 S_AXI_WLAST                                     ,
    input  wire                                 S_AXI_WVALID                                    ,
    output wire                                 S_AXI_WREADY                                    ,

    output wire [ID_WIDTH       - 1 : 0]        S_AXI_BID                                       ,
    output wire [                 1 : 0]        S_AXI_BRESP                                     ,
    output wire                                 S_AXI_BVALID                                    ,
    input  wire                                 S_AXI_BREADY                                    ,

    input  wire [ID_WIDTH       - 1 : 0]        S_AXI_ARID                                      ,
    input  wire [ARCHI          - 1 : 0]        S_AXI_ARADDR                                    ,
    input  wire [                 7 : 0]        S_AXI_ARLEN                                     ,
    input  wire [                 2 : 0]        S_AXI_ARSIZE                                    ,
    input  wire [                 1 : 0]        S_AXI_ARBURST                                   ,
    input  wire [                 1 : 0]        S_AXI_ARLOCK                                    ,
    input  wire [                 3 : 0]        S_AXI_ARCACHE                                   ,
    input  wire [                 2 : 0]        S_AXI_ARPROT                                    ,
    input  wire                                 S_AXI_ARVALID                                   ,
    output wire                                 S_AXI_ARREADY                                   ,

    output wire [ID_WIDTH       - 1 : 0]        S_AXI_RID                                       ,
    output wire [ARCHI          - 1 : 0]        S_AXI_RDATA                                     ,
    output wire [                 1 : 0]        S_AXI_RRESP                                     ,
    output wire                                 S_AXI_RLAST                                     ,
    output wire                                 S_AXI_RVALID                                    ,
    input  wire                                 S_AXI_RREADY
);


/******************** PARAMETERS VERIFICATION ********************/

/********************                         ********************/

/******************** LOCAL PARAMETERS ********************/
`ifdef ARCHI64

`else

localparam TAG_MSB                      = 19;
localparam TAG_LSB                      = 16;

localparam INSTR_RAM_SIZE               = 32'h00004000;
localparam INSTR_RAM_DEPTH              = INSTR_RAM_SIZE / (ARCHI / 8);
localparam INSTR_RAM_ADDR_WIDTH         = $clog2(INSTR_RAM_SIZE);
localparam INSTR_RAM_ADDR_TAG           = 4'b0000;

localparam DATA_RAM_SIZE                = 32'h00004000;
localparam DATA_RAM_DEPTH               = DATA_RAM_SIZE / (ARCHI / 8);
localparam DATA_RAM_ADDR_WIDTH          = $clog2(DATA_RAM_SIZE);
localparam DATA_RAM_ADDR_TAG            = 4'b0001;

localparam PTC_SHARED_RAM_SIZE         = 32'h00000800;
localparam PTC_SHARED_RAM_DEPTH        = PTC_SHARED_RAM_SIZE / (ARCHI / 8);
localparam PTC_SHARED_RAM_ADDR_WIDTH   = $clog2(PTC_SHARED_RAM_SIZE);
localparam PTC_SHARED_RAM_ADDR_TAG     = 4'b0010;

localparam CTP_SHARED_RAM_SIZE         = 32'h00000800;
localparam CTP_SHARED_RAM_DEPTH        = CTP_SHARED_RAM_SIZE / (ARCHI / 8);
localparam CTP_SHARED_RAM_ADDR_WIDTH   = $clog2(CTP_SHARED_RAM_SIZE);
localparam CTP_SHARED_RAM_ADDR_TAG     = 4'b0011;

localparam START_ADDR                  = 32'h80000000;
`endif

/********************                  ********************/

/******************** TYPES DEFINITION ********************/

/********************                  ********************/

/******************** WIRES ********************/
/* verilator lint_off UNUSEDSIGNAL */                                     // Disable Verilator warning `Bits of signal are not used`
wire [ARCHI     - 1 : 0]        core_i_m_addr;
/* verilator lint_on UNUSEDSIGNAL */                                      // Re-enable Verilator warning `Bits of signal are not used`
wire                            core_i_m_rden;
wire [ARCHI     - 1 : 0]        core_i_m_dout;
wire                            core_i_m_hit;

wire [ARCHI     - 1 : 0]        core_d_m_addr;
wire                            core_d_m_wren;
wire [ARCHI     - 1 : 0]        core_d_m_din;
wire [(ARCHI/8) - 1 : 0]        core_d_m_wmask;
wire                            core_d_m_rden;
wire [ARCHI     - 1 : 0]        core_d_m_dout;
wire                            core_d_m_hit;

/* verilator lint_off UNUSEDSIGNAL */                                     // Disable Verilator warning `Bits of signal are not used`
wire [ARCHI     - 1 : 0]        data_ram_addr ;
/* verilator lint_on UNUSEDSIGNAL */                                      // Re-enable Verilator warning `Bits of signal are not used`
wire                            data_ram_wren ;
wire [ARCHI     - 1 : 0]        data_ram_wdata;
wire [ARCHI/8   - 1 : 0]        data_ram_wmask;
wire                            data_ram_rden ;
wire [ARCHI     - 1 : 0]        data_ram_rdata;
wire                            data_ram_hit  ;

/* verilator lint_off UNUSEDSIGNAL */                                     // Disable Verilator warning `Bits of signal are not used`
wire [ARCHI     - 1 : 0]        ptc_shared_ram_addr ;
/* verilator lint_on UNUSEDSIGNAL */                                      // Re-enable Verilator warning `Bits of signal are not used`
wire                            ptc_shared_ram_wren ;
wire [ARCHI     - 1 : 0]        ptc_shared_ram_wdata;
wire [ARCHI/8   - 1 : 0]        ptc_shared_ram_wmask;
wire                            ptc_shared_ram_rden ;
wire [ARCHI     - 1 : 0]        ptc_shared_ram_rdata;
wire                            ptc_shared_ram_hit  ;

/* verilator lint_off UNUSEDSIGNAL */                                     // Disable Verilator warning `Bits of signal are not used`
wire [ARCHI     - 1 : 0]        ctp_shared_ram_addr ;
/* verilator lint_on UNUSEDSIGNAL */                                      // Re-enable Verilator warning `Bits of signal are not used`
wire                            ctp_shared_ram_wren ;
wire [ARCHI     - 1 : 0]        ctp_shared_ram_wdata;
wire [ARCHI/8   - 1 : 0]        ctp_shared_ram_wmask;
wire                            ctp_shared_ram_rden ;
wire [ARCHI     - 1 : 0]        ctp_shared_ram_rdata;
wire                            ctp_shared_ram_hit  ;


wire [ID_WIDTH       - 1 : 0]   axi_instr_ram_awid   ;
/* verilator lint_off UNUSEDSIGNAL */                                     // Disable Verilator warning `Bits of signal are not used`
wire [ARCHI          - 1 : 0]   axi_instr_ram_awaddr ;
/* verilator lint_on UNUSEDSIGNAL */                                      // Re-enable Verilator warning `Bits of signal are not used`
wire [                 7 : 0]   axi_instr_ram_awlen  ;
wire [                 2 : 0]   axi_instr_ram_awsize ;
wire [                 1 : 0]   axi_instr_ram_awburst;
wire [                 1 : 0]   axi_instr_ram_awlock ;
wire [                 3 : 0]   axi_instr_ram_awcache;
wire [                 2 : 0]   axi_instr_ram_awprot ;
wire                            axi_instr_ram_awvalid;
wire                            axi_instr_ram_awready;
wire [ARCHI          - 1 : 0]   axi_instr_ram_wdata  ;
wire [(ARCHI/8)      - 1 : 0]   axi_instr_ram_wstrb  ;
wire                            axi_instr_ram_wlast  ;
wire                            axi_instr_ram_wvalid ;
wire                            axi_instr_ram_wready ;
wire [ID_WIDTH       - 1 : 0]   axi_instr_ram_bid    ;
wire [                 1 : 0]   axi_instr_ram_bresp  ;
wire                            axi_instr_ram_bvalid ;
wire                            axi_instr_ram_bready ;

wire [ID_WIDTH       - 1 : 0]   axi_data_ram_awid   ;
/* verilator lint_off UNUSEDSIGNAL */                                     // Disable Verilator warning `Bits of signal are not used`
wire [ARCHI          - 1 : 0]   axi_data_ram_awaddr ;
/* verilator lint_on UNUSEDSIGNAL */                                      // Re-enable Verilator warning `Bits of signal are not used`
wire [                 7 : 0]   axi_data_ram_awlen  ;
wire [                 2 : 0]   axi_data_ram_awsize ;
wire [                 1 : 0]   axi_data_ram_awburst;
wire [                 1 : 0]   axi_data_ram_awlock ;
wire [                 3 : 0]   axi_data_ram_awcache;
wire [                 2 : 0]   axi_data_ram_awprot ;
wire                            axi_data_ram_awvalid;
wire                            axi_data_ram_awready;
wire [ARCHI          - 1 : 0]   axi_data_ram_wdata  ;
wire [(ARCHI/8)      - 1 : 0]   axi_data_ram_wstrb  ;
wire                            axi_data_ram_wlast  ;
wire                            axi_data_ram_wvalid ;
wire                            axi_data_ram_wready ;
wire [ID_WIDTH       - 1 : 0]   axi_data_ram_bid    ;
wire [                 1 : 0]   axi_data_ram_bresp  ;
wire                            axi_data_ram_bvalid ;
wire                            axi_data_ram_bready ;

wire [ID_WIDTH       - 1 : 0]   axi_shared_ram_awid   ;
/* verilator lint_off UNUSEDSIGNAL */                                     // Disable Verilator warning `Bits of signal are not used`
wire [ARCHI          - 1 : 0]   axi_shared_ram_awaddr ;
/* verilator lint_on UNUSEDSIGNAL */                                      // Re-enable Verilator warning `Bits of signal are not used`
wire [                 7 : 0]   axi_shared_ram_awlen  ;
wire [                 2 : 0]   axi_shared_ram_awsize ;
wire [                 1 : 0]   axi_shared_ram_awburst;
wire [                 1 : 0]   axi_shared_ram_awlock ;
wire [                 3 : 0]   axi_shared_ram_awcache;
wire [                 2 : 0]   axi_shared_ram_awprot ;
wire                            axi_shared_ram_awvalid;
wire                            axi_shared_ram_awready;
wire [ARCHI          - 1 : 0]   axi_shared_ram_wdata  ;
wire [(ARCHI/8)      - 1 : 0]   axi_shared_ram_wstrb  ;
wire                            axi_shared_ram_wlast  ;
wire                            axi_shared_ram_wvalid ;
wire                            axi_shared_ram_wready ;
wire [ID_WIDTH       - 1 : 0]   axi_shared_ram_bid    ;
wire [                 1 : 0]   axi_shared_ram_bresp  ;
wire                            axi_shared_ram_bvalid ;
wire                            axi_shared_ram_bready ;

wire [ID_WIDTH       - 1 : 0]   axi_shared_ram_arid    ;
/* verilator lint_off UNUSEDSIGNAL */                                     // Disable Verilator warning `Bits of signal are not used`
wire [ARCHI          - 1 : 0]   axi_shared_ram_araddr  ;
/* verilator lint_on UNUSEDSIGNAL */                                      // Re-enable Verilator warning `Bits of signal are not used`
wire [                 7 : 0]   axi_shared_ram_arlen   ;
wire [                 2 : 0]   axi_shared_ram_arsize  ;
wire [                 1 : 0]   axi_shared_ram_arburst ;
wire [                 1 : 0]   axi_shared_ram_arlock  ;
wire [                 3 : 0]   axi_shared_ram_arcache ;
wire [                 2 : 0]   axi_shared_ram_arprot  ;
wire                            axi_shared_ram_arvalid ;
wire                            axi_shared_ram_arready ;
wire [ID_WIDTH       - 1 : 0]   axi_shared_ram_rid     ;
wire [ARCHI          - 1 : 0]   axi_shared_ram_rdata   ;
wire [                 1 : 0]   axi_shared_ram_rresp   ;
wire                            axi_shared_ram_rlast   ;
wire                            axi_shared_ram_rvalid  ;
wire                            axi_shared_ram_rready  ;
/********************       ********************/


/******************** REGISTERS ********************/

/********************           ********************/

/******************** MACHINE STATE ********************/

/********************               ********************/

scholar_riscv_core
#(
    .ARCHI          (ARCHI                          ),
    .START_ADDR     (START_ADDR                     )
) scholar_riscv_core
(
`ifdef DUT
    .GPR_EN         (GPR_EN                         ),
    .GPR_ADDR       (GPR_ADDR                       ),
    .GPR_DATA       (GPR_DATA                       ),
    .GPR_MEMORY     (GPR_MEMORY                     ),
    .GPR_PC_REG     (GPR_PC_REG                     ),
    .CSR_MCYCLE     (CSR_MCYCLE                     ),
`endif

    .CLK            (CORE_CLK                       ),
    .RSTN           (CORE_RSTN                      ),

    .I_M_DOUT       (core_i_m_dout                  ),
    .I_M_HIT        (core_i_m_hit                   ),
    .I_M_ADDR       (core_i_m_addr                  ),
    .I_M_RDEN       (core_i_m_rden                  ),


    .D_M_DOUT       (core_d_m_dout                  ),
    .D_M_HIT        (core_d_m_hit                   ),
    .D_M_ADDR       (core_d_m_addr                  ),
    .D_M_RDEN       (core_d_m_rden                  ),
    .D_M_WREN       (core_d_m_wren                  ),
    .D_M_WMASK      (core_d_m_wmask                 ),
    .D_M_DIN        (core_d_m_din                   )
);



instr_dpram
#(
    .DATA_WIDTH         (ARCHI                                              ),
    .SIZE               (INSTR_RAM_SIZE                                     )
)instr_ram
(
`ifdef DUT
    .INSTR_DPRAM_MEM    (INSTR_DPRAM_MEM                                    ),
`endif
    .CORE_CLK           (CORE_CLK                                           ),
    .AXI_CLK            (AXI_CLK                                            ),
    .RSTN               (AXI_RSTN                                           ),

    // Core
    .CORE_M_ADDR        (core_i_m_addr[INSTR_RAM_ADDR_WIDTH - 1 : 0]        ),
    .CORE_M_RDEN        (core_i_m_rden                                      ),
    .CORE_M_RDATA       (core_i_m_dout                                      ),
    .CORE_M_HIT         (core_i_m_hit                                       ),

    // AXI
    .S_AXI_AWID         (axi_instr_ram_awid                                 ),
    .S_AXI_AWADDR       (axi_instr_ram_awaddr[INSTR_RAM_ADDR_WIDTH - 1 : 0] ),
    .S_AXI_AWLEN        (axi_instr_ram_awlen                                ),
    .S_AXI_AWSIZE       (axi_instr_ram_awsize                               ),
    .S_AXI_AWBURST      (axi_instr_ram_awburst                              ),
    .S_AXI_AWLOCK       (axi_instr_ram_awlock                               ),
    .S_AXI_AWCACHE      (axi_instr_ram_awcache                              ),
    .S_AXI_AWPROT       (axi_instr_ram_awprot                               ),
    .S_AXI_AWVALID      (axi_instr_ram_awvalid                              ),
    .S_AXI_AWREADY      (axi_instr_ram_awready                              ),

    .S_AXI_WDATA        (axi_instr_ram_wdata                                ),
    .S_AXI_WSTRB        (axi_instr_ram_wstrb                                ),
    .S_AXI_WLAST        (axi_instr_ram_wlast                                ),
    .S_AXI_WVALID       (axi_instr_ram_wvalid                               ),
    .S_AXI_WREADY       (axi_instr_ram_wready                               ),

    .S_AXI_BID          (axi_instr_ram_bid                                  ),
    .S_AXI_BRESP        (axi_instr_ram_bresp                                ),
    .S_AXI_BVALID       (axi_instr_ram_bvalid                               ),
    .S_AXI_BREADY       (axi_instr_ram_bready                               )
);

data_dpram
#(
    .DATA_WIDTH     (ARCHI                                              ),
    .SIZE           (DATA_RAM_SIZE                                      )
)data_ram
(
`ifdef DUT
    .DATA_DPRAM_MEM (DATA_DPRAM_MEM                                     ),
`endif
    // .FLAG(DATA_RAM_FLAG),

    .CORE_CLK       (CORE_CLK                                           ),
    .AXI_CLK        (AXI_CLK                                            ),
    .RSTN           (AXI_RSTN                                           ),

    // Core
    .CORE_M_ADDR    (data_ram_addr[DATA_RAM_ADDR_WIDTH - 1 : 0]         ),
    .CORE_M_WREN    (data_ram_wren                                      ),
    .CORE_M_WDATA   (data_ram_wdata                                     ),
    .CORE_M_WMASK   (data_ram_wmask                                     ),
    .CORE_M_RDEN    (data_ram_rden                                      ),
    .CORE_M_RDATA   (data_ram_rdata                                     ),
    .CORE_M_HIT     (data_ram_hit                                       ),

    // AXI
    .S_AXI_AWID     (axi_data_ram_awid                                  ),
    .S_AXI_AWADDR   (axi_data_ram_awaddr[DATA_RAM_ADDR_WIDTH - 1 : 0]   ),
    .S_AXI_AWLEN    (axi_data_ram_awlen                                 ),
    .S_AXI_AWSIZE   (axi_data_ram_awsize                                ),
    .S_AXI_AWBURST  (axi_data_ram_awburst                               ),
    .S_AXI_AWLOCK   (axi_data_ram_awlock                                ),
    .S_AXI_AWCACHE  (axi_data_ram_awcache                               ),
    .S_AXI_AWPROT   (axi_data_ram_awprot                                ),
    .S_AXI_AWVALID  (axi_data_ram_awvalid                               ),
    .S_AXI_AWREADY  (axi_data_ram_awready                               ),

    .S_AXI_WDATA    (axi_data_ram_wdata                                 ),
    .S_AXI_WSTRB    (axi_data_ram_wstrb                                 ),
    .S_AXI_WLAST    (axi_data_ram_wlast                                 ),
    .S_AXI_WVALID   (axi_data_ram_wvalid                                ),
    .S_AXI_WREADY   (axi_data_ram_wready                                ),

    .S_AXI_BID      (axi_data_ram_bid                                   ),
    .S_AXI_BRESP    (axi_data_ram_bresp                                 ),
    .S_AXI_BVALID   (axi_data_ram_bvalid                                ),
    .S_AXI_BREADY   (axi_data_ram_bready                                )
);

ptc_dpram
#(
    .DATA_WIDTH     (ARCHI                                                      ),
    .SIZE           (PTC_SHARED_RAM_SIZE                                        )
)w_axi_shared_ram
(
`ifdef DUT
    .PTC_DPRAM_MEM  (PTC_SHARED_DPRAM_MEM                                       ),
`endif
    // .FLAG(PTC_RAM_FLAG),

    .CORE_CLK       (CORE_CLK                                                   ),
    .AXI_CLK        (AXI_CLK                                                    ),
    .RSTN           (AXI_RSTN                                                   ),

    // Core
    .CORE_M_ADDR    (ptc_shared_ram_addr[PTC_SHARED_RAM_ADDR_WIDTH - 1 : 0]     ),
    .CORE_M_WREN    (ptc_shared_ram_wren                                        ),
    .CORE_M_WDATA   (ptc_shared_ram_wdata                                       ),
    .CORE_M_WMASK   (ptc_shared_ram_wmask                                       ),
    .CORE_M_RDEN    (ptc_shared_ram_rden                                        ),
    .CORE_M_RDATA   (ptc_shared_ram_rdata                                       ),
    .CORE_M_HIT     (ptc_shared_ram_hit                                         ),

    // AXI
    .S_AXI_AWID     (axi_shared_ram_awid                                        ),
    .S_AXI_AWADDR   (axi_shared_ram_awaddr[PTC_SHARED_RAM_ADDR_WIDTH - 1 : 0]   ),
    .S_AXI_AWLEN    (axi_shared_ram_awlen                                       ),
    .S_AXI_AWSIZE   (axi_shared_ram_awsize                                      ),
    .S_AXI_AWBURST  (axi_shared_ram_awburst                                     ),
    .S_AXI_AWLOCK   (axi_shared_ram_awlock                                      ),
    .S_AXI_AWCACHE  (axi_shared_ram_awcache                                     ),
    .S_AXI_AWPROT   (axi_shared_ram_awprot                                      ),
    .S_AXI_AWVALID  (axi_shared_ram_awvalid                                     ),
    .S_AXI_AWREADY  (axi_shared_ram_awready                                     ),

    .S_AXI_WDATA    (axi_shared_ram_wdata                                       ),
    .S_AXI_WSTRB    (axi_shared_ram_wstrb                                       ),
    .S_AXI_WLAST    (axi_shared_ram_wlast                                       ),
    .S_AXI_WVALID   (axi_shared_ram_wvalid                                      ),
    .S_AXI_WREADY   (axi_shared_ram_wready                                      ),

    .S_AXI_BID      (axi_shared_ram_bid                                         ),
    .S_AXI_BRESP    (axi_shared_ram_bresp                                       ),
    .S_AXI_BVALID   (axi_shared_ram_bvalid                                      ),
    .S_AXI_BREADY   (axi_shared_ram_bready                                      )
);

ctp_dpram
#(
    .DATA_WIDTH     (ARCHI                                                      ),
    .SIZE           (CTP_SHARED_RAM_SIZE                                        )
)r_axi_shared_ram
(
`ifdef DUT
    .CTP_DPRAM_MEM  (CTP_SHARED_DPRAM_MEM                                       ),
`endif

    // .FLAG(CTP_RAM_FLAG),

    .CORE_CLK       (CORE_CLK                                                   ),
    .AXI_CLK        (AXI_CLK                                                    ),
    .RSTN           (AXI_RSTN                                                   ),

    // Core
    .CORE_M_ADDR    (ctp_shared_ram_addr[CTP_SHARED_RAM_ADDR_WIDTH - 1 : 0]     ),
    .CORE_M_WREN    (ctp_shared_ram_wren                                        ),
    .CORE_M_WDATA   (ctp_shared_ram_wdata                                       ),
    .CORE_M_WMASK   (ctp_shared_ram_wmask                                       ),
    .CORE_M_RDEN    (ctp_shared_ram_rden                                        ),
    .CORE_M_RDATA   (ctp_shared_ram_rdata                                       ),
    .CORE_M_HIT     (ctp_shared_ram_hit                                         ),

    // AXI
    .S_AXI_ARID     (axi_shared_ram_arid                                        ),
    .S_AXI_ARADDR   (axi_shared_ram_araddr[CTP_SHARED_RAM_ADDR_WIDTH - 1 : 0]   ),
    .S_AXI_ARLEN    (axi_shared_ram_arlen                                       ),
    .S_AXI_ARSIZE   (axi_shared_ram_arsize                                      ),
    .S_AXI_ARBURST  (axi_shared_ram_arburst                                     ),
    .S_AXI_ARLOCK   (axi_shared_ram_arlock                                      ),
    .S_AXI_ARCACHE  (axi_shared_ram_arcache                                     ),
    .S_AXI_ARPROT   (axi_shared_ram_arprot                                      ),
    .S_AXI_ARVALID  (axi_shared_ram_arvalid                                     ),
    .S_AXI_ARREADY  (axi_shared_ram_arready                                     ),

    .S_AXI_RID      (axi_shared_ram_rid                                         ),
    .S_AXI_RDATA    (axi_shared_ram_rdata                                       ),
    .S_AXI_RRESP    (axi_shared_ram_rresp                                       ),
    .S_AXI_RLAST    (axi_shared_ram_rlast                                       ),
    .S_AXI_RVALID   (axi_shared_ram_rvalid                                      ),
    .S_AXI_RREADY   (axi_shared_ram_rready                                      )
);

bus_fabric
#(
    .ADDR_WIDTH                 (ARCHI                      ),
    .DATA_WIDTH                 (ARCHI                      ),

    .TAG_MSB                    (TAG_MSB                    ),
    .TAG_LSB                    (TAG_LSB                    ),
    .INSTR_RAM_ADDR_TAG         (INSTR_RAM_ADDR_TAG         ),
    .DATA_RAM_ADDR_TAG          (DATA_RAM_ADDR_TAG          ),
    .PTC_SHARED_RAM_ADDR_TAG    (PTC_SHARED_RAM_ADDR_TAG    ),
    .CTP_SHARED_RAM_ADDR_TAG    (CTP_SHARED_RAM_ADDR_TAG    ),

    .ID_WIDTH                   (ID_WIDTH                   )
)bus_fabric
(
    .CLK                        (AXI_CLK                    ),
    .RSTN                       (AXI_RSTN                   ),

    // Core
    .CORE_D_M_ADDR              (core_d_m_addr              ),
    .CORE_D_M_RDEN              (core_d_m_rden              ),
    .CORE_D_M_WREN              (core_d_m_wren              ),
    .CORE_D_M_WMASK             (core_d_m_wmask             ),
    .CORE_D_M_DIN               (core_d_m_din               ),
    .CORE_D_M_DOUT              (core_d_m_dout              ),
    .CORE_D_M_HIT               (core_d_m_hit               ),


    .DATA_RAM_ADDR              (data_ram_addr              ),
    .DATA_RAM_WREN              (data_ram_wren              ),
    .DATA_RAM_WDATA             (data_ram_wdata             ),
    .DATA_RAM_WMASK             (data_ram_wmask             ),
    .DATA_RAM_RDEN              (data_ram_rden              ),
    .DATA_RAM_RDATA             (data_ram_rdata             ),
    .DATA_RAM_HIT               (data_ram_hit               ),

    .PTC_SHARED_RAM_ADDR        (ptc_shared_ram_addr        ),
    .PTC_SHARED_RAM_WREN        (ptc_shared_ram_wren        ),
    .PTC_SHARED_RAM_WDATA       (ptc_shared_ram_wdata       ),
    .PTC_SHARED_RAM_WMASK       (ptc_shared_ram_wmask       ),
    .PTC_SHARED_RAM_RDEN        (ptc_shared_ram_rden        ),
    .PTC_SHARED_RAM_RDATA       (ptc_shared_ram_rdata       ),
    .PTC_SHARED_RAM_HIT         (ptc_shared_ram_hit         ),


    .CTP_SHARED_RAM_ADDR        (ctp_shared_ram_addr        ),
    .CTP_SHARED_RAM_WREN        (ctp_shared_ram_wren        ),
    .CTP_SHARED_RAM_WDATA       (ctp_shared_ram_wdata       ),
    .CTP_SHARED_RAM_WMASK       (ctp_shared_ram_wmask       ),
    .CTP_SHARED_RAM_RDEN        (ctp_shared_ram_rden        ),
    .CTP_SHARED_RAM_RDATA       (ctp_shared_ram_rdata       ),
    .CTP_SHARED_RAM_HIT         (ctp_shared_ram_hit         ),

    // AXI
    .S_AXI_AWID                 (S_AXI_AWID                 ),
    .S_AXI_AWADDR               (S_AXI_AWADDR               ),
    .S_AXI_AWLEN                (S_AXI_AWLEN                ),
    .S_AXI_AWSIZE               (S_AXI_AWSIZE               ),
    .S_AXI_AWBURST              (S_AXI_AWBURST              ),
    .S_AXI_AWLOCK               (S_AXI_AWLOCK               ),
    .S_AXI_AWCACHE              (S_AXI_AWCACHE              ),
    .S_AXI_AWPROT               (S_AXI_AWPROT               ),
    .S_AXI_AWVALID              (S_AXI_AWVALID              ),
    .S_AXI_AWREADY              (S_AXI_AWREADY              ),

    .S_AXI_WDATA                (S_AXI_WDATA                ),
    .S_AXI_WSTRB                (S_AXI_WSTRB                ),
    .S_AXI_WLAST                (S_AXI_WLAST                ),
    .S_AXI_WVALID               (S_AXI_WVALID               ),
    .S_AXI_WREADY               (S_AXI_WREADY               ),

    .S_AXI_BID                  (S_AXI_BID                  ),
    .S_AXI_BRESP                (S_AXI_BRESP                ),
    .S_AXI_BVALID               (S_AXI_BVALID               ),
    .S_AXI_BREADY               (S_AXI_BREADY               ),

    .S_AXI_ARID                 (S_AXI_ARID                 ),
    .S_AXI_ARADDR               (S_AXI_ARADDR               ),
    .S_AXI_ARLEN                (S_AXI_ARLEN                ),
    .S_AXI_ARSIZE               (S_AXI_ARSIZE               ),
    .S_AXI_ARBURST              (S_AXI_ARBURST              ),
    .S_AXI_ARLOCK               (S_AXI_ARLOCK               ),
    .S_AXI_ARCACHE              (S_AXI_ARCACHE              ),
    .S_AXI_ARPROT               (S_AXI_ARPROT               ),
    .S_AXI_ARVALID              (S_AXI_ARVALID              ),
    .S_AXI_ARREADY              (S_AXI_ARREADY              ),

    .S_AXI_RID                  (S_AXI_RID                  ),
    .S_AXI_RDATA                (S_AXI_RDATA                ),
    .S_AXI_RRESP                (S_AXI_RRESP                ),
    .S_AXI_RLAST                (S_AXI_RLAST                ),
    .S_AXI_RVALID               (S_AXI_RVALID               ),
    .S_AXI_RREADY               (S_AXI_RREADY               ),


    .AXI_INSTR_RAM_AWID         (axi_instr_ram_awid         ),
    .AXI_INSTR_RAM_AWADDR       (axi_instr_ram_awaddr       ),
    .AXI_INSTR_RAM_AWLEN        (axi_instr_ram_awlen        ),
    .AXI_INSTR_RAM_AWSIZE       (axi_instr_ram_awsize       ),
    .AXI_INSTR_RAM_AWBURST      (axi_instr_ram_awburst      ),
    .AXI_INSTR_RAM_AWLOCK       (axi_instr_ram_awlock       ),
    .AXI_INSTR_RAM_AWCACHE      (axi_instr_ram_awcache      ),
    .AXI_INSTR_RAM_AWPROT       (axi_instr_ram_awprot       ),
    .AXI_INSTR_RAM_AWVALID      (axi_instr_ram_awvalid      ),
    .AXI_INSTR_RAM_AWREADY      (axi_instr_ram_awready      ),
    .AXI_INSTR_RAM_WDATA        (axi_instr_ram_wdata        ),
    .AXI_INSTR_RAM_WSTRB        (axi_instr_ram_wstrb        ),
    .AXI_INSTR_RAM_WLAST        (axi_instr_ram_wlast        ),
    .AXI_INSTR_RAM_WVALID       (axi_instr_ram_wvalid       ),
    .AXI_INSTR_RAM_WREADY       (axi_instr_ram_wready       ),
    .AXI_INSTR_RAM_BID          (axi_instr_ram_bid          ),
    .AXI_INSTR_RAM_BRESP        (axi_instr_ram_bresp        ),
    .AXI_INSTR_RAM_BVALID       (axi_instr_ram_bvalid       ),
    .AXI_INSTR_RAM_BREADY       (axi_instr_ram_bready       ),

    .AXI_DATA_RAM_AWID          (axi_data_ram_awid          ),
    .AXI_DATA_RAM_AWADDR        (axi_data_ram_awaddr        ),
    .AXI_DATA_RAM_AWLEN         (axi_data_ram_awlen         ),
    .AXI_DATA_RAM_AWSIZE        (axi_data_ram_awsize        ),
    .AXI_DATA_RAM_AWBURST       (axi_data_ram_awburst       ),
    .AXI_DATA_RAM_AWLOCK        (axi_data_ram_awlock        ),
    .AXI_DATA_RAM_AWCACHE       (axi_data_ram_awcache       ),
    .AXI_DATA_RAM_AWPROT        (axi_data_ram_awprot        ),
    .AXI_DATA_RAM_AWVALID       (axi_data_ram_awvalid       ),
    .AXI_DATA_RAM_AWREADY       (axi_data_ram_awready       ),
    .AXI_DATA_RAM_WDATA         (axi_data_ram_wdata         ),
    .AXI_DATA_RAM_WSTRB         (axi_data_ram_wstrb         ),
    .AXI_DATA_RAM_WLAST         (axi_data_ram_wlast         ),
    .AXI_DATA_RAM_WVALID        (axi_data_ram_wvalid        ),
    .AXI_DATA_RAM_WREADY        (axi_data_ram_wready        ),
    .AXI_DATA_RAM_BID           (axi_data_ram_bid           ),
    .AXI_DATA_RAM_BRESP         (axi_data_ram_bresp         ),
    .AXI_DATA_RAM_BVALID        (axi_data_ram_bvalid        ),
    .AXI_DATA_RAM_BREADY        (axi_data_ram_bready        ),

    .AXI_SHARED_RAM_AWID        (axi_shared_ram_awid        ),
    .AXI_SHARED_RAM_AWADDR      (axi_shared_ram_awaddr      ),
    .AXI_SHARED_RAM_AWLEN       (axi_shared_ram_awlen       ),
    .AXI_SHARED_RAM_AWSIZE      (axi_shared_ram_awsize      ),
    .AXI_SHARED_RAM_AWBURST     (axi_shared_ram_awburst     ),
    .AXI_SHARED_RAM_AWLOCK      (axi_shared_ram_awlock      ),
    .AXI_SHARED_RAM_AWCACHE     (axi_shared_ram_awcache     ),
    .AXI_SHARED_RAM_AWPROT      (axi_shared_ram_awprot      ),
    .AXI_SHARED_RAM_AWVALID     (axi_shared_ram_awvalid     ),
    .AXI_SHARED_RAM_AWREADY     (axi_shared_ram_awready     ),
    .AXI_SHARED_RAM_WDATA       (axi_shared_ram_wdata       ),
    .AXI_SHARED_RAM_WSTRB       (axi_shared_ram_wstrb       ),
    .AXI_SHARED_RAM_WLAST       (axi_shared_ram_wlast       ),
    .AXI_SHARED_RAM_WVALID      (axi_shared_ram_wvalid      ),
    .AXI_SHARED_RAM_WREADY      (axi_shared_ram_wready      ),
    .AXI_SHARED_RAM_BID         (axi_shared_ram_bid         ),
    .AXI_SHARED_RAM_BRESP       (axi_shared_ram_bresp       ),
    .AXI_SHARED_RAM_BVALID      (axi_shared_ram_bvalid      ),
    .AXI_SHARED_RAM_BREADY      (axi_shared_ram_bready      ),

    .AXI_SHARED_RAM_ARID        (axi_shared_ram_arid        ),
    .AXI_SHARED_RAM_ARADDR      (axi_shared_ram_araddr      ),
    .AXI_SHARED_RAM_ARLEN       (axi_shared_ram_arlen       ),
    .AXI_SHARED_RAM_ARSIZE      (axi_shared_ram_arsize      ),
    .AXI_SHARED_RAM_ARBURST     (axi_shared_ram_arburst     ),
    .AXI_SHARED_RAM_ARLOCK      (axi_shared_ram_arlock      ),
    .AXI_SHARED_RAM_ARCACHE     (axi_shared_ram_arcache     ),
    .AXI_SHARED_RAM_ARPROT      (axi_shared_ram_arprot      ),
    .AXI_SHARED_RAM_ARVALID     (axi_shared_ram_arvalid     ),
    .AXI_SHARED_RAM_ARREADY     (axi_shared_ram_arready     ),
    .AXI_SHARED_RAM_RID         (axi_shared_ram_rid         ),
    .AXI_SHARED_RAM_RDATA       (axi_shared_ram_rdata       ),
    .AXI_SHARED_RAM_RRESP       (axi_shared_ram_rresp       ),
    .AXI_SHARED_RAM_RLAST       (axi_shared_ram_rlast       ),
    .AXI_SHARED_RAM_RVALID      (axi_shared_ram_rvalid      ),
    .AXI_SHARED_RAM_RREADY      (axi_shared_ram_rready      )
 );

endmodule

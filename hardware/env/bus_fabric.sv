/*!
********************************************************************************
*  \file      bus_fabric.sv
*  \module    bus_fabric
*  \brief     Bus interconnect module between CPU/AXI and memory blocks
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/06/2025
*
********************************************************************************
*  \details
*  This module implements the interconnect fabric for routing memory transactions
*  between the SCHOLAR RISC-V core, an AXI master (e.g., CPU/DMA), and several
*  target memory blocks.
*
*  It decodes the memory-mapped address space using configurable "address tags"
*  and redirects transactions (read or write) to the appropriate memory target:
*     - Instruction RAM
*     - Data RAM
*     - Shared RAM (write path)
*     - Shared RAM (read path)
*
*  This module ensures proper decoding and support for
*  AXI burst behavior (including read/write transactions).
*
*  The design assumes a simple one-master model (no contention) for both the core
*  and AXI master on their respective paths.
********************************************************************************
*  \parameters
*    - ADDR_WIDTH                               : Address bus width in bits
*    - DATA_WIDTH                               : Data bus width in bits
*    - TAG_MSB / TAG_LSB                        : Bit positions used to extract the memory address tag
*    - INSTR_RAM_ADDR_TAG                       : Tag identifying instruction memory region
*    - DATA_RAM_ADDR_TAG                        : Tag identifying data memory region
*    - PTC_SHARED_RAM_ADDR_TAG                  : Tag for AXI write-side shared RAM access
*    - CTP_SHARED_RAM_ADDR_TAG                  : Tag for AXI read-side shared RAM access
*    - ID_WIDTH                                 : AXI transaction ID width
*
*  \inputs
*    - CLK                                      : Clock signal
*    - RSTN                                     : Active-low reset
*    - CORE_D_M_ADDR                            : Address issued by the SCHOLAR RISC-V core
*    - CORE_D_M_RDEN                            : SCHOLAR RISC-V core read enable
*    - CORE_D_M_WREN                            : SCHOLAR RISC-V core write enable
*    - CORE_D_M_WMASK                           : SCHOLAR RISC-V core Byte-enable mask
*    - CORE_D_M_DIN                             : SCHOLAR RISC-V core output data   (memory input data)
*    - DATA_RAM_RDATA                           : Data memory output data
*    - DATA_RAM_HIT                             : Data memory HIT flag
*    - PTC_SHARED_RAM_RDATA                     : Output data of platform-to-core shared RAM
*    - PTC_SHARED_RAM_HIT                       : Hit flag of platform-to-core shared RAM access
*    - CTP_SHARED_RAM_RDATA                     : Output data of core-to-platform shared RAM
*    - CTP_SHARED_RAM_HIT                       : Hit flag of core-to-platform shared RAM access
*    - S_AXI_*                                  : AXI master interface (write/read address, data, handshake)
*    - AXI_INSTR_RAM_*                          : Instruction RAM AXI signals
*    - AXI_DATA_RAM_*                           : Data RAM AXI signals
*    - AXI_SHARED_RAM_*                         : Platform-to-core & core-to-platform shared RAM AXI signals
*
*  \outputs
*    - CORE_D_M_HIT                             : SCHOLAR RISC-V core hit flag      (from memory)
*    - CORE_D_M_DOUT                            : SCHOLAR RISC-V core input data    (memory output data)
*    - DATA_RAM_ADDR                            : Data memory address
*    - DATA_RAM_WREN                            : Data memory write enable
*    - DATA_RAM_WDATA                           : Data memory input data
*    - DATA_RAM_WMASK                           : Data memory byte-enable mask
*    - DATA_RAM_RDEN                            : Data memory read enable
*    - PTC_SHARED_RAM_ADDR                      : Platform-to-core shared memory address
*    - PTC_SHARED_RAM_WREN                      : Platform-to-core shared memory write enable
*    - PTC_SHARED_RAM_WDATA                     : Platform-to-core shared memory input data
*    - PTC_SHARED_RAM_WMASK                     : Platform-to-core shared memory byte-enable mask
*    - PTC_SHARED_RAM_RDEN                      : Platform-to-core shared memory read enable
*    - CTP_SHARED_RAM_ADDR                      : Core-to-platform memory address
*    - CTP_SHARED_RAM_WREN                      : Core-to-platform memory write enable
*    - CTP_SHARED_RAM_WDATA                     : Core-to-platform memory write data
*    - CTP_SHARED_RAM_WMASK                     : Core-to-platform memory byte-enable
*    - CTP_SHARED_RAM_RDEN                      : Core-to-platform memory read enable
*    - S_AXI_*                                  : AXI master interface (write/read address, data, handshake)
*    - AXI_INSTR_RAM_*                          : Instruction RAM AXI signals
*    - AXI_DATA_RAM_*                           : Data RAM AXI signals
*    - AXI_SHARED_RAM_*                         : Platform-to-core & core-to-platform shared RAM AXI signals
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
*  - TODO: Improve comments.
*  - TODO: Handle AXI write transactions and AXI read transactions in parrallel.
********************************************************************************
*/
module bus_fabric
#(
    parameter                                       ADDR_WIDTH  = 32            ,
    parameter                                       DATA_WIDTH  = 32            ,

    parameter                                       TAG_MSB     = 19            ,
    parameter                                       TAG_LSB     = 16            ,

    parameter   logic [TAG_MSB - TAG_LSB  : 0]      INSTR_RAM_ADDR_TAG          ,
    parameter   logic [TAG_MSB - TAG_LSB  : 0]      DATA_RAM_ADDR_TAG           ,
    parameter   logic [TAG_MSB - TAG_LSB  : 0]      PTC_SHARED_RAM_ADDR_TAG     ,
    parameter   logic [TAG_MSB - TAG_LSB  : 0]      CTP_SHARED_RAM_ADDR_TAG     ,

    parameter                                       ID_WIDTH    = 8
)
(
    input  wire                                     CLK                         ,
    input  wire                                     RSTN                        ,

    input  wire [ADDR_WIDTH     - 1 : 0]            CORE_D_M_ADDR 	            ,
    input  wire                                     CORE_D_M_RDEN               ,
    input  wire                                     CORE_D_M_WREN               ,
    input  wire [(DATA_WIDTH/8) - 1 : 0]            CORE_D_M_WMASK              ,
    input  wire [DATA_WIDTH     - 1 : 0]            CORE_D_M_DIN                ,
    output wire [DATA_WIDTH     - 1 : 0]            CORE_D_M_DOUT               ,
    output wire                                     CORE_D_M_HIT                ,

    output wire [ADDR_WIDTH     - 1 : 0]            DATA_RAM_ADDR               ,
    output wire                                     DATA_RAM_WREN               ,
    output wire [DATA_WIDTH     - 1 : 0]            DATA_RAM_WDATA              ,
    output wire [(DATA_WIDTH/8) - 1 : 0]            DATA_RAM_WMASK              ,
    output wire                                     DATA_RAM_RDEN               ,
    input  wire [DATA_WIDTH     - 1 : 0]            DATA_RAM_RDATA              ,
    input  wire                                     DATA_RAM_HIT                ,

    output wire [ADDR_WIDTH     - 1 : 0]            PTC_SHARED_RAM_ADDR         ,
    output wire                                     PTC_SHARED_RAM_WREN         ,
    output wire [DATA_WIDTH     - 1 : 0]            PTC_SHARED_RAM_WDATA        ,
    output wire [(DATA_WIDTH/8) - 1 : 0]            PTC_SHARED_RAM_WMASK        ,
    output wire                                     PTC_SHARED_RAM_RDEN         ,
    input  wire [DATA_WIDTH     - 1 : 0]            PTC_SHARED_RAM_RDATA        ,
    input  wire                                     PTC_SHARED_RAM_HIT          ,

    output wire [ADDR_WIDTH     - 1 : 0]            CTP_SHARED_RAM_ADDR         ,
    output wire                                     CTP_SHARED_RAM_WREN         ,
    output wire [DATA_WIDTH     - 1 : 0]            CTP_SHARED_RAM_WDATA        ,
    output wire [(DATA_WIDTH/8) - 1 : 0]            CTP_SHARED_RAM_WMASK        ,
    output wire                                     CTP_SHARED_RAM_RDEN         ,
    input  wire [DATA_WIDTH     - 1 : 0]            CTP_SHARED_RAM_RDATA        ,
    input  wire                                     CTP_SHARED_RAM_HIT          ,


    // AXI
    input  wire [ID_WIDTH       - 1 : 0]            S_AXI_AWID                  ,
    input  wire [ADDR_WIDTH     - 1 : 0]            S_AXI_AWADDR                ,
    input  wire [                 7 : 0]            S_AXI_AWLEN                 ,
    input  wire [                 2 : 0]            S_AXI_AWSIZE                ,
    input  wire [                 1 : 0]            S_AXI_AWBURST               ,
    input  wire [                 1 : 0]            S_AXI_AWLOCK                ,
    input  wire [                 3 : 0]            S_AXI_AWCACHE               ,
    input  wire [                 2 : 0]            S_AXI_AWPROT                ,
    input  wire                                     S_AXI_AWVALID               ,
    output wire                                     S_AXI_AWREADY               ,
    input  wire [DATA_WIDTH     - 1 : 0]            S_AXI_WDATA                 ,
    input  wire [(DATA_WIDTH/8) - 1 : 0]            S_AXI_WSTRB                 ,
    input  wire                                     S_AXI_WLAST                 ,
    input  wire                                     S_AXI_WVALID                ,
    output wire                                     S_AXI_WREADY                ,
    output wire [ID_WIDTH       - 1 : 0]            S_AXI_BID                   ,
    output wire [                 1 : 0]            S_AXI_BRESP                 ,
    output wire                                     S_AXI_BVALID                ,
    input  wire                                     S_AXI_BREADY                ,
    input  wire [ID_WIDTH       - 1 : 0]            S_AXI_ARID                  ,
    input  wire [ADDR_WIDTH     - 1 : 0]            S_AXI_ARADDR                ,
    input  wire [                 7 : 0]            S_AXI_ARLEN                 ,
    input  wire [                 2 : 0]            S_AXI_ARSIZE                ,
    input  wire [                 1 : 0]            S_AXI_ARBURST               ,
    input  wire [                 1 : 0]            S_AXI_ARLOCK                ,
    input  wire [                 3 : 0]            S_AXI_ARCACHE               ,
    input  wire [                 2 : 0]            S_AXI_ARPROT                ,
    input  wire                                     S_AXI_ARVALID               ,
    output wire                                     S_AXI_ARREADY               ,
    output wire [ID_WIDTH       - 1 : 0]            S_AXI_RID                   ,
    output wire [DATA_WIDTH     - 1 : 0]            S_AXI_RDATA                 ,
    output wire [                 1 : 0]            S_AXI_RRESP                 ,
    output wire                                     S_AXI_RLAST                 ,
    output wire                                     S_AXI_RVALID                ,
    input  wire                                     S_AXI_RREADY                ,

    output wire [ID_WIDTH       - 1 : 0]            AXI_INSTR_RAM_AWID          ,
    output wire [ADDR_WIDTH     - 1 : 0]            AXI_INSTR_RAM_AWADDR        ,
    output wire [                 7 : 0]            AXI_INSTR_RAM_AWLEN         ,
    output wire [                 2 : 0]            AXI_INSTR_RAM_AWSIZE        ,
    output wire [                 1 : 0]            AXI_INSTR_RAM_AWBURST       ,
    output wire [                 1 : 0]            AXI_INSTR_RAM_AWLOCK        ,
    output wire [                 3 : 0]            AXI_INSTR_RAM_AWCACHE       ,
    output wire [                 2 : 0]            AXI_INSTR_RAM_AWPROT        ,
    output wire                                     AXI_INSTR_RAM_AWVALID       ,
    input  wire                                     AXI_INSTR_RAM_AWREADY       ,
    output wire [DATA_WIDTH     - 1 : 0]            AXI_INSTR_RAM_WDATA         ,
    output wire [(DATA_WIDTH/8) - 1 : 0]            AXI_INSTR_RAM_WSTRB         ,
    output wire                                     AXI_INSTR_RAM_WLAST         ,
    output wire                                     AXI_INSTR_RAM_WVALID        ,
    input  wire                                     AXI_INSTR_RAM_WREADY        ,
    input  wire [ID_WIDTH       - 1 : 0]            AXI_INSTR_RAM_BID           ,
    input  wire [                 1 : 0]            AXI_INSTR_RAM_BRESP         ,
    input  wire                                     AXI_INSTR_RAM_BVALID        ,
    output wire                                     AXI_INSTR_RAM_BREADY        ,

    output wire [ID_WIDTH       - 1 : 0]            AXI_DATA_RAM_AWID           ,
    output wire [ADDR_WIDTH     - 1 : 0]            AXI_DATA_RAM_AWADDR         ,
    output wire [                 7 : 0]            AXI_DATA_RAM_AWLEN          ,
    output wire [                 2 : 0]            AXI_DATA_RAM_AWSIZE         ,
    output wire [                 1 : 0]            AXI_DATA_RAM_AWBURST        ,
    output wire [                 1 : 0]            AXI_DATA_RAM_AWLOCK         ,
    output wire [                 3 : 0]            AXI_DATA_RAM_AWCACHE        ,
    output wire [                 2 : 0]            AXI_DATA_RAM_AWPROT         ,
    output wire                                     AXI_DATA_RAM_AWVALID        ,
    input  wire                                     AXI_DATA_RAM_AWREADY        ,
    output wire [DATA_WIDTH     - 1 : 0]            AXI_DATA_RAM_WDATA          ,
    output wire [(DATA_WIDTH/8) - 1 : 0]            AXI_DATA_RAM_WSTRB          ,
    output wire                                     AXI_DATA_RAM_WLAST          ,
    output wire                                     AXI_DATA_RAM_WVALID         ,
    input  wire                                     AXI_DATA_RAM_WREADY         ,
    input  wire [ID_WIDTH       - 1 : 0]            AXI_DATA_RAM_BID            ,
    input  wire [                 1 : 0]            AXI_DATA_RAM_BRESP          ,
    input  wire                                     AXI_DATA_RAM_BVALID         ,
    output wire                                     AXI_DATA_RAM_BREADY         ,

    output wire [ID_WIDTH       - 1 : 0]            AXI_SHARED_RAM_AWID         ,
    output wire [ADDR_WIDTH     - 1 : 0]            AXI_SHARED_RAM_AWADDR       ,
    output wire [                 7 : 0]            AXI_SHARED_RAM_AWLEN        ,
    output wire [                 2 : 0]            AXI_SHARED_RAM_AWSIZE       ,
    output wire [                 1 : 0]            AXI_SHARED_RAM_AWBURST      ,
    output wire [                 1 : 0]            AXI_SHARED_RAM_AWLOCK       ,
    output wire [                 3 : 0]            AXI_SHARED_RAM_AWCACHE      ,
    output wire [                 2 : 0]            AXI_SHARED_RAM_AWPROT       ,
    output wire                                     AXI_SHARED_RAM_AWVALID      ,
    input  wire                                     AXI_SHARED_RAM_AWREADY      ,
    output wire [DATA_WIDTH     - 1 : 0]            AXI_SHARED_RAM_WDATA        ,
    output wire [(DATA_WIDTH/8) - 1 : 0]            AXI_SHARED_RAM_WSTRB        ,
    output wire                                     AXI_SHARED_RAM_WLAST        ,
    output wire                                     AXI_SHARED_RAM_WVALID       ,
    input  wire                                     AXI_SHARED_RAM_WREADY       ,
    input  wire [ID_WIDTH       - 1 : 0]            AXI_SHARED_RAM_BID          ,
    input  wire [                 1 : 0]            AXI_SHARED_RAM_BRESP        ,
    input  wire                                     AXI_SHARED_RAM_BVALID       ,
    output wire                                     AXI_SHARED_RAM_BREADY       ,

    output wire [ID_WIDTH       - 1 : 0]            AXI_SHARED_RAM_ARID         ,
    output wire [ADDR_WIDTH     - 1 : 0]            AXI_SHARED_RAM_ARADDR       ,
    output wire [                 7 : 0]            AXI_SHARED_RAM_ARLEN        ,
    output wire [                 2 : 0]            AXI_SHARED_RAM_ARSIZE       ,
    output wire [                 1 : 0]            AXI_SHARED_RAM_ARBURST      ,
    output wire [                 1 : 0]            AXI_SHARED_RAM_ARLOCK       ,
    output wire [                 3 : 0]            AXI_SHARED_RAM_ARCACHE      ,
    output wire [                 2 : 0]            AXI_SHARED_RAM_ARPROT       ,
    output wire                                     AXI_SHARED_RAM_ARVALID      ,
    input  wire                                     AXI_SHARED_RAM_ARREADY      ,
    input  wire [ID_WIDTH       - 1 : 0]            AXI_SHARED_RAM_RID          ,
    input  wire [DATA_WIDTH     - 1 : 0]            AXI_SHARED_RAM_RDATA        ,
    input  wire [                 1 : 0]            AXI_SHARED_RAM_RRESP        ,
    input  wire                                     AXI_SHARED_RAM_RLAST        ,
    input  wire                                     AXI_SHARED_RAM_RVALID       ,
    output wire                                     AXI_SHARED_RAM_RREADY
);


/******************** MACHINE STATE ********************/
typedef enum reg [2:0]
{
    IDLE,
    AXI_INSTR_RAM_BURST,
    AXI_DATA_RAM_BURST,
    WAXI_SHARED_RAM_BURST,
    RAXI_SHARED_RAM_BURST
}readStates;
readStates state_reg;
/********************               ********************/

/******************** FUNCTIONS ********************/
    /* verilator lint_off UNUSEDSIGNAL */                               // Disable Verilator warning `Bits of signal are not used`
function logic is_matching_tag (input logic [ADDR_WIDTH-1:0] addr, input logic [TAG_MSB:TAG_LSB] tag);
    return addr[TAG_MSB:TAG_LSB] == tag;
endfunction
    /* verilator lint_on UNUSEDSIGNAL */                                // Re-enable Verilator warning `Bits of signal are not used`
/********************           ********************/


/******************** CONTROL ********************/

/*
* Finite State Machine (FSM) controlling the AXI access routing.
*
* This FSM tracks the active AXI transaction and determines which target memory
* (instruction RAM, data RAM, or shared RAM) should receive the AXI request.
* It transitions through predefined burst handling states and returns to IDLE
* once the transaction completes.
*
* - In the `IDLE` state:
*     • If a write address (`AWADDR`) matches a specific memory region and is valid,
*       the FSM transitions to the corresponding write burst state.
*     • If a read address (`ARADDR`) matches the shared memory region and is valid,
*       it transitions to the read burst state for shared memory.
*
* - Each *_BURST state remains active until the AXI transaction completes:
*     • For write transactions, completion is detected via `S_AXI_BVALID && S_AXI_BREADY`.
*     • For read transactions, completion is detected via `AXI_SHARED_RAM_RLAST`.
*
* This design ensures that only one AXI transaction is processed at a time,
* avoiding collisions and guaranteeing proper memory access routing.
*/
always_ff @(posedge CLK)
begin
    if(!RSTN) state_reg <= IDLE;
    else begin
        case(state_reg)

            IDLE                    : begin
                     if(is_matching_tag(S_AXI_AWADDR, INSTR_RAM_ADDR_TAG)       && S_AXI_AWVALID) state_reg <= AXI_INSTR_RAM_BURST;
                else if(is_matching_tag(S_AXI_AWADDR, DATA_RAM_ADDR_TAG)        && S_AXI_AWVALID) state_reg <= AXI_DATA_RAM_BURST;
                else if(is_matching_tag(S_AXI_AWADDR, PTC_SHARED_RAM_ADDR_TAG)  && S_AXI_AWVALID) state_reg <= WAXI_SHARED_RAM_BURST;
                else if(is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  && S_AXI_ARVALID) state_reg <= RAXI_SHARED_RAM_BURST;
            end

            AXI_INSTR_RAM_BURST     : if(S_AXI_BREADY && S_AXI_BVALID)                            state_reg <= IDLE;

            AXI_DATA_RAM_BURST      : if(S_AXI_BREADY && S_AXI_BVALID)                            state_reg <= IDLE;

            WAXI_SHARED_RAM_BURST   : if(S_AXI_BREADY && S_AXI_BVALID)                            state_reg <= IDLE;

            RAXI_SHARED_RAM_BURST   : if(AXI_SHARED_RAM_RLAST)                                    state_reg <= IDLE;

            default                 :                                                             state_reg <= IDLE;

        endcase
    end

end
/********************         ********************/


/******************** DATA PATH ********************/
assign DATA_RAM_ADDR            = is_matching_tag(CORE_D_M_ADDR, DATA_RAM_ADDR_TAG)       ? CORE_D_M_ADDR           : {ADDR_WIDTH  {1'b0}};
assign DATA_RAM_WREN            = is_matching_tag(CORE_D_M_ADDR, DATA_RAM_ADDR_TAG)       ? CORE_D_M_WREN           : {1           {1'b0}};
assign DATA_RAM_WDATA           = is_matching_tag(CORE_D_M_ADDR, DATA_RAM_ADDR_TAG)       ? CORE_D_M_DIN            : {DATA_WIDTH  {1'b0}};
assign DATA_RAM_WMASK           = is_matching_tag(CORE_D_M_ADDR, DATA_RAM_ADDR_TAG)       ? CORE_D_M_WMASK          : {DATA_WIDTH/8{1'b0}};
assign DATA_RAM_RDEN            = is_matching_tag(CORE_D_M_ADDR, DATA_RAM_ADDR_TAG)       ? CORE_D_M_RDEN           : {1           {1'b0}};

assign PTC_SHARED_RAM_ADDR      = is_matching_tag(CORE_D_M_ADDR, PTC_SHARED_RAM_ADDR_TAG) ? CORE_D_M_ADDR           : {ADDR_WIDTH  {1'b0}};
assign PTC_SHARED_RAM_WREN      = is_matching_tag(CORE_D_M_ADDR, PTC_SHARED_RAM_ADDR_TAG) ? CORE_D_M_WREN           : {1           {1'b0}};
assign PTC_SHARED_RAM_WDATA     = is_matching_tag(CORE_D_M_ADDR, PTC_SHARED_RAM_ADDR_TAG) ? CORE_D_M_DIN            : {DATA_WIDTH  {1'b0}};
assign PTC_SHARED_RAM_WMASK     = is_matching_tag(CORE_D_M_ADDR, PTC_SHARED_RAM_ADDR_TAG) ? CORE_D_M_WMASK          : {DATA_WIDTH/8{1'b0}};
assign PTC_SHARED_RAM_RDEN      = is_matching_tag(CORE_D_M_ADDR, PTC_SHARED_RAM_ADDR_TAG) ? CORE_D_M_RDEN           : {1           {1'b0}};

assign CTP_SHARED_RAM_ADDR      = is_matching_tag(CORE_D_M_ADDR, CTP_SHARED_RAM_ADDR_TAG) ? CORE_D_M_ADDR           : {ADDR_WIDTH  {1'b0}};
assign CTP_SHARED_RAM_WREN      = is_matching_tag(CORE_D_M_ADDR, CTP_SHARED_RAM_ADDR_TAG) ? CORE_D_M_WREN           : {1           {1'b0}};
assign CTP_SHARED_RAM_WDATA     = is_matching_tag(CORE_D_M_ADDR, CTP_SHARED_RAM_ADDR_TAG) ? CORE_D_M_DIN            : {DATA_WIDTH  {1'b0}};
assign CTP_SHARED_RAM_WMASK     = is_matching_tag(CORE_D_M_ADDR, CTP_SHARED_RAM_ADDR_TAG) ? CORE_D_M_WMASK          : {DATA_WIDTH/8{1'b0}};
assign CTP_SHARED_RAM_RDEN      = is_matching_tag(CORE_D_M_ADDR, CTP_SHARED_RAM_ADDR_TAG) ? CORE_D_M_RDEN           : {1           {1'b0}};

assign CORE_D_M_DOUT            = is_matching_tag(CORE_D_M_ADDR, DATA_RAM_ADDR_TAG)       ? DATA_RAM_RDATA          :
                                  is_matching_tag(CORE_D_M_ADDR, PTC_SHARED_RAM_ADDR_TAG) ? PTC_SHARED_RAM_RDATA    :
                                  is_matching_tag(CORE_D_M_ADDR, CTP_SHARED_RAM_ADDR_TAG) ? CTP_SHARED_RAM_RDATA    :
                                                                                            {DATA_WIDTH{1'b0}};

assign CORE_D_M_HIT            = is_matching_tag(CORE_D_M_ADDR, DATA_RAM_ADDR_TAG)        ? DATA_RAM_HIT            :
                                 is_matching_tag(CORE_D_M_ADDR, PTC_SHARED_RAM_ADDR_TAG)  ? PTC_SHARED_RAM_HIT      :
                                 is_matching_tag(CORE_D_M_ADDR, CTP_SHARED_RAM_ADDR_TAG)  ? CTP_SHARED_RAM_HIT      :
                                                                                            1'b0;


assign AXI_INSTR_RAM_AWID      = is_matching_tag(S_AXI_AWADDR, INSTR_RAM_ADDR_TAG)        ? S_AXI_AWID              : {ID_WIDTH    {1'b0}};
assign AXI_INSTR_RAM_AWADDR    = is_matching_tag(S_AXI_AWADDR, INSTR_RAM_ADDR_TAG)        ? S_AXI_AWADDR            : {ADDR_WIDTH  {1'b0}};
assign AXI_INSTR_RAM_AWLEN     = is_matching_tag(S_AXI_AWADDR, INSTR_RAM_ADDR_TAG)        ? S_AXI_AWLEN             : {8           {1'b0}};
assign AXI_INSTR_RAM_AWSIZE    = is_matching_tag(S_AXI_AWADDR, INSTR_RAM_ADDR_TAG)        ? S_AXI_AWSIZE            : {3           {1'b0}};
assign AXI_INSTR_RAM_AWBURST   = is_matching_tag(S_AXI_AWADDR, INSTR_RAM_ADDR_TAG)        ? S_AXI_AWBURST           : {2           {1'b0}};
assign AXI_INSTR_RAM_AWLOCK    = is_matching_tag(S_AXI_AWADDR, INSTR_RAM_ADDR_TAG)        ? S_AXI_AWLOCK            : {2           {1'b0}};
assign AXI_INSTR_RAM_AWCACHE   = is_matching_tag(S_AXI_AWADDR, INSTR_RAM_ADDR_TAG)        ? S_AXI_AWCACHE           : {4           {1'b0}};
assign AXI_INSTR_RAM_AWPROT    = is_matching_tag(S_AXI_AWADDR, INSTR_RAM_ADDR_TAG)        ? S_AXI_AWPROT            : {3           {1'b0}};
assign AXI_INSTR_RAM_AWVALID   = is_matching_tag(S_AXI_AWADDR, INSTR_RAM_ADDR_TAG)        ? S_AXI_AWVALID           : {1           {1'b0}};
assign AXI_INSTR_RAM_WDATA     = state_reg == AXI_INSTR_RAM_BURST                         ? S_AXI_WDATA             : {DATA_WIDTH  {1'b0}};
assign AXI_INSTR_RAM_WSTRB     = state_reg == AXI_INSTR_RAM_BURST                         ? S_AXI_WSTRB             : {DATA_WIDTH/8{1'b0}};
assign AXI_INSTR_RAM_WLAST     = state_reg == AXI_INSTR_RAM_BURST                         ? S_AXI_WLAST             : {1           {1'b0}};
assign AXI_INSTR_RAM_WVALID    = state_reg == AXI_INSTR_RAM_BURST                         ? S_AXI_WVALID            : {1           {1'b0}};
assign AXI_INSTR_RAM_BREADY    = state_reg == AXI_INSTR_RAM_BURST                         ? S_AXI_BREADY            : {1           {1'b0}};




assign AXI_DATA_RAM_AWID       = is_matching_tag(S_AXI_AWADDR, DATA_RAM_ADDR_TAG)         ? S_AXI_AWID              : {ID_WIDTH    {1'b0}};
assign AXI_DATA_RAM_AWADDR     = is_matching_tag(S_AXI_AWADDR, DATA_RAM_ADDR_TAG)         ? S_AXI_AWADDR            : {ADDR_WIDTH  {1'b0}};
assign AXI_DATA_RAM_AWLEN      = is_matching_tag(S_AXI_AWADDR, DATA_RAM_ADDR_TAG)         ? S_AXI_AWLEN             : {8           {1'b0}};
assign AXI_DATA_RAM_AWSIZE     = is_matching_tag(S_AXI_AWADDR, DATA_RAM_ADDR_TAG)         ? S_AXI_AWSIZE            : {3           {1'b0}};
assign AXI_DATA_RAM_AWBURST    = is_matching_tag(S_AXI_AWADDR, DATA_RAM_ADDR_TAG)         ? S_AXI_AWBURST           : {2           {1'b0}};
assign AXI_DATA_RAM_AWLOCK     = is_matching_tag(S_AXI_AWADDR, DATA_RAM_ADDR_TAG)         ? S_AXI_AWLOCK            : {2           {1'b0}};
assign AXI_DATA_RAM_AWCACHE    = is_matching_tag(S_AXI_AWADDR, DATA_RAM_ADDR_TAG)         ? S_AXI_AWCACHE           : {4           {1'b0}};
assign AXI_DATA_RAM_AWPROT     = is_matching_tag(S_AXI_AWADDR, DATA_RAM_ADDR_TAG)         ? S_AXI_AWPROT            : {3           {1'b0}};
assign AXI_DATA_RAM_AWVALID    = is_matching_tag(S_AXI_AWADDR, DATA_RAM_ADDR_TAG)         ? S_AXI_AWVALID           : {1           {1'b0}};
assign AXI_DATA_RAM_WDATA      = state_reg == AXI_DATA_RAM_BURST                          ? S_AXI_WDATA             : {DATA_WIDTH  {1'b0}};
assign AXI_DATA_RAM_WSTRB      = state_reg == AXI_DATA_RAM_BURST                          ? S_AXI_WSTRB             : {DATA_WIDTH/8{1'b0}};
assign AXI_DATA_RAM_WLAST      = state_reg == AXI_DATA_RAM_BURST                          ? S_AXI_WLAST             : {1           {1'b0}};
assign AXI_DATA_RAM_WVALID     = state_reg == AXI_DATA_RAM_BURST                          ? S_AXI_WVALID            : {1           {1'b0}};
assign AXI_DATA_RAM_BREADY     = state_reg == AXI_DATA_RAM_BURST                          ? S_AXI_BREADY            : {1           {1'b0}};



assign AXI_SHARED_RAM_AWID     = is_matching_tag(S_AXI_AWADDR, PTC_SHARED_RAM_ADDR_TAG)  ? S_AXI_AWID              : {ID_WIDTH    {1'b0}};
assign AXI_SHARED_RAM_AWADDR   = is_matching_tag(S_AXI_AWADDR, PTC_SHARED_RAM_ADDR_TAG)  ? S_AXI_AWADDR            : {ADDR_WIDTH  {1'b0}};
assign AXI_SHARED_RAM_AWLEN    = is_matching_tag(S_AXI_AWADDR, PTC_SHARED_RAM_ADDR_TAG)  ? S_AXI_AWLEN             : {8           {1'b0}};
assign AXI_SHARED_RAM_AWSIZE   = is_matching_tag(S_AXI_AWADDR, PTC_SHARED_RAM_ADDR_TAG)  ? S_AXI_AWSIZE            : {3           {1'b0}};
assign AXI_SHARED_RAM_AWBURST  = is_matching_tag(S_AXI_AWADDR, PTC_SHARED_RAM_ADDR_TAG)  ? S_AXI_AWBURST           : {2           {1'b0}};
assign AXI_SHARED_RAM_AWLOCK   = is_matching_tag(S_AXI_AWADDR, PTC_SHARED_RAM_ADDR_TAG)  ? S_AXI_AWLOCK            : {2           {1'b0}};
assign AXI_SHARED_RAM_AWCACHE  = is_matching_tag(S_AXI_AWADDR, PTC_SHARED_RAM_ADDR_TAG)  ? S_AXI_AWCACHE           : {4           {1'b0}};
assign AXI_SHARED_RAM_AWPROT   = is_matching_tag(S_AXI_AWADDR, PTC_SHARED_RAM_ADDR_TAG)  ? S_AXI_AWPROT            : {3           {1'b0}};
assign AXI_SHARED_RAM_AWVALID  = is_matching_tag(S_AXI_AWADDR, PTC_SHARED_RAM_ADDR_TAG)  ? S_AXI_AWVALID           : {1           {1'b0}};
assign AXI_SHARED_RAM_WDATA    = state_reg == WAXI_SHARED_RAM_BURST                      ? S_AXI_WDATA             : {DATA_WIDTH  {1'b0}};
assign AXI_SHARED_RAM_WSTRB    = state_reg == WAXI_SHARED_RAM_BURST                      ? S_AXI_WSTRB             : {DATA_WIDTH/8{1'b0}};
assign AXI_SHARED_RAM_WLAST    = state_reg == WAXI_SHARED_RAM_BURST                      ? S_AXI_WLAST             : {1           {1'b0}};
assign AXI_SHARED_RAM_WVALID   = state_reg == WAXI_SHARED_RAM_BURST                      ? S_AXI_WVALID            : {1           {1'b0}};
assign AXI_SHARED_RAM_BREADY   = state_reg == WAXI_SHARED_RAM_BURST                      ? S_AXI_BREADY            : {1           {1'b0}};




assign S_AXI_AWREADY           = state_reg == AXI_INSTR_RAM_BURST                         ? AXI_INSTR_RAM_AWREADY  :
                                 state_reg == AXI_DATA_RAM_BURST                          ? AXI_DATA_RAM_AWREADY   :
                                 state_reg == WAXI_SHARED_RAM_BURST                       ? AXI_SHARED_RAM_AWREADY :
                                                                                            {1           {1'b0}};

assign S_AXI_WREADY            = state_reg == AXI_INSTR_RAM_BURST                         ? AXI_INSTR_RAM_WREADY   :
                                 state_reg == AXI_DATA_RAM_BURST                          ? AXI_DATA_RAM_WREADY    :
                                 state_reg == WAXI_SHARED_RAM_BURST                       ? AXI_SHARED_RAM_WREADY  :
                                                                                            {1           {1'b0}};

assign S_AXI_BID               = state_reg == AXI_INSTR_RAM_BURST                         ? AXI_INSTR_RAM_BID      :
                                 state_reg == AXI_DATA_RAM_BURST                          ? AXI_DATA_RAM_BID       :
                                 state_reg == WAXI_SHARED_RAM_BURST                       ? AXI_SHARED_RAM_BID     :
                                                                                            {8           {1'b0}};

assign S_AXI_BRESP             = state_reg == AXI_INSTR_RAM_BURST                         ? AXI_INSTR_RAM_BRESP    :
                                 state_reg == AXI_DATA_RAM_BURST                          ? AXI_DATA_RAM_BRESP     :
                                 state_reg == WAXI_SHARED_RAM_BURST                       ? AXI_SHARED_RAM_BRESP   :
                                                                                            {2           {1'b0}};

assign S_AXI_BVALID            = state_reg == AXI_INSTR_RAM_BURST                         ? AXI_INSTR_RAM_BVALID   :
                                 state_reg == AXI_DATA_RAM_BURST                          ? AXI_DATA_RAM_BVALID    :
                                 state_reg == WAXI_SHARED_RAM_BURST                       ? AXI_SHARED_RAM_BVALID  :
                                                                                            {1           {1'b0}};




assign AXI_SHARED_RAM_ARID     = is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  ? S_AXI_ARID              : {ID_WIDTH    {1'b0}};
assign AXI_SHARED_RAM_ARADDR   = is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  ? S_AXI_ARADDR            : {ADDR_WIDTH  {1'b0}};
assign AXI_SHARED_RAM_ARLEN    = is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  ? S_AXI_ARLEN             : {8           {1'b0}};
assign AXI_SHARED_RAM_ARSIZE   = is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  ? S_AXI_ARSIZE            : {3           {1'b0}};
assign AXI_SHARED_RAM_ARBURST  = is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  ? S_AXI_ARBURST           : {2           {1'b0}};
assign AXI_SHARED_RAM_ARLOCK   = is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  ? S_AXI_ARLOCK            : {2           {1'b0}};
assign AXI_SHARED_RAM_ARCACHE  = is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  ? S_AXI_ARCACHE           : {4           {1'b0}};
assign AXI_SHARED_RAM_ARPROT   = is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  ? S_AXI_ARPROT            : {3           {1'b0}};
assign AXI_SHARED_RAM_ARVALID  = is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  ? S_AXI_ARVALID           : {1           {1'b0}};
assign S_AXI_ARREADY           = is_matching_tag(S_AXI_ARADDR, CTP_SHARED_RAM_ADDR_TAG)  ? AXI_SHARED_RAM_ARREADY  : {1           {1'b0}};

assign S_AXI_RID               = state_reg == RAXI_SHARED_RAM_BURST                       ? AXI_SHARED_RAM_RID     : {ID_WIDTH    {1'b0}};
assign S_AXI_RDATA             = state_reg == RAXI_SHARED_RAM_BURST                       ? AXI_SHARED_RAM_RDATA   : {DATA_WIDTH  {1'b0}};
assign S_AXI_RRESP             = state_reg == RAXI_SHARED_RAM_BURST                       ? AXI_SHARED_RAM_RRESP   : {2           {1'b0}};
assign S_AXI_RLAST             = state_reg == RAXI_SHARED_RAM_BURST                       ? AXI_SHARED_RAM_RLAST   : {1           {1'b0}};
assign S_AXI_RVALID            = state_reg == RAXI_SHARED_RAM_BURST                       ? AXI_SHARED_RAM_RVALID  : {1           {1'b0}};
assign AXI_SHARED_RAM_RREADY   = state_reg == RAXI_SHARED_RAM_BURST                       ? S_AXI_RREADY           : {1           {1'b0}};

/********************           ********************/
endmodule

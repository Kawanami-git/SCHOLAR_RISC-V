/*!
********************************************************************************
*  \file      data_dpram.sv
*  \module    data_dpram
*  \brief     SCHOLAR RISC-V data ram (write-only from AXI)
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/06/2025
*
********************************************************************************
*  \details
*  This module implements a dual-port RAM used for firmware data storage,
*  including read access by the SCHOLAR RISC-V core and write access by both the core
*  and an external AXI master (e.g., DMA or host CPU).
*
*  From the AXI perspective, only write transactions are supported.
*  The controller inside this module handles the AXI write address (AW),
*  write data (W), and write response (B) channels.
*
*  From the core perspective, both read and write accesses are supported
*  through a synchronous interface, independent of the AXI protocol.
*
*  In simulation, the instantiated RAM is the behavioral `dpram.sv`, which mimics
*  Microchip Libero's Dual-Port Large SRAM IP. The entire memory is exposed
*  at the top level to allow C++ access.
*
*  For FPGA synthesis (PolarFire SoC-FPGAs), the Dual-Port Large SRAM IP
*  (`DP_LSRAM_16K`) is instantiated instead.
*
*  This separation ensures correctness and traceability in simulation,
*  while maintaining compatibility with the production memory IP in hardware.
*
*  note:
*  Due to compatibility issues with the AXI Interconnect IP of the PolarFire fabric,
*  AXI burst transfers have been disabled in this module. Only single-beat write
*  transactions are supported. Additionally, this AXI interface is a simplified subset
*  of AXI4-full; several features (e.g., transaction IDs, protection levels, and locking)
*  are not handled, as they are unnecessary for the intended use-case of memory
*  access and firmware injection in a processor study context.
********************************************************************************
*  \parameters
*    - DATA_WIDTH       : Width of the data bus, in bits
*    - SIZE             : Total size of the RAM, in bytes
*    - ID_WIDTH         : Width of AXI transaction ID signal
*    - ADDR_WIDTH       : Width of the address bus, automatically derived from SIZE
*
*  \inputs
*    - CORE_CLK         : Clock for the SCHOLAR RISC-V core interface
*    - AXI_CLK          : Clock for the AXI interface
*    - RSTN             : Active-low reset
*
*    - CORE_M_ADDR      : Address for memory access issued by the core
*    - CORE_M_WREN      : Core write enable (1: write, 0: no write)
*    - CORE_M_WDATA     : Data to be written by the core
*    - CORE_M_WMASK     : Byte-enable write mask from the core
*    - CORE_M_RDEN      : Core read enable (1: read, 0: no read)
*
*    - S_AXI_AWID       : AXI write transaction ID
*    - S_AXI_AWADDR     : Write address
*    - S_AXI_AWLEN      : Burst length (number of beats - 1)
*    - S_AXI_AWSIZE     : Burst size (number of bytes per beat)
*    - S_AXI_AWBURST    : Burst type (e.g., fixed, increment)
*    - S_AXI_AWLOCK     : Lock signal for exclusive access
*    - S_AXI_AWCACHE    : Cacheable attribute
*    - S_AXI_AWPROT     : Protection type
*    - S_AXI_AWVALID    : Write address valid signal
*
*    - S_AXI_WDATA      : Write data payload
*    - S_AXI_WSTRB      : Write strobes (byte-level)
*    - S_AXI_WLAST      : Indicates the last data beat in burst
*    - S_AXI_WVALID     : Write data valid signal
*
*    - S_AXI_BREADY     : Write response ready (from master)
*
*  \outputs
*    - CORE_M_RDATA     : Read data returned to the core
*    - CORE_M_HIT       : Indicates transaction (read or write) completion to core
*
*    - S_AXI_AWREADY    : Slave ready to accept write address
*
*    - S_AXI_WREADY     : Slave ready to accept write data
*
*    - S_AXI_BID        : Write response ID
*    - S_AXI_BRESP      : Write response status (OKAY, SLVERR, etc.)
*    - S_AXI_BVALID     : Write response valid
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
module data_dpram
#(
    parameter                                       DATA_WIDTH  = 32,
    parameter                                       SIZE        = 16384,
    parameter                                       ID_WIDTH    = 8,

    parameter                                       ADDR_WIDTH = $clog2(SIZE)
)
(

`ifdef DUT
    output logic [DATA_WIDTH-1:0]                   DATA_DPRAM_MEM [0:(SIZE / (DATA_WIDTH / 8))-1],
`endif

    input  wire                                     CORE_CLK        ,
    input  wire                                     AXI_CLK         ,
    input  wire                                     RSTN            ,

    // Core
    input  wire [ADDR_WIDTH-1:0] 	                CORE_M_ADDR 	,
    input  wire                  	                CORE_M_WREN     ,
    input  wire [DATA_WIDTH-1:0] 	                CORE_M_WDATA    ,
    input  wire [(DATA_WIDTH/8)-1:0]                CORE_M_WMASK	,
    input  wire                  	                CORE_M_RDEN     ,
    output wire [DATA_WIDTH-1:0] 	                CORE_M_RDATA    ,
    output wire                  	                CORE_M_HIT      ,

    // AXI
    input  wire [ID_WIDTH       - 1 : 0]            S_AXI_AWID      ,
    input  wire [ADDR_WIDTH     - 1 : 0]            S_AXI_AWADDR    ,
    input  wire [                 2 : 0]            S_AXI_AWSIZE    ,
    /* verilator lint_off UNUSEDSIGNAL */                               // Disable Verilator warning `Signal is not used`
    input  wire [                 7 : 0]            S_AXI_AWLEN     ,
    input  wire [                 1 : 0]            S_AXI_AWBURST   ,
    input  wire [                 1 : 0]            S_AXI_AWLOCK    ,
    input  wire [                 3 : 0]            S_AXI_AWCACHE   ,
    input  wire [                 2 : 0]            S_AXI_AWPROT    ,
    input  wire                                     S_AXI_AWVALID   ,
    /* verilator lint_off UNUSEDSIGNAL */                               // Re-enable Verilator warning `Signal is not used`
    output wire                                     S_AXI_AWREADY   ,

    input  wire [DATA_WIDTH     - 1 : 0]            S_AXI_WDATA     ,
    input  wire [(DATA_WIDTH/8) - 1 : 0]            S_AXI_WSTRB     ,
    input  wire                                     S_AXI_WLAST     ,
    input  wire                                     S_AXI_WVALID    ,
    output wire                                     S_AXI_WREADY    ,

    output wire [ID_WIDTH       - 1 : 0]            S_AXI_BID       ,
    output wire [                 1 : 0]            S_AXI_BRESP     ,
    output wire                                     S_AXI_BVALID    ,
    input  wire                                     S_AXI_BREADY
);


/******************** PARAMETERS VERIFICATION ********************/

/********************                         ********************/


/******************** LOCAL PARAMETERS ********************/

/********************                  ********************/

/******************** MACHINE STATE ********************/
typedef enum reg [1:0]
{
    WR_IDLE,
    WR_BURST,
    WR_RESP
}writeStates;
writeStates write_state_reg;
/********************               ********************/


/******************** REGISTERS ********************/
reg [ID_WIDTH   - 1 : 0] s_axi_awid_reg;                // Stores the AXI write transaction ID
reg [ADDR_WIDTH - 1 : 0] s_axi_awaddr_reg;              // Stores the AXI write address
reg [             2 : 0] s_axi_awsize_reg;              // Stores the size of each AXI beat (in bytes)
reg [             1 : 0] s_axi_awburst_reg;             // Stores the AXI burst type (INCR, FIXED, etc.)
reg                      s_axi_awready_reg;             // Controls handshake with master for write address channel

reg                      s_axi_wready_reg;              // Controls handshake with master for write data channel

reg [ID_WIDTH   - 1 : 0] s_axi_bid_reg;                 // Stores the ID to return in write response
reg [             1 : 0] s_axi_bresp_reg;               // Indicates write response status (e.g., OKAY)
reg                      s_axi_bvalid_reg;              // Controls handshake for write response channel
/********************           ********************/



/*
* Write machine state.
*
* This finite state machine (FSM) handles the AXI write transaction flow.
*
* - WR_IDLE:      Waits for a valid AXI write address (`S_AXI_AWVALID`). Upon assertion,
*                 it captures the write parameters and moves to WR_BURST.
*
* - WR_BURST:     Handles incoming write data beats. Transition to WR_RESP occurs
*                 when the last write data beat (`S_AXI_WLAST`) is valid.
*
* - WR_RESP:      Sends the write response (`BVALID`). Once the master acknowledges
*                 by asserting `S_AXI_BREADY`, the FSM returns to WR_IDLE.
*
* This ensures correct sequencing of the write address, data, and response phases.
*/
always_ff @(posedge AXI_CLK) begin
    if(!RSTN)                                           write_state_reg <= WR_IDLE;
    else begin
        case(write_state_reg)
            WR_IDLE : if(S_AXI_AWVALID)                 write_state_reg <= WR_BURST;

            WR_BURST: if(S_AXI_WLAST && S_AXI_WVALID)   write_state_reg <= WR_RESP;

            WR_RESP : if(S_AXI_BREADY)                  write_state_reg <= WR_IDLE;

            default :                                   write_state_reg <= WR_IDLE;
        endcase
    end
end
/**/

/*
* AXI write control logic.
*
* This block manages the internal control and handshake signals for the AXI write channels:
* - Write address (AW)
* - Write data (W)
* - Write response (B)
*
* Behavior:
* - In `WR_IDLE`, the module latches the incoming address channel signals if `S_AXI_AWVALID` is high,
*   and asserts `AWREADY` to accept the transaction.
*
* - In `WR_BURST`, the module accepts write data when `S_AXI_WVALID` is asserted and raises `WREADY`.
*   The burst increment logic is commented out here, as burst transfers are not supported
*   due to PolarFire interconnect compatibility issues.
*
* - In `WR_RESP`, a valid write response (`BVALID`) is sent back to the master, echoing the transaction ID.
*
* All control signals are reset to default values upon reset.
*/
always_ff @(posedge AXI_CLK) begin
    if(!RSTN) begin
        s_axi_awid_reg    <= {ID_WIDTH{1'b0}};
        s_axi_awaddr_reg  <= {ADDR_WIDTH{1'b0}};
        s_axi_awsize_reg  <= 3'b000;
        s_axi_awburst_reg <= 2'b00;
        s_axi_awready_reg <= 1'b0;

        s_axi_wready_reg  <= 1'b0;

        s_axi_bid_reg     <= {ID_WIDTH{1'b0}};
        s_axi_bresp_reg   <= 2'b0;
        s_axi_bvalid_reg  <= 1'b0;
    end else begin
        case (write_state_reg)
            WR_IDLE: begin
                s_axi_bvalid_reg  <= 1'b0;

                if (S_AXI_AWVALID) begin
                    s_axi_awid_reg    <= S_AXI_AWID;
                    s_axi_awaddr_reg  <= S_AXI_AWADDR;
                    s_axi_awsize_reg  <= S_AXI_AWSIZE;
                    s_axi_awburst_reg <= S_AXI_AWBURST;
                    s_axi_awready_reg <= 1'b1;
                end
            end

            WR_BURST: begin
                s_axi_awready_reg <= 1'b0;
                s_axi_wready_reg  <= S_AXI_WVALID;
                // if (S_AXI_WVALID && s_axi_awburst_reg != 2'b00) s_axi_awaddr_reg <= s_axi_awaddr_reg + (1 << s_axi_awsize_reg);
            end

            WR_RESP: begin
                s_axi_wready_reg   <= 1'b0;

                s_axi_bid_reg      <= s_axi_awid_reg;
                s_axi_bresp_reg    <= 2'b00;
                s_axi_bvalid_reg   <= 1'b1;
            end

            default: ;
        endcase
    end
end

assign S_AXI_AWREADY = s_axi_awready_reg;
assign S_AXI_WREADY  = s_axi_wready_reg;
assign S_AXI_BID     = s_axi_bid_reg;
assign S_AXI_BRESP   = s_axi_bresp_reg;
assign S_AXI_BVALID  = s_axi_bvalid_reg;
/**/

/*
* Core-side memory hit signal.
*
* Since the dual-port RAM provides single-cycle access and is always available,
* the `CORE_M_HIT` signal can directly reflect the validity of the core's request.
*
* - If either a read (`CORE_M_RDEN`) or a write (`CORE_M_WREN`) is requested,
*   the memory is assumed to complete the operation without wait states.
*
* This simplifies handshaking by eliminating the need for an explicit memory
* ready/acknowledge protocol.
*/
assign CORE_M_HIT = CORE_M_RDEN || CORE_M_WREN;
/**/


/*
* Dual-Port RAM instantiation.
*
* This conditional block instantiates either the behavioral simulation RAM
* (`dpram`) or the synthesizable IP (`DP_LSRAM_16K`) depending on the compilation
* flag `DUT`.
*
* - In simulation (`DUT` defined), the behavioral `dpram` is used.
*   - Port A is connected to the AXI read channel.
*   - Port B is connected to the RISC-V core for read/write.
*   - The full memory (`DATA_DPRAM_MEM`) is exposed for inspection from C++ testbenches.
*
* - In synthesis (`DUT` undefined), the FPGA memory macro `DP_LSRAM_16K` is used.
*   - Same port mapping applies.
*   - Port A write-enable and data-in are forced to zero since only read access is needed on AXI.
*
* This setup ensures the same interface is preserved in both simulation and hardware contexts.
*/
`ifdef DUT
dpram
#(
    .DATA_WIDTH(DATA_WIDTH                          ),
    .SIZE      (SIZE                                )
)dpram
(
    .MEM        (DATA_DPRAM_MEM                     ),

    .A_ADDR     (s_axi_awaddr_reg                   ),
    .A_CLK      (AXI_CLK                            ),
    .A_DIN      (S_AXI_WDATA                        ),
    .A_WBYTE_EN (S_AXI_WSTRB                        ),
    .A_WEN      (S_AXI_WVALID                       ),
    .A_REN      (1'b0                               ),

    .B_CLK      (CORE_CLK                           ),
    .B_ADDR     (CORE_M_ADDR                        ),
    .B_DIN      (CORE_M_WDATA                       ),
    .B_WBYTE_EN (CORE_M_WMASK                       ),
    .B_WEN      (CORE_M_WREN                        ),
    .B_REN      (CORE_M_RDEN                        ),

    /* verilator lint_off PINCONNECTEMPTY */                // Disable Verilator warning `Cell pin connected by name with empty reference`
    .A_DOUT     (                                   ),
    /* verilator lint_on PINCONNECTEMPTY */                 // Re-enable Verilator warning `Cell pin connected by name with empty reference`
    .B_DOUT     (CORE_M_RDATA                       )
);

`else

logic [31:0] a_wbyte_en;
logic [31:0] b_wbyte_en;

assign a_wbyte_en[31:24] = S_AXI_WSTRB[3] ? 8'b11111111 : 8'b00000000;
assign a_wbyte_en[23:16] = S_AXI_WSTRB[2] ? 8'b11111111 : 8'b00000000;
assign a_wbyte_en[15: 8] = S_AXI_WSTRB[1] ? 8'b11111111 : 8'b00000000;
assign a_wbyte_en[ 7: 0] = S_AXI_WSTRB[0] ? 8'b11111111 : 8'b00000000;

assign b_wbyte_en[31:24] = CORE_M_WMASK[3] ? 8'b11111111 : 8'b00000000;
assign b_wbyte_en[23:16] = CORE_M_WMASK[2] ? 8'b11111111 : 8'b00000000;
assign b_wbyte_en[15: 8] = CORE_M_WMASK[1] ? 8'b11111111 : 8'b00000000;
assign b_wbyte_en[ 7: 0] = CORE_M_WMASK[0] ? 8'b11111111 : 8'b00000000;

DP_LSRAM_16K dpram
(
    .A_ADDR     (s_axi_awaddr_reg                   ),
    .A_CLK      (AXI_CLK                            ),
    .A_DIN      (S_AXI_WDATA                        ),
    .A_WBYTE_EN (a_wbyte_en                         ),
    .A_WEN      (S_AXI_WVALID                       ),
    .A_REN      (1'b0                               ),

    .B_CLK      (CORE_CLK                           ),
    .B_ADDR     (CORE_M_ADDR                        ),
    .B_DIN      (CORE_M_WDATA                       ),
    .B_WBYTE_EN (b_wbyte_en                         ),
    .B_WEN      (CORE_M_WREN                        ),
    .B_REN      (CORE_M_RDEN                        ),

    .A_DOUT     (                                   ),
    .B_DOUT     (CORE_M_RDATA                       )
);

`endif

endmodule

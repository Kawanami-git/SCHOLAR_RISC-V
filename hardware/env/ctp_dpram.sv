/*!
********************************************************************************
*  \file      ctp_dpram.sv
*  \module    ctp_dpram
*  \brief     Core-to-Platform Dual-Port RAM (read-only from AXI)
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/06/2025
*
********************************************************************************
*  \details
*  This module implements a dual-port RAM enabling data sharing from the SCHOLAR
*  RISC-V core to the platform through a read-only AXI interface.
*  The memory can be read and written by the core and read by an AXI master (e.g., DMA, CPU).
*
*  This file implements the AXI Read Address and Read Data channel controllers,
*  allowing the AXI interface to access an instantiated Dual-Port RAM.
*
*  In simulation, the instantiated RAM is `dpram.sv`. It follows the interface style
*  of Microchip’s Libero-generated Dual-Port Large SRAM and is directly accessible
*  from C++ testbenches.
*
*  For synthesis on Microchip PolarFire SoC-FPGAs, the Dual-Port Large SRAM IP
*  is instantiated instead of the simulation RAM.
*
*  The AXI interface only supports read transactions. The RISC-V core side
*  supports both read and write access using a simpler synchronous protocol.
*
*  note:
*  This AXI interface is a simplified subset
*  of AXI4-full; several features (e.g., transaction IDs, protection levels, and locking)
*  are not handled, as they are unnecessary for the intended use-case of memory
*  access and firmware injection in a processor study context.
********************************************************************************
*  \parameters
*    - DATA_WIDTH       : Width of the data bus, in bits
*    - SIZE             : Total size of the RAM, in bytes
*    - ID_WIDTH         : AXI ID signal width
*    - ADDR_WIDTH       : Width of the address bus (automatically derived from SIZE)
*
*  \inputs
*    - CORE_CLK         : Clock for the SCHOLAR RISC-V core interface
*    - AXI_CLK          : Clock for the AXI interface
*    - RSTN             : Active-low reset
*
*    - CORE_M_ADDR      : Address from the core
*    - CORE_M_WREN      : Write enable signal from core (1: write)
*    - CORE_M_WDATA     : Write data from core
*    - CORE_M_WMASK     : Byte-enable mask for core write
*    - CORE_M_RDEN      : Read enable signal from core
*
*    - S_AXI_ARID       : AXI read transaction ID
*    - S_AXI_ARADDR     : AXI read address
*    - S_AXI_ARLEN      : AXI burst length
*    - S_AXI_ARSIZE     : AXI burst size
*    - S_AXI_ARBURST    : AXI burst type
*    - S_AXI_ARLOCK     : AXI lock signal
*    - S_AXI_ARCACHE    : AXI cache attribute
*    - S_AXI_ARPROT     : AXI protection type
*    - S_AXI_ARVALID    : Read address valid
*    - S_AXI_RREADY     : Read data ready (handshake)
*
*  \outputs
*    - CORE_M_RDATA     : Read data output to core
*    - CORE_M_HIT       : Read/write transaction complete from core side
*
*    - S_AXI_ARREADY    : Read address accepted by slave
*    - S_AXI_RID        : Response ID
*    - S_AXI_RDATA      : Read data response to AXI
*    - S_AXI_RRESP      : Read response code (OKAY, SLVERR, etc.)
*    - S_AXI_RLAST      : AXI burst last signal
*    - S_AXI_RVALID     : Read data valid (handshake)
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
module ctp_dpram
#(
    parameter                                       DATA_WIDTH  = 32,
    parameter                                       SIZE        = 2048,
    parameter                                       ID_WIDTH    = 8,

    parameter                                       ADDR_WIDTH = $clog2(SIZE)
)
(

`ifdef DUT
    output logic [DATA_WIDTH-1:0]                   CTP_DPRAM_MEM [0:(SIZE / (DATA_WIDTH / 8))-1],
`endif

    input  wire                                     CORE_CLK        ,
    input  wire                                     AXI_CLK         ,
    input  wire                                     RSTN            ,

    // Core
    input  wire [ADDR_WIDTH     - 1 : 0]            CORE_M_ADDR 	,
    input  wire                  	                CORE_M_WREN     ,
    input  wire [DATA_WIDTH     - 1 : 0] 	        CORE_M_WDATA    ,
    input  wire [(DATA_WIDTH/8) - 1 : 0]            CORE_M_WMASK    ,
    input  wire                  	                CORE_M_RDEN     ,
    output wire [DATA_WIDTH     - 1 : 0] 	        CORE_M_RDATA    ,
    output wire                  	                CORE_M_HIT      ,

    // AXI
    input  wire [ID_WIDTH       - 1 : 0]            S_AXI_ARID      ,
    input  wire [ADDR_WIDTH     - 1 : 0]            S_AXI_ARADDR    ,
    input  wire [                 7 : 0]            S_AXI_ARLEN     ,
    input  wire [                 2 : 0]            S_AXI_ARSIZE    ,
    input  wire [                 1 : 0]            S_AXI_ARBURST   ,
    /* verilator lint_off UNUSEDSIGNAL */                               // Disable Verilator warning `Signal is not used`
    input  wire [                 1 : 0]            S_AXI_ARLOCK    ,
    input  wire [                 3 : 0]            S_AXI_ARCACHE   ,
    input  wire [                 2 : 0]            S_AXI_ARPROT    ,
    /* verilator lint_off UNUSEDSIGNAL */                               // Re-enable Verilator warning `Signal is not used`
    input  wire                                     S_AXI_ARVALID   ,
    output wire                                     S_AXI_ARREADY   ,

    output wire [ID_WIDTH       - 1 : 0]            S_AXI_RID       ,
    output wire [DATA_WIDTH     - 1 : 0]            S_AXI_RDATA     ,
    output wire [                 1 : 0]            S_AXI_RRESP     ,
    output wire                                     S_AXI_RLAST     ,
    output wire                                     S_AXI_RVALID    ,
    input  wire                                     S_AXI_RREADY
);


/******************** PARAMETERS VERIFICATION ********************/

/********************                         ********************/


/******************** LOCAL PARAMETERS ********************/

/********************                  ********************/

/******************** MACHINE STATE ********************/
typedef enum reg [0:0]
{
    RD_IDLE,
    RD_BURST
}readStates;
readStates read_state_reg;
/********************               ********************/

/******************** REGISTERS ********************/
reg [ID_WIDTH-1:0]      s_axi_arid_reg;                     // Registered ARID from AXI read address channel (transaction ID)
reg [ADDR_WIDTH-1:0]    s_axi_araddr_reg;                   // Registered read address from AXI master
reg [7:0]               s_axi_arlen_reg;                    // Registered burst length (number of data beats - 1)
reg [2:0]               s_axi_arsize_reg;                   // Registered size of each transfer in the burst (log2(bytes))
reg [1:0]               s_axi_arburst_reg;                  // Registered burst type (e.g., INCR, FIXED)
reg                     s_axi_arready_reg;                  // Indicates if the slave can accept a new read address

reg [1:0]               s_axi_rresp_reg;                    // Response code for read transaction (OKAY, SLVERR, etc.)
reg                     s_axi_rlast_reg;                    // Indicates the last data beat in a burst
reg                     s_axi_rvalid_reg;                   // Indicates valid read data is available on the bus
/********************           ********************/

/*
* Read machine state.
*
* This state machine governs the AXI read transaction lifecycle.
* It manages the transition between idle and active burst states, ensuring proper handshaking.
*
* - RD_IDLE: Waits for a valid read address phase (`S_AXI_ARVALID`).
*            Once received, transitions to `RD_BURST`.
*
* - RD_BURST: Actively sends read data beats to the AXI master.
*             Transitions back to `RD_IDLE` when the last beat is sent (`s_axi_rlast_reg`).
*
* The state is updated on the rising edge of the AXI clock (`AXI_CLK`),
* and is reset to `RD_IDLE` when `RSTN` is deasserted.
*/
always_ff @(posedge AXI_CLK) begin
    if(!RSTN)                                                 read_state_reg <= RD_IDLE;
    else begin
        case(read_state_reg)
            RD_IDLE : if (S_AXI_ARVALID)                      read_state_reg <= RD_BURST;
            RD_BURST: if(s_axi_rlast_reg)                     read_state_reg <= RD_IDLE;
            default :                                         read_state_reg <= RD_IDLE;

        endcase
    end
end
/**/

/*
* Read control signals.
*
* This block manages the control path for AXI read transactions.
* It registers the AXI address channel information and controls the response channel behavior.
*
* On reset:
* - All internal control registers are cleared.
*
* In `RD_IDLE` state:
* - Waits for a valid address phase (`S_AXI_ARVALID`).
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
* AXI response signals (`RID`, `RRESP`, `RLAST`, `RVALID`) are driven combinatorially
* from the registered control fields to maintain timing consistency.
*/
always_ff @(posedge  AXI_CLK) begin
    if(!RSTN) begin
        s_axi_arid_reg      <= {ID_WIDTH{1'b0}};
        s_axi_araddr_reg    <= {ADDR_WIDTH{1'b0}};
        s_axi_arlen_reg     <= 8'b00000000;
        s_axi_arsize_reg    <= 3'b000;
        s_axi_arburst_reg   <= 2'b00;
        s_axi_arready_reg   <= 1'b0;

        s_axi_rresp_reg     <= 2'b00;
        s_axi_rlast_reg     <= 1'b0;
        s_axi_rvalid_reg    <= 1'b0;
    end else begin
        case (read_state_reg)
            RD_IDLE: begin
                s_axi_rlast_reg     <= 1'b0;
                s_axi_rvalid_reg    <= 1'b0;

                if (S_AXI_ARVALID) begin
                    s_axi_arid_reg      <= S_AXI_ARID;
                    s_axi_araddr_reg    <= S_AXI_ARADDR;
                    s_axi_arlen_reg     <= S_AXI_ARLEN;
                    s_axi_arsize_reg    <= S_AXI_ARSIZE;
                    s_axi_arburst_reg   <= S_AXI_ARBURST;
                    s_axi_arready_reg   <= 1'b1;
                end
            end

            RD_BURST: begin
                s_axi_arready_reg       <= 1'b0;

                if (S_AXI_RREADY) begin
                    s_axi_rvalid_reg    <= 1'b1;
                    s_axi_arlen_reg     <= s_axi_arlen_reg - 1;

                    if (s_axi_arburst_reg != 2'b00) s_axi_araddr_reg <= s_axi_araddr_reg + (1 << s_axi_arsize_reg);
                    if(s_axi_arlen_reg == 0)        s_axi_rlast_reg  <= 1'b1;

                end else s_axi_rvalid_reg <= 1'b0;
            end
        endcase
    end
end

assign S_AXI_ARREADY = s_axi_arready_reg;

assign S_AXI_RID     = s_axi_arid_reg;
assign S_AXI_RRESP   = s_axi_rresp_reg;
assign S_AXI_RLAST   = s_axi_rlast_reg;
assign S_AXI_RVALID  = s_axi_rvalid_reg;
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


/*
* Dual-Port RAM instantiation.
*
* This conditional block instantiates either the behavioral simulation RAM
* (`dpram`) or the synthesizable IP (`DP_LSRAM_2K`) depending on the compilation
* flag `DUT`.
*
* - In simulation (`DUT` defined), the behavioral `dpram` is used.
*   - Port A is connected to the AXI read channel.
*   - Port B is connected to the RISC-V core for read/write.
*   - The full memory (`CTP_DPRAM_MEM`) is exposed for inspection from C++ testbenches.
*
* - In synthesis (`DUT` undefined), the FPGA memory macro `DP_LSRAM_2K` is used.
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
    .MEM        (CTP_DPRAM_MEM                      ),

    .A_ADDR     (s_axi_araddr_reg                   ),
    .A_CLK      (AXI_CLK                            ),
    .A_DIN      ({DATA_WIDTH{1'b0}}                 ),
    .A_WBYTE_EN ({DATA_WIDTH/8{1'b0}}               ),
    .A_WEN      (1'b0                               ),
    .A_REN      (S_AXI_RREADY                       ),

    .B_CLK      (CORE_CLK                           ),
    .B_ADDR     (CORE_M_ADDR                        ),
    .B_DIN      (CORE_M_WDATA                       ),
    .B_WBYTE_EN (CORE_M_WMASK                       ),
    .B_WEN      (CORE_M_WREN                        ),
    .B_REN      (CORE_M_RDEN                        ),

    .A_DOUT     (S_AXI_RDATA                        ),
    .B_DOUT     (CORE_M_RDATA                       )
);

`else

DP_LSRAM_2K dpram
(
    .A_ADDR     (s_axi_araddr_reg                   ),
    .A_CLK      (AXI_CLK                            ),
    .A_DIN      ({DATA_WIDTH{1'b0}}                 ),
    .A_WBYTE_EN ({DATA_WIDTH/8{1'b1}  }             ),
    .A_WEN      (1'b0                               ),
    .A_REN      (S_AXI_RREADY                       ),

    .B_CLK      (CORE_CLK                           ),
    .B_ADDR     (CORE_M_ADDR                        ),
    .B_DIN      (CORE_M_WDATA                       ),
    .B_WBYTE_EN (CORE_M_WMASK                       ),
    .B_WEN      (CORE_M_WREN                        ),
    .B_REN      (CORE_M_RDEN                        ),

    .A_DOUT     (S_AXI_RDATA                        ),
    .B_DOUT     (CORE_M_RDATA                       )
);
`endif


endmodule

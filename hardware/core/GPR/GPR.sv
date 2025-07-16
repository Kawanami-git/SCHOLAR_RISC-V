/*!
********************************************************************************
*  \file      GPR.sv
*  \module    GPR
*  \brief     SCHOLAR RISC-V core General Purpose Registers file module
*
*  \author    Kawanami
*  \version   1.0
*  \date      31/05/2025
*
********************************************************************************
*  \details
*  This module implements the SCHOLAR RISC-V register file.
*  It contains all general-purpose registers (GPRs) along with the program counter (PC).
*  It consists of a RAM with two read ports (for operand fetch) and
*  one write port (for result storage).
*  The PC is stored in a dedicated register, separate from the general-purpose registers.
********************************************************************************
*  \parameters
*    - ADDR_WIDTH       : Number of bits for addressing
*    - DATA_WIDTH       : Width of data paths (in bits)
*    - START_ADDR       : Core boot address
*
*  \inputs
*    - CLK                     : System clock
*    - RSTN                    : Active-low reset
*    - DECODE_RS1              : Register Source 1
*    - DECODE_RS2              : Register Source 2
*    - COMMIT_RD               : Register Destination
*    - COMMIT_RD_VAL           : Data to write in the Register Destination 
*    - COMMIT_RD_VALID         : Data to write in the Register Destination valid flag (1: valid, 0: not valid)
*    - COMMIT_PC_NEXT          : Next value of PC
*
*  \outputs
*    - RS1_VAL                 : Register Source 1 value
*    - RS2_VAL                 : Register Source 2 value
*    - PC                      : Program counter
*
*  \inouts
*    - None.
*
********************************************************************************
*  \versioning
*
*  Version   Date          Author          Description
*  -------   ----------    ------------    --------------------------------------
*  1.0       31/05/2025    Kawanami        Initial version of the module
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

module GPR
    import archi_pkg::*;
#(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter START_ADDR  = {ADDR_WIDTH{1'b0}}
)
(
`ifdef DUT
    input  wire                         GPR_EN                      ,
    input  wire [RF_ADDR_WIDTH - 1 : 0] GPR_ADDR                    ,
    input  wire [DATA_WIDTH    - 1 : 0] GPR_DATA                    ,
    output wire [DATA_WIDTH    - 1 : 0] GPR_MEMORY [0:NB_GPR-1]     ,
    output wire [ADDR_WIDTH    - 1 : 0] GPR_PC_REG                  ,
`endif

    input  wire                         CLK                         ,
    input  wire                         RSTN                        ,

    input  wire [RF_ADDR_WIDTH - 1 : 0] DECODE_RS1                  ,
    input  wire [RF_ADDR_WIDTH - 1 : 0] DECODE_RS2                  ,
    input  wire [RF_ADDR_WIDTH - 1 : 0] COMMIT_RD                   ,
    input  wire [DATA_WIDTH    - 1 : 0] COMMIT_RD_VAL               ,
    input  wire                         COMMIT_RD_VALID             ,
    output wire [DATA_WIDTH    - 1 : 0] RS1_VAL                     ,
    output wire [DATA_WIDTH    - 1 : 0] RS2_VAL                     ,

    input  wire [ADDR_WIDTH    - 1 : 0] COMMIT_PC_NEXT              ,
    output wire [ADDR_WIDTH    - 1 : 0] PC
);



/******************** PARAMETERS VERIFICATION ********************/
/********************                         ********************/

/******************** LOCAL PARAMETERS ********************/
/********************                  ********************/

/******************** TYPES DEFINITION ********************/
/********************                  ********************/

/******************** WIRES ********************/
/********************       ********************/

/******************** REGISTERS ********************/
// Control registers

// Data registers

// General Purpose Registers. x0 = mem[0], x1 = mem[1] ... x31 = mem[31].
reg [DATA_WIDTH - 1 : 0] mem [0:NB_GPR-1];
reg [ADDR_WIDTH - 1 : 0] pc_reg;             // Program Counter register
/********************           ********************/


/******************** MACHINE STATE ********************/
/********************               ********************/

/******************** CONTROL ********************/
/********************         ********************/

/******************** DATA PATH ********************/

/*
* Write operations are performed synchronously, while read operations are handled asynchronously.
* On reset, the PC register is initialized to `START_ADDR` and the register 0 is initialized with zeroes.
* The non-reset of the others registers does not affect system behavior, and it helps to reduce hardware costs.
*
* The PC register is updated each cycle. Thus, to hold an instruction, the `COMMIT_PC_NEXT` shall
* remain the same.
* Memory (mem) is updated only if:
*   - The address is valid (i.e., greater than 0, to prevent writing to register x0).
*   - `COMMIT_RD_VALID` is asserted, indicating that the data input is valid for writing.
*/
always_ff @(posedge CLK)
begin
         if(!RSTN)                                          pc_reg      <= START_ADDR;
    else                                                    pc_reg      <= COMMIT_PC_NEXT;

         if(!RSTN)                                          mem[0]      <= {DATA_WIDTH{1'b0}};
    else if(COMMIT_RD_VALID && COMMIT_RD > {RF_ADDR_WIDTH{1'b0}})         mem[COMMIT_RD]     <= COMMIT_RD_VAL;
end

assign RS1_VAL = mem[DECODE_RS1];
assign RS2_VAL = mem[DECODE_RS2];
assign PC      = pc_reg;
/**/

/*
* This block is active only when the design is under test (DUT).
* It forwards the General Purpose Registers (GPRs) to Verilator for verification of the core's internal states.
* This also allows Verilator to modify these internal states during testing.
*/
`ifdef DUT
always_latch
begin
    if(GPR_EN)  mem[GPR_ADDR]  = GPR_DATA;
end

assign GPR_MEMORY = mem;
assign GPR_PC_REG = pc_reg;
`endif
/**/


/********************           ********************/


endmodule

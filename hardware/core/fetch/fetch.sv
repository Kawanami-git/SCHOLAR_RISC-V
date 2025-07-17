/*!
********************************************************************************
*  \file      fetch.sv
*  \module    fetch
*  \brief     SCHOLAR RISC-V core fetch module
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/07/2025
*
********************************************************************************
*  \details
*  This module implements the instruction fetch unit of the SCHOLAR RISC-V core.
*
*  It retrieves the instruction located at `COMMIT_PC_NEXT` via the memory interface.
*  The instruction data is provided by `M_DOUT` and is considered valid when `M_HIT` is high.
*
*  As this is a single-cycle processor, instruction fetch and execution occur in the same cycle.
*  Therefore, a new instruction must be fetched at every clock cycle.
*
*  For memory-dependent operations (e.g., load/store), which require two cycles
*  to be processed, it is essential that `COMMIT_PC_NEXT`
*  remains stable while the instruction completes to avoid fetching incorrect data.
*
*  This fetch unit forms the entry point of the core pipeline, providing a steady
*  flow of valid instructions to the decode unit.
********************************************************************************
*  \parameters
*    - ADDR_WIDTH       : Number of bits for addressing
*
*  \inputs
*    - CLK              : System clock
*    - RSTN             : System active low reset
*    - COMMIT_PC_NEXT   : Program counter (address of the next instruction to fetch)
*    - M_DOUT           : Memory output data
*    - M_HIT            : Memory hit flag (1: hit, 0: miss)
*
*  \outputs
*    - INSTR            : Instruction
*    - VALID            : Instruction valid flag (1: valid, 0: invalid)
*    - M_ADDR           : Memory address
*    - M_RDEN           : Memory read enable (1: enable, 0: disable)
*
*  \inouts
*    - None.
*
********************************************************************************
*  \versioning
*
*  Version   Date          Author          Description
*  -------   ----------    ------------    --------------------------------------
*  1.0       02/07/2025    Kawanami        Initial version of the module
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

module fetch
    import archi_pkg::*;
#(
    parameter ADDR_WIDTH  = 32
)
(
    input  wire                       CLK            ,
    input  wire                       RSTN           ,

    input  wire [ADDR_WIDTH  - 1 : 0] COMMIT_PC_NEXT ,
    output wire [INSTR_WIDTH - 1 : 0] INSTR          ,
    output wire                       VALID          ,

    input  wire [INSTR_WIDTH - 1 : 0] M_DOUT         ,
    input  wire                       M_HIT          ,
    output wire [ADDR_WIDTH  - 1 : 0] M_ADDR         ,
    output wire                       M_RDEN
);


/******************** PARAMETERS VERIFICATION ********************/

/********************                         ********************/

/******************** LOCAL PARAMETERS ********************/

/********************                  ********************/

/******************** TYPES DEFINITION ********************/

/********************                  ********************/

/******************** WIRES ********************/
// Machine state wires

// Control wires

// Data wires
logic [INSTR_WIDTH - 1 : 0] instr;          // Fetched instruction
/********************       ********************/

/******************** REGISTERS ********************/
// Machine state register

// Control registers
reg                         valid_reg;      // Instruction valid flag register
reg                         m_rden_reg;     // Memory read enable register
// Data registers

/********************           ********************/


/******************** MACHINE STATE ********************/

/********************               ********************/

/*
* Memory access control signals.
*
* In a single-cycle (monocycle) processor, one instruction is fetched every cycle.
* Therefore, M_RDEN is always asserted (except during reset).
*
* Since the fetch unit only performs instruction reads, the memory address (M_ADDR)
* is always set to the value of the program counter (COMMIT_PC_NEXT), which corresponds
* to the address of the next instruction.
*
* The instruction is considered valid (VALID) if the memory signals a hit (M_HIT),
* and the system is not in reset.
*
* For instructions that take more than one cycle to complete (e.g., memory accesses),
* the COMMIT_PC_NEXT must remain stable to ensure correct execution.
*/
always_ff @(posedge CLK) begin : mem_controller
    if(!RSTN) begin
        valid_reg  <= 1'b0;
        m_rden_reg <= 1'b0;
    end else begin
        valid_reg  <= M_HIT;
        m_rden_reg <= 1'b1;
    end
end

assign M_RDEN = m_rden_reg;
assign M_ADDR = COMMIT_PC_NEXT;
assign VALID  = valid_reg;
/**/


/*
* Instruction selection logic.
*
* - During reset (when RSTN is low), the instruction is forced to 0 to prevent
*   the decode unit from processing garbage data.
*
* - Once reset is deasserted, the fetched instruction from memory (M_DOUT)
*   is forwarded to the decode unit.
*
* This ensures clean instruction flow and avoids misbehavior during system initialization.
*/
always_comb begin : instr_mux
     if(!RSTN) begin
        instr = {INSTR_WIDTH{1'b0}};
    end else begin
        instr = M_DOUT;
    end   
end

assign INSTR = instr;
/**/

endmodule

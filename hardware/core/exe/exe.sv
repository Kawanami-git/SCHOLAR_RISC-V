/*!
********************************************************************************
*  \file      exe.sv
*  \module    exe
*  \brief     SCHOLAR RISC-V core execution module
*
*  \author    Kawanami
*  \version   1.0
*  \date      08/07/2025
*
********************************************************************************
*  \details
* This module implements the execution (EXE) unit of the SCHOLAR RISC-V processor core.
*
* Its main role is to perform the actual computation specified by each instruction,
* using the control signal computed the previous unit.
*
* This unit typically involves arithmetic and logical operations (performed by the ALU),
* as well as comparisons used by branch instructions.
*
* The operands (`RS1`, `RS2` or immediate) are provided by the decode unit through `DECODE_OP1` and
* `DECODE_OP2`.
* The computed result is then forwarded to the commit unit, either for memory access,
* register write-back, or control flow resolution (e.g., branch target).
*
* The module also generates a `valid` signal to indicate whether the result is ready and should be used
* by subsequent units.
********************************************************************************
*  \parameters
*    - DATA_WIDTH       : Width of data paths (in bits)
*
*  \inputs
*    - DECODE_OP1       : First operand  (RS1)
*    - DECODE_OP2       : Second operand (either RS2 or immediate)
*    - DECODE_EXE_CTRL  : Control (operation to execute)
*
*  \outputs
*    - OUT              : Output data value
*
*  \inouts
*    - None.
*
********************************************************************************
*  \versioning
*
*  Version   Date          Author          Description
*  -------   ----------    ------------    --------------------------------------
*  1.0       08/07/2025    Kawanami        Initial version of the module
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

module exe
    import archi_pkg::*;
#(
    parameter DATA_WIDTH = 32
)
(
    input  wire [DATA_WIDTH     - 1 : 0]  DECODE_OP1        ,
    input  wire [DATA_WIDTH     - 1 : 0]  DECODE_OP2        ,
    input  wire [EXE_CTRL_WIDTH - 1 : 0]  DECODE_EXE_CTRL   ,

    output wire [DATA_WIDTH     - 1 : 0]  OUT
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
logic [DATA_WIDTH - 1 : 0]    out;  // Operation result
/********************       ********************/


/******************** REGISTERS ********************/
// Machine state register

// Control registers

// Data registers
/********************           ********************/


/******************** MACHINE STATE ********************/

/********************               ********************/


/*
* This block computes the result of the operation based on the decoded control signal (`DECODE_EXE_CTRL`)
* and the two operands (`DECODE_OP1`, `DECODE_OP2`), both coming from the decode unit.
*
* The `DECODE_EXE_CTRL` signal selects the arithmetic or logical operation to apply.
*
* - Arithmetic/logical operations (ADD, SUB, SLL, etc.) directly apply the operation to DECODE_OP1 and DECODE_OP2.
* - Shift amounts are truncated to log2(DATA_WIDTH) bits (as per RISC-V spec).
* - Comparison operations return 1 or 0 depending on the result (used in branches or SLT/SLTU).
* - Signed operations use `$signed()` to enforce correct signed behavior.
*
* If `DECODE_EXE_CTRL` does not match a valid operation, the output defaults to zero.
*/
always_comb begin : alu
    case(DECODE_EXE_CTRL)

        ADD  : out = DECODE_OP1 + DECODE_OP2;
        SUB  : out = DECODE_OP1 - DECODE_OP2;
        SLL  : out = DECODE_OP1 << DECODE_OP2[$clog2(DATA_WIDTH) - 1 : 0];
        SRL  : out = DECODE_OP1 >> DECODE_OP2[$clog2(DATA_WIDTH) - 1 : 0];
        SRA  : out = $signed(DECODE_OP1) >>> DECODE_OP2[$clog2(DATA_WIDTH) - 1 : 0];
        SLT  : out = ($signed(DECODE_OP1) < $signed(DECODE_OP2)) ? 1 : 0;
        SLTU : out = (DECODE_OP1 < DECODE_OP2) ? 1 : 0;
        XOR  : out = DECODE_OP1 ^ DECODE_OP2;
        OR   : out = DECODE_OP1 | DECODE_OP2;
        AND  : out = DECODE_OP1 & DECODE_OP2;

        EQ   : out = (DECODE_OP1 == DECODE_OP2) ? 1 : 0;
        NE   : out = (DECODE_OP1 != DECODE_OP2) ? 1 : 0;
        GE   : out = ($signed(DECODE_OP1) >= $signed(DECODE_OP2)) ? 1 : 0;
        GEU  : out = (DECODE_OP1 >= DECODE_OP2) ? 1 : 0;

        default: out = {DATA_WIDTH{1'b0}};

    endcase
end

assign OUT = out;
/**/


endmodule

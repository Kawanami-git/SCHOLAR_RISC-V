/*!
********************************************************************************
*  \file      CSR.sv
*  \module    CSR
*  \brief     SCHOLAR RISC-V core control/status registers file module
*
*  \author    Kawanami
*  \version   1.0
*  \date      01/06/2025
*
********************************************************************************
*  \details
* This module implements the SCHOLAR RISC-V Control and Status Register (CSR) file.
*
* It currently supports only the `mcycle` register, which counts the number of cycles
* since reset. According to the RISC-V specification, `mcycle` can be accessed through:
*   - Address 0xC00 → lower 32 bits (LSB)
*   - Address 0xC80 → upper 32 bits (MSB)
*
* For simplicity, this implementation only provides access to the lower 32 bits (`mcycle[31:0]`),
* and this value is returned through the `CSR_VAL` output regardless of the address used.
*
* The `mcycle` register is read-only: writes to it are ignored,
* and no write-enable logic is implemented.
********************************************************************************
*  \parameters

*    - DATA_WIDTH           : Width of data paths (in bits)
*
*  \inputs
*    - CLK                  : System clock
*    - RSTN                 : Active-low reset
*    - COMMIT_CSR_WADDR     : Write address
*    - COMMIT_CSR_DIN       : Input data
*    - COMMIT_CSR_DIN_VALID : Input data valid flag (1: valid, 0: not valid)
*    - DECODE_RADDR         : Read address
*
*  \outputs
*    - CSR_VAL              : Output data
*
*  \inouts
*    - None.
*
********************************************************************************
*  \versioning
*
*  Version   Date          Author          Description
*  -------   ----------    ------------    --------------------------------------
*  1.0       01/06/2025    Kawanami        Initial version of the module
*  1.1       [Date]        [Author]        [Description]
*  1.2       [Date]        [Author]        [Description]
*
********************************************************************************
*  \remarks
*  - This implementation currently supports only the mcycle CSR register.
*  - TODO: Extend the module to support additional RISC-V CSR registers such as `
*          mtvec`, `mstatus`, etc.
*  - TODO: Implement handling for 64-bit data in the future
*          (if required by the specification).
********************************************************************************
*/

`include "packages.sv"

module CSR
    import archi_pkg::*;
#(
    parameter DATA_WIDTH = 32
)
(
`ifdef DUT
    output wire [DATA_WIDTH - 1 : 0]     MCYCLE                 ,
`endif

    input  wire                          CLK                    ,
    input  wire                          RSTN                   ,

    /* verilator lint_off UNUSED */                                     // Disable Verilator warning `Signal is not used`
    input  wire [CSR_ADDR_WIDTH - 1 : 0] COMMIT_CSR_WADDR       ,
    input  wire [DATA_WIDTH     - 1 : 0] COMMIT_CSR_VAL         ,
    input  wire                          COMMIT_CSR_VALID       ,
    input  wire [CSR_ADDR_WIDTH - 1 : 0] DECODE_RADDR           ,
    /* verilator lint_on UNUSED */                                      // Re-enable Verilator warning `Signal is not used`
    output wire [DATA_WIDTH     - 1 : 0] CSR_VAL
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
// Machine state register

// Control registers

// Data registers
reg [63 : 0] mcycle_reg;    // mcycle register
/********************           ********************/


/******************** MACHINE STATE ********************/

/********************               ********************/

/******************** CONTROL ********************/

/********************         ********************/

/******************** DATA PATH ********************/

/*
* This block implements the `mcycle` CSR, which counts the number of clock cycles since reset.
*
* - The register is incremented on every rising edge of `CLK`.
* - On reset (`RSTN` low), it is initialized to 0.
*
* - The CSR is read-only and does not support write operations.
*   Since `mcycle` is the only CSR available in this module, the output `CSR_VAL`
*   always returns its lower bits (`mcycle[DATA_WIDTH-1:0]`), regardless of the address.
*
* - Reads are handled combinatorially and reflect the current value of the cycle counter.
*
* This register can be used for basic performance monitoring or instruction timing analysis.
*/
always_ff @(posedge CLK)
begin
    if(!RSTN)                                        mcycle_reg      <= {64{1'b0}};
    else                                             mcycle_reg      <= mcycle_reg + 1;
end

assign CSR_VAL    = mcycle_reg[DATA_WIDTH-1:0];
/**/


/*
* This block is active only when the design is under test (DUT).
* It forwards the control/status registers (CSRs) to Verilator for verification of the core's internal states.
*/
`ifdef DUT
assign MCYCLE  = mcycle_reg[DATA_WIDTH-1:0];
`endif
/**/

/********************           ********************/


endmodule

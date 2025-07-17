/*!
********************************************************************************
*  \file      packages.sv
*  \module    N/ASR
*  \brief     SCHOLAR RISC-V packages
*
*  \author    Kawanami
*  \version   1.0
*  \date      01/06/2025
*
********************************************************************************
*  \details
* This file defines various packages used throughout the SCHOLAR RISC-V project.
* Each package groups together local parameters that define signal widths, encoding values,
* and control constants used across the core modules.
********************************************************************************
*  \parameters
*    - None.
*
*  \inputs
*    - None.
*
*  \outputs
*    - None.
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
*  - This implementation complies with [reference or standard].
*  - TODO: [possible improvements or future features]
********************************************************************************
*/

`ifndef ARCHI_PKG
`define ARCHI_PKG

/* verilator lint_off DECLFILENAME */                   // Disable Verilator warning `Filename does not match PACKAGE name`
package archi_pkg;
/* verilator lint_on DECLFILENAME */                    // Re-enable Verilator warning `Filename does not match PACKAGE name`

    localparam BYTE_LENGTH     = 8;                     // Number of bits in a byte
    localparam INSTR_WIDTH     = 32;                    // Width of an instruction (in bits)
    localparam NB_GPR          = 32;                    // Number of general-purpose registers
    localparam CSR_ADDR_WIDTH  = 12;                    // Address width of Control and Status Registers (CSR)
    localparam RF_ADDR_WIDTH   = $clog2(NB_GPR);        // Address width of the general-purpose register file

    // Execution Unit (EXE) Control Signals
    localparam EXE_CTRL_WIDTH  = 4;                     // Width of EXE control signals
    localparam ADD             = 4'b0000;               // Addition operation
    localparam SUB             = 4'b0001;               // Subtraction operation
    localparam SLL             = 4'b0010;               // Logical shift left
    localparam SRL             = 4'b0011;               // Logical shift right
    localparam SRA             = 4'b0100;               // Arithmetic shift right
    localparam SLT             = 4'b0101;               // Set if less than (signed comparison)
    localparam SLTU            = 4'b0110;               // Set if less than (unsigned comparison)
    localparam XOR             = 4'b0111;               // Bitwise XOR
    localparam OR              = 4'b1000;               // Bitwise OR
    localparam AND             = 4'b1001;               // Bitwise AND
    localparam EQ              = 4'b1010;               // Equality comparison
    localparam NE              = 4'b1011;               // Not equal comparison
    localparam GE              = 4'b1100;               // Greater than or equal (signed comparison)
    localparam GEU             = 4'b1101;               // Greater than or equal (unsigned comparison)

    // Program Counter (PC) Control Signals
    localparam PC_CTRL_WIDTH   = 2;                     // Width of PC control signals
    localparam PC_INC          = 2'b00;                 // Increment PC (PC = PC + ADDR_OFFSET)
    localparam PC_SET          = 2'b01;                 // Set PC to EXE output (used in JALR)
    localparam PC_ADD          = 2'b10;                 // Compute PC as PC + EXE output (used in JAL)
    localparam PC_COND         = 2'b11;                 // Conditional branch (PC = PC + offset if condition met, else PC + ADDR_OFFSET)

    // Memory Control Signals (used in commit)
    localparam MEM_CTRL_WIDTH  = 5;                     // Width of memory control signals
    localparam MEM_IDLE        = 5'b00000;              // No memory operation (idle)
    localparam MEM_RD          = 2'b10;                 // Read from memory (load)
    localparam MEM_WR          = 2'b11;                 // Write to memory (store)
    localparam MEM_B           = 3'b000;                // Byte access
    localparam MEM_BU          = 3'b001;                // Byte access (unsigned load)
    localparam MEM_H           = 3'b010;                // Half-word (16-bit) access
    localparam MEM_HU          = 3'b011;                // Half-word access (unsigned load)
    localparam MEM_W           = 3'b100;                // Word (32-bit) access

    // General purpose register file Control Signals (used in commit)
    localparam GPR_CTRL_WIDTH   = 3;                    // Width of register file control signals
    localparam GPR_IDLE         = 3'b000;               // No register update (idle)
    localparam GPR_MEM          = 3'b100;               // commit from memory to register file (load instructions)
    localparam GPR_ALU          = 3'b101;               // commit from EXE output to register file (ALU operations)
    localparam GPR_PRGMC        = 3'b110;               // commit from PC to register file (JAL, JALR instructions)
    localparam GPR_OP2          = 3'b111;               // commit from RS2 operand to register file (used in CSR operations)

    // Control and Status Register (CSR) Control Signals (used in commit)
    localparam CSR_CTRL_WIDTH  = 1;                     // Width of CSR control signals
    localparam CSR_IDLE        = 1'b0;                  // No CSR update (idle)
    /* verilator lint_off UNUSED */                     // Disable verilator warning `Parameter is not used`
    localparam CSR_ALU         = 1'b1;                  // Writeback from EXE output to CSR (CSR instructions)
    /* verilator lint_on UNUSED */                      // Re-enable verilator warning `Parameter is not used`
endpackage


`endif

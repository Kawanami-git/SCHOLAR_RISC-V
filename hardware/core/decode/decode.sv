/*!
********************************************************************************
*  \file      decode.sv
*  \module    decode
*  \brief     SCHOLAR RISC-V core decode module
*
*  \author    Kawanami
*  \version   1.0
*  \date      01/06/2025
*
********************************************************************************
*  \details
* This module implements the decode unit of the SCHOLAR RISC-V processor core.
*
* The primary role of the decode unit is to interpret the binary instruction
* fetched during the previous unit and to extract all relevant fields needed
* for the execution and commit units.
*
* Specifically, the decoder:
* - Extracts the source register indices (RS1 and RS2) from the instruction,
*   and reads their current values from the general-purpose register file (GPRs)
* - Extracts the destination register index (RD)
* - Decodes and extands the immediate value, if applicable
* - Determines the operation type (e.g., arithmetic, load/store, branch, etc.)
* - Generates the control signals required for the execution unit,
*   memory access, and register write-back
*
* Based on the decoded instruction, this unit generates the appropriate
* control signals and forwards the operands to the execution (EXE) and commit units.
*
* This unit is essential in translating an instruction from its binary form
* into actionable signals that guide how the processor behaves in the
* subsequent units.
********************************************************************************
*  \parameters
*    - ADDR_WIDTH       : Number of bits for addressing
*    - DATA_WIDTH       : Width of data paths (in bits)
*
*  \inputs
*    - RSTN             : System active low reset (unused)
*    - FETCH_INSTR      : Instruction to decode
*    - FETCH_VALID      : Instruction valid flag (1: valid, 0: invalid)
*    - GPR_RS1_VAL      : General purpose register file RS1 value
*    - GPR_RS2_VAL      : General purpose register file RS2 value
*    - GPR_PC           : Program counter
*    - CSR_VAL          : Control/status register file output data
*
*  \outputs
*    - RS1              : General purpose register file port 0 read address (RS1)
*    - RS2              : General purpose register file port 1 read address (RS2)
*    - CSR_RADDR        : Control/status register file read address
*    - OP1              : RS1 value or zeroes
*    - OP2              : RS2 value (REG_OP or BRANCH_OP) or immediate
*    - EXE_CTRL         : EXE unit control
*    - OP3              : immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
*    - RD               : Destination register
*    - PC_CTRL          : Program counter control
*    - CSR_CTRL         : Control/status register file control
*    - GPR_CTRL         : General purpose register file control
*    - MEM_CTRL         : Memory control
*    - VALID            : valid flag (1: valid, 0: invalid)
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
*  - TODO: For memory control signal, remove the funct3 decoder and use the 
*          funct3 field directly (anyway, the control signal is decoded in the commit unit).
********************************************************************************
*/

`include "packages.sv"

module decode
    import archi_pkg::*;
#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)
(
    input  wire                           RSTN          ,
    input  wire  [INSTR_WIDTH    - 1 : 0] FETCH_INSTR   ,
    input  wire                           FETCH_VALID   ,

    input  wire  [DATA_WIDTH     - 1 : 0] GPR_RS1_VAL   ,
    input  wire  [DATA_WIDTH     - 1 : 0] GPR_RS2_VAL   ,
    input  wire  [ADDR_WIDTH     - 1 : 0] GPR_PC        ,
    output wire  [RF_ADDR_WIDTH  - 1 : 0] RS1           ,
    output wire  [RF_ADDR_WIDTH  - 1 : 0] RS2           ,

    input  wire  [DATA_WIDTH     - 1 : 0] CSR_VAL       ,
    output wire  [CSR_ADDR_WIDTH - 1 : 0] CSR_RADDR     ,

    output wire  [DATA_WIDTH     - 1 : 0] OP1           ,
    output wire  [DATA_WIDTH     - 1 : 0] OP2           ,
    output wire  [EXE_CTRL_WIDTH - 1 : 0] EXE_CTRL      ,

    output wire  [DATA_WIDTH     - 1 : 0] OP3           ,
    output wire  [RF_ADDR_WIDTH  - 1 : 0] RD            ,
    output wire  [PC_CTRL_WIDTH  - 1 : 0] PC_CTRL       ,
    output wire  [CSR_CTRL_WIDTH - 1 : 0] CSR_CTRL      ,
    output wire  [GPR_CTRL_WIDTH - 1 : 0] GPR_CTRL      ,
    output wire  [MEM_CTRL_WIDTH - 1 : 0] MEM_CTRL      ,

    output wire                           VALID
);



/******************** PARAMETERS VERIFICATION ********************/

/********************                         ********************/

/******************** LOCAL PARAMETERS ********************/
localparam OP_WIDTH      = 7;                   // Number of bits used for the RISC-V opcode field
localparam FUNCT7_WIDTH  = 1;                   // The RISC-V funct7 field is 7 bits wide, but only bit 5 (funct7[5]) is used in this design
localparam FUNCT3_WIDTH  = 3;                   // Number of bits used for the RISC-V funct3 field

localparam LOAD_OP       = 7'b0000011;          // Opcode for load instructions (e.g., LW)
localparam IMM_OP        = 7'b0010011;          // Opcode for ALU operations with immediate (I-type)
localparam AUIPC_OP      = 7'b0010111;          // Opcode for AUIPC instruction (Add Upper Immediate to GPR_PC)
localparam STORE_OP      = 7'b0100011;          // Opcode for store instructions (e.g., SW)
localparam REG_OP        = 7'b0110011;          // Opcode for register-register ALU operations (R-type)
localparam LUI_OP        = 7'b0110111;          // Opcode for LUI instruction (Load Upper Immediate)
localparam BRANCH_OP     = 7'b1100011;          // Opcode for branch instructions (e.g., BEQ, BNE)
localparam JALR_OP       = 7'b1100111;          // Opcode for JALR (Jump and Link Register, I-type)
localparam JAL_OP        = 7'b1101111;          // Opcode for JAL (Jump and Link, J-type)
localparam CSR_OP        = 7'b1110011;          // Opcode for CSR instructions (Control and Status Registers)

/********************                  ********************/

/******************** TYPES DEFINITION ********************/

/********************                  ********************/

/******************** WIRES ********************/
// Machine state wires

// Control wires
logic [OP_WIDTH       - 1 : 0] op;              // Instruction opcode field

logic [RF_ADDR_WIDTH  - 1 : 0] rs1;             // Read address for GPR port 0 (RS1)
logic [RF_ADDR_WIDTH  - 1 : 0] rs2;             // Read address for GPR port 1 (RS2)
logic [CSR_ADDR_WIDTH - 1 : 0] csr_raddr;       // Read address for CSR access
logic [FUNCT3_WIDTH   - 1 : 0] funct3;          // Instruction funct3 field (operation sub-type)
logic [FUNCT7_WIDTH   - 1 : 0] funct7;          // Instruction funct7[5] field (for R-type variants)

logic [EXE_CTRL_WIDTH - 1 : 0] exe_ctrl;        // ALU operation control signal (EXE unit)
logic [PC_CTRL_WIDTH  - 1 : 0] pc_ctrl;         // Program counter update control (commit unit)
logic [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl;        // Memory access control signal (commit unit)
logic [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl;        // Register write-back control signal (commit unit)

logic [DATA_WIDTH     - 1 : 0] op1;             // Value of source register RS1 or zero if unused
logic [DATA_WIDTH     - 1 : 0] op2;             // RS2 value (REG/BRANCH) or immediate (IMM/CSR)
logic [DATA_WIDTH     - 1 : 0] op3;             // Immediate (BRANCH/CSR) or RS2 (STORE) or zero if unused
logic [RF_ADDR_WIDTH  - 1 : 0] rd;              // Destination register address
/********************       ********************/



/******************** REGISTERS ********************/
// Machine state register

// Control registers

// Data registers

/********************           ********************/


/******************** MACHINE STATE ********************/

/********************               ********************/


/*
* Retreives OP code from the instruction.
*/
assign op = FETCH_INSTR[6:0];
/**/


/*
* This block performs the decoding of the fetched instruction by examining its opcode (`op`).
*
* Depending on the instruction type, various fields from the instruction word (`FETCH_INSTR`)
* are extracted and assigned to the appropriate control signals.
*
* - `funct3` is extracted for most instruction types, but is not meaningful for
*   AUIPC, LUI, and JAL, which do not require function-specific variants.
*
* - `funct7` is only used by R-type instructions (like ADD, SUB, etc.) to differentiate
*   between operations such as ADD and SUB. It is not relevant for STORE, BRANCH,
*   AUIPC, LUI, or JAL.
*
* - The register source 1 (`rs1`) is extracted for all instructions
*   that require a first source operand.
*
* - The register source 2 (`rs2`) is extracted for all instructions
*   that require a second source operand (e.g., R-type, STORE, BRANCH).
*
* - `csr_raddr` is extracted only for CSR instructions, as it provides the address
*   of the control and status register being accessed.
*
* - The destination register (`rd`) is set to zero for STORE and BRANCH instructions,
*   since they do not write to the register file. For other instruction types,
*   it is extracted from the appropriate instruction field.
*
* No instruction decoding error is handled in this unit; the `valid` signal is
* directly propagated from `FETCH_VALID`.
*/
always_comb begin : instr_decoder
    if(op != AUIPC_OP && op != LUI_OP && op != JAL_OP)                                      funct3      = FETCH_INSTR[14:12];
    else                                                                                    funct3      = {FUNCT3_WIDTH{1'b0}};

    if(op != STORE_OP && op != BRANCH_OP && op != AUIPC_OP && op != LUI_OP && op != JAL_OP) funct7      = FETCH_INSTR[30];
    else                                                                                    funct7      = {FUNCT7_WIDTH{1'b0}};

    if(op != AUIPC_OP && op != LUI_OP && op != JAL_OP)                                      rs1         = FETCH_INSTR[19:15];
    else                                                                                    rs1         = {RF_ADDR_WIDTH{1'b0}};

    if(op == REG_OP || op == BRANCH_OP || op == STORE_OP)                                   rs2         = FETCH_INSTR[24:20];
    else                                                                                    rs2         = {RF_ADDR_WIDTH{1'b0}};

    if(op == CSR_OP)                                                                        csr_raddr   = FETCH_INSTR[31:20];
    else                                                                                    csr_raddr   = {CSR_ADDR_WIDTH{1'b0}};

    if(op == STORE_OP || op == BRANCH_OP)                                                   rd          = {RF_ADDR_WIDTH{1'b0}};
    else                                                                                    rd          = FETCH_INSTR[11:7];
end

assign CSR_RADDR    = csr_raddr;
assign RS2          = rs2;
assign RS1          = rs1;
assign RD           = rd;
assign VALID        = FETCH_VALID;
/**/


/*
* This block sets the execution control signal (`exe_ctrl`) based on the instruction type (`op`)
* and function codes (`funct3`, `funct7[5]`).
*
* - For arithmetic/logical operations (REG_OP, IMM_OP), the ALU operation is selected
*   using `funct3`, and in some cases `funct7[5]` (e.g., to distinguish ADD/SUB or SRL/SRA).
*
* - For branch instructions (BRANCH_OP), `funct3` specifies the comparison type (e.g., BEQ, BNE, SLT).
*
* - For other instructions (LOAD, STORE, AUIPC, LUI, JAL, CSR), the default ALU operation is ADD.
*   This is functionally correct for AUIPC and address calculations, and harmless for CSR,
*   where the result is unused but required to maintain pipeline consistency.
*/
always_comb begin : exe_ctrl_gen
    if(op == REG_OP || op == IMM_OP) begin
        case(funct3)
                3'b000 : exe_ctrl = (op == REG_OP) && funct7 ? SUB : ADD;
                3'b001 : exe_ctrl = SLL;
                3'b010 : exe_ctrl = SLT;
                3'b011 : exe_ctrl = SLTU;
                3'b100 : exe_ctrl = XOR;
                3'b101 : exe_ctrl = funct7 ? SRA : SRL;
                3'b110 : exe_ctrl = OR;
                3'b111 : exe_ctrl = AND;
        endcase
    end else if(op == BRANCH_OP) begin
            case (funct3)
                3'b000 : exe_ctrl = EQ;
                3'b001 : exe_ctrl = NE;
                3'b100 : exe_ctrl = SLT;
                3'b101 : exe_ctrl = GE;
                3'b110 : exe_ctrl = SLTU;
                3'b111 : exe_ctrl = GEU;
                default: exe_ctrl = {EXE_CTRL_WIDTH{1'bx}};
            endcase
    end else exe_ctrl = ADD;
end

assign EXE_CTRL = exe_ctrl;
/**/

/*
* This block generates the program counter control signal (`pc_ctrl`)
* based on the instruction type (`op`).
*
* - JALR_OP     → The GPR_PC is set to the value in a register plus an immediate (used for returns and indirect jumps).
* - JAL_OP      → The GPR_PC is set to GPR_PC + immediate (unconditional jump).
* - BRANCH_OP   → The GPR_PC is updated conditionally based on a comparison result.
* - default     → The GPR_PC increments normally to GPR_PC + 4 (sequential execution).
*/
always_comb begin : pc_ctrl_gen
    case (op)
        JALR_OP      : pc_ctrl = PC_SET;
        JAL_OP       : pc_ctrl = PC_ADD;
        BRANCH_OP    : pc_ctrl = PC_COND;
        default      : pc_ctrl = PC_INC;
    endcase
end
assign PC_CTRL  = pc_ctrl;
/**/

/*
* This block generates the memory access control signal (`mem_ctrl`)
* based on the instruction type (`op`) and the `funct3` field, which encodes
* both access size (byte, halfword, word) and, for LOAD, whether the value is signed or unsigned.
*
* - For LOAD instructions (`LOAD_OP`), a read operation is triggered.
*   `funct3` defines the data width and sign-extension:
*     • 000 → Read byte (signed)
*     • 001 → Read halfword (signed)
*     • 100 → Read byte (unsigned)
*     • 101 → Read halfword (unsigned)
*     • default → Read word (32-bit)
*
* - For STORE instructions (`STORE_OP`), a write operation is triggered.
*   The width of the write is determined by `funct3`:
*     • 000 → Write byte
*     • 001 → Write halfword
*     • default → Write word (32-bit)
*
* - For all other instruction types, no memory operation is performed (`MEM_IDLE`).
*
* The final control signal is built by concatenating the access type (read/write/idle)
* with the access size (B, H, W, BU, HU).
*/
always_comb begin : mem_ctrl_gen
    if(!RSTN) begin
        mem_ctrl = MEM_IDLE;
    end else begin
        if(op == LOAD_OP) begin
            case(funct3)
                3'b000 : mem_ctrl = {MEM_RD,  MEM_B};
                3'b001 : mem_ctrl = {MEM_RD,  MEM_H};
                3'b100 : mem_ctrl = {MEM_RD,  MEM_BU};
                3'b101 : mem_ctrl = {MEM_RD,  MEM_HU};
                default: mem_ctrl = {MEM_RD,  MEM_W};
            endcase
        end else if(op == STORE_OP) begin
            case(funct3)
                3'b000 : mem_ctrl = {MEM_WR,  MEM_B};
                3'b001 : mem_ctrl = {MEM_WR,  MEM_H};
                default: mem_ctrl = {MEM_WR,  MEM_W};
            endcase
        end else mem_ctrl = MEM_IDLE;
    end
end

assign MEM_CTRL = mem_ctrl;
/**/

/*
* This block generates the destination register control signal (`gpr_ctrl`),
* which selects the value to be written back to the general-purpose register file (GPR),
* depending on the instruction type (`op`).
*
* The `gpr_ctrl` signal is used to drive a multiplexer at the commit unit:
*
* - LOAD_OP         → Write the value loaded from memory (RD_MEM)
* - IMM_OP,
*   AUIPC_OP,
*   REG_OP,
*   LUI_OP          → Write the result from the ALU (RD_ALU)
*                    (AUIPC uses ALU to compute GPR_PC + imm)
* - JAL_OP,
*   JALR_OP         → Write the return address (GPR_PC + 4) (RD_PC)
* - CSR_OP          → Write the content of source register RS2 (RD_RS2)
*                     which contain the mcycle register value
* - Others          → No register write-back (RD_IDLE)
*/
always_comb begin : gpr_ctrl_gen
    if(!RSTN) begin
        gpr_ctrl = GPR_IDLE;
    end else begin
        case (op)
            LOAD_OP                             : gpr_ctrl = GPR_MEM;
            IMM_OP, AUIPC_OP, REG_OP, LUI_OP    : gpr_ctrl = GPR_ALU;
            JALR_OP, JAL_OP                     : gpr_ctrl = GPR_PRGMC;
            CSR_OP                              : gpr_ctrl = GPR_OP2;
            default                             : gpr_ctrl = GPR_IDLE;
        endcase
    end
end
assign GPR_CTRL  = gpr_ctrl;
/**/

/*
* For the current version of this core, only mcycle is implemented in the CSR.
* The CSR automatically return the 32 LSb of the mcycle value. Thus, nothing to control.
*/
assign CSR_CTRL  = CSR_IDLE;
/**/



/*
* This block builds the operand values used in the execute and commit units,
* based on the instruction type (`op`) and immediate formats defined by RISC-V.
*
* The following signals are computed:
* - `op1` : first operand. Usually read from GPR[rs1], but may be GPR_PC (JALR) or zero (others).
* - `op2` : second operand or immediate. Depends on the instruction format:
*              - R-type / Branch : RS2 value
*              - I/U/J-type      : immediate value, sign-extended if needed
*              - LUI/AUIPC       : upper immediate (shifted)
* - `op3` : second operand (for STORE), branch offset (BRANCH), or CSR value.
*
* All immediate values are sign-extended to match `DATA_WIDTH`.
*/
always_comb begin : operands_gen
             if(op != LUI_OP && op != AUIPC_OP && op != JAL_OP)         op1 = GPR_RS1_VAL;
        else if(!op[5])                                                 op1 = GPR_PC;
        else                                                            op1 = {DATA_WIDTH{1'b0}};

             if(op == REG_OP  || op == BRANCH_OP)                       op2 = GPR_RS2_VAL;
        else if(op == STORE_OP)                                         op2 = {{DATA_WIDTH-12{FETCH_INSTR[31]}}, FETCH_INSTR[31:25], FETCH_INSTR[11:7]};
        else if(op == LUI_OP  || op == AUIPC_OP)                        op2 = FETCH_INSTR[31] == 1'b1 ? {FETCH_INSTR[31:12], {12{1'b0}}} : {FETCH_INSTR[31:12], {12{1'b0}}};
        else if(op == JAL_OP)                                           op2 = {{DATA_WIDTH-21{FETCH_INSTR[31]}}, FETCH_INSTR[31], FETCH_INSTR[19:12], FETCH_INSTR[20], FETCH_INSTR[30:21], 1'b0}; // J_TYPE
        else if(op == LOAD_OP || op == JALR_OP)                         op2 = {{DATA_WIDTH-12{FETCH_INSTR[31]}}, FETCH_INSTR[31:20]};
        else if(op == IMM_OP && (funct3 == 3'b001 || funct3 == 3'b101)) op2 = {{DATA_WIDTH-12{1'b0}}, FETCH_INSTR[31:20]};
        else                                                            op2 = {{DATA_WIDTH-12{FETCH_INSTR[31]}}, FETCH_INSTR[31:20]}; // IMM_OP signed

             if(op == STORE_OP)                                         op3 = GPR_RS2_VAL;
        else if(op == BRANCH_OP)                                        op3 = {{DATA_WIDTH-13{FETCH_INSTR[31]}}, FETCH_INSTR[31], FETCH_INSTR[7], FETCH_INSTR[30:25], FETCH_INSTR[11:8], 1'b0};
        else if(op == CSR_OP)                                           op3 = CSR_VAL;
        else                                                            op3 = {DATA_WIDTH{1'b0}};
end

assign OP1 = op1;
assign OP2 = op2;
assign OP3 = op3;
/**/

/********************           ********************/

endmodule

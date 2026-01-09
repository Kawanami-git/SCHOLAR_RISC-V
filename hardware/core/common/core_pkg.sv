// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       core_pkg.sv
\brief      Core-wide parameters and control encodings for SCHOLAR RISC-V
\author     Kawanami
\date       19/12/2025
\version    1.0

\details
  Centralizes architectural widths (XLEN/ADDR/DATA), register-file sizes,
  and all micro-op/control encodings used across the pipeline:
  - Execution unit opcodes (EXE_*),
  - Program Counter control (PC_*),
  - Memory access control (MEM_*),
  - GPR/CSR write-back control (GPR_*, CSR_*).

  XLEN-dependent constants are selected via the preprocessor macro `XLEN32`.

\remarks
  - Keep these encodings in sync with decode/execute/MEM/WB logic.
  - Changing bit widths or enumerations here impacts multiple stages
    (decode tables, forwarding/hazard logic, memory formatting, etc.).
  - TODO: add M/CSR extensions encodings when implemented.

\section core_pkg_version_history Version history
| Version | Date       | Author   | Description                              |
|:-------:|:----------:|:---------|:-----------------------------------------|
| 1.0     | 19/12/2025 | Kawanami | Initial version of the core package.     |
********************************************************************************
*/


package core_pkg;
  /// Number of bits in a byte
  localparam int BYTE_LENGTH = 8;
`ifdef XLEN64
  /// Number of bits for addressing
  localparam int ADDR_WIDTH = 64;
  /// Width of data paths (in bits)
  localparam int DATA_WIDTH = 64;
`else
  /// Number of bits for addressing
  localparam int ADDR_WIDTH = 32;
  /// Width of data paths (in bits)
  localparam int DATA_WIDTH = 32;
`endif
  /// Number of bits used for the RISC-V opcode field
  localparam int OP_WIDTH = 7;
  /// The RISC-V funct7 field is 7 bits wide,
  /// but only bit 5 (funct7[5]) is used in this design
  localparam int FUNCT7_WIDTH = 1;
  /// Number of bits used for the RISC-V funct3 field
  localparam int FUNCT3_WIDTH = 3;
  /// Opcode for load instructions (e.g., LW)
  localparam logic [OP_WIDTH - 1 : 0] LOAD_OP = 7'b0000011;
  /// Opcode for ALU operations with immediate (I-type)
  localparam logic [OP_WIDTH - 1 : 0] IMM_OP = 7'b0010011;
  /// Opcode for 32-bits operations with immediate on 64 bits architecture
  localparam logic [OP_WIDTH - 1 : 0] IMMW_OP = 7'b0011011;
  /// Opcode for 32-bits operations with registers on 64 bits architecture
  localparam logic [OP_WIDTH - 1 : 0] REGW_OP = 7'b0111011;
  /// Opcode for AUIPC instruction (Add Upper Immediate to pc)
  localparam logic [OP_WIDTH - 1 : 0] AUIPC_OP = 7'b0010111;
  /// Opcode for store instructions (e.g., SW)
  localparam logic [OP_WIDTH - 1 : 0] STORE_OP = 7'b0100011;
  /// Opcode for register-register ALU operations (R-type)
  localparam logic [OP_WIDTH - 1 : 0] REG_OP = 7'b0110011;
  /// Opcode for LUI instruction (Load Upper Immediate)
  localparam logic [OP_WIDTH - 1 : 0] LUI_OP = 7'b0110111;
  /// Opcode for branch instructions (e.g., BEQ, BNE)
  localparam logic [OP_WIDTH - 1 : 0] BRANCH_OP = 7'b1100011;
  /// Opcode for JALR (Jump and Link Register, I-type)
  localparam logic [OP_WIDTH - 1 : 0] JALR_OP = 7'b1100111;
  /// Opcode for JAL (Jump and Link, J-type)
  localparam logic [OP_WIDTH - 1 : 0] JAL_OP = 7'b1101111;
  /// Opcode for CSR instructions (Control and Status Registers)
  localparam logic [OP_WIDTH - 1 : 0] CSR_OP = 7'b1110011;
  /// Address granularity in bytes (e.g., 4 bytes for 32-bit, 8 for 64-bit)
  localparam int unsigned ADDR_OFFSET = DATA_WIDTH / BYTE_LENGTH;
  /// Number of bits needed to encode byte offset within a word
  localparam int unsigned ADDR_OFFSET_WIDTH = $clog2(ADDR_OFFSET);
  /// Instruction width (in bits, usually 32)
  localparam int INSTR_WIDTH = 32;
  /// Number of general-purpose registers
  localparam int NB_GPR = 32;
  /// Address width of the general-purpose register file
  localparam int RF_ADDR_WIDTH = $clog2(NB_GPR);
  /// Width of the CSR address field (in bits, usually 12)
  localparam int CSR_ADDR_WIDTH = 12;
  /* Execution unit control parameters */
  /// Width of the execution unit control signal
  localparam int EXE_CTRL_WIDTH = 5;
  /// Add operation code
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_ADD = 5'b00001;
  /// Sub operation code
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_SUB = 5'b00010;
  /// Shift Left Logical operation code
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_SLL = 5'b00011;
  /// Shift Right Logical operation code
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_SRL = 5'b00100;
  /// Shift Right Arithmetic operation code
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_SRA = 5'b00101;
  /// Set on Less Than operation code (signed)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_SLT = 5'b00110;
  /// Set on Less Than operation code (unsigned)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_SLTU = 5'b00111;
  /// Bitwise Xor operation code
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_XOR = 5'b01000;
  /// Bitwise Or operation code
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_OR = 5'b01001;
  /// Bitwise And operation code
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_AND = 5'b01010;
  /// Compare Equal operation code (branch condition)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_EQ = 5'b01011;
  /// Compare Not Equal operation code (branch condition)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_NE = 5'b01100;
  /// Greater or Equal operation code (signed compare)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_GE = 5'b01101;
  /// Greater or Equal Unsigned operation code (unsigned compare)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_GEU = 5'b01110;
  /// Add Word operation code (RV64 only)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_ADDW = 5'b10000;
  /// Sub Word operation code (RV64 only)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_SUBW = 5'b10001;
  /// Shift Left Logical Word operation code (RV64 only)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_SLLW = 5'b10010;
  /// Shift Right Logical Word operation code (RV64 only)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_SRLW = 5'b10011;
  /// Shift Right Arithmetic Word operation code (RV64 only)
  localparam logic [EXE_CTRL_WIDTH-1:0] EXE_SRAW = 5'b10100;
  /* Program counter control parameters */
  /// Width of the program counter control signal
  localparam int PC_CTRL_WIDTH = 2;
  /// PC increment (+4)
  localparam logic [PC_CTRL_WIDTH-1:0] PC_INC = 2'b00;
  /// PC set to ALU output (absolute jump)
  localparam logic [PC_CTRL_WIDTH-1:0] PC_SET = 2'b01;
  /// PC Add with ALU output (PC-relative)
  localparam logic [PC_CTRL_WIDTH-1:0] PC_ADD = 2'b10;
  /// Conditional PC update (based on branch condition)
  localparam logic [PC_CTRL_WIDTH-1:0] PC_COND = 2'b11;
  /* Memory control parameters */
  /// Width of the memory control signal
  localparam int MEM_CTRL_WIDTH = 4;
  /// Memory idle (no memory operation)
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_IDLE = 4'b0000;
  /// Load byte (sign-extended)
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_RB = 4'b0001;
  /// Load byte (zero-extended)
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_RBU = 4'b0010;
  /// Load half-word (sign-extended, 16 bits)
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_RH = 4'b0011;
  /// Load half-word (zero-extended, 16 bits)
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_RHU = 4'b0100;
  /// Load word (sign-extended, 32 bits)
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_RW = 4'b0101;
  /// Load word (zero-extended, 32 bits)
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_RWU = 4'b0110;
  /// Load double-word (64 bits)
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_RD = 4'b0111;
  /// Store byte
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_WB = 4'b1000;
  /// Store half-word
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_WH = 4'b1001;
  /// Store word (32 bits)
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_WW = 4'b1010;
  /// Store double-word (64 bits)
  localparam logic [MEM_CTRL_WIDTH-1:0] MEM_WD = 4'b1011;
  /* General Purpose Registers control parameters */
  /// Width of the GPR write-back control signal
  localparam int GPR_CTRL_WIDTH = 3;
  /// No update to GPR
  localparam logic [GPR_CTRL_WIDTH-1:0] GPR_IDLE = 3'b000;
  /// Write-back from memory output
  localparam logic [GPR_CTRL_WIDTH-1:0] GPR_MEM = 3'b100;
  /// Write-back from ALU output
  localparam logic [GPR_CTRL_WIDTH-1:0] GPR_ALU = 3'b101;
  /// Write-back from program counter (link reg)
  localparam logic [GPR_CTRL_WIDTH-1:0] GPR_PRGMC = 3'b110;
  /// Write-back from operand 3 (e.g., for CSR ops)
  localparam logic [GPR_CTRL_WIDTH-1:0] GPR_OP3 = 3'b111;
  /* Control & Status Registers control parameters */
  /// Width of the CSR control signal
  localparam int CSR_CTRL_WIDTH = 1;
  /// No update to CSR
  localparam logic [CSR_CTRL_WIDTH-1:0] CSR_IDLE = 1'b0;

endpackage



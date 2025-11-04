// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       decode.sv
\brief      SCHOLAR RISC-V core decode module
\author     Kawanami
\date       20/09/2025
\version    1.1

\details
  This module implements the decode unit
  of the SCHOLAR RISC-V processor core.

  The primary role of the decode unit is to interpret
  the binary instruction fetched by the previous unit
  and to extract all relevant fields needed
  for the execution and write-back units.

  Specifically, the decoder:
  - Extracts the source register indices (`rs1_o` and 'rs2_o`) from the instruction
    and reads their current values from the general-purpose register file (GPRs)
  - Extracts the destination register index ('rd_o')
  - Decodes and extends the immediate value, if applicable
  - Determines the operation type (e.g., arithmetic, load/store, branch, etc.)
  - Generates the control signals required for the execution unit,
    memory access, and register write-back

  Based on the decoded instruction,
  this unit generates the appropriate control signals
  and forwards the operands to the execution (exe) and write-back units.

  This unit is essential in translating an instruction from its binary form
  into actionable signals that guide how the processor behaves in the
  subsequent units.

\remarks
- This implementation complies with [reference or standard].
- TODO: [possible improvements or future features]

\section decode_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/07/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 20/09/2025 | Kawanami   | Remove packages.sv and provide useful metadata through parameters.<br>Add RV64 support.<br>Update the whole file for coding style compliance.<br>Update the whole file comments for doxygen support. |
********************************************************************************
*/

module decode #(
    /* Global parameters */
    /// Number of bits for addressing
    parameter int                          AddrWidth    = 32,
    /// Width of data paths (in bits)
    parameter int                          DataWidth    = 32,
    /// Instruction width (in bits, usually 32)
    parameter int                          InstrWidth   = 32,
    /// Width of the GPR index (in bits, usually 5 for 32 regs)
    parameter int                          RfAddrWidth  = 5,
    /// Width of the CSR address field (in bits, usually 12)
    parameter int                          CsrAddrWidth = 12,
    /* Exe control parameters */
    /// Width of the execution unit control signal
    parameter int                          ExeCtrlWidth = 5,
    /// Add operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Add          = 5'b00000,
    /// Sub operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Sub          = 5'b00001,
    /// Shift Left Logical operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Sll          = 5'b00010,
    /// Shift Right Logical operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Srl          = 5'b00011,
    /// Shift Right Arithmetic operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Sra          = 5'b00100,
    /// Set on Less Than operation code (signed)
    parameter logic [ExeCtrlWidth - 1 : 0] Slt          = 5'b00101,
    /// Set on Less Than operation code (unsigned)
    parameter logic [ExeCtrlWidth - 1 : 0] Sltu         = 5'b00110,
    /// Bitwise Xor operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Xor          = 5'b00111,
    /// Bitwise Or operation code
    parameter logic [ExeCtrlWidth - 1 : 0] Or           = 5'b01000,
    /// Bitwise And operation code
    parameter logic [ExeCtrlWidth - 1 : 0] And          = 5'b01001,
    /// Compare Equal operation code (branch condition)
    parameter logic [ExeCtrlWidth - 1 : 0] Eq           = 5'b01010,
    /// Compare Not Equal operation code (branch condition)
    parameter logic [ExeCtrlWidth - 1 : 0] Ne           = 5'b01011,
    /// Greater or Equal operation code (signed compare)
    parameter logic [ExeCtrlWidth - 1 : 0] Ge           = 5'b01100,
    /// Greater or Equal Unsigned operation code (unsigned compare)
    parameter logic [ExeCtrlWidth - 1 : 0] Geu          = 5'b01101,
    /* verilator lint_off UNUSEDPARAM */
    /// Add Word operation code (RV64 only)
    parameter logic [ExeCtrlWidth - 1 : 0] Addw         = 5'b10000,
    /// Sub Word operation code (RV64 only)
    parameter logic [ExeCtrlWidth - 1 : 0] Subw         = 5'b10001,
    /// Shift Left Logical Word operation code (RV64 only)
    parameter logic [ExeCtrlWidth - 1 : 0] Sllw         = 5'b10010,
    /// Shift Right Logical Word operation code (RV64 only)
    parameter logic [ExeCtrlWidth - 1 : 0] Srlw         = 5'b10011,
    /// Shift Right Arithmetic Word operation code (RV64 only)
    parameter logic [ExeCtrlWidth - 1 : 0] Sraw         = 5'b10100,
    /* verilator lint_on UNUSEDPARAM */
    /* Program counter control parameters */
    /// Width of the program counter control signal
    parameter int                          PcCtrlWidth  = 2,
    /// PC increment (+4)
    parameter logic [ PcCtrlWidth - 1 : 0] PcInc        = 2'b00,
    /// PC set to ALU output (absolute jump)
    parameter logic [ PcCtrlWidth - 1 : 0] PcSet        = 2'b01,
    /// PC Add with ALU output (PC-relative)
    parameter logic [ PcCtrlWidth - 1 : 0] PcAdd        = 2'b10,
    /// Conditional PC update (based on branch condition)
    parameter logic [ PcCtrlWidth - 1 : 0] PcCond       = 2'b11,
    /* Memory control parameters */
    /// Width of the memory control signal
    parameter int                          MemCtrlWidth = 5,
    /// Memory idle (no memory operation)
    parameter logic [MemCtrlWidth - 1 : 0] MemIdle      = 5'b00000,
    /// Load byte (sign-extended)
    parameter logic [MemCtrlWidth - 1 : 0] MemRb        = 5'b00001,
    /// Load byte (zero-extended)
    parameter logic [MemCtrlWidth - 1 : 0] MemRbu       = 5'b01001,
    /// Store byte
    parameter logic [MemCtrlWidth - 1 : 0] MemWb        = 5'b10001,
    /// Load half-word (sign-extended, 16 bits)
    parameter logic [MemCtrlWidth - 1 : 0] MemRh        = 5'b00010,
    /// Load half-word (zero-extended, 16 bits)
    parameter logic [MemCtrlWidth - 1 : 0] MemRhu       = 5'b01010,
    /// Store half-word
    parameter logic [MemCtrlWidth - 1 : 0] MemWh        = 5'b10010,
    /// Load word (sign-extended, 32 bits)
    parameter logic [MemCtrlWidth - 1 : 0] MemRw        = 5'b00011,
    /// Load word (zero-extended, 32 bits)
    parameter logic [MemCtrlWidth - 1 : 0] MemRwu       = 5'b01011,
    /// Store word (32 bits)
    parameter logic [MemCtrlWidth - 1 : 0] MemWw        = 5'b10011,
    /// Load double-word (64 bits)
    parameter logic [MemCtrlWidth - 1 : 0] MemRd        = 5'b00100,
    /// Store double-word (64 bits)
    parameter logic [MemCtrlWidth - 1 : 0] MemWd        = 5'b10100,
    /* General Purpose Registers control parameters */
    /// Width of the GPR write-back control signal
    parameter int                          GprCtrlWidth = 3,
    /// No update to GPR
    parameter logic [GprCtrlWidth - 1 : 0] GprIdle      = 3'b000,
    /// Write-back from memory output
    parameter logic [GprCtrlWidth - 1 : 0] GprMem       = 3'b100,
    /// Write-back from ALU output
    parameter logic [GprCtrlWidth - 1 : 0] GprAlu       = 3'b101,
    /// Write-back from program counter (link reg)
    parameter logic [GprCtrlWidth - 1 : 0] GprPrgmc     = 3'b110,
    /// Write-back from operand 3 (e.g., for CSR ops)
    parameter logic [GprCtrlWidth - 1 : 0] GprOp3       = 3'b111,
    /* Control & Status Registers control parameters */
    /// Width of the CSR control signal
    parameter int                          CsrCtrlWidth = 1,
    /// No update to CSR
    parameter logic [CsrCtrlWidth - 1 : 0] CsrIdle      = 1'b0
) (
    /// System active low reset
    input  wire                         rstn_i,
    /// valid flag (1: valid, 0: invalid)
    output wire                         valid_o,
    /// Instruction to decode
    input  wire [InstrWidth    - 1 : 0] instr_i,
    /// Instruction valid flag
    input  wire                         instr_valid_i,
    /// General purpose register file RS1 value
    input  wire [DataWidth     - 1 : 0] rs1_val_i,
    /// General purpose register file RS2 value
    input  wire [DataWidth     - 1 : 0] rs2_val_i,
    /// Program counter
    input  wire [AddrWidth     - 1 : 0] pc_i,
    /// General purpose register file port 0 read address
    output wire [ RfAddrWidth  - 1 : 0] rs1_o,
    /// General purpose register file port 1 read address
    output wire [ RfAddrWidth  - 1 : 0] rs2_o,
    /// Control/status register file output data
    input  wire [DataWidth     - 1 : 0] csr_val_i,
    /// Control/status register file read address
    output wire [ CsrAddrWidth - 1 : 0] csr_raddr_o,
    /// RS1 value or zeroes
    output wire [DataWidth     - 1 : 0] op1_o,
    /// RS2 value (REG_OP or BRANCH_OP) or immediate
    output wire [DataWidth     - 1 : 0] op2_o,
    /// Exe unit control
    output wire [ ExeCtrlWidth - 1 : 0] exe_ctrl_o,
    /// Immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
    output wire [DataWidth     - 1 : 0] op3_o,
    /// Destination register
    output wire [ RfAddrWidth  - 1 : 0] rd_o,
    /// Program counter control
    output wire [ PcCtrlWidth  - 1 : 0] pc_ctrl_o,
    /// Control/status register file control
    output wire [ CsrCtrlWidth - 1 : 0] csr_ctrl_o,
    /// General purpose register file control
    output wire [ GprCtrlWidth - 1 : 0] gpr_ctrl_o,
    /// Memory control
    output wire [ MemCtrlWidth - 1 : 0] mem_ctrl_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
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
  /// Opcode for AUIPC instruction (Add Upper Immediate to pc_i)
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

  /* functions */

  /* wires */


  /* registers */
  /// Instruction opcode field
  logic [OP_WIDTH       - 1 : 0] op;
  /// Read address for GPR port 0
  logic [  RfAddrWidth  - 1 : 0] rs1;
  /// Read address for GPR port 1
  logic [  RfAddrWidth  - 1 : 0] rs2;
  /// Read address for CSR access
  logic [  CsrAddrWidth - 1 : 0] csr_raddr;
  /// Instruction funct3 field (operation Sub-type)
  logic [FUNCT3_WIDTH   - 1 : 0] funct3;
  /// Instruction funct7[5] field (for R-type variants)
  logic [FUNCT7_WIDTH   - 1 : 0] funct7;
  /// ALU operation control signal (exe unit)
  logic [  ExeCtrlWidth - 1 : 0] exe_ctrl;
  /// Program counter update control (write-back unit)
  logic [  PcCtrlWidth  - 1 : 0] pc_ctrl;
  /// Memory access control signal (write-back unit)
  logic [  MemCtrlWidth - 1 : 0] mem_ctrl;
  /// Register write-back control signal (write-back unit)
  logic [  GprCtrlWidth - 1 : 0] gpr_ctrl;
  /// Value of source register RS1 or zero if unused
  logic [ DataWidth     - 1 : 0] op1;
  /// RS2 value (REG/BRANCH) or immediate (IMM/CSR)
  logic [ DataWidth     - 1 : 0] op2;
  /// Immediate (BRANCH/CSR) or RS2 (STORE) or zero if unused
  logic [ DataWidth     - 1 : 0] op3;
  /// Destination register address
  logic [  RfAddrWidth  - 1 : 0] rd;
  /********************             ********************/




  /// Retreives opcode from the instruction.
  assign op = instr_i[6:0];


  /// Instruction decoder
  /*!
  * This block performs the decoding of the fetched instruction
  * by examining its opcode (`op`).
  *
  * Depending on the instruction type, various fields
  * from the instruction word (`instr_i`) are extracted
  * and assigned to the appropriate control signals.
  *
  * - `funct3` is extracted for most instruction types,
  *   but is not meaningful for AUIPC, LUI, and JAL,
  *   which do not require function-specific variants.
  *
  * - `funct7` is only used by R-type instructions (like Add, Sub, etc.)
  *   to differentiate between operations such as Add and Sub.
  *   It is not relevant for STORE, BRANCH, AUIPC, LUI, or JAL.
  *
  * - The register source 1 (`rs1_o`) is extracted for all instructions
  *   that require a first source operand.
  *
  * - The register source 2 (`rs2_o`) is extracted for all instructions
  *   that require a second source operand (e.g., R-type, STORE, BRANCH).
  *
  * - `csr_raddr_o` is extracted only for CSR instructions,
  *    as it provides the address of the control and status
  *    register being accessed.
  *
  * - The destination register (`rd_o`) is set to zero
  *   for STORE and BRANCH instructions,
  *   since they do not write to the register file.
  *   For other instruction types,
  *   it is extracted from the appropriate instruction field.
  *
  * No instruction decoding error is handled in this unit;
  * the `valid_o` signal is directly propagated from `instr_valid_i`.
  */
  always_comb begin : instr_decoder
    funct3    = instr_i[14:12];
    funct7    = instr_i[30];
    rs1       = instr_i[19:15];
    rs2       = instr_i[24:20];
    csr_raddr = instr_i[31:20];
    rd        = instr_i[11:7];
    case (op)

      STORE_OP: begin
        funct7    = '0;
        csr_raddr = '0;
        rd        = '0;
      end

      IMM_OP, IMMW_OP: begin
        rs2       = '0;
        csr_raddr = '0;
      end

      LOAD_OP, JALR_OP, CSR_OP: begin
        funct7    = '0;
        rs2       = '0;
        csr_raddr = '0;
      end

      REG_OP, REGW_OP: begin
        csr_raddr = '0;
      end

      AUIPC_OP, LUI_OP: begin
        funct3    = '0;
        funct7    = '0;
        rs1       = '0;
        rs2       = '0;
        csr_raddr = '0;
      end

      BRANCH_OP: begin
        funct7    = '0;
        csr_raddr = '0;
      end

      JAL_OP: begin
        funct3    = '0;
        funct7    = '0;
        rs1       = '0;
        rs2       = '0;
        csr_raddr = '0;
      end

      default: begin
        funct3    = '0;
        funct7    = '0;
        rs1       = '0;
        rs2       = '0;
        csr_raddr = '0;
        rd        = '0;
      end
    endcase
  end

  /// Output driven by instr_decoder
  assign csr_raddr_o = csr_raddr;
  /// Output driven by instr_decoder
  assign rs2_o       = rs2;
  /// Output driven by instr_decoder
  assign rs1_o       = rs1;
  /// Output driven by instr_decoder
  assign rd_o        = rd;
  /// Output driven by instr_decoder
  assign valid_o     = instr_valid_i;



  /// Exe control signals generator
  /*!
  * This block sets the execution control signal (`exe_ctrl_o`)
  * based on the instruction type (`op`) and function codes (`funct3`, `funct7[5]`).
  *
  * - For arithmetic/logical operations (`REG_OP`, `IMM_OP`),
  *   the ALU operation is selected using `funct3` and in some cases,
  *  `funct7[5]` (e.g., to distinguish Add/Sub or Srl/Sra).
  *
  * - For branch instructions (`BRANCH_OP`),
  *   `funct3` specifies the comparison type (e.g., Beq, Bne, Slt).
  *
  * - For other instructions (LOAD, STORE, AUIPC, LUI, JAL, CSR, unsupported),
  *   the default ALU operation is Add.
  *   This is functionally correct for U-Type instructions
  *   and address calculations, and harmless for current CSR implementation
  *   or unsupported instructions where the result is unused
  *   but required to maintain data flow consistency.
  */
  generate
    if (DataWidth == 64) begin : gen_exe_ctrl_gen_64
      always_comb begin : exe_ctrl_gen
        if (op == REG_OP || op == IMM_OP) begin
          case (funct3)
            3'b000:  exe_ctrl = (op == REG_OP) && funct7 ? Sub : Add;
            3'b001:  exe_ctrl = Sll;
            3'b010:  exe_ctrl = Slt;
            3'b011:  exe_ctrl = Sltu;
            3'b100:  exe_ctrl = Xor;
            3'b101:  exe_ctrl = funct7 ? Sra : Srl;
            3'b110:  exe_ctrl = Or;
            3'b111:  exe_ctrl = And;
            default: exe_ctrl = Add;
          endcase
        end
        else if (op == REGW_OP || op == IMMW_OP) begin
          case (funct3)
            3'b000:  exe_ctrl = (op == REGW_OP) && funct7 ? Subw : Addw;
            3'b001:  exe_ctrl = Sllw;
            3'b101:  exe_ctrl = funct7 ? Sraw : Srlw;
            default: exe_ctrl = Addw;
          endcase
        end
        else if (op == BRANCH_OP) begin
          case (funct3)
            3'b000:  exe_ctrl = Eq;
            3'b001:  exe_ctrl = Ne;
            3'b100:  exe_ctrl = Slt;
            3'b101:  exe_ctrl = Ge;
            3'b110:  exe_ctrl = Sltu;
            3'b111:  exe_ctrl = Geu;
            default: exe_ctrl = 'x;
          endcase
        end
        else exe_ctrl = Add;
      end
    end
    else begin : gen_exe_ctrl_gen_32
      always_comb begin : exe_ctrl_gen
        if (op == REG_OP || op == IMM_OP) begin
          case (funct3)
            3'b000:  exe_ctrl = (op == REG_OP) && funct7 ? Sub : Add;
            3'b001:  exe_ctrl = Sll;
            3'b010:  exe_ctrl = Slt;
            3'b011:  exe_ctrl = Sltu;
            3'b100:  exe_ctrl = Xor;
            3'b101:  exe_ctrl = funct7 ? Sra : Srl;
            3'b110:  exe_ctrl = Or;
            3'b111:  exe_ctrl = And;
            default: exe_ctrl = Add;
          endcase
        end
        else if (op == BRANCH_OP) begin
          case (funct3)
            3'b000:  exe_ctrl = Eq;
            3'b001:  exe_ctrl = Ne;
            3'b100:  exe_ctrl = Slt;
            3'b101:  exe_ctrl = Ge;
            3'b110:  exe_ctrl = Sltu;
            3'b111:  exe_ctrl = Geu;
            default: exe_ctrl = 'x;
          endcase
        end
        else exe_ctrl = Add;
      end
    end
  endgenerate

  /// Output driven by exe_ctrl_gen
  assign exe_ctrl_o = exe_ctrl;


  /// PC control signals generator
  /*!
  * This block generates the program counter control signal (`pc_ctrl_o`)
  * based on the instruction type (`op`).
  *
  * - JALR_OP     → The `pc_i` is set to the value in a register
  *                 plus an immediate (used for returns and indirect jumps).
  * - JAL_OP      → The `pc_i` is set to `pc_i` + immediate (unconditional jump).
  * - BRANCH_OP   → The `pc_i` is updated conditionally based on a comparison result.
  * - default     → The `pc_i` increments normally to `pc_i` + 4 (sequential execution).
  *                 Using PC = PC + 4 as default allows to prevent unsupported instruction
  *                 to realize an invalid jump and to skip them.
  */
  always_comb begin : pc_ctrl_gen
    case (op)
      JALR_OP:   pc_ctrl = PcSet;
      JAL_OP:    pc_ctrl = PcAdd;
      BRANCH_OP: pc_ctrl = PcCond;
      default:   pc_ctrl = PcInc;
    endcase
  end

  /// Output driven by pc_ctrl_gen
  assign pc_ctrl_o = pc_ctrl;


  /// Memory control signals generator
  /*!
  * This block generates the memory access control signal (`mem_ctrl_o`)
  * based on the instruction type (`op`) and the `funct3` field,
  * which encodes both access size (byte, halfword, word, double word) and,
  * for LOAD, whether the value is signed or unsigned.
  *
  * - For LOAD instructions (`LOAD_OP`), a read operation is triggered.
  *   `funct3` defines the data width and sign-extension:
  *     • 000 → Read byte (signed)
  *     • 001 → Read halfword (signed)
  *     • 010 → Read word (signed - RV64I only)
  *     • 100 → Read byte (unsigned)
  *     • 101 → Read halfword (unsigned)
  *     • 110 → Read word (unsigned - RV64I only)
  *     • default → Read word (32-bit) or read double word (64-bit)
  *
  * - For STORE instructions (`STORE_OP`), a write operation is triggered.
  *   The width of the write is determined by `funct3`:
  *     • 000 → Write byte
  *     • 001 → Write halfword
  *     • 010 → Write word (signed - RV64I only)
  *     • default → Write word (32-bit) or write double word (64-bit)
  *
  * - For all other instruction types,
  *   no memory operation is performed (`MemIdle`).
  *   This also prevents unsupported instructions to write into memory.
  */
  generate
    if (DataWidth == 32) begin : gen_mem_ctrl_32
      always_comb begin : mem_ctrl_gen
        if (!rstn_i) begin
          mem_ctrl = MemIdle;
        end
        else begin
          if (op == LOAD_OP) begin
            case (funct3)
              3'b000:  mem_ctrl = MemRb;
              3'b001:  mem_ctrl = MemRh;
              3'b100:  mem_ctrl = MemRbu;
              3'b101:  mem_ctrl = MemRhu;
              default: mem_ctrl = MemRw;
            endcase
          end
          else if (op == STORE_OP) begin
            case (funct3)
              3'b000:  mem_ctrl = MemWb;
              3'b001:  mem_ctrl = MemWh;
              default: mem_ctrl = MemWw;
            endcase
          end
          else mem_ctrl = MemIdle;
        end
      end

    end
    else begin : gen_mem_ctrl_64

      always_comb begin : mem_ctrl_gen
        if (!rstn_i) begin
          mem_ctrl = MemIdle;
        end
        else begin
          if (op == LOAD_OP) begin
            case (funct3)
              3'b000:  mem_ctrl = MemRb;
              3'b001:  mem_ctrl = MemRh;
              3'b010:  mem_ctrl = MemRw;
              3'b100:  mem_ctrl = MemRbu;
              3'b101:  mem_ctrl = MemRhu;
              3'b110:  mem_ctrl = MemRwu;
              default: mem_ctrl = MemRd;
            endcase
          end
          else if (op == STORE_OP) begin
            case (funct3)
              3'b000:  mem_ctrl = MemWb;
              3'b001:  mem_ctrl = MemWh;
              3'b010:  mem_ctrl = MemWw;
              default: mem_ctrl = MemWd;
            endcase
          end
          else mem_ctrl = MemIdle;
        end
      end

    end

  endgenerate

  /// Output driven by mem_ctrl_gen
  assign mem_ctrl_o = mem_ctrl;


  /// GPR control signals generator
  /*!
  * This block generates the destination register control signal (`gpr_ctrl_o`),
  * which selects the value to be written back
  * to the general-purpose register file (GPR),
  * depending on the instruction type (`op`).
  *
  * The `gpr_ctrl_o` signal is used to drive a multiplexer at the write-back unit:
  *
  * - `LOAD_OP`         → Write the value loaded from memory (`GprMem`)
  * - `IMM_OP`,
  *   `IMMW_OP`,
  *   `AUIPC_OP`,
  *   `REG_OP`,
  *   `REGW_OP`,
  *   `LUI_OP`          → Write the result from the ALU (`GprAlu`)
  *                      (AUIPC uses ALU to compute `pc_i` + imm)
  * - `JAL_OP`,
  *   `JALR_OP`         → Write the return address (`pc_i` + 4) (`GprPrgmc`)
  * - `CSR_OP`          → Write the content of source register op3_o (`GprOp3`)
  *                       which contain the mcycle register value
  * - Others            → No register write-back (`RD_IDLE`).
  *                       This also prevent unsupported instructions to write
  *                       into the GPRs.
  */
  always_comb begin : gpr_ctrl_gen
    if (!rstn_i) begin
      gpr_ctrl = GprIdle;
    end
    else begin
      case (op)
        LOAD_OP:                                            gpr_ctrl = GprMem;
        IMM_OP, IMMW_OP, REGW_OP, AUIPC_OP, REG_OP, LUI_OP: gpr_ctrl = GprAlu;
        JALR_OP, JAL_OP:                                    gpr_ctrl = GprPrgmc;
        CSR_OP:                                             gpr_ctrl = GprOp3;

        default: gpr_ctrl = GprIdle;
      endcase
    end
  end

  /// Output driven by gpr_ctrl_gen
  assign gpr_ctrl_o = gpr_ctrl;


  /// CSR control signals generator
  /*!
  * For the current version of this core,
  * only mcycle is implemented in the CSR.
  * The CSR automatically returns the 32 LSb of the mcycle value.
  * Thus, nothing to control.
  */
  assign csr_ctrl_o = CsrIdle;


  /// Operands generator
  /*!
  * This block builds the operand values used in the execute and write-back units,
  * based on the instruction type (`op`)
  * and immediate formats defined by RISC-V.
  *
  * The following signals are computed:
  * - `op1_o` : first operand. Usually read from GPR[rs1_o],
  *             but may be `pc_i` (JALR) or zero (others).
  *
  * - `op2_o` : second operand or immediate.
  *             Depends on the instruction format:
  *              - R-type / Branch : `rs2_o` value
  *              - I/U/J-type      : immediate value, sign-extended if needed
  *              - LUI/AUIPC       : upper immediate (shifted)
  *
  * - `op3_o` : second operand (for STORE),
  *             branch offset (BRANCH), or CSR value.
  *
  * All immediate values are sign-extended to match `DataWidth`.
  */
  always_comb begin : operands_gen
    op1 = rs1_val_i;
    op2 = rs2_val_i;
    op3 = '0;
    case (op)

      LOAD_OP: begin
        op2 = {{DataWidth - 12{instr_i[31]}}, instr_i[31:20]};
      end

      STORE_OP: begin
        op2 = {{DataWidth - 12{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
        op3 = rs2_val_i;
      end

      IMM_OP, IMMW_OP: begin
        if (funct3 == 3'b001 || funct3 == 3'b101) op2 = {{DataWidth - 12{1'b0}}, instr_i[31:20]};
        else op2 = {{DataWidth - 12{instr_i[31]}}, instr_i[31:20]};
      end

      REG_OP, REGW_OP: begin
      end

      AUIPC_OP: begin
        op1 = pc_i;
        op2 = instr_i[31] == 1'b1 ? {{DataWidth - 32{1'b1}}, instr_i[31:12], {12{1'b0}}} :
            {{DataWidth - 32{1'b0}}, instr_i[31:12], {12{1'b0}}};
      end

      LUI_OP: begin
        op1 = '0;
        op2 = instr_i[31] == 1'b1 ? {{DataWidth - 32{1'b1}}, instr_i[31:12], {12{1'b0}}} :
            {{DataWidth - 32{1'b0}}, instr_i[31:12], {12{1'b0}}};
      end

      BRANCH_OP: begin
        op3 = {
          {DataWidth - 13{instr_i[31]}},
          instr_i[31],
          instr_i[7],
          instr_i[30:25],
          instr_i[11:8],
          1'b0
        };
      end

      JALR_OP: begin
        op2 = {{DataWidth - 12{instr_i[31]}}, instr_i[31:20]};
      end

      JAL_OP: begin
        op1 = '0;
        op2 = {
          {DataWidth - 21{instr_i[31]}},
          instr_i[31],
          instr_i[19:12],
          instr_i[20],
          instr_i[30:21],
          1'b0
        };
      end

      CSR_OP: begin
        op2 = {{DataWidth - 12{instr_i[31]}}, instr_i[31:20]};
        op3 = csr_val_i;
      end

      default: begin
        op1 = '0;
        op2 = '0;
        op3 = '0;
      end
    endcase
  end

  /// Output driven by operands_gen
  assign op1_o = op1;
  /// Output driven by operands_gen
  assign op2_o = op2;
  /// Output driven by operands_gen
  assign op3_o = op3;

endmodule

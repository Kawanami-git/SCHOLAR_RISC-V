// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       decode.sv
\brief      SCHOLAR RISC-V core decode module
\author     Kawanami
\date       01/05/2026
\version    1.4

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
| 1.1     | 20/09/2025 | Kawanami   | Remove packages.sv and provide useful metadata through parameters.<br>EXE_ADD RV64 support.<br>Update the whole file for coding style compliance.<br>Update the whole file comments for doxygen support. |
| 1.2     | 28/03/2026 | Kawanami   | Seperate SYS_OP from LOAD and JALR which prevents to detect a CSR operation (spike compatibility). |
| 1.3     | 29/03/2026 | Kawanami   | Improve global lisibility by using package instead of parameters. |
| 1.5     | 01/05/2026 | Kawanami   | Refactor CSR signals name. |
********************************************************************************
*/

module decode

  import core_pkg::INSTR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::OP_WIDTH;
  import core_pkg::FUNCT3_WIDTH;
  import core_pkg::FUNCT7_WIDTH;
  import core_pkg::LOAD_OP;
  import core_pkg::IMM_OP;
  import core_pkg::IMMW_OP;
  import core_pkg::REGW_OP;
  import core_pkg::AUIPC_OP;
  import core_pkg::STORE_OP;
  import core_pkg::REG_OP;
  import core_pkg::LUI_OP;
  import core_pkg::BRANCH_OP;
  import core_pkg::JALR_OP;
  import core_pkg::JAL_OP;
  import core_pkg::SYS_OP;
  import core_pkg::EXE_CTRL_WIDTH;
  import core_pkg::EXE_ADD;
  import core_pkg::EXE_SUB;
  import core_pkg::EXE_SLL;
  import core_pkg::EXE_SRL;
  import core_pkg::EXE_SRA;
  import core_pkg::EXE_SLT;
  import core_pkg::EXE_SLTU;
  import core_pkg::EXE_XOR;
  import core_pkg::EXE_OR;
  import core_pkg::EXE_AND;
  import core_pkg::EXE_EQ;
  import core_pkg::EXE_NE;
  import core_pkg::EXE_GE;
  import core_pkg::EXE_GEU;
  import core_pkg::EXE_ADDW;
  import core_pkg::EXE_SUBW;
  import core_pkg::EXE_SLLW;
  import core_pkg::EXE_SRLW;
  import core_pkg::EXE_SRAW;
  import core_pkg::PC_CTRL_WIDTH;
  import core_pkg::PC_INC;
  import core_pkg::PC_SET;
  import core_pkg::PC_ADD;
  import core_pkg::PC_COND;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::MEM_IDLE;
  import core_pkg::MEM_RB;
  import core_pkg::MEM_RBU;
  import core_pkg::MEM_WB;
  import core_pkg::MEM_RH;
  import core_pkg::MEM_RHU;
  import core_pkg::MEM_WH;
  import core_pkg::MEM_RW;
  import core_pkg::MEM_RWU;
  import core_pkg::MEM_WW;
  import core_pkg::MEM_RD;
  import core_pkg::MEM_WD;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::GPR_IDLE;
  import core_pkg::GPR_MEM;
  import core_pkg::GPR_ALU;
  import core_pkg::GPR_PRGMC;
  import core_pkg::GPR_OP3;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::CSR_IDLE;
  import core_pkg::CSR_ALU;


#(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
) (
    /// System active low reset
    input  wire                          rstn_i,
    /// valid flag (1: valid, 0: invalid)
    output wire                          valid_o,
    /// Instruction to decode
    input  wire [INSTR_WIDTH    - 1 : 0] instr_i,
    /// Instruction valid flag
    input  wire                          instr_valid_i,
    /// General purpose register file RS1 value
    input  wire [     Archi     - 1 : 0] rs1_val_i,
    /// General purpose register file RS2 value
    input  wire [     Archi     - 1 : 0] rs2_val_i,
    /// Program counter
    input  wire [     Archi     - 1 : 0] pc_i,
    /// General purpose register file port 0 read address
    output wire [RF_ADDR_WIDTH  - 1 : 0] rs1_o,
    /// General purpose register file port 1 read address
    output wire [RF_ADDR_WIDTH  - 1 : 0] rs2_o,
    /// Control/status register file output data
    input  wire [     Archi     - 1 : 0] csr_rdata_i,
    /// Control/status register file read address
    output wire [CSR_ADDR_WIDTH - 1 : 0] csr_raddr_o,
    /// RS1 value or zeroes
    output wire [     Archi     - 1 : 0] op1_o,
    /// RS2 value (REG_OP or BRANCH_OP) or immediate
    output wire [     Archi     - 1 : 0] op2_o,
    /// Exe unit control
    output wire [EXE_CTRL_WIDTH - 1 : 0] exe_ctrl_o,
    /// Immediate (BRANCH_OP or SYS_OP) or RS2 value (STORE_OP) or zeroes
    output wire [     Archi     - 1 : 0] op3_o,
    /// Destination register
    output wire [RF_ADDR_WIDTH  - 1 : 0] rd_o,
    /// Program counter control
    output wire [PC_CTRL_WIDTH  - 1 : 0] pc_ctrl_o,
    /// Control/status register file control
    output wire [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl_o,
    /// General purpose register file control
    output wire [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl_o,
    /// Memory control
    output wire [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */


  /* registers */
  /// Instruction opcode field
  logic [OP_WIDTH       - 1 : 0] op;
  /// Read address for GPR port 0
  logic [RF_ADDR_WIDTH  - 1 : 0] rs1;
  /// Read address for GPR port 1
  logic [RF_ADDR_WIDTH  - 1 : 0] rs2;
  /// Read address for CSR access
  logic [CSR_ADDR_WIDTH - 1 : 0] csr_raddr;
  /// Instruction funct3 field (operation EXE_SUB-type)
  logic [FUNCT3_WIDTH   - 1 : 0] funct3;
  /// Instruction funct7[5] field (for R-type variants)
  logic [FUNCT7_WIDTH   - 1 : 0] funct7;
  /// ALU operation control signal (exe unit)
  logic [EXE_CTRL_WIDTH - 1 : 0] exe_ctrl;
  /// Program counter update control (write-back unit)
  logic [PC_CTRL_WIDTH  - 1 : 0] pc_ctrl;
  /// Memory access control signal (write-back unit)
  logic [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl;
  /// Register write-back control signal (write-back unit)
  logic [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl;
  /// Value of source register RS1 or zero if unused
  logic [     Archi     - 1 : 0] op1;
  /// RS2 value (REG/BRANCH) or immediate (IMM/CSR)
  logic [     Archi     - 1 : 0] op2;
  /// Immediate (BRANCH/CSR) or RS2 (STORE) or zero if unused
  logic [     Archi     - 1 : 0] op3;
  /// Destination register address
  logic [RF_ADDR_WIDTH  - 1 : 0] rd;
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
  * - `funct7` is only used by R-type instructions (like EXE_ADD, EXE_SUB, etc.)
  *   to differentiate between operations such as EXE_ADD and EXE_SUB.
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

      LOAD_OP, JALR_OP: begin
        funct7    = '0;
        rs2       = '0;
        csr_raddr = '0;
      end

      SYS_OP: begin
        funct7 = '0;
        rs2    = '0;
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
  *  `funct7[5]` (e.g., to distinguish EXE_ADD/EXE_SUB or EXE_SRL/EXE_SRA).
  *
  * - For branch instructions (`BRANCH_OP`),
  *   `funct3` specifies the comparison type (e.g., Beq, Bne, EXE_SLT).
  *
  * - For other instructions (LOAD, STORE, AUIPC, LUI, JAL, CSR, unsupported),
  *   the default ALU operation is EXE_ADD.
  *   This is functionally correct for U-Type instructions
  *   and address calculations, and harmless for current CSR implementation
  *   or unsupported instructions where the result is unused
  *   but required to maintain data flow consistency.
  */
  generate
    if (Archi == 64) begin : gen_exe_ctrl_gen_64
      always_comb begin : exe_ctrl_gen
        if (op == REG_OP || op == IMM_OP) begin
          case (funct3)
            3'b000:  exe_ctrl = (op == REG_OP) && funct7 ? EXE_SUB : EXE_ADD;
            3'b001:  exe_ctrl = EXE_SLL;
            3'b010:  exe_ctrl = EXE_SLT;
            3'b011:  exe_ctrl = EXE_SLTU;
            3'b100:  exe_ctrl = EXE_XOR;
            3'b101:  exe_ctrl = funct7 ? EXE_SRA : EXE_SRL;
            3'b110:  exe_ctrl = EXE_OR;
            3'b111:  exe_ctrl = EXE_AND;
            default: exe_ctrl = EXE_ADD;
          endcase
        end
        else if (op == REGW_OP || op == IMMW_OP) begin
          case (funct3)
            3'b000:  exe_ctrl = (op == REGW_OP) && funct7 ? EXE_SUBW : EXE_ADDW;
            3'b001:  exe_ctrl = EXE_SLLW;
            3'b101:  exe_ctrl = funct7 ? EXE_SRAW : EXE_SRLW;
            default: exe_ctrl = EXE_ADDW;
          endcase
        end
        else if (op == BRANCH_OP) begin
          case (funct3)
            3'b000:  exe_ctrl = EXE_EQ;
            3'b001:  exe_ctrl = EXE_NE;
            3'b100:  exe_ctrl = EXE_SLT;
            3'b101:  exe_ctrl = EXE_GE;
            3'b110:  exe_ctrl = EXE_SLTU;
            3'b111:  exe_ctrl = EXE_GEU;
            default: exe_ctrl = 'x;
          endcase
        end
        else exe_ctrl = EXE_ADD;
      end
    end
    else begin : gen_exe_ctrl_gen_32
      always_comb begin : exe_ctrl_gen
        if (op == REG_OP || op == IMM_OP) begin
          case (funct3)
            3'b000:  exe_ctrl = (op == REG_OP) && funct7 ? EXE_SUB : EXE_ADD;
            3'b001:  exe_ctrl = EXE_SLL;
            3'b010:  exe_ctrl = EXE_SLT;
            3'b011:  exe_ctrl = EXE_SLTU;
            3'b100:  exe_ctrl = EXE_XOR;
            3'b101:  exe_ctrl = funct7 ? EXE_SRA : EXE_SRL;
            3'b110:  exe_ctrl = EXE_OR;
            3'b111:  exe_ctrl = EXE_AND;
            default: exe_ctrl = EXE_ADD;
          endcase
        end
        else if (op == BRANCH_OP) begin
          case (funct3)
            3'b000:  exe_ctrl = EXE_EQ;
            3'b001:  exe_ctrl = EXE_NE;
            3'b100:  exe_ctrl = EXE_SLT;
            3'b101:  exe_ctrl = EXE_GE;
            3'b110:  exe_ctrl = EXE_SLTU;
            3'b111:  exe_ctrl = EXE_GEU;
            default: exe_ctrl = 'x;
          endcase
        end
        else exe_ctrl = EXE_ADD;
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
      JALR_OP:   pc_ctrl = PC_SET;
      JAL_OP:    pc_ctrl = PC_ADD;
      BRANCH_OP: pc_ctrl = PC_COND;
      default:   pc_ctrl = PC_INC;
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
  *   no memory operation is performed (`MEM_IDLE`).
  *   This also prevents unsupported instructions to write into memory.
  */
  generate
    if (Archi == 32) begin : gen_mem_ctrl_32
      always_comb begin : mem_ctrl_gen
        if (!rstn_i) begin
          mem_ctrl = MEM_IDLE;
        end
        else begin
          if (op == LOAD_OP) begin
            case (funct3)
              3'b000:  mem_ctrl = MEM_RB;
              3'b001:  mem_ctrl = MEM_RH;
              3'b100:  mem_ctrl = MEM_RBU;
              3'b101:  mem_ctrl = MEM_RHU;
              default: mem_ctrl = MEM_RW;
            endcase
          end
          else if (op == STORE_OP) begin
            case (funct3)
              3'b000:  mem_ctrl = MEM_WB;
              3'b001:  mem_ctrl = MEM_WH;
              default: mem_ctrl = MEM_WW;
            endcase
          end
          else mem_ctrl = MEM_IDLE;
        end
      end

    end
    else begin : gen_mem_ctrl_64

      always_comb begin : mem_ctrl_gen
        if (!rstn_i) begin
          mem_ctrl = MEM_IDLE;
        end
        else begin
          if (op == LOAD_OP) begin
            case (funct3)
              3'b000:  mem_ctrl = MEM_RB;
              3'b001:  mem_ctrl = MEM_RH;
              3'b010:  mem_ctrl = MEM_RW;
              3'b100:  mem_ctrl = MEM_RBU;
              3'b101:  mem_ctrl = MEM_RHU;
              3'b110:  mem_ctrl = MEM_RWU;
              default: mem_ctrl = MEM_RD;
            endcase
          end
          else if (op == STORE_OP) begin
            case (funct3)
              3'b000:  mem_ctrl = MEM_WB;
              3'b001:  mem_ctrl = MEM_WH;
              3'b010:  mem_ctrl = MEM_WW;
              default: mem_ctrl = MEM_WD;
            endcase
          end
          else mem_ctrl = MEM_IDLE;
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
  * - `LOAD_OP`         → Write the value loaded from memory (`GPR_MEM`)
  * - `IMM_OP`,
  *   `IMMW_OP`,
  *   `AUIPC_OP`,
  *   `REG_OP`,
  *   `REGW_OP`,
  *   `LUI_OP`          → Write the result from the ALU (`GPR_ALU`)
  *                      (AUIPC uses ALU to compute `pc_i` + imm)
  * - `JAL_OP`,
  *   `JALR_OP`         → Write the return address (`pc_i` + 4) (`GPR_PRGMC`)
  * - `SYS_OP`          → Write the content of source register op3_o (`GPR_OP3`)
  *                       which contain the mcycle register value
  * - Others            → No register write-back (`RD_IDLE`).
  *                       This also prevent unsupported instructions to write
  *                       into the GPRs.
  */
  always_comb begin : gpr_ctrl_gen
    if (!rstn_i) begin
      gpr_ctrl = GPR_IDLE;
    end
    else begin
      case (op)
        LOAD_OP:                                            gpr_ctrl = GPR_MEM;
        IMM_OP, IMMW_OP, REGW_OP, AUIPC_OP, REG_OP, LUI_OP: gpr_ctrl = GPR_ALU;
        JALR_OP, JAL_OP:                                    gpr_ctrl = GPR_PRGMC;
        SYS_OP:                                             gpr_ctrl = GPR_OP3;

        default: gpr_ctrl = GPR_IDLE;
      endcase
    end
  end

  /// Output driven by gpr_ctrl_gen
  assign gpr_ctrl_o = gpr_ctrl;


  /// CSR control signals generator
  /*!
  * For the current version of this core,
  * only mcycle is implemented in the CSR.
  * This CSR is read-only.
  * Thus, nothing to control.
  */
  assign csr_ctrl_o = CSR_IDLE;


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
  * All immediate values are sign-extended to match `Archi`.
  */
  always_comb begin : operands_gen
    op1 = rs1_val_i;
    op2 = rs2_val_i;
    op3 = '0;
    case (op)

      LOAD_OP: begin
        op2 = {{Archi - 12{instr_i[31]}}, instr_i[31:20]};
      end

      STORE_OP: begin
        op2 = {{Archi - 12{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
        op3 = rs2_val_i;
      end

      IMM_OP, IMMW_OP: begin
        if (funct3 == 3'b001 || funct3 == 3'b101) op2 = {{Archi - 12{1'b0}}, instr_i[31:20]};
        else op2 = {{Archi - 12{instr_i[31]}}, instr_i[31:20]};
      end

      REG_OP, REGW_OP: begin
      end

      AUIPC_OP: begin
        op1 = pc_i;
        op2 = instr_i[31] == 1'b1 ? {{Archi - 32{1'b1}}, instr_i[31:12], {12{1'b0}}} :
            {{Archi - 32{1'b0}}, instr_i[31:12], {12{1'b0}}};
      end

      LUI_OP: begin
        op1 = '0;
        op2 = instr_i[31] == 1'b1 ? {{Archi - 32{1'b1}}, instr_i[31:12], {12{1'b0}}} :
            {{Archi - 32{1'b0}}, instr_i[31:12], {12{1'b0}}};
      end

      BRANCH_OP: begin
        op3 = {
          {Archi - 13{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0
        };
      end

      JALR_OP: begin
        op2 = {{Archi - 12{instr_i[31]}}, instr_i[31:20]};
      end

      JAL_OP: begin
        op1 = '0;
        op2 = {
          {Archi - 21{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0
        };
      end

      SYS_OP: begin
        op2 = {{Archi - 12{instr_i[31]}}, instr_i[31:20]};
        op3 = csr_rdata_i;
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

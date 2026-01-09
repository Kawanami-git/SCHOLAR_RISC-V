// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       decode_unit.sv
\brief      SCHOLAR RISC-V core decode unit module
\author     Kawanami
\date       15/12/2025
\version    1.0

\details
 Instruction Decode Unit (ID) for the SCHOLAR RISC-V core.

  The decode unit interprets the binary instruction from IF/ID and produces:
    - register addresses (rs1/rs2) to read the GPR file
    - destination register (rd)
    - immediate expansion (I/S/B/U/J formats)
    - control fields for EXE/MEM/WB stages
    - operand buses (op1/op2/op3) for the next stages

  Ready/valid handshake:
    - `valid_o` indicates the current decoded payload is valid (supported opcode
      and required operands available).
    - `ready_o` indicates the decode unit can accept a new instruction payload
      from the fetch stage.
    - In this design, `ready_o` also depends on `exe_ready_i` (back-pressure)
      and operand availability (dirty flags), so decode stalls fetch when needed.

\remarks
    - Hazard gating uses `rs1_dirty_i` and `rs2_dirty_i` unconditionally.
      Therefore, instructions that do not use rs1/rs2 must map their unused
      register index to x0, and x0 must never be marked dirty by the GPR file.
    - Current CSR support is minimal (mcycle read only).


\section decode_unit_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 15/12/2025 | Kawanami   | Initial version of the module.            |
********************************************************************************
*/

/* verilator lint_off IMPORTSTAR */
import core_pkg::*;
/* verilator lint_on IMPORTSTAR */

module decode_unit #(
) (
    /// System active low reset
    input  wire                          rstn_i,
    /// Decode unit ready (1: can accept a new instruction to decode)
    output wire                          ready_o,
    /// EXE stage ready flag (back-pressure from the next stage)
    input  wire                          exe_ready_i,
    /// Instruction to decode program counter
    input  wire [    ADDR_WIDTH - 1 : 0] pc_i,
    /// Instruction to decode
    input  wire [       INSTR_WIDTH-1:0] instr_i,
    /// Register file port 0 read address (rs1 index)
    output wire [RF_ADDR_WIDTH  - 1 : 0] rs1_o,
    /// Register file port 0 read data (rs1 value)
    input  wire [DATA_WIDTH     - 1 : 0] rs1_data_i,
    /// Register file rs1 dependency flag (1: data not ready / pending write)
    input  wire                          rs1_dirty_i,
    /// Register file port 1 read address (rs2 index)
    output wire [RF_ADDR_WIDTH  - 1 : 0] rs2_o,
    /// Register file port 1 read data (rs2 value)
    input  wire [DATA_WIDTH     - 1 : 0] rs2_data_i,
    /// Register file rs2 dependency flag (1: data not ready / pending write)
    input  wire                          rs2_dirty_i,
    /// CSR file read address
    output wire [CSR_ADDR_WIDTH - 1 : 0] csr_raddr_o,
    /// CSR file read data
    input  wire [DATA_WIDTH     - 1 : 0] csr_data_i,
    /// First operand: RS1 value or zeroes
    output wire [    DATA_WIDTH - 1 : 0] op1_o,
    /// Second operand: RS2 value (REG_OP or BRANCH_OP) or immediate
    output wire [    DATA_WIDTH - 1 : 0] op2_o,
    /// Third operand: Immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
    output wire [    DATA_WIDTH - 1 : 0] op3_o,
    /// Destination register
    output wire [ RF_ADDR_WIDTH - 1 : 0] rd_o,
    /// Instruction to decode program counter
    output wire [    ADDR_WIDTH - 1 : 0] pc_o,
    /// Exe stage control signal
    output wire [    EXE_CTRL_WIDTH-1:0] exe_ctrl_o,
    /// Memory stage control signal
    output wire [    MEM_CTRL_WIDTH-1:0] mem_ctrl_o,
    /// CSR (writeback) control signal
    output wire [    CSR_CTRL_WIDTH-1:0] csr_ctrl_o,
    /// GPR (writeback) control signal
    output wire [    GPR_CTRL_WIDTH-1:0] gpr_ctrl_o,
    /// PC (controller) control signal
    output wire [     PC_CTRL_WIDTH-1:0] pc_ctrl_o,
    /// Decoded instruction valid flag (1: `id2exe_o` fields are valid)
    output wire                          valid_o
);



  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */
  /*!
  * This function returns '1' if the input address match the provided tag, otherwise '0'.
  * It allows to select a slave according an input address.
  */
  function automatic logic instr_is_valid(input logic [6:0] op);
    return op == LOAD_OP || op == IMM_OP || op == IMMW_OP || op == REGW_OP || op == AUIPC_OP ||
        op == STORE_OP || op == REG_OP || op == LUI_OP || op == BRANCH_OP || op == JALR_OP ||
        op == JAL_OP || op == CSR_OP;
  endfunction



  /* wires */

  /// Instruction opcode field
  logic [OP_WIDTH       - 1 : 0] op;
  /// Read address for GPR port 0
  logic [RF_ADDR_WIDTH  - 1 : 0] rs1;
  /// Read address for GPR port 1
  logic [RF_ADDR_WIDTH  - 1 : 0] rs2;
  /// Destination register for writeback
  logic [RF_ADDR_WIDTH  - 1 : 0] rd;
  /// Read address for CSR access
  logic [CSR_ADDR_WIDTH - 1 : 0] csr_raddr;
  /// Instruction funct3 field (operation Sub-type)
  logic [FUNCT3_WIDTH   - 1 : 0] funct3;
  /// Instruction funct7[5] field (for R-type variants)
  logic [FUNCT7_WIDTH   - 1 : 0] funct7;
  /// 1: can accept a new IF->ID payload
  logic                          ready;
  /// 1: `id2exe_o` fields are valid
  logic                          valid;
  /// Exe stage control signal
  logic [EXE_CTRL_WIDTH - 1 : 0] exe_ctrl;
  /// Pc control signal
  logic [ PC_CTRL_WIDTH - 1 : 0] pc_ctrl;
  /// Gpr (writeback) control signal
  logic [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl;
  /// Mem control signakl
  logic [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl;
  /// First operand
  logic [    DATA_WIDTH - 1 : 0] op1;
  /// Second operand
  logic [    DATA_WIDTH - 1 : 0] op2;
  /// Third operand
  logic [    DATA_WIDTH - 1 : 0] op3;
  /* registers */

  /********************             ********************/

  /// Retreives opcode from the instruction.
  assign op   = instr_i[6:0];

  /// Forward decoded instruction program counter
  assign pc_o = pc_i;

  /// Ready/valid generation
  /*!
  * `valid` is asserted when:
  *  - the instruction opcode is supported
  *  - all required operands are available (no dirty dependency)
  *
  * `ready` indicates whether decode can accept a new payload from IF/ID.
  * In this design, decode is ready only when the next stage can accept
  * the current instruction (`exe_ready_i`) AND operands are available.
  *
  * Dirty flags are checked unconditionally (rs1/rs2).
  * For instructions that do not use rs1/rs2, the decoder must map the
  * corresponding register index to x0, and x0 must never be dirty.
  */
  always_comb begin : ctrl
    if (!rstn_i) begin
      ready = 1'b0;
      valid = 1'b0;
    end
    else if (instr_is_valid(op)) begin
      ready = exe_ready_i && !rs1_dirty_i && !rs2_dirty_i;
      valid = !rs1_dirty_i && !rs2_dirty_i;
    end
    else begin
      ready = 1'b1;
      valid = 1'b0;
    end
  end

  /// Output driven by ctrl
  assign ready_o = ready;
  /// Output driven by ctrl
  assign valid_o = valid;







  /// Instruction decoder
  /*!
  * This block performs the decoding of the instruction
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
  *   It is not relevant for STORE, BRANCH, AUIPC, LUI, CSR, or JAL.
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

      CSR_OP: begin
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
        rd        = '0;
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
    if (DATA_WIDTH == 64) begin : gen_exe_ctrl_gen_64
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
  *   no memory operation is performed (`MemIdle`).
  *   This also prevents unsupported instructions to write into memory.
  */
  generate
    if (DATA_WIDTH == 32) begin : gen_mem_ctrl_32
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
      gpr_ctrl = GPR_IDLE;
    end
    else begin
      case (op)
        LOAD_OP:                                            gpr_ctrl = GPR_MEM;
        IMM_OP, IMMW_OP, REGW_OP, AUIPC_OP, REG_OP, LUI_OP: gpr_ctrl = GPR_ALU;
        JALR_OP, JAL_OP:                                    gpr_ctrl = GPR_PRGMC;
        CSR_OP:                                             gpr_ctrl = GPR_OP3;

        default: gpr_ctrl = GPR_IDLE;
      endcase
    end
  end

  /// Output driven by gpr_ctrl_gen
  assign gpr_ctrl_o = gpr_ctrl;


  /// CSR control signals generator
  /*!
  * For the current version of this core,
  * only read-only CSRs are implemented.
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
  * All immediate values are sign-extended to match `DATA_WIDTH`.
  */
  always_comb begin : operands_gen
    op1 = rs1_data_i;
    op2 = rs2_data_i;
    op3 = '0;
    case (op)

      LOAD_OP: begin
        op2 = {{DATA_WIDTH - 12{instr_i[31]}}, instr_i[31:20]};
      end

      STORE_OP: begin
        op2 = {{DATA_WIDTH - 12{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
        op3 = rs2_data_i;
      end

      IMM_OP, IMMW_OP: begin
        if (funct3 == 3'b001 || funct3 == 3'b101) op2 = {{DATA_WIDTH - 12{1'b0}}, instr_i[31:20]};
        else op2 = {{DATA_WIDTH - 12{instr_i[31]}}, instr_i[31:20]};
      end

      REG_OP, REGW_OP: begin
      end

      AUIPC_OP: begin
        op1 = pc_i;
        op2 = instr_i[31] == 1'b1 ? {{DATA_WIDTH - 32{1'b1}}, instr_i[31:12], {12{1'b0}}} :
            {{DATA_WIDTH - 32{1'b0}}, instr_i[31:12], {12{1'b0}}};
      end

      LUI_OP: begin
        op1 = '0;
        op2 = instr_i[31] == 1'b1 ? {{DATA_WIDTH - 32{1'b1}}, instr_i[31:12], {12{1'b0}}} :
            {{DATA_WIDTH - 32{1'b0}}, instr_i[31:12], {12{1'b0}}};
      end

      BRANCH_OP: begin
        op3 = {
          {DATA_WIDTH - 13{instr_i[31]}},
          instr_i[31],
          instr_i[7],
          instr_i[30:25],
          instr_i[11:8],
          1'b0
        };
      end

      JALR_OP: begin
        op2 = {{DATA_WIDTH - 12{instr_i[31]}}, instr_i[31:20]};
        op3 = pc_i;
      end

      JAL_OP: begin
        op1 = '0;
        op2 = {
          {DATA_WIDTH - 21{instr_i[31]}},
          instr_i[31],
          instr_i[19:12],
          instr_i[20],
          instr_i[30:21],
          1'b0
        };
        op3 = pc_i;
      end

      CSR_OP: begin
        op1 = '0;
        op2 = '0;
        op3 = csr_data_i;
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

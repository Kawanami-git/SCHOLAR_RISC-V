// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       writeback.sv
\brief      SCHOLAR RISC-V core write-back module
\author     Kawanami
\date       01/05/2026
\version    1.5

\details
 This module implements the write-back  unit
 of the SCHOLAR RISC-V processor core.

 The write-back unit is the final step in instruction execution.
 It is responsible for:
  - Writing results to the general-purpose register file (GPR), if applicable
  - Performing memory writes for STORE instructions
  - Updating control and status registers (CSR), if needed
  - Updating the program counter (`pc_i`)
    based on control flow (e.g., jump, branch)

 This unit receives:
  - Results from the execution (exev) unit
  - The `op3_i` operand from the decode unit
    (used for STORE and CSR instructions)
  - Control signals (`gpr_ctrl_i`, `mem_ctrl_i`,
    `pc_ctrl_i`, `csr_ctrl_i`, etc.)
    that determine which updates are to be applied

 Although write-back  logic is triggered in the same cycle as execution,
 the actual writes to memory, GPR, and CSR
 occur on the next clock edge.
 This ensures proper synchronization and consistency
 across all architectural state updates.

 These synchronized writes do not introduce
 additional latency in the core, since the GPRs, `pc_i`, and CSRs
 are read combinatorially. Therefore, the next instruction
 can use updated values without waiting an extra cycle.

 However, external memory accesses (e.g., data memory)
 are managed over two cycles:
  - The first cycle emits the memory request,
  - The second cycle completes the operation:
    - Either by writing the read result to the GPR (in case of a LOAD),
    - Or by ensuring the memory write is completed (STORE).
    - Or by ensuring the memory write is completed (STORE).

 Even though STORE operations could be completed in a single cycle
 (as memory is always ready), both LOAD and STORE are handled in two cycles
 for simplification and consistency.

\remarks
- This implementation complies with [reference or standard].
- TODO: [possible improvements or future features]

\section writeback_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/07/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 21/09/2025 | Kawanami   | Remove packages.sv and provide useful metadata through parameters.<br>Add RV64 support.<br>Update the whole file for coding style compliance.<br>Update the whole file comments for doxygen support. |
| 1.2     | 13/02/2026 | Kawanami   | Replace custom interface with OBI standard. |
| 1.3     | 28/03/2026 | Kawanami   | Improve spike compatibility by detecting whenever a instruction is committed. |
| 1.4     | 29/03/2026 | Kawanami   | Improve global lisibility by using package instead of parameters. |
| 1.5     | 01/05/2026 | Kawanami   | Refactor CSR signals name. |
********************************************************************************
*/
module writeback

  import core_pkg::BYTE_LENGTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
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
    parameter int unsigned                 Archi        = 32,
    /// Number of bits of bytes enable
    parameter int unsigned                 BeWidth      = Archi / BYTE_LENGTH,
    /// Core boot/start address
    parameter logic        [Archi - 1 : 0] StartAddress = '0
) (
`ifdef SIM
    /// To verilator (used in simulation_vs_spike)
    output wire                           instr_committed_o,
`endif
    /// System clock
    input  wire                           clk_i,
    /// System active low reset
    input  wire                           rstn_i,
    /// Result from the execute (EXE) unit
    input  wire [     Archi      - 1 : 0] exe_out_i,
    /// Decode unit valid signal
    input  wire                           decode_valid_i,
    /// Operand 3 from (used for STOREs and branches)
    input  wire [     Archi      - 1 : 0] op3_i,
    /// Destination register index
    input  wire [RF_ADDR_WIDTH   - 1 : 0] rd_i,
    /// Program counter control signal
    input  wire [PC_CTRL_WIDTH   - 1 : 0] pc_ctrl_i,
    /// General-purpose register file control signal
    input  wire [GPR_CTRL_WIDTH  - 1 : 0] gpr_ctrl_i,
    /* verilator lint_off UNUSED */
    /// Control and status register (CSR) control signal
    input  wire [CSR_CTRL_WIDTH  - 1 : 0] csr_ctrl_i,
    /* verilator lint_on UNUSED */
    /// Memory control signal
    input  wire [MEM_CTRL_WIDTH  - 1 : 0] mem_ctrl_i,
    /// Register index to be written (GPR destination)
    output wire [RF_ADDR_WIDTH   - 1 : 0] rd_o,
    /// Write enable for GPR destination register
    output wire                           rd_valid_o,
    /// Data to write to the destination register
    output wire [     Archi      - 1 : 0] rd_val_o,
    /// Current program counter value
    input  wire [     Archi      - 1 : 0] pc_i,
    /// Next program counter value
    output wire [     Archi      - 1 : 0] pc_next_o,
    /// Write address for CSR file
    output wire [ CSR_ADDR_WIDTH - 1 : 0] csr_waddr_o,
    /// Data to write to CSR
    output wire [      Archi     - 1 : 0] csr_wdata_o,
    /// CSR write enable signal
    output wire                           csr_wen_o,
    /// Address transfer request
    output wire                           req_o,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Grant: Ready to accept address transfert
    input  wire                           gnt_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// Address for memory access
    output wire [         Archi  - 1 : 0] addr_o,
    /// Write enable (1: write - 0: read)
    output wire                           we_o,
    /// Write data
    output wire [          Archi - 1 : 0] wdata_o,
    /// Byte enable
    output wire [        BeWidth - 1 : 0] be_o,
    /// Response transfer valid
    input  wire                           rvalid_i,
    /// Read data
    input  wire [          Archi - 1 : 0] rdata_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Error response
    input  wire                           err_i
    /* verilator lint_on UNUSEDSIGNAL */
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  /// Address granularity in bytes (e.g., 4 bytes for 32-bit, 8 for 64-bit)
  localparam int unsigned ADDR_OFFSET = Archi / BYTE_LENGTH;
  /// Number of bits needed to encode byte offset within a word
  localparam int unsigned ADDR_OFFSET_WIDTH = $clog2(ADDR_OFFSET);
  /* functions */

  /* wires */
  /// Address used for memory access (read or write)
  logic [       Archi      - 1 : 0] addr;
  /// Byte offset within the accessed word (used for write alignment)
  wire  [ADDR_OFFSET_WIDTH - 1 : 0] m_addr_offset;
  ///
  logic                             req;
  /// Memory write enable (1 = write)
  logic                             we;
  /// Byte-wise write mask for memory store operations
  logic [         BeWidth  - 1 : 0] be;
  /// Destination register validity flag
  logic                             rd_valid;
  /// Data to write into memory
  logic [       Archi      - 1 : 0] wdata;
  /// Data to write into GPR (register file)
  logic [       Archi      - 1 : 0] gpr_din;
  /// Next value for the program counter (pc_i)
  logic [       Archi      - 1 : 0] pc_next;

  /* registers */
  /// Byte offset within the accessed word (used for read alignment)
  reg   [ADDR_OFFSET_WIDTH - 1 : 0] m_addr_offset_q;
  /// Indicates that the current memory request has been completed
  reg                               m_req_done_q;

  /********************             ********************/

`ifdef SIM
  /// Instruction committed flag
  reg instr_committed_q;
  /// Instruction commit
  /*!
  * Detect when a new instruction is committed.
  * Used by Verilator for simulation_vs_spike.
  */
  always_ff @(posedge clk_i) begin : instr_commit
    if (!rstn_i) begin
      instr_committed_q <= '0;
    end
    else if (decode_valid_i && (mem_ctrl_i == MEM_IDLE || m_req_done_q)) begin
      instr_committed_q <= 1'b1;
    end
    else begin
      instr_committed_q <= '0;
    end
  end
  /// Output driven by instr_commit
  assign instr_committed_o = instr_committed_q;
`endif


  /// Memory access control signals
  /*!
  * This block generates and controls memory access signals
  * (`addr`, `req`, `we`, `be` and `wdata`)
  * based on the validity of the decode unit
  * (`decode_valid_i`) and the memory control signal (`mem_ctrl_i`).
  *
  * The 5th bit of `mem_ctrl_i` signal is used to
  * detect the kind of operation (read or write).
  *
  * They support both LOAD and STORE instructions:
  *   - For LOAD: a read request is triggered (`req` && `!we`),
  *               and a full write mask is applied.
  *               (Some memories use write masks for read access as well,
  *               so we use the same mask logic.)
  *
  *   - For STORE: a write request is triggered (`req` && `we`)
  *               and the write mask (`be`) and the data to write (`wdata`)
  *               are generated based on the access size
  *               (byte, halfword, word, double word) and the address offset.
  *
  * Memory request completion is tracked via `m_req_done_q`,
  * which is set when the memory reports a completion (`rvalid`).
  *
  * Notes:
  *   - Read/write assertion is done combinatorially to avoid stalling the core,
  *     while deassertion is done synchronously
  *     to ensure proper timing with the memory (`gen_mem_ack`).
  *
  *   - The memory address (`addr`) must remain stable
  *     during the entire memory access.
  *     This is ensured by keeping the `pc_i` constant in a separate block
  *     until the request is completed.
  *
  *   - For LOAD instructions: even after the memory returns data,
  *     one additional cycle is needed to write-back the value into the GPR file.
  *     During that cycle, the exe unit may already have moved to the next instruction
  *     and modified `exe_out_i`.
  *     To avoid incorrect masking due to address change,
  *     the byte offset is saved in `m_addr_offset_q`
  *     (registered on the `negedge` of the clock)
  *     and reused for proper data alignment during write-back (`gen_mem_offset`).
  *
  *   - The synchronized nature of write-back introduces no visible latency,
  *     since register and CSR reads are combinational.
  */
  generate
    if (Archi == 32) begin : gen_mem_controller_32
      always_comb begin : mem_controller
        if (mem_ctrl_i != MEM_IDLE) addr = exe_out_i;
        else addr = '0;

        if (mem_ctrl_i != MEM_IDLE && m_req_done_q == 1'b0) begin
          req = 1'b1;
          if (mem_ctrl_i[3] == 1'b0) begin  // Read
            we    = 1'b0;
            be    = '0;
            wdata = '0;
          end
          else begin  // Write
            we = 1'b1;

            case (mem_ctrl_i)
              MEM_WB: begin
                wdata = ({{Archi - 8{1'b0}}, op3_i[7:0]}) << m_addr_offset * BYTE_LENGTH;
                be    = 1'b1 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MEM_WH: begin
                wdata = ({{Archi - 16{1'b0}}, op3_i[15:0]}) << m_addr_offset * BYTE_LENGTH;
                be    = 3 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              default: begin
                wdata = op3_i;
                be    = {Archi / 8{1'b1}};
              end
            endcase
          end
        end
        else begin
          wdata = '0;
          req   = 1'b0;
          we    = 1'b0;
          be    = '0;
        end
      end

    end
    else begin : gen_mem_controller_64

      always_comb begin : mem_controller
        if (mem_ctrl_i != MEM_IDLE) addr = exe_out_i;
        else addr = '0;

        if (mem_ctrl_i != MEM_IDLE && m_req_done_q == 1'b0) begin
          req = 1'b1;
          if (!mem_ctrl_i[3]) begin  // Read
            we    = 1'b0;
            be    = '0;
            wdata = '0;
          end
          else begin  // Write
            we = 1'b1;

            case (mem_ctrl_i)
              MEM_WB: begin
                wdata = ({{Archi - 8{1'b0}}, op3_i[7:0]}) << m_addr_offset * BYTE_LENGTH;
                be    = 1'b1 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MEM_WH: begin
                wdata = ({{Archi - 16{1'b0}}, op3_i[15:0]}) << m_addr_offset * BYTE_LENGTH;
                be    = 3 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MEM_WW: begin
                wdata = ({{Archi - 32{1'b0}}, op3_i[31:0]}) << m_addr_offset * BYTE_LENGTH;
                be    = 15 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              default: begin
                wdata = op3_i;
                be    = {Archi / 8{1'b1}};
              end
            endcase
          end
        end
        else begin
          wdata = '0;
          req   = 1'b0;
          we    = 1'b0;
          be    = '0;
        end
      end

    end

  endgenerate

  /// Memory transaction completion tracker
  /*!
  * This block tracks memory request completion.
  * It sets `m_req_done_q` signal when a memory transaction
  * is completed, allowing the `gen_mem_request` to disassert
  * the `req` signal.
  */
  always_ff @(posedge clk_i) begin : mem_ack_gen
    if (!rstn_i) m_req_done_q <= 1'b0;
    else if (req && rvalid_i) m_req_done_q <= 1'b1;
    else m_req_done_q <= 1'b0;
  end

  /// Memory transaction address offset logger
  /*!
  * This block allows to save the address offset
  * (i.e. [2:0] (64 bits) or [1:0] (32 bits) bits).
  * For LOAD instructions, even after the memory returns data,
  * one additional cycle is needed to write-back the value into the GPR file.
  * During that cycle, the exe unit may already have moved to the next instruction
  * and modified `exe_out_i`, which contain the address of the data to load.
  * To avoid incorrect masking due to address change,
  * the byte offset is saved in `m_addr_offset_q`
  * (registered on the `negedge` of the clock)
  * and reused for proper data alignment during write-back.
  */
  always_ff @(posedge clk_i) begin : mem_offset_gen
    if (!rstn_i) m_addr_offset_q <= '0;
    else if (req && !we) m_addr_offset_q <= m_addr_offset;
  end

  /// Address offset computation for correct alignment during write requests
  assign m_addr_offset = exe_out_i[ADDR_OFFSET_WIDTH-1 : 0];


  /// Output driven by mem_controller
  assign wdata_o       = wdata;
  /// Output driven by mem_controller
  assign addr_o        = {addr[Archi-1:ADDR_OFFSET_WIDTH], {ADDR_OFFSET_WIDTH{1'b0}}};
  /// Output driven by mem_controller
  assign req_o         = req;
  /// Output driven by mem_controller
  assign we_o          = we;
  /// Output driven by mem_controller
  assign be_o          = be;



  /*!
  * Since only the `mcycle` register is implemented in the CSR file,
  * and it is read-only, there is no need to perform any write to the CSRs.
  *
  * `csr_wen_o` is permanently set to 0 to disable CSRs write operations.
  */
  assign csr_wen_o     = 1'b0;

  /*!
  * Since only the `mcycle` register is implemented in the CSR file,
  * and it is read-only, there is no need to perform any write to the CSRs.
  *
  * `csr_waddr_o` is tied to zero since no write will occur.
  */
  assign csr_waddr_o   = 'b0;

  /// General Purpose registers updater
  /*!
  * This block computes the final value written back to the GPR file (`gpr_din`)
  * and its validity (`rd_valid`) based on the decoded control signals.
  *
  * Source selection (`gpr_ctrl_i`):
  *   - GPR_ALU    : Write back ALU/execution result (`exe_out_i`)
  *   - GPR_PRGMC  : Write back return address (`pc_i` + 4) for JAL/JALR
  *   - GPR_OP3    : Write back `op3_i` (e.g., CSR read path)
  *   - GPR_MEM    : Write back load data from memory (`rdata_i`)
  *
  * Load formatting (when `gpr_ctrl_i` == GPR_MEM):
  *   - `rd_valid` is asserted only when the outstanding memory request completes
  *      (`m_req_done_q` == 1).
  *   - `mem_ctrl_i` selects width and signedness:
  *       - MEM_RB  / MEM_RBU : Load byte (signed / zero-extended)
  *       - MEM_RH  / MEM_RHU : Load half-word (signed / zero-extended)
  *       - MEM_RW  / MEM_RWU : Load word (signed / zero-extented )
  *       - default           : Load word (32-bit architecture)
  *                             or Load double word (64-bit architecture)
  *   - The byte/half-word is extracted from `rdata_i` using `m_addr_offset_q`
  *     (byte offset within the aligned read data) and then sign- or zero-extended
  *     to `Archi`.
  *     The same rule is applied to a word for RV64I.
  *
  *  Default / no write-back:
  *    - If none of the above sources is selected, `gpr_din` is cleared to 0 and
  *      `rd_valid` is deasserted.
  *
  *  Notes:
  *    - `csr_wdata_o` is tied to 0 in this design (no CSR write-back performed here).
  */
  generate

    if (Archi == 32) begin : gen_rd_32

      logic [15 : 0] mem_rdata;

      always_comb begin : rd_gen
        mem_rdata = 'b0;
        rd_valid  = decode_valid_i;

        if (gpr_ctrl_i == GPR_ALU) begin
          gpr_din = exe_out_i;
        end
        else if (gpr_ctrl_i == GPR_PRGMC) begin
          gpr_din = pc_i + 4;
        end
        else if (gpr_ctrl_i == GPR_OP3) begin
          gpr_din = op3_i;
        end
        else if (gpr_ctrl_i == GPR_MEM) begin
          rd_valid = m_req_done_q;
          case (mem_ctrl_i)

            MEM_RB, MEM_RBU: begin
              mem_rdata = {8'b00000000, rdata_i[(m_addr_offset_q*8)+:8]};

              if (mem_ctrl_i == MEM_RBU) gpr_din = {{Archi - 8{1'b0}}, mem_rdata[7:0]};
              else
                gpr_din = mem_rdata[7] == 1 ?
                    {{Archi - 8{1'b1}}, mem_rdata[7:0]} : {{Archi - 8{1'b0}}, mem_rdata[7:0]};
            end

            MEM_RH, MEM_RHU: begin
              mem_rdata = rdata_i[(m_addr_offset_q*8)+:16];
              if (mem_ctrl_i == MEM_RHU) gpr_din = {{Archi - 16{1'b0}}, mem_rdata[15:0]};
              else
                gpr_din = mem_rdata[15] == 1 ?
                    {{Archi - 16{1'b1}}, mem_rdata[15:0]} : {{Archi - 16{1'b0}}, mem_rdata[15:0]};
            end

            default: begin
              gpr_din = rdata_i;
            end
          endcase

        end
        else begin
          mem_rdata = '0;
          gpr_din   = '0;
          rd_valid  = 1'b0;
        end
      end

    end
    else begin : gen_rd_64

      logic [31 : 0] mem_rdata;

      always_comb begin : rd_gen
        mem_rdata = 'b0;
        rd_valid  = decode_valid_i;

        if (gpr_ctrl_i == GPR_ALU) begin
          gpr_din = exe_out_i;
        end
        else if (gpr_ctrl_i == GPR_PRGMC) begin
          gpr_din = pc_i + 4;
        end
        else if (gpr_ctrl_i == GPR_OP3) begin
          gpr_din = op3_i;
        end
        else if (gpr_ctrl_i == GPR_MEM) begin
          rd_valid = m_req_done_q;
          case (mem_ctrl_i)

            MEM_RB, MEM_RBU: begin
              mem_rdata = {24'h000000, rdata_i[(m_addr_offset_q*8)+:8]};

              if (mem_ctrl_i == MEM_RBU) gpr_din = {{Archi - 8{1'b0}}, mem_rdata[7:0]};
              else
                gpr_din = mem_rdata[7] == 1 ?
                    {{Archi - 8{1'b1}}, mem_rdata[7:0]} : {{Archi - 8{1'b0}}, mem_rdata[7:0]};
            end

            MEM_RH, MEM_RHU: begin
              mem_rdata = {16'h0000, rdata_i[(m_addr_offset_q*8)+:16]};

              if (mem_ctrl_i == MEM_RHU) gpr_din = {{Archi - 16{1'b0}}, mem_rdata[15:0]};
              else
                gpr_din = mem_rdata[15] == 1 ?
                    {{Archi - 16{1'b1}}, mem_rdata[15:0]} : {{Archi - 16{1'b0}}, mem_rdata[15:0]};
            end

            MEM_RW, MEM_RWU: begin
              mem_rdata = rdata_i[(m_addr_offset_q*8)+:32];

              if (mem_ctrl_i == MEM_RWU) gpr_din = {{Archi - 32{1'b0}}, mem_rdata[31:0]};
              else
                gpr_din = mem_rdata[31] == 1 ?
                    {{Archi - 32{1'b1}}, mem_rdata[31:0]} : {{Archi - 32{1'b0}}, mem_rdata[31:0]};
            end

            default: begin
              gpr_din = rdata_i;
            end
          endcase

        end
        else begin
          mem_rdata = '0;
          gpr_din   = '0;
          rd_valid  = 1'b0;
        end
      end

    end

  endgenerate


  /// Destination register address in the register file
  assign rd_o        = rd_i;
  /// Output driven by rd_gen
  assign rd_valid_o  = rd_valid;
  /// Output driven by rd_gen
  assign rd_val_o    = gpr_din;
  /// CSR is read only in this version of the core.
  assign csr_wdata_o = '0;

  /// Program Counter updater
  /*!
  * This block computes the next value of the program counter (`pc_next`)
  * based on:
  *   - The current `pc_i`                  (`pc_i`)
  *   - The reset signal                    (`rstn_i`)
  *   - The decode/execute validity         (`decode_valid_i`)
  *   - The memory state                    (`mem_ctrl_i[4]` and `m_req_done_q`)
  *   - The program counter control signal  (`pc_ctrl_i`)
  *
  * On reset (`rstn_i` low): the pc_i is initialized to `StartAddress`.
  *
  * If an instruction is valid (`decode_valid_i`):
  *   - If it's a memory instruction:
  *     - If the memory access is complete (`m_req_done_q`),
  *       advance the `pc_i`.
  *     - Otherwise, hold the pc_i to stall execution.
  *
  *   - For non-memory instructions,
  *     `pc_ctrl_i` determines the update mode:
  *     - `PC_INC`  → Increment `pc_i` by `ADDR_OFFSET` (sequential execution)
  *
  *     - `PC_SET`  → Load `pc_i` with `exe_out_i`,
  *                   typically for JALR (address is already computed and aligned)
  *
  *     - `PC_ADD`  → Perform a `pc_i`-relative jump: `pc_i` + `exe_out_i` (used for JAL)
  *
  *     - `PC_COND` → Conditional branch: if `exe_out_i[0]` is set (condition true),
  *                   `pc_i` += `op3_i`; otherwise, continue sequentially.
  *
  *   - If the instruction is not valid, hold `pc_i`.
  *
  * This logic ensures proper handling of all control flow instructions,
  * including jumps, branches, and returns,
  * while maintaining memory consistency.
  */
  always_comb begin : pc_gen
    if (!rstn_i) begin
      pc_next = StartAddress;
    end
    else if (decode_valid_i) begin
      if (mem_ctrl_i != MEM_IDLE) begin
        if (m_req_done_q) pc_next = pc_i + 4;
        else pc_next = pc_i;
      end
      else begin
        case (pc_ctrl_i)
          PC_INC:  pc_next = pc_i + 4;
          PC_SET:  pc_next = {exe_out_i[Archi-1:1], 1'b0};
          PC_ADD:  pc_next = pc_i + exe_out_i;
          PC_COND: pc_next = exe_out_i[0] ? pc_i + op3_i : pc_i + 4;
          default: pc_next = pc_i + 4;
        endcase
      end
    end
    else begin
      pc_next = pc_i;
    end
  end

  /// Output driven by pc_gen
  assign pc_next_o = pc_next;

endmodule

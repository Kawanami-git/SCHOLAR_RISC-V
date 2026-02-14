// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       writeback.sv
\brief      SCHOLAR RISC-V core write-back module
\author     Kawanami
\date       13/02/2026
\version    1.2

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
********************************************************************************
*/
module writeback #(
    /* Global parameters */
    /// Number of bits in a byte
    parameter int                          ByteLength   = 8,
    /// Number of bits for addressing
    parameter int                          AddrWidth    = 32,
    /// Width of data paths (in bits)
    parameter int                          DataWidth    = 32,
    /// Width of the GPR index (in bits, usually 5 for 32 regs)
    parameter int                          RfAddrWidth  = 5,
    /// Width of the CSR address field (in bits, usually 12)
    parameter int                          CsrAddrWidth = 12,
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
    /* General Purpose Registers control parameters */
    /// Width of the GPR write-back control signal
    parameter int                          GprCtrlWidth = 3,
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
    /// Core boot/start address
    parameter logic [   AddrWidth - 1 : 0] StartAddress = '0
) (
    /// System clock
    input  wire                          clk_i,
    /// System active low reset
    input  wire                          rstn_i,
    /// Result from the execute (EXE) unit
    input  wire [DataWidth      - 1 : 0] exe_out_i,
    /// Decode unit valid signal
    input  wire                          decode_valid_i,
    /// Operand 3 from (used for STOREs and branches)
    input  wire [DataWidth      - 1 : 0] op3_i,
    /// Destination register index
    input  wire [ RfAddrWidth   - 1 : 0] rd_i,
    /// Program counter control signal
    input  wire [ PcCtrlWidth   - 1 : 0] pc_ctrl_i,
    /// General-purpose register file control signal
    input  wire [ GprCtrlWidth  - 1 : 0] gpr_ctrl_i,
    /* verilator lint_off UNUSED */
    /// Control and status register (CSR) control signal
    input  wire [ CsrCtrlWidth  - 1 : 0] csr_ctrl_i,
    /* verilator lint_on UNUSED */
    /// Memory control signal
    input  wire [ MemCtrlWidth  - 1 : 0] mem_ctrl_i,
    /// Register index to be written (GPR destination)
    output wire [ RfAddrWidth   - 1 : 0] rd_o,
    /// Write enable for GPR destination register
    output wire                          rd_valid_o,
    /// Data to write to the destination register
    output wire [DataWidth      - 1 : 0] rd_val_o,
    /// Current program counter value
    input  wire [AddrWidth      - 1 : 0] pc_i,
    /// Next program counter value
    output wire [AddrWidth      - 1 : 0] pc_next_o,
    /// Write address for CSR file
    output wire [  CsrAddrWidth - 1 : 0] csr_waddr_o,
    /// Data to write to CSR
    output wire [ DataWidth     - 1 : 0] csr_val_o,
    /// CSR write enable signal
    output wire                          csr_valid_o,
    /// Address transfer request
    output wire                          req_o,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Grant: Ready to accept address transfert
    input  wire                          gnt_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// Address for memory access
    output wire [    AddrWidth  - 1 : 0] addr_o,
    /// Write enable (1: write - 0: read)
    output wire                          we_o,
    /// Write data
    output wire [     DataWidth - 1 : 0] wdata_o,
    /// Byte enable
    output wire [ (DataWidth/8) - 1 : 0] be_o,
    /// Response transfer valid
    input  wire                          rvalid_i,
    /// Read data
    input  wire [     DataWidth - 1 : 0] rdata_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Error response
    input  wire                          err_i
    /* verilator lint_on UNUSEDSIGNAL */
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  /// Address granularity in bytes (e.g., 4 bytes for 32-bit, 8 for 64-bit)
  localparam int unsigned ADDR_OFFSET = DataWidth / ByteLength;
  /// Number of bits needed to encode byte offset within a word
  localparam int unsigned ADDR_OFFSET_WIDTH = $clog2(ADDR_OFFSET);
  /* functions */

  /* wires */
  /// Address used for memory access (read or write)
  logic [   AddrWidth      - 1 : 0] addr;
  /// Byte offset within the accessed word (used for write alignment)
  wire  [ADDR_OFFSET_WIDTH - 1 : 0] m_addr_offset;
  ///
  logic                             req;
  /// Memory write enable (1 = write)
  logic                             we;
  /// Byte-wise write mask for memory store operations
  logic [   (DataWidth/8)  - 1 : 0] be;
  /// Destination register validity flag
  logic                             rd_valid;
  /// Data to write into memory
  logic [   DataWidth      - 1 : 0] wdata;
  /// Data to write into GPR (register file)
  logic [   DataWidth      - 1 : 0] gpr_din;
  /// Next value for the program counter (pc_i)
  logic [   AddrWidth      - 1 : 0] pc_next;

  /* registers */
  /// Byte offset within the accessed word (used for read alignment)
  reg   [ADDR_OFFSET_WIDTH - 1 : 0] m_addr_offset_q;
  /// Indicates that the current memory request has been completed
  reg                               m_req_done_q;

  /********************             ********************/

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
    if (DataWidth == 32) begin : gen_mem_controller_32
      always_comb begin : mem_controller
        if (mem_ctrl_i != MemIdle) addr = exe_out_i;
        else addr = '0;

        if (mem_ctrl_i != MemIdle && m_req_done_q == 1'b0) begin
          req = 1'b1;
          if (mem_ctrl_i[4] == 1'b0) begin  // Read
            we    = 1'b0;
            be    = {DataWidth / 8{1'b1}};
            wdata = '0;
          end
          else begin  // Write
            we = 1'b1;

            case (mem_ctrl_i)
              MemWb: begin
                wdata = ({{DataWidth - 8{1'b0}}, op3_i[7:0]}) << m_addr_offset * ByteLength;
                be    = 1'b1 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MemWh: begin
                wdata = ({{DataWidth - 16{1'b0}}, op3_i[15:0]}) << m_addr_offset * ByteLength;
                be    = 3 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              default: begin
                wdata = op3_i;
                be    = {DataWidth / 8{1'b1}};
              end
            endcase
          end
        end
        else begin
          wdata = '0;
          req   = 1'b0;
          be    = {DataWidth / 8{1'b1}};
        end
      end

    end
    else begin : gen_mem_controller_64

      always_comb begin : mem_controller
        if (mem_ctrl_i != MemIdle) addr = exe_out_i;
        else addr = {AddrWidth{1'b0}};

        if (mem_ctrl_i != MemIdle && m_req_done_q == 1'b0) begin
          req = 1'b1;
          if (!mem_ctrl_i[4]) begin  // Read
            we    = 1'b0;
            be    = {DataWidth / 8{1'b1}};
            wdata = '0;
          end
          else begin  // Write
            we = 1'b1;

            case (mem_ctrl_i)
              MemWb: begin
                wdata = ({{DataWidth - 8{1'b0}}, op3_i[7:0]}) << m_addr_offset * ByteLength;
                be    = 1'b1 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MemWh: begin
                wdata = ({{DataWidth - 16{1'b0}}, op3_i[15:0]}) << m_addr_offset * ByteLength;
                be    = 3 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MemWw: begin
                wdata = ({{DataWidth - 32{1'b0}}, op3_i[31:0]}) << m_addr_offset * ByteLength;
                be    = 15 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              default: begin
                wdata = op3_i;
                be    = {DataWidth / 8{1'b1}};
              end
            endcase
          end
        end
        else begin
          wdata = '0;
          req   = 1'b0;
          be    = {DataWidth / 8{1'b1}};
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
  assign addr_o        = {addr[AddrWidth-1:ADDR_OFFSET_WIDTH], {ADDR_OFFSET_WIDTH{1'b0}}};
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
  * `csr_valid_o` is permanently set to 0 to disable CSRs write operations.
  */
  assign csr_valid_o   = 1'b0;

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
  *   - GprAlu    : Write back ALU/execution result (`exe_out_i`)
  *   - GprPrgmc  : Write back return address (`pc_i` + 4) for JAL/JALR
  *   - GprOp3    : Write back `op3_i` (e.g., CSR read path)
  *   - GprMem    : Write back load data from memory (`rdata_i`)
  *
  * Load formatting (when `gpr_ctrl_i` == GprMem):
  *   - `rd_valid` is asserted only when the outstanding memory request completes
  *      (`m_req_done_q` == 1).
  *   - `mem_ctrl_i` selects width and signedness:
  *       - MemRb  / MemRbu : Load byte (signed / zero-extended)
  *       - MemRh  / MemRhu : Load half-word (signed / zero-extended)
  *       - MemRw  / MemRwu : Load word (signed / zero-extented )
  *       - default           : Load word (32-bit architecture)
  *                             or Load double word (64-bit architecture)
  *   - The byte/half-word is extracted from `rdata_i` using `m_addr_offset_q`
  *     (byte offset within the aligned read data) and then sign- or zero-extended
  *     to `DataWidth`.
  *     The same rule is applied to a word for RV64I.
  *
  *  Default / no write-back:
  *    - If none of the above sources is selected, `gpr_din` is cleared to 0 and
  *      `rd_valid` is deasserted.
  *
  *  Notes:
  *    - `csr_val_o` is tied to 0 in this design (no CSR write-back performed here).
  */
  generate

    if (DataWidth == 32) begin : gen_rd_32

      logic [15 : 0] mem_rdata;

      always_comb begin : rd_gen
        mem_rdata = 'b0;
        rd_valid  = decode_valid_i;

        if (gpr_ctrl_i == GprAlu) begin
          gpr_din = exe_out_i;
        end
        else if (gpr_ctrl_i == GprPrgmc) begin
          gpr_din = pc_i + 4;
        end
        else if (gpr_ctrl_i == GprOp3) begin
          gpr_din = op3_i;
        end
        else if (gpr_ctrl_i == GprMem) begin
          rd_valid = m_req_done_q;
          case (mem_ctrl_i)

            MemRb, MemRbu: begin
              mem_rdata = {8'b00000000, rdata_i[(m_addr_offset_q*8)+:8]};

              if (mem_ctrl_i == MemRbu) gpr_din = {{DataWidth - 8{1'b0}}, mem_rdata[7:0]};
              else
                gpr_din = mem_rdata[7] == 1 ? {{DataWidth - 8{1'b1}}, mem_rdata[7:0]} :
                    {{DataWidth - 8{1'b0}}, mem_rdata[7:0]};
            end

            MemRh, MemRhu: begin
              mem_rdata = rdata_i[(m_addr_offset_q*8)+:16];
              if (mem_ctrl_i == MemRhu) gpr_din = {{DataWidth - 16{1'b0}}, mem_rdata[15:0]};
              else
                gpr_din = mem_rdata[15] == 1 ? {{DataWidth - 16{1'b1}}, mem_rdata[15:0]} :
                    {{DataWidth - 16{1'b0}}, mem_rdata[15:0]};
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

        if (gpr_ctrl_i == GprAlu) begin
          gpr_din = exe_out_i;
        end
        else if (gpr_ctrl_i == GprPrgmc) begin
          gpr_din = pc_i + 4;
        end
        else if (gpr_ctrl_i == GprOp3) begin
          gpr_din = op3_i;
        end
        else if (gpr_ctrl_i == GprMem) begin
          rd_valid = m_req_done_q;
          case (mem_ctrl_i)

            MemRb, MemRbu: begin
              mem_rdata = {24'h000000, rdata_i[(m_addr_offset_q*8)+:8]};

              if (mem_ctrl_i == MemRbu) gpr_din = {{DataWidth - 8{1'b0}}, mem_rdata[7:0]};
              else
                gpr_din = mem_rdata[7] == 1 ? {{DataWidth - 8{1'b1}}, mem_rdata[7:0]} :
                    {{DataWidth - 8{1'b0}}, mem_rdata[7:0]};
            end

            MemRh, MemRhu: begin
              mem_rdata = {16'h0000, rdata_i[(m_addr_offset_q*8)+:16]};

              if (mem_ctrl_i == MemRhu) gpr_din = {{DataWidth - 16{1'b0}}, mem_rdata[15:0]};
              else
                gpr_din = mem_rdata[15] == 1 ? {{DataWidth - 16{1'b1}}, mem_rdata[15:0]} :
                    {{DataWidth - 16{1'b0}}, mem_rdata[15:0]};
            end

            MemRw, MemRwu: begin
              mem_rdata = rdata_i[(m_addr_offset_q*8)+:32];

              if (mem_ctrl_i == MemRwu) gpr_din = {{DataWidth - 32{1'b0}}, mem_rdata[31:0]};
              else
                gpr_din = mem_rdata[31] == 1 ? {{DataWidth - 32{1'b1}}, mem_rdata[31:0]} :
                    {{DataWidth - 32{1'b0}}, mem_rdata[31:0]};
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
  assign rd_o       = rd_i;
  /// Output driven by rd_gen
  assign rd_valid_o = rd_valid;
  /// Output driven by rd_gen
  assign rd_val_o   = gpr_din;
  /// CSR is read only in this version of the core.
  assign csr_val_o  = '0;

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
  *     - `PcInc`  → Increment `pc_i` by `ADDR_OFFSET` (sequential execution)
  *
  *     - `PcSet`  → Load `pc_i` with `exe_out_i`,
  *                   typically for JALR (address is already computed and aligned)
  *
  *     - `PcAdd`  → Perform a `pc_i`-relative jump: `pc_i` + `exe_out_i` (used for JAL)
  *
  *     - `PcCond` → Conditional branch: if `exe_out_i[0]` is set (condition true),
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
      if (mem_ctrl_i != MemIdle) begin
        if (m_req_done_q) pc_next = pc_i + 4;
        else pc_next = pc_i;
      end
      else begin
        case (pc_ctrl_i)
          PcInc:   pc_next = pc_i + 4;
          PcSet:   pc_next = {exe_out_i[DataWidth-1:1], 1'b0};
          PcAdd:   pc_next = pc_i + exe_out_i;
          PcCond:  pc_next = exe_out_i[0] ? pc_i + op3_i : pc_i + 4;
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

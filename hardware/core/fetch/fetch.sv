// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       fetch.sv
\brief      SCHOLAR RISC-V core fetch stage
\author     Kawanami
\date       12/12/2025
\version    1.0

\details
  Instruction Fetch (IF) stage for the SCHOLAR RISC-V core pipeline.

  The stage issues a read request to the instruction memory using `pc_i`
  through `core_mem_if.cpu` and forwards the returned instruction to decode.

  The instruction memory is assumed synchronous:
    - `imem_if.hit` indicates in the *request* cycle whether data will be valid
      in the *next* cycle.
    - `i_m_rdata_i` is consumed in the next cycle (registered validity).

  A lightweight pre-decode is performed to extract rs1/rs2/rd early (from the
  fetched instruction) so the hazard controller can evaluate dependencies
  without adding a critical path: decode -> ctrl -> decode.

  Fetching is gated by `decode_ready_i`. If decode cannot accept a new
  instruction (stall), IF holds its internal state and does not issue new
  memory requests.

\remarks
  - The instruction memory shall be is synchrone (1-cycle) and perfect (no miss).
  - TODO: [possible improvements or future features]

\section fetch_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 12/12/2025 | Kawanami   | Initial version of the module.            |
********************************************************************************
*/

/*!
* Import useful packages.
*/
import if2id_pkg::if2id_t;
import core_pkg::INSTR_WIDTH;
import core_pkg::ADDR_WIDTH;
import core_pkg::RF_ADDR_WIDTH;
import core_pkg::OP_WIDTH;
import core_pkg::AUIPC_OP;
import core_pkg::STORE_OP;
import core_pkg::LUI_OP;
import core_pkg::BRANCH_OP;
import core_pkg::JAL_OP;
import core_pkg::REGW_OP;
import core_pkg::REG_OP;
/**/

module fetch #(
) (

    /// System clock
    input  wire                            clk_i,
    /// System active low reset
    input  wire                            rstn_i,
    /// Current program counter (address used for the memory request)
    input  wire    [  ADDR_WIDTH  - 1 : 0] pc_i,
    /// Decode-stage ready. When low, fetch is stalled (no new request)
    input  wire                            decode_ready_i,
    /// Instruction valid flag
    output wire                            valid_o,
    /// IF->ID payload: fetched instruction and its associated PC
    output if2id_t                         if2id_o,
    /// Pre-decoded register source 1 (for hazard checking)
    output wire    [RF_ADDR_WIDTH - 1 : 0] rs1_o,
    /// Pre-decoded register source 2 (for hazard checking)
    output wire    [RF_ADDR_WIDTH - 1 : 0] rs2_o,
    /// Pre-decoded destination register (for hazard checking)
    output wire    [RF_ADDR_WIDTH - 1 : 0] rd_o,
    /// Memory output data
    input  wire    [    INSTR_WIDTH - 1:0] i_m_rdata_i,
    /// Memory hit flag (1: hit, 0: miss)
    input  wire                            i_m_hit_i,
    /// Memory address
    output wire    [   ADDR_WIDTH - 1 : 0] i_m_addr_o,
    /// Memory read enable (1: enable, 0: disable)
    output wire                            i_m_rden_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// Source register 1 extracted from the fetched instruction
  logic [RF_ADDR_WIDTH - 1 : 0] rs1;
  /// Source register 2 extracted from the fetched instruction
  logic [RF_ADDR_WIDTH - 1 : 0] rs2;
  /// Destination register extracted from the fetched instruction
  logic [RF_ADDR_WIDTH - 1 : 0] rd;

  /* registers */
  /// Registered memory "hit": indicates that `rdata` is valid in this cycle
  reg                           hit_q;
  /// Registered PC matching the instruction returned in this cycle
  reg   [   ADDR_WIDTH - 1 : 0] pc_q;
  /********************             ********************/

  /// Instruction memory address is driven directly by the current PC
  assign i_m_addr_o = pc_i;

  /// Issue a read request only when decode can accept the next instruction
  /// When `decode_ready_i` is low, IF stalls and does not advance
  assign i_m_rden_o = decode_ready_i & rstn_i;

  /// Synchronous instruction memory handshake
  /*!
  * `imem_if.hit` is asserted in the request cycle if the instruction will be
  * available in the next cycle on `i_m_rdata_i`.
  *
  * We register `hit` so `valid_o` aligns with `if2id_o.instr` / `if2id_o.pc`.
  */
  always_ff @(posedge clk_i) begin : mem_ack
    if (!rstn_i) begin
      hit_q <= 1'b0;
    end
    else if (decode_ready_i) begin  // Save last mem rsq rsp
      hit_q <= i_m_hit_i;
    end
  end

  /// Ouptut driven by mem_ack
  assign valid_o = hit_q;


  /// PC alignment for a synchronous memory
  /*!
  * Because `pc_i` may advance to request the next instruction while the
  * current instruction returns, we register the request PC so the PC forwarded
  * to decode matches `i_m_rdata_i`.
  */
  always_ff @(posedge clk_i) begin : pc
    if (decode_ready_i) begin
      pc_q <= pc_i;
    end
  end

  /// Output driven by pc
  assign if2id_o.pc    = pc_q;


  /// Forward the instruction data from memory
  assign if2id_o.instr = i_m_rdata_i;



  /// Instruction pre-decode for hazard detection
  /*!
  * Extract rs1/rs2/rd early so the hazard controller can check dependencies
  * without waiting for the full decode logic, reducing critical path pressure.
  *
  * Notes:
  * - Some opcodes do not use rs1 (e.g., LUI/AUIPC/JAL) -> rs1 = 0
  * - Some opcodes do not use rs2 (e.g., I-type loads/ALU imm) -> rs2 = 0
  * - Some opcodes do not write rd (e.g., stores/branches) -> rd = 0
  */
  always_comb begin : pre_decode
    if ((i_m_rdata_i[6:0] == AUIPC_OP) || (i_m_rdata_i[6:0] == LUI_OP) ||
        (i_m_rdata_i[6:0] == JAL_OP)) begin
      rs1 = '0;
    end
    else begin
      rs1 = i_m_rdata_i[19:15];
    end

    if ((i_m_rdata_i[6:0] == STORE_OP) || (i_m_rdata_i[6:0] == REG_OP) ||
        (i_m_rdata_i[6:0] == REGW_OP) || (i_m_rdata_i[6:0] == BRANCH_OP)) begin
      rs2 = i_m_rdata_i[24:20];
    end
    else begin
      rs2 = '0;
    end

    if ((i_m_rdata_i[6:0] == BRANCH_OP) || (i_m_rdata_i[6:0] == STORE_OP)) begin
      rd = '0;
    end
    else begin
      rd = i_m_rdata_i[11:7];
    end
  end

  /// Output driven by pre_decode
  assign rs1_o = rs1;
  /// Output driven by pre_decode
  assign rs2_o = rs2;
  /// Output driven by pre_decode
  assign rd_o  = rd;



endmodule

// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       fetch.sv
\brief      SCHOLAR RISC-V core fetch stage
\author     Kawanami
\date       15/02/2026
\version    1.2

\details
  Instruction Fetch (IF) stage for the SCHOLAR RISC-V core pipeline.

  The stage issues a read request to the instruction memory using `pc_i`
  through `core_mem_if.cpu` and forwards the returned instruction to decode.

  The instruction memory is assumed synchronous:
    - `rvalid_i` indicates in the *request* cycle whether data will be valid
      in the *next* cycle.
    - `rdata_i` is consumed in the next cycle (registered validity).

  A lightweight pre-decode is performed to extract rs1/rs2/csr_raddr early (from the
  fetched instruction) so the hazard controller can evaluate dependencies
  without adding a critical path: decode -> ctrl -> decode.

  Fetching is gated by `decode_ready_i`. If decode cannot accept a new
  instruction (stall), IF holds its internal state and does not issue new
  memory requests.

\remarks

\section fetch_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 12/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 30/01/2026 | Kawanami   | Add csr_raddr extraction & non-perfect memory support.            |
| 1.2     | 15/02/2026 | Kawanami   | Replace custom interface with OBI standard. |
********************************************************************************
*/

module fetch

  /*!
* Import useful packages.
*/
  import if2id_pkg::if2id_t;
  import if2ctrl_pkg::if2ctrl_t;
  import core_pkg::INSTR_WIDTH;
  import core_pkg::ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::OP_WIDTH;
  import core_pkg::AUIPC_OP;
  import core_pkg::STORE_OP;
  import core_pkg::LUI_OP;
  import core_pkg::BRANCH_OP;
  import core_pkg::JAL_OP;
  import core_pkg::REGW_OP;
  import core_pkg::REG_OP;
  import core_pkg::SYS_OP;
/**/

#(
) (

    /// System clock
    input  wire                            clk_i,
    /// System active low reset
    input  wire                            rstn_i,
    /// Current program counter (address used for the memory request)
    input  wire      [ADDR_WIDTH  - 1 : 0] pc_i,
    /// Decode-stage ready. When low, fetch is stalled (no new request)
    input  wire                            decode_ready_i,
    /// Instruction valid flag
    output wire                            valid_o,
    /// IF->ID payload: fetched instruction and its associated PC
    output if2id_t                         if2id_o,
    /// IF->CTRL payload (rs1/rs1/csr_raddr)
    output if2ctrl_t                       if2ctrl_o,
    /// Address transfer request
    output wire                            req_o,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Grant: Ready to accept address transfert
    input  wire                            gnt_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// Address for memory access
    output wire      [ADDR_WIDTH  - 1 : 0] addr_o,
    /// Response transfer valid
    input  wire                            rvalid_i,
    /// Read data
    input  wire      [INSTR_WIDTH - 1 : 0] rdata_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Error response
    input  wire                            err_i
    /* verilator lint_on UNUSEDSIGNAL */
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// Source register 1 extracted from the fetched instruction
  logic [ RF_ADDR_WIDTH - 1 : 0] rs1;
  /// Source register 2 extracted from the fetched instruction
  logic [ RF_ADDR_WIDTH - 1 : 0] rs2;
  /// Control & Status register read address extracted from the fetched instruction
  logic [CSR_ADDR_WIDTH - 1 : 0] csr_raddr;

  /* registers */
  /// Registered memory "hit": indicates that `rdata` is valid in this cycle
  reg                            rvalid_q;
  /// Registered PC matching the instruction returned in this cycle
  reg   [    ADDR_WIDTH - 1 : 0] pc_q;
  /********************             ********************/

  /// Instruction memory address is driven directly by the current PC
  assign addr_o = pc_i;

  /// Issue a read request only when decode can accept the next instruction
  /// When `decode_ready_i` is low, IF stalls and does not advance
  assign req_o  = decode_ready_i && rstn_i;

  /// Synchronous instruction memory handshake
  /*!
  * `rvalid_i` is asserted in the request cycle if the instruction will be
  * available in the next cycle on `rdata_i`.
  *
  * We register `rvalid` so `valid_o` aligns with `if2id_o.instr` / `if2id_o.pc`.
  */
  always_ff @(posedge clk_i) begin : mem_ack
    if (!rstn_i) begin
      rvalid_q <= 1'b0;
    end
    else begin
      if (rvalid_i) begin
        rvalid_q <= 1'b1;
      end
      else if (decode_ready_i) begin
        rvalid_q <= 1'b0;
      end
    end
  end

  /// Ouptut driven by mem_ack
  assign valid_o = rvalid_q;


  /// PC alignment for a synchronous memory
  /*!
  * Because `pc_i` may advance to request the next instruction while the
  * current instruction returns, we register the request PC so the PC forwarded
  * to decode matches `rdata_i`.
  */
  always_ff @(posedge clk_i) begin : pc
    if (decode_ready_i) begin
      pc_q <= pc_i;
    end
  end

  /// Output driven by pc
  assign if2id_o.pc    = pc_q;


  /// Forward the instruction data from memory
  assign if2id_o.instr = rdata_i;



  /// Instruction pre-decode for hazard detection
  /*!
  * Extract rs1/rs2/rd early so the hazard controller can check dependencies
  * without waiting for the full decode logic, reducing critical path pressure.
  *
  * Notes:
  * - Some opcodes do not use rs1 (e.g., LUI/AUIPC/JAL) -> rs1 = 0
  * - Some opcodes do not use rs2 (e.g., I-type loads/ALU imm) -> rs2 = 0
  * - Some opcodes do not read CSR (e.g., stores/branches) -> csr_raddr = 0
  */
  always_comb begin : pre_decode
    if ((rdata_i[6:0] == AUIPC_OP) || (rdata_i[6:0] == LUI_OP) || (rdata_i[6:0] == JAL_OP) ||
        ((rdata_i[6:0] == SYS_OP) && rdata_i[14] && |rdata_i[14:12])) begin
      rs1 = '0;
    end
    else begin
      rs1 = rdata_i[19:15];
    end

    if ((rdata_i[6:0] == STORE_OP) || (rdata_i[6:0] == REG_OP) || (rdata_i[6:0] == REGW_OP) ||
        (rdata_i[6:0] == BRANCH_OP)) begin
      rs2 = rdata_i[24:20];
    end
    else begin
      rs2 = '0;
    end

    if (rdata_i[6:0] == SYS_OP && |rdata_i[14:12]) begin
      csr_raddr = rdata_i[31:20];
    end
    else begin
      csr_raddr = '0;
    end
  end

  /// Output driven by pre_decode
  assign if2ctrl_o.rs1       = rs1;
  /// Output driven by pre_decode
  assign if2ctrl_o.rs2       = rs2;
  /// Output driven by pre_decode
  assign if2ctrl_o.csr_raddr = csr_raddr;



endmodule

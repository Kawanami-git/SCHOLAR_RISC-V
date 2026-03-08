// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe.sv
\brief      SCHOLAR RISC-V core execution stage
\author     Kawanami
\date       07/03/2026
\version    1.0

\details
  Execution (Exe) stage of the SCHOLAR RISC-V pipeline.

  The Exe stage consumes the decoded micro-operation (uop) + operands from ID,
  performs the arithmetic/logic work through the ALU, and forwards:
    - ALU result + writeback/memory control to the MEM stage
    - PC-related information (pc/op3/pc_ctrl + ALU result) to the Pipeline Controller

  This stage is split into:
    - `exe.sv`     : stage wrapper and ID->EXE input register
    - `alu.sv`     : arithmetic / logic / compare operations

  Handshake / back-pressure:
    - `ready_o` is asserted when the next stage (MEM) is ready (`mem_ready_i`).
      This means EXE can accept a new ID->EXE payload only when MEM
      can accept the current one.
    - The ID->EXE payload register is updated only on `decode_valid_i && mem_ready_i`.
    - When MEM is ready but ID does not provide a valid payload, EXE injects a
      bubble (NOP-like uop) by clearing the register. This prevents re-executing
      the previous uop.

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section exe_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 07/03/2026 | Kawanami   | Initial version of the module.            |
********************************************************************************
*/

module exe

  /*!
* Import useful packages.
*/
  import id2exe_pkg::id2exe_t;
  import wb2exe_pkg::wb2exe_t;
  import exe2mem_pkg::exe2mem_t;
  import exe2ctrl_pkg::exe2ctrl_t;
  import exe2id_pkg::exe2id_t;
  import core_pkg::DATA_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::SEL_MEM;
  import core_pkg::SEL_WB;
  import core_pkg::CSR_IDLE;
/**/

#(
) (
    /// System clock
    input  wire       clk_i,
    /// System active low reset
    input  wire       rstn_i,
    /// ID stage valid flag
    input  wire       decode_valid_i,
    /// Mem stage ready flag (back-pressure from the next stage)
    input  wire       mem_ready_i,
    /// Exe stage ready (1: can accept a new ID->EXE payload)
    output wire       ready_o,
    /// Exe result valid flag (1: ALU result and forwarded fields are valid)
    output wire       valid_o,
    /// Decode to Exe payload (operands + control micro-ops)
    input  id2exe_t   id2exe_i,
    /// Writeback to Exe bypass
    input  wb2exe_t   wb2exe_i,
    /// Exe to Decode bypass
    output exe2id_t   exe2id_o,
    /// Exe to Mem payload (operands + control micro-ops)
    output exe2mem_t  exe2mem_o,
    /// Exe to PC payload (operands + control micro-ops)
    output exe2ctrl_t exe2ctrl_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// ALU output value
  wire     [DATA_WIDTH - 1 : 0] alu_out;
  /// ALU valid flag
  wire                          valid;
  /// First operand
  wire     [DATA_WIDTH - 1 : 0] op1;
  /// Second operand
  wire     [DATA_WIDTH - 1 : 0] op2;
  /* registers */
  /// ID->EXE payload register
  id2exe_t                      id2exe_q;
  /********************             ********************/

  /// ID->EXE pipeline register
  /*!
  * Capture when:
  *  - ID provides a valid uop (`decode_valid_i`)
  *  - MEM is ready to accept the current EXE output (`mem_ready_i`)
  *
  * Stall behavior:
  *  - If `mem_ready_i` is low, EXE holds `id2exe_q` (no overwrite).
  *
  * NOP injection:
  *  - If `mem_ready_i` is high but `decode_valid_i` is low, EXE clears `id2exe_q`
  *    to propagate a NOP-like uop downstream. This prevents reusing the previous
  *    uop data when no new instruction is available.
  */
  always_ff @(posedge clk_i) begin : id_exe
    if (!rstn_i) begin
      id2exe_q <= '0;
    end
    else if (decode_valid_i && mem_ready_i) begin
      id2exe_q <= id2exe_i;
    end
    else if (mem_ready_i) begin
      id2exe_q <= '0;
    end
  end

  /// EXE is ready if Mem consume current micro-ops
  assign ready_o              = mem_ready_i;
  /// Forward op3 to Mem
  assign exe2mem_o.op3        = id2exe_q.exe_op3_sel == SEL_WB ? wb2exe_i.bypass : id2exe_q.op3;
  /// Provide ALU out to Mem
  assign exe2mem_o.exe_out    = alu_out;
  /// Forward rd to Mem
  assign exe2mem_o.rd         = id2exe_q.rd;
  /// Forward CSR waddr to Mem
  assign exe2mem_o.csr_waddr  = id2exe_q.csr_waddr;
  /// Forward Mem control signal to Mem
  assign exe2mem_o.mem_ctrl   = id2exe_q.mem_ctrl;
  /// Forward GPR control signal to Mem
  assign exe2mem_o.gpr_ctrl   = id2exe_q.gpr_ctrl;
  /// Forward CSR control signal to Mem
  assign exe2mem_o.csr_ctrl   = id2exe_q.csr_ctrl;
  // Forward mem_op3_sel to Mem
  // assign exe2mem_o.mem_op3_sel = id2exe_q.mem_op3_sel;
  /// Forward op3 to PC
  assign exe2ctrl_o.op3       = id2exe_q.op3;
  /// Forward instruction pc to Controller
  assign exe2ctrl_o.pc        = id2exe_q.pc;
  /// Forward ALU out to Controller
  assign exe2ctrl_o.exe_out   = alu_out;
  /// Forward PC control signal to Controller
  assign exe2ctrl_o.pc_ctrl   = id2exe_q.pc_ctrl;
  /// Forward instruction rd to Controller
  assign exe2ctrl_o.rd        = id2exe_q.rd;
  /// Forward instruction csr write address to Controller
  assign exe2ctrl_o.csr_waddr = id2exe_q.csr_waddr;
  /// Forward instruction csr control to Controller
  assign exe2ctrl_o.csr_ctrl  = id2exe_q.csr_ctrl;
  /// Generate is_load flag for controller bypass
  assign exe2ctrl_o.is_load   = |id2exe_q.mem_ctrl[MEM_CTRL_WIDTH-2:0];
  /// Output driven by ALU
  assign valid_o              = valid;
  /// Generate bypass for Decode
  assign exe2id_o.bypass      = id2exe_q.csr_ctrl == CSR_IDLE ? alu_out : id2exe_q.op3;
  /// ALU first operand
  assign op1                  = id2exe_q.op1;
  // assign op1                   = id2exe_q.exe_op1_sel == SEL_WB ? wb2exe_i.bypass : id2exe_q.op1;
  /// ALU second operand
  assign op2                  = id2exe_q.op2;
  // assign op2                   = id2exe_q.exe_op2_sel == SEL_WB ? wb2exe_i.bypass : id2exe_q.op2;

  /// ALU instantiation
  /*!
  * ALU computes the operation selected by `id2exe_q.exe_ctrl` using op1/op2.
  *
  * Note:
  * - If `id2exe_q` is cleared (bubble), `exe_ctrl` becomes 0.
  *   Ensure ALU interprets ctrl=0 as a NOP operation and deasserts `valid_o`.
  */
  alu #() alu (
      .rstn_i (rstn_i),
      .valid_o(valid),
      .op1_i  (op1),
      .op2_i  (op2),
      .ctrl_i (id2exe_q.exe_ctrl),
      .out_o  (alu_out)
  );




endmodule

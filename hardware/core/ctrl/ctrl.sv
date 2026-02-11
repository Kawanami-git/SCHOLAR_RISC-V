// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       ctrl.sv
\brief      SCHOLAR RISC-V core control (front-end control & hazards)
\author     Kawanami
\date       28/01/2026
\version    1.2

\details
  The CTRL stage coordinates front-end flow control and simple hazard handling.
  It is responsible for:
    - Control-flow redirection management (flush on taken branch / jump)
    - RAW hazard detection for GPR and CSR sources (no bypassing)
    - Program Counter (PC) update enable and redirect control

  Control-flow changes are resolved in EXE. When a redirect is required, CTRL
  asserts a one-cycle active-low flush (softresetn) to invalidate younger
  instructions in IF/ID/EXE and restart the front-end from the redirected PC.

  Data hazards are detected by comparing the decode-time source operands
  (rs1/rs2/csr_raddr) against the destination operands of in-flight instructions
  in EXE/MEM/WB. When a match is found, CTRL reports the corresponding dirty
  flag to the decode stage to stall until the value becomes architecturally
  available.

\remarks
  - No forwarding/bypassing is implemented: any RAW dependency against EXE/MEM/WB
    stalls decode.
  - Register x0 is never considered dirty (matches against x0 are ignored).
  - CSR hazards are asserted only for instructions expected to write a CSR
    (csr_ctrl != CSR_IDLE).
  - Redirect/flush is gated by mem_ready_i to avoid discarding a control-flow
    instruction before it can leave EXE under back-pressure.

\section ctrl_version_history Version history
| Version | Date       | Author   | Description                                                                 |
|:-------:|:----------:|:---------|:----------------------------------------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami | Initial version of the module. |
| 1.1     | 10/01/2026 | Kawanami | Add non-perfect memory support in the controller by checking `mem_ready_i` before triggering the softreset. |
| 1.2     | 28/01/2026 | Kawanami | Improve readability using payload structs; refine GPR hazards; add CSR hazards. |
********************************************************************************
*/

module ctrl

  /*!
* Import useful packages.
*/
  import if2ctrl_pkg::if2ctrl_t;
  import exe2ctrl_pkg::exe2ctrl_t;
  import mem2ctrl_pkg::mem2ctrl_t;
  import wb2ctrl_pkg::wb2ctrl_t;
  import core_pkg::ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::PC_SET;
  import core_pkg::PC_ADD;
  import core_pkg::PC_COND;
  import core_pkg::CSR_IDLE;
/**/

#(
    /// Core boot/start address
    parameter logic [ADDR_WIDTH - 1 : 0] StartAddress = '0
) (
    /// System clock
    input  wire                        clk_i,
    /// System active-low reset
    input  wire                        rstn_i,
    /// Instruction memory hit handshake (request accepted; data available next cycle)
    input  wire                        i_m_hit_i,
    /// IF->CTRL payload (pre-decoded sources for hazard detection)
    input  if2ctrl_t                   if2ctrl_i,
    /// EXE->CTRL payload (control-flow resolution + in-flight destination tracking)
    input  exe2ctrl_t                  exe2ctrl_i,
    /// MEM->CTRL payload (in-flight destination tracking)
    input  mem2ctrl_t                  mem2ctrl_i,
    /// WB->CTRL payload (in-flight destination tracking)
    input  wb2ctrl_t                   wb2ctrl_i,
    /// rs1 dependency flag (1 => source not yet ready)
    output wire                        rs1_dirty_o,
    /// rs2 dependency flag (1 => source not yet ready)
    output wire                        rs2_dirty_o,
    /// CSR dependency flag (1 => source not yet ready)
    output wire                        csr_dirty_o,
    /// Decode ready flag (1: ready  0: not ready)
    input  wire                        decode_ready_i,
    /// Memory ready flag (1: ready  0: not ready)
    input  wire                        mem_ready_i,
    /// One-cycle flush (active-low) for control-flow redirection
    output wire                        softresetn_o,
    /// Program Counter
    output wire       [ADDR_WIDTH-1:0] pc_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// PC update enable flag
  logic     pc_en;
  /// One-cycle flush (active-low) for control-flow redirection
  logic     softresetn;
  /// rs1 dependency flag
  logic     rs1_dirty;
  /// rs2 dependency flag
  logic     rs2_dirty;
  /// CSR dependency flag
  logic     csr_dirty;

  /* registers */
  /// IF->CTRL payload register (holds decode sources stable while decode stalls)
  if2ctrl_t if2ctrl_q;
  /********************             ********************/

  /// IF->CTRL payload registration
  /*!
  * Captures pre-decoded source operands (rs1/rs2/csr_raddr) when decode is ready.
  * While the instruction is captured by decode, the source operands are
  * captured by fetch_reg. It ensures that the registered source operands
  * correspond to the instruction in decode.
  *
  * After a jump, while fetch is flushed, decode, which is flushed
  * one cycle later, captures the if2id bundle.
  * However, the instruction is not valid anymore (jump = new instruction path).
  * To avoid unattended stalls due to the invalid instruction in decode,
  * `if2ctrl_q` is flushed at the same time than fetch.
  *
  * It forces gpr_data_hazard to compare older instructions
  * `rd` and `csr_waddr` with zeroes, preventing the dirty flags
  * to raise.
  */
  always_ff @(posedge clk_i) begin : fetch_reg
    if (!rstn_i || !softresetn) begin
      if2ctrl_q <= '0;
    end
    else if (decode_ready_i) begin
      if2ctrl_q <= if2ctrl_i;
    end
  end


  /// Control hazard (front-end flush on redirect)
  /*!
  * Jumps and taken branches are resolved in EXE. When a redirect is required,
  * younger instructions already present in IF/ID/EXE belong to the wrong path.
  *
  * CTRL generates a one-cycle active-low flush (softresetn) to invalidate
  * front-end stages and restart fetching from the redirected PC.
  *
  * The flush is asserted only when MEM is ready (mem_ready_i). Under back-pressure,
  * the control-flow instruction must not be flushed away before it is allowed to
  * progress to MEM, otherwise its architectural effect could be lost.
  */
  always_comb begin : control_hazard
    if (!rstn_i) begin
      softresetn = 1'b1;
    end
    else if (mem_ready_i && (exe2ctrl_i.pc_ctrl == PC_SET || exe2ctrl_i.pc_ctrl == PC_ADD ||
                             (exe2ctrl_i.pc_ctrl == PC_COND && exe2ctrl_i.exe_out[0]))) begin
      softresetn = 1'b0;
    end
    else begin
      softresetn = 1'b1;
    end
  end

  /// Output driven by control_hazard
  assign softresetn_o = softresetn;


  /// GPR RAW hazard detection
  /*!
  * Detects RAW hazards by comparing decode source registers (rs1/rs2) against the
  * destination register of in-flight instructions in EXE/MEM/WB.
  *
  * Matches against x0 are ignored to avoid stalling on unused operands.
  */
  always_comb begin : gpr_data_hazard
    if ((if2ctrl_q.rs1 == exe2ctrl_i.rd || if2ctrl_q.rs1 == mem2ctrl_i.rd ||
         if2ctrl_q.rs1 == wb2ctrl_i.rd) && if2ctrl_q.rs1 != '0) begin
      rs1_dirty = 1'b1;
    end
    else begin
      rs1_dirty = 1'b0;
    end

    if ((if2ctrl_q.rs2 == exe2ctrl_i.rd || if2ctrl_q.rs2 == mem2ctrl_i.rd ||
         if2ctrl_q.rs2 == wb2ctrl_i.rd) && if2ctrl_q.rs2 != '0) begin
      rs2_dirty = 1'b1;
    end
    else begin
      rs2_dirty = 1'b0;
    end
  end

  /// Output driven by gpr_data_hazard
  assign rs1_dirty_o = rs1_dirty;
  /// Output driven by gpr_data_hazard
  assign rs2_dirty_o = rs2_dirty;


  /// CSR RAW hazard detection
  /*!
  * Detects CSR dependencies by comparing the decode CSR read address (csr_raddr)
  * against CSR write addresses of in-flight instructions in EXE/MEM/WB.
  *
  * A CSR is considered pending only if the in-flight instruction is expected to
  * write a CSR (csr_ctrl != CSR_IDLE). Reads of CSR address 0 are ignored.
  */
  always_comb begin : csr_data_hazard
    if (!rstn_i) begin
      csr_dirty = 1'b0;
    end
    else if (if2ctrl_q.csr_raddr == '0) begin
      csr_dirty = 1'b0;
    end
    else begin
      if (((exe2ctrl_i.csr_ctrl != CSR_IDLE) && (exe2ctrl_i.csr_waddr == if2ctrl_q.csr_raddr)) ||
          ((mem2ctrl_i.csr_ctrl != CSR_IDLE) && (mem2ctrl_i.csr_waddr == if2ctrl_q.csr_raddr)) ||
          ((wb2ctrl_i.csr_ctrl != CSR_IDLE) && (wb2ctrl_i.csr_waddr == if2ctrl_q.csr_raddr))) begin
        csr_dirty = 1'b1;
      end
      else begin
        csr_dirty = 1'b0;
      end
    end
  end

  /// Output driven by csr_data_hazard
  assign csr_dirty_o = csr_dirty;


  /// PC update enable
  /*!
  * PC advances on an instruction fetch accept (i_m_hit_i) or when forcing a
  * redirect/flush (!softresetn). This allows the PC to update immediately when
  * a control-flow change is committed.
  */
  assign pc_en       = i_m_hit_i || !softresetn;


  /// Program Counter unit
  /*!
  * Updates the current PC according to the PC control micro-op and EXE operands.
  */
  pc #(
      .StartAddress(StartAddress)
  ) pc (
      .clk_i    (clk_i),
      .rstn_i   (rstn_i),
      .en_i     (pc_en),
      .ctrl_i   (exe2ctrl_i.pc_ctrl),
      .pc_i     (exe2ctrl_i.pc),
      .exe_out_i(exe2ctrl_i.exe_out),
      .op3_i    (exe2ctrl_i.op3),
      .pc_o     (pc_o)
  );

endmodule

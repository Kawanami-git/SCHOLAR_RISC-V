// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       ctrl.sv
\brief      SCHOLAR RISC-V core controller (front-end control and hazard handling)
\author     Kawanami
\date       07/03/2026
\version    1.0
\details
  The CTRL stage coordinates front-end flow control and hazard handling for the
  SCHOLAR RISC-V in-order pipeline.

  Responsibilities:
    - Control-flow redirection management (flush on taken branch / jump).
    - Program Counter (PC) update enable and redirect control.
    - RAW hazard detection for the GPR file (rs1/rs2).
    - RAW hazard detection for CSR dependencies (csr_raddr vs in-flight csr_waddr).
    - Forwarding (bypass) selection and stall signaling when forwarding is not possible.

  Control-flow changes are resolved in Exe. When a redirect is required, CTRL
  asserts a one-cycle active-low flush (`softresetn`) to invalidate younger
  instructions in the front-end and restart fetching from the redirected PC.

  Data hazards are detected by comparing decode-time sources (rs1/rs2/csr_raddr)
  against the destination fields of in-flight instructions in Exe/Mem/Writeback.
  When a match is found, the corresponding source is marked dirty.
  The bypass selection logic attempts to resolve the hazard by selecting the
  youngest available producer (priority: Exe -> Mem -> Writeback). If the value
  is not available (e.g. load-use), CTRL propagates dirty flags to Decode to
  request a stall.

\remarks
  - Forwarding is implemented with a frequency-driven trade-off: some late-stage
    bypasses may be disabled to improve Fmax.
  - Register x0 is never considered dirty (matches against x0 are ignored).
  - CSR hazards are asserted only for CSR-update instructions (`csr_ctrl == CSR_ALU`).
  - Redirect/flush is gated by `mem_ready_i` to avoid discarding a control-flow
    instruction before it can leave Exe under back-pressure.
  - Some commented-out paths are kept as hooks for future/full forwarding support.

\section ctrl_version_history Version history
| Version | Date       | Author   | Description                    |
|:-------:|:----------:|:---------|:-------------------------------|
| 1.0     | 07/03/2026 | Kawanami | Initial version of the module. |
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
  import ctrl2id_pkg::ctrl2id_t;
  import core_pkg::ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::PC_SET;
  import core_pkg::PC_ADD;
  import core_pkg::PC_COND;
  import core_pkg::CSR_IDLE;
  import core_pkg::CSR_ALU;
  import core_pkg::SEL_CTRL_WIDTH;
  import core_pkg::SEL_NONE;
  import core_pkg::SEL_EXE;
  import core_pkg::SEL_MEM;
  import core_pkg::SEL_WB;
/**/

#(
    /// Core boot/start address
    parameter logic [ADDR_WIDTH - 1 : 0] StartAddress = '0
) (
    /// System clock
    input  wire                        clk_i,
    /// System active-low reset
    input  wire                        rstn_i,
    /// Instruction memory handshake (request accepted; data available next cycle)
    input  wire                        imem_rvalid_i,
    /// IF->CTRL payload (pre-decoded sources for hazard detection)
    input  if2ctrl_t                   if2ctrl_i,
    /// IF->ID payload valid flag
    input  wire                        fetch_valid_i,
    /// EXE->CTRL payload (control-flow resolution + in-flight destination tracking)
    input  exe2ctrl_t                  exe2ctrl_i,
    /// MEM->CTRL payload (in-flight destination tracking)
    input  mem2ctrl_t                  mem2ctrl_i,
    /// WB->CTRL payload (in-flight destination tracking)
    input  wb2ctrl_t                   wb2ctrl_i,
    /// CTRL->ID payload (dirty flags + bypass control)
    output ctrl2id_t                   ctrl2id_o,
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
  logic                              pc_en;
  /// One-cycle flush (active-low) for control-flow redirection
  logic                              softresetn;
  /// rs1 dependency flag
  logic                              rs1_dirty;
  /// rs2 dependency flag
  logic                              rs2_dirty;
  /// CSR dependency flag
  logic                              csr_dirty;
  /// Decode operand 1 select signal
  logic     [SEL_CTRL_WIDTH - 1 : 0] decode_op1_sel;
  /// Decode operand 2 select signal
  logic     [SEL_CTRL_WIDTH - 1 : 0] decode_op2_sel;
  /// Decode operand 3 select signal
  logic     [SEL_CTRL_WIDTH - 1 : 0] decode_op3_sel;

  // Exe operand 1 select signal
  // logic     [SEL_CTRL_WIDTH - 1 : 0] exe_op1_sel;

  // Exe operand 2 select signal
  // logic     [SEL_CTRL_WIDTH - 1 : 0] exe_op2_sel;

  /// Exe operand 3 select signal
  logic     [SEL_CTRL_WIDTH - 1 : 0] exe_op3_sel;

  // Mem operand 3 select signal
  // logic     [SEL_CTRL_WIDTH - 1 : 0] mem_op3_sel;

  /* registers */
  /// IF->CTRL payload register (holds decode sources stable while decode stalls)
  if2ctrl_t                          if2ctrl_q;
  /********************             ********************/

  /// IF->CTRL payload registration
  /*!
  * Latches IF pre-decode fields (rs1/rs2/csr_raddr/is_store) so hazard detection
  * remains stable while Decode stalls.
  *
  * The register is updated only when both `fetch_valid_i` and `decode_ready_i`
  * are asserted, ensuring `if2ctrl_q` always corresponds to the instruction
  * currently entering Decode.
  *
  * On a front-end flush (`!softresetn`), `if2ctrl_q` is cleared to prevent
  * spurious dirty flags caused by invalid (flushed) Decode contents.
  */
  always_ff @(posedge clk_i) begin : fetch_reg
    if (!rstn_i || !softresetn) begin
      if2ctrl_q <= '0;
    end
    else if (decode_ready_i && fetch_valid_i) begin
      if2ctrl_q <= if2ctrl_i;
    end
    else if (decode_ready_i) begin
      if2ctrl_q <= '0;
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

  /// Bypass selection logic (forwarding control)
  /*!
  * Computes operand-selection signals used by Decode (and partially by Exe) to
  * resolve RAW hazards without stalling when possible.
  *
  * Generated controls:
  *  - `decode_op1_sel`: source for Decode operand `op1` (rs1).
  *  - `decode_op2_sel`: source for Decode operand `op2` (rs2, non-store).
  *  - `decode_op3_sel`: source for Decode operand `op3` (store data for stores).
  *  - `exe_op3_sel`   : late store-data capture control in Exe (Writeback -> Exe for op3).
  *
  * Selection policy:
  *  - Youngest producer wins (priority: Exe -> Mem -> Writeback).
  *  - Exe/Mem cannot be selected as bypass sources for loads (`is_load == 1`)
  *    because load data is only available at Writeback.
  *
  * Store special-case:
  *  - For stores, `rs2` is treated as store data and mapped to `op3`.
  *    Therefore rs2 hazards drive `decode_op3_sel` instead of `decode_op2_sel`.
  *
  * Load -> Store special-case (late capture):
  *  - If the store is in Decode while the producer load is in Mem, the store data
  *    is not yet available. The controller asserts `exe_op3_sel = SEL_WB` so the
  *    store captures `wb_wdata` in Exe and carries it to Mem through `exe2mem.op3`.
  */
  always_comb begin : bypass
    decode_op1_sel = SEL_NONE;
    decode_op2_sel = SEL_NONE;
    decode_op3_sel = SEL_NONE;
    // exe_op1_sel    = SEL_NONE;
    // exe_op2_sel    = SEL_NONE;
    exe_op3_sel    = SEL_NONE;
    // mem_op3_sel    = SEL_NONE;

    if (rs1_dirty) begin
      if ((if2ctrl_q.rs1 == exe2ctrl_i.rd)) begin
        if (!exe2ctrl_i.is_load) begin
          decode_op1_sel = SEL_EXE;
        end
      end
      else if ((if2ctrl_q.rs1 == mem2ctrl_i.rd)) begin
        if (!mem2ctrl_i.is_load) begin
          decode_op1_sel = SEL_MEM;
        end
        else begin
          // exe_op1_sel = SEL_WB;
        end
      end
      else if (if2ctrl_q.rs1 == wb2ctrl_i.rd) begin
        decode_op1_sel = SEL_WB;
      end
    end

    if (rs2_dirty) begin
      if ((if2ctrl_q.rs2 == exe2ctrl_i.rd)) begin
        if (!exe2ctrl_i.is_load) begin
          if (if2ctrl_q.is_store) decode_op3_sel = SEL_EXE;
          else decode_op2_sel = SEL_EXE;
        end
        else begin
          // if (if2ctrl_q.is_store) mem_op3_sel = SEL_WB;
        end
      end
      else if ((if2ctrl_q.rs2 == mem2ctrl_i.rd)) begin
        if (!mem2ctrl_i.is_load) begin
          if (if2ctrl_q.is_store) decode_op3_sel = SEL_MEM;
          else decode_op2_sel = SEL_MEM;
        end
        else begin
          if (if2ctrl_q.is_store) exe_op3_sel = SEL_WB;
          // else exe_op2_sel = SEL_WB;
        end
      end

      else if (if2ctrl_q.rs2 == wb2ctrl_i.rd) begin
        if (if2ctrl_q.is_store) decode_op3_sel = SEL_WB;
        else decode_op2_sel = SEL_WB;
      end
    end
  end

  /// Output driven by bypass
  assign ctrl2id_o.rs1_dirty = rs1_dirty && !(|decode_op1_sel);
  // assign ctrl2id_o.rs1_dirty      = rs1_dirty && !(|decode_op1_sel) && !(|exe_op1_sel);

  /// Output driven by bypass
  assign
      ctrl2id_o.rs2_dirty = rs2_dirty && !(|decode_op2_sel || |decode_op3_sel) && !(|exe_op3_sel);
  // assign ctrl2id_o.rs2_dirty      = rs2_dirty && !(|decode_op2_sel || |decode_op3_sel) && !(|exe_op2_sel) && !(|exe_op3_sel) && !(|mem_op3_sel);


  /// Output driven by bypass
  assign ctrl2id_o.decode_op1_sel = decode_op1_sel;
  /// Output driven by bypass
  assign ctrl2id_o.decode_op2_sel = decode_op2_sel;
  /// Output driven by bypass
  assign ctrl2id_o.decode_op3_sel = decode_op3_sel;

  // Output driven by bypass
  // assign ctrl2id_o.exe_op1_sel = exe_op1_sel;

  // Output driven by bypass
  // assign ctrl2id_o.exe_op2_sel = exe_op2_sel;

  /// Output driven by bypass
  assign ctrl2id_o.exe_op3_sel = exe_op3_sel;

  // Output driven by bypass
  // assign ctrl2id_o.mem_op3_sel = mem_op3_sel;

  /// CSR RAW hazard detection
  /*!
  * Detects CSR dependencies by comparing the decode CSR read address (csr_raddr)
  * against CSR write addresses of in-flight instructions in EXE/MEM/WB.
  *
  * A CSR is considered pending only if the in-flight instruction is expected to
  * write a CSR (csr_ctrl == CSR_ALU). Reads of CSR address 0 are ignored.
  */
  always_comb begin : csr_data_hazard
    if (!rstn_i) begin
      csr_dirty = 1'b0;
    end
    else if (if2ctrl_q.csr_raddr == '0) begin
      csr_dirty = 1'b0;
    end
    else begin
      if (((exe2ctrl_i.csr_ctrl == CSR_ALU) && (exe2ctrl_i.csr_waddr == if2ctrl_q.csr_raddr)) ||
          ((mem2ctrl_i.csr_ctrl == CSR_ALU) && (mem2ctrl_i.csr_waddr == if2ctrl_q.csr_raddr)) ||
          ((wb2ctrl_i.csr_ctrl == CSR_ALU) && (wb2ctrl_i.csr_waddr == if2ctrl_q.csr_raddr))) begin
        csr_dirty = 1'b1;
      end
      else begin
        csr_dirty = 1'b0;
      end
    end
  end

  /// Output driven by csr_data_hazard
  assign ctrl2id_o.csr_dirty = csr_dirty;


  /// PC update enable
  /*!
  * PC advances on an instruction fetch accept (imem_rvalid_i) or when forcing a
  * redirect/flush (!softresetn). This allows the PC to update immediately when
  * a control-flow change is committed.
  */
  assign pc_en               = imem_rvalid_i || !softresetn;


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



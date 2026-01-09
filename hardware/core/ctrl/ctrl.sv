// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       ctrl.sv
\brief      SCHOLAR RISC-V core control stage (front-end control & hazards)
\author     Kawanami
\date       19/12/2025
\version    1.0

\details
  Control stage in charge of:
  - Managing front-end flow control (soft reset on control-flow changes)
  - Tracking RAW hazards through a small "dirty" scoreboarding table
  - Driving the Program Counter (PC) update path

\remarks
- TODO: .

\section ctrl_version_history Version history
| Version | Date       | Author   | Description                    |
|:-------:|:----------:|:---------|:-------------------------------|
| 1.0     | 19/12/2025 | Kawanami | Initial version of the module. |
********************************************************************************
*/

/*!
* Import useful packages.
*/
import exe2pc_pkg::exe2pc_t;
import core_pkg::ADDR_WIDTH;
import core_pkg::RF_ADDR_WIDTH;
import core_pkg::ADDR_WIDTH;
import core_pkg::NB_GPR;
import core_pkg::PC_SET;
import core_pkg::PC_ADD;
import core_pkg::PC_COND;
/**/

module ctrl #(
    /// Core boot/start address
    parameter logic [ADDR_WIDTH - 1 : 0] StartAddress = '0
) (
    /// System clock
    input  wire                         clk_i,
    /// System active-low reset
    input  wire                         rstn_i,
    /// Instruction memory hit (current PC instruction fetched)
    input  wire                         i_m_hit_i,
    /// EXE->PC payload (PC control + operands)
    input  exe2pc_t                     exe2pc_i,
    /// Instruction rs1 (pre-decode from fetch)
    input  wire     [RF_ADDR_WIDTH-1:0] rs1_i,
    /// rs1 dependency flag (1 => source not yet ready)
    output wire                         rs1_dirty_o,
    /// Instruction rs2 (pre-decode from fetch)
    input  wire     [RF_ADDR_WIDTH-1:0] rs2_i,
    /// rs2 dependency flag (1 => source not yet ready)
    output wire                         rs2_dirty_o,
    /// Instruction destination register (pre-decode from fetch)
    input  wire     [RF_ADDR_WIDTH-1:0] fetch_rd_i,
    /// Decode ready flag (1: ready  0: not ready)
    input  wire                         decode_ready_i,
    /// Decode valid flag (1: valid  0: not valid)
    input  wire                         decode_valid_i,
    /// One-cycle soft reset (active-low) for taken branch handling
    output wire                         softresetn_o,
    /// Destination register (from writeback)
    input  wire     [RF_ADDR_WIDTH-1:0] wb_rd_i,
    /// Program Counter
    output wire     [   ADDR_WIDTH-1:0] pc_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  /// small per-GPR counter (0..3)
  localparam int BUSY_WIDTH = 2;
  /* functions */

  /* wires */
  /// PC update enable flag
  logic                         pc_en;
  /// One-cycle soft reset (active-low) for taken branch handling
  logic                         softresetn;

  /* registers */
  /// Dirty counter for each GPR (!=0 rgister is dirty and cannot be used)
  reg   [       BUSY_WIDTH-1:0] dirty_q      [NB_GPR-1:0];
  /// Fetch rd (pre-decode) register
  reg   [RF_ADDR_WIDTH - 1 : 0] fetch_rd_q;
  /// Fetch rs1 (pre-decode) register
  reg   [RF_ADDR_WIDTH - 1 : 0] fetch_rs1_q;
  /// Fetch rs2 (pre-decode) register
  reg   [RF_ADDR_WIDTH - 1 : 0] fetch_rs2_q;
  /********************             ********************/

  /// Fetch data registration
  /*!
  * Captures pre-decoded rs1/rs2/rd to
  * detect any data hazard.
  */
  always_ff @(posedge clk_i) begin : fetch_reg
    if (!rstn_i) begin
      fetch_rd_q  <= '0;
      fetch_rs1_q <= '0;
      fetch_rs2_q <= '0;
    end
    else if (decode_ready_i) begin
      fetch_rd_q  <= fetch_rd_i;
      fetch_rs1_q <= rs1_i;
      fetch_rs2_q <= rs2_i;
    end
  end



  /// Control Hazard
  /*!
  * This block handles the branch management
  * of the pipeline.
  * If a taken branch is detected, the controller
  * applies a reset on fetch, decode & exe stages
  * to reinitialize them.
  * Thus, the pipiline does a clean restart using
  * the branch program counter.
  */
  always_comb begin : control_hazard
    if (!rstn_i) begin
      softresetn = 1'b1;
    end
    else if ((exe2pc_i.pc_ctrl == PC_SET || exe2pc_i.pc_ctrl == PC_ADD ||
                              (exe2pc_i.pc_ctrl == PC_COND && exe2pc_i.exe_out[0]))) begin
      softresetn = 1'b0;
    end
    else begin
      softresetn = 1'b1;
    end
  end

  /// Output driven by branch_handler
  assign softresetn_o = softresetn;

  /// Data hazard handler (RAW scoreboard)
  /*!
 * Tracks pending writes to GPRs and exposes hazards to decode.
 *
 * A register becomes dirty when an instruction that writes this GPR
 * has entered the pipeline but the write-back has not happened yet.
 * We increment a small counter per GPR on decode accept, and decrement
 * it when the write-back retires. A GPR is considered available when
 * its counter is zero.
 *
 * Scope & notes:
 *  - This handles RAW hazards only. WAW/WAR are naturally resolved by
 *    the single write-back port and in-order pipeline.
 *  - x0 is never written: it must remain non-dirty at all times.
 *  - Simultaneous decode-increment and WB-decrement on the same rd are
 *    guarded so the counter does not oscillate spuriously.
 *  - BUSY_WIDTH=2 is enough for current single-issue + single-cycle WB,
 *    but may be increased for deeper latencies; consider saturation if needed.
 *
 * Back-pressure:
 *  - rs1_dirty_o / rs2_dirty_o are raised when the current fetched sources
 *    are dirty; the decode stage can stall (and thus back-pressure fetch)
 *    until both become clean.
 */
  always_ff @(posedge clk_i) begin : data_hazard
    if (!rstn_i) begin
      for (int i = 0; i < NB_GPR; i++) dirty_q[i] <= '0;
    end
    else begin
      if ((fetch_rd_q != wb_rd_i) || !decode_valid_i || !softresetn) begin
        if (softresetn && decode_valid_i && fetch_rd_q != '0) begin
          dirty_q[fetch_rd_q] <= dirty_q[fetch_rd_q] + 1'b1;
        end

        if (wb_rd_i != '0) begin
          dirty_q[wb_rd_i] <= dirty_q[wb_rd_i] - 1'b1;
        end
      end
    end
  end

  /// Output driven by data_hazard_handler
  assign rs1_dirty_o = dirty_q[fetch_rs1_q] != '0;
  /// Output driven by data_hazard_handler
  assign rs2_dirty_o = dirty_q[fetch_rs2_q] != '0;

  /// PC update enabler
  /*!
  * PC can be updated if:
  *   - We are handling a control hazard
  *   - The current instruction has been fetched.
  */
  assign pc_en       = i_m_hit_i || !softresetn;

  /// PC instantiation
  /*!
  * `pc` updates the current PC value
  * according to control signals and operands.
  */
  pc #(
      .StartAddress(StartAddress)
  ) pc (

      .clk_i    (clk_i),
      .rstn_i   (rstn_i),
      .en_i     (pc_en),
      .ctrl_i   (exe2pc_i.pc_ctrl),
      .pc_i     (exe2pc_i.pc),
      .exe_out_i(exe2pc_i.exe_out),
      .op3_i    (exe2pc_i.op3),
      .pc_o     (pc_o)
  );

endmodule

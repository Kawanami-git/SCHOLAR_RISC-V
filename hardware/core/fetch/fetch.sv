// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       fetch.sv
\brief      SCHOLAR RISC-V core fetch module
\author     Kawanami
\date       20/09/2025
\version    1.1

\details
  This module implements the instruction fetch unit
  of the SCHOLAR RISC-V core.

  It retrieves the instruction located at
  `pc_next_i` via the memory interface.
  The instruction data is provided by `m_dout_i`
  and is considered valid when `m_hit_i` is high.

  As this is a single-cycle processor, instruction fetch
  and execution occur in the same cycle.
  Therefore, a new instruction must be fetched at every clock cycle.

  For memory-dependent operations (e.g., load/store),
  which require two cycles to be processed,
  it is essential that `pc_next_i` remains stable
  while the instruction completes to avoid fetching incorrect data.

  This fetch unit forms the entry point of the core pipeline,
  providing a steady flow of valid instructions to the decode unit.

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section fetch_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/07/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 20/09/2025 | Kawanami   | Remove packages.sv and provide useful metadata through parameters.<br>Update the whole file for coding style compliance.<br>Update the whole file comments for doxygen support. |
********************************************************************************
*/

module fetch #(
    /// Number of bits for addressing
    parameter int AddrWidth  = 32,
    /// Instructions width (in bits, usually 32)
    parameter int InstrWidth = 32
) (

    /// System clock
    input  wire                      clk_i,
    /// System active low reset
    input  wire                      rstn_i,
    /// Program counter (address of the next instruction to fetch)
    input  wire [AddrWidth  - 1 : 0] pc_next_i,
    /// Instruction
    output wire [InstrWidth - 1 : 0] instr_o,
    /// Instruction valid flag (1: valid, 0: invalid)
    output wire                      valid_o,
    /// Memory output data
    input  wire [InstrWidth - 1 : 0] m_dout_i,
    /// Memory hit flag (1: hit, 0: miss)
    input  wire                      m_hit_i,
    /// Memory address
    output wire [AddrWidth  - 1 : 0] m_addr_o,
    /// Memory read enable (1: enable, 0: disable)
    output wire                      m_rden_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// Fetched instruction
  logic [InstrWidth - 1 : 0] instr;

  /* registers */
  /// Instruction valid flag register
  reg                        valid_q;
  /// Memory read enable register
  reg                        m_rden_q;
  /********************             ********************/


  /// Memory access control signals
  /*!
  * In a single-cycle processor,
  * one instruction is fetched every cycle.
  * Therefore, `m_rden_o` is always asserted (except during reset).
  *
  * Since the fetch unit only performs instruction reads,
  * the memory address (`m_addr_o`) is always set to the value
  * of the program counter (`pc_next_i`),
  * which corresponds to the address of the next instruction.
  *
  * The instruction is considered valid (`valid_o`)
  * if the memory signals a hit (`m_hit_i`), and the system is not in reset.
  *
  * For instructions that take more than one cycle to complete
  * (e.g., memory accesses), the `pc_next_i` must remain stable
  * to ensure correct execution.
  */
  always_ff @(posedge clk_i) begin : mem_controller
    if (!rstn_i) begin
      valid_q  <= 1'b0;
      m_rden_q <= 1'b0;
    end
    else begin
      valid_q  <= m_hit_i;
      m_rden_q <= 1'b1;
    end
  end

  /// Output driven by mem_controller
  assign m_rden_o = m_rden_q;
  /// Provide to memory next instruction address
  assign m_addr_o = pc_next_i;
  /// Output driven mem_controller
  assign valid_o  = valid_q;

  /// Instruction selection logic
  /*!
  * - During reset (when `rstn_i` is low),
  *   the instruction is forced to '0 to prevent the decode unit
  *   from processing garbage data.
  *
  * - Once reset is deasserted,
  *   the fetched instruction from memory (`m_dout_i`) is forwarded
  *   to the decode unit.
  *
  * This ensures clean instruction flow
  * and avoids misbehavior during system initialization.
  */
  always_comb begin : instr_mux
    if (!rstn_i) begin
      instr = 'b0;
    end
    else begin
      instr = m_dout_i;
    end
  end

  /// Output driven by instr_mux
  assign instr_o = instr;

endmodule

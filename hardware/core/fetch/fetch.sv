// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       fetch.sv
\brief      SCHOLAR RISC-V core fetch module
\author     Kawanami
\date       13/02/2026
\version    1.2

\details
  This module implements the instruction fetch unit
  of the SCHOLAR RISC-V core.

  It retrieves the instruction located at
  `pc_next_i` via the memory interface.
  The instruction data is provided by `rdata_i`
  and is considered valid when `rvalid_i` is high.

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
| 1.2     | 13/02/2026 | Kawanami   | Replace custom interface with OBI standard. |
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
    /// Address transfer request
    output wire                      req_o,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Grant: Ready to accept address transfert
    input  wire                      gnt_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// Address for memory access
    output wire [AddrWidth  - 1 : 0] addr_o,
    /// Response transfer valid
    input  wire                      rvalid_i,
    /// Read data
    input  wire [InstrWidth - 1 : 0] rdata_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Error response
    input  wire                      err_i
    /* verilator lint_on UNUSEDSIGNAL */
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
  /// Memory request register
  reg                        req_q;
  /********************             ********************/


  /// Memory access control signals
  /*!
  * In a single-cycle processor,
  * one instruction is fetched every cycle.
  * Therefore, `req_q` is always asserted (except during reset).
  *
  * Since the fetch unit only performs instruction reads,
  * the memory address (`addr_o`) is always set to the value
  * of the program counter (`pc_next_i`),
  * which corresponds to the address of the next instruction.
  *
  * The instruction is considered valid (`valid_o`)
  * if the memory signals a hit (`rvalid_i`), and the system is not in reset.
  *
  * For instructions that take more than one cycle to complete
  * (e.g., memory accesses), the `pc_next_i` must remain stable
  * to ensure correct execution.
  */
  always_ff @(posedge clk_i) begin : mem_controller
    if (!rstn_i) begin
      valid_q <= 1'b0;
      req_q   <= 1'b0;
    end
    else begin
      valid_q <= rvalid_i;
      req_q   <= 1'b1;
    end
  end

  /// Output driven by mem_controller
  assign req_o   = req_q;
  /// Provide to memory next instruction address
  assign addr_o  = pc_next_i;
  /// Output driven mem_controller
  assign valid_o = valid_q;

  /// Instruction selection logic
  /*!
  * - During reset (when `rstn_i` is low),
  *   the instruction is forced to '0 to prevent the decode unit
  *   from processing garbage data.
  *
  * - Once reset is deasserted,
  *   the fetched instruction from memory (`rdata_i`) is forwarded
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
      instr = rdata_i;
    end
  end

  /// Output driven by instr_mux
  assign instr_o = instr;

endmodule

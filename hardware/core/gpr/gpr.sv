// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       gpr.sv
\brief      SCHOLAR RISC-V core General Purpose Registers file module
\author     Kawanami
\date       22/09/2025
\version    1.1

\details
  This module implements the SCHOLAR RISC-V register file.
  It contains all general-purpose registers (GPRs)
  along with the program counter (pc_o).
  It consists of a RAM with two read ports
  (for operand fetch) and one write port (for result storage).
  The pc_o is stored in a dedicated register,
  separate from the general-purpose registers.

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section gpr_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/07/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 22/09/2025 | Kawanami   | Remove packages.sv and provide useful metadata through parameters.<br>Add RV64 support.<br>Update the whole file for coding style compliance.<br>Update the whole file comments for doxygen support. |
********************************************************************************
*/
module gpr #(
    /// Number of bits for addressing
    parameter int                       AddrWidth    = 32,
    /// Width of data paths (in bits)
    parameter int                       DataWidth    = 32,
    /// Width of the GPR index (in bits, usually 5 for 32 regs)
    parameter int                       RfAddrWidth  = 5,
    /// Number of General Purpose Registers
    parameter int                       NbGpr        = 32,
    /// Core boot/start address
    parameter logic [AddrWidth - 1 : 0] StartAddress = '0
) (
`ifdef SIM
    /// GPR write enable (SIM only)
    input  wire                        en_i,
    /// GPR write address (SIM only)
    input  wire [ RfAddrWidth - 1 : 0] addr_i,
    /// GPR write data (SIM only)
    input  wire [DataWidth    - 1 : 0] data_i,
    /// GPR memory (SIM only)
    output wire [DataWidth    - 1 : 0] memory_o[NbGpr],
    /// GPR program counter (SIM only)
    output wire [AddrWidth    - 1 : 0] pc_q_o,
`endif

    /// System clock
    input  wire                        clk_i,
    /// System active low reset
    input  wire                        rstn_i,
    /// Register Source 1 (rs1)
    input  wire [ RfAddrWidth - 1 : 0] rs1_i,
    /// Register Source 2 (rs2)
    input  wire [ RfAddrWidth - 1 : 0] rs2_i,
    /// Destination register address
    input  wire [ RfAddrWidth - 1 : 0] rd_i,
    /// Data written to destination register
    input  wire [DataWidth    - 1 : 0] rd_val_i,
    /// Data written to destination register valid flag
    input  wire                        rd_valid_i,
    /// Next value of PC
    input  wire [AddrWidth    - 1 : 0] pc_next_i,
    /// Register Source 1 value
    output wire [DataWidth    - 1 : 0] rs1_val_o,
    /// Register Source 2 value
    output wire [DataWidth    - 1 : 0] rs2_val_o,
    /// Program counter
    output wire [AddrWidth    - 1 : 0] pc_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */

  /* registers */
  /// General Purpose Registers. x0 = mem[0], x1 = mem[1] ... x31 = mem[31].
  reg [DataWidth - 1 : 0] mem  [NbGpr];
  /// Program Counter register
  reg [AddrWidth - 1 : 0] pc_q;
  /********************             ********************/

  /// GPR & PC management
  /*!
  * Write operations are performed synchronously,
  * while read operations are handled asynchronously.
  * On reset, the pc_o register is initialized to `StartAddress`
  * and the register 0 is initialized with zeroes.
  * Not resetting the other registers does not affect system behavior,
  * and it helps to reduce hardware costs.
  *
  * The pc_o register is updated each cycle. Thus, to hold an instruction,
  * the `pc_next_i` shall remain the same.
  * Memory (mem) is updated only if:
  *   - The address is valid (i.e., greater than 0, to prevent writing to register x0).
  *   - `rd_valid_i` is asserted, indicating that the data input is valid for writing.
  */
  always_ff @(posedge clk_i) begin : gpr_pc
    if (!rstn_i) pc_q <= StartAddress;
    else pc_q <= pc_next_i;

    if (!rstn_i) mem[0] <= '0;
    else if (rd_valid_i && rd_i != '0) mem[rd_i] <= rd_val_i;
  end

  /// Register source 1 value according to Register source address
  assign rs1_val_o = mem[rs1_i];
  /// Register source 2 value according to Register source address
  assign rs2_val_o = mem[rs2_i];
  /// Output driven by gpr_pc
  assign pc_o      = pc_q;


  /// GPR debug access
  /*
  * This block is active only when the design is simulated (SIM).
  * It forwards the General Purpose Registers (GPRs)
  * to Verilator for verification of the core's internal states.
  * This also allows Verilator to modify these internal states during testing.
  */
`ifdef SIM
  always_latch begin : gpr_debug
    if (en_i && (addr_i != '0)) mem[addr_i] = data_i;
  end

  /// Provide access to the GPR internal memory through `memory_o`
  assign memory_o = mem;
  /// Provide access to the PC through `pc_q_o`
  assign pc_q_o   = pc_q;
`endif

endmodule

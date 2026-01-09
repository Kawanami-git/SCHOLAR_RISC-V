// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       imem_bus_if.sv
\brief      Instruction memory bus interface for SCHOLAR RISC-V core.
\author     Kawanami
\version    1.0
\date       22/11/2025
\details
  This interface describes the instruction memory bus used by the
  SCHOLAR RISC-V core.

  It models a simple read-only Harvard-style instruction bus:
    - The core drives the address and read enable.
    - The instruction memory (or I-cache) returns the 32-bit instruction
      word and a hit flag.

  The address width is parameterized by \p Archi (32-bit or 64-bit core).
********************************************************************************
*/
/* verilator lint_off UNUSEDSIGNAL */
interface core_mem_if #(
    /// Number of bits for addressing
    parameter int unsigned AddrWidth = 32,
    /// Data bus width in bits
    parameter int unsigned DataWidth = 32
);
  /// Memory address driven by the core
  logic [    AddrWidth-1:0] addr;
  /// Memory write enable (1: enable, 0: disable)
  logic                     wren;
  /// Memory write data
  logic [    DataWidth-1:0] wdata;
  /// Memory write data
  logic [(DataWidth/8)-1:0] wmask;
  /// Memory read enable (1: enable, 0: disable)
  logic                     rden;
  /// Memory output data (32-bit instruction word)
  logic [    DataWidth-1:0] rdata;
  /// Memory hit flag (1: hit, 0: miss)
  logic                     hit;

  /// Core (CPU) side modport.
  /*!
   * The core:
   *  - drives addr and rden
   *  - receives dout and hit
   */
  modport cpu(
      output addr,
      output wren,
      output wdata,
      output wmask,
      output rden,
      input rdata,
      input hit
  );

  ///Instruction memory / I-cache side modport.
  /*!
   * The memory:
   *  - receives addr and rden
   *  - drives dout and hit
   */
  modport mem(
      input addr,
      input wren,
      input wdata,
      input wmask,
      input rden,
      output rdata,
      output hit
  );

endinterface : core_mem_if

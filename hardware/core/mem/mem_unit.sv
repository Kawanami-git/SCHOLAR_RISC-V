// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       mem_unit.sv
\brief      SCHOLAR RISC-V core memory unit
\author     Kawanami
\date       17/12/2025
\version    1.0

\details
  This module implements the memory unit of the SCHOLAR RISC-V processor core.
  Its purpose is to perform the data-memory transaction associated with the
  current micro-operation (LOAD/STORE), including byte-enable mask generation
  and data alignment.

\remarks
- External data memories are assumed to be perfect 1-cycle memories.
- TODO: [possible improvements or future features]

\section mem_unit_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 17/12/2025 | Kawanami   | Initial version of the module.            |
********************************************************************************
*/

/*!
* Import useful packages.
*/
import core_pkg::BYTE_LENGTH;
import core_pkg::ADDR_WIDTH;
import core_pkg::DATA_WIDTH;
import core_pkg::MEM_CTRL_WIDTH;
import core_pkg::ADDR_OFFSET_WIDTH;
import core_pkg::MEM_IDLE;
import core_pkg::MEM_WB;
import core_pkg::MEM_WH;
import core_pkg::MEM_WW;
/**/

module mem_unit #(
) (
    /// System clock
    input  wire                           clk_i,
    /// System active low reset
    input  wire                           rstn_i,
    /// Enable signal
    input  wire                           exe_valid_i,
    /// Mem unit ready (1: can accept a new transaction to perform)
    output wire                           ready_o,
    /// Memory transaction executed
    output wire                           valid_o,
    /// Operand 3 (used for STOREs)
    input  wire [DATA_WIDTH      - 1 : 0] op3_i,
    /// Result from the execute (EXE) stage
    input  wire [DATA_WIDTH      - 1 : 0] exe_out_i,
    /// Memory control signal
    input  wire [MEM_CTRL_WIDTH  - 1 : 0] mem_ctrl_i,
    /// Data to write to memory
    output wire [DATA_WIDTH      - 1 : 0] d_m_wdata_o,
    /// Memory hit flag
    input  wire                           d_m_hit_i,
    /// Memory address for LOAD or STORE
    output wire [     ADDR_WIDTH - 1 : 0] d_m_addr_o,
    /// Memory read enable
    output wire                           d_m_rden_o,
    /// Memory write enable
    output wire                           d_m_wren_o,
    /// Byte-level write mask for STOREs
    output wire [(DATA_WIDTH/8)  - 1 : 0] d_m_wmask_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  /* functions */

  /* wires */
  /// Address used for memory access (read or write)
  logic [  ADDR_WIDTH      - 1 : 0] m_addr;
  /// Byte offset within the accessed word (used for write alignment)
  wire  [ADDR_OFFSET_WIDTH - 1 : 0] m_addr_offset;
  /// Memory write enable (1 = write)
  logic                             m_wren;
  /// Byte-wise write mask for memory store operations
  logic [  (DATA_WIDTH/8)  - 1 : 0] m_wmask;
  /// Memory read enable (1 = read)
  logic                             m_rden;
  /// Data to write into memory
  logic [  DATA_WIDTH      - 1 : 0] m_wdata;
  /// Ready flag
  logic                             ready;
  /// Valid flag
  logic                             valid;
  /* registers */
  /// Exe valid register
  reg                               exe_valid_q;
  /********************             ********************/

  /// EXE valid signal registration
  /*!
  * Holds `exe_valid_i` for one cycle to preserve the MEM→WB latency
  * even when no memory transaction is required by the current uop.
  * In that case, MEM’s output becomes valid in the following cycle.
  */
  always_ff @(posedge clk_i) begin : exe_valid_reg
    if (!rstn_i) begin
      exe_valid_q <= 1'b0;
    end
    else begin
      exe_valid_q <= exe_valid_i;
    end
  end

  /// Ready/valid generation
  /*!
  * `valid` is asserted when:
  *   - A memory transaction is required and acknowledged by the memory (hit),
  *   - OR no memory transaction is required and EXE provided a valid input
  *     in the previous cycle (`exe_valid_q`).
  *
  * `ready` is asserted when:
  *   - A memory transaction is required and the memory acknowledges (hit),
  *   - OR no memory transaction is required (always ready in that case).
  */
  always_comb begin : ctrl
    if (!rstn_i) begin
      ready = 1'b0;
      valid = 1'b0;
    end
    else if (mem_ctrl_i != MEM_IDLE) begin
      ready = d_m_hit_i;
      valid = d_m_hit_i;
    end
    else begin
      ready = 1'b1;
      valid = exe_valid_q;
    end
  end

  /// Output driven by ctrl
  assign ready_o = ready;
  /// Output driven by ctrl
  assign valid_o = valid;



  /// Memory access control signals
  /*!
  * Generates the access signals (`m_addr`, `m_wren`, `m_rden`, `m_wmask`, `m_wdata`)
  * from the decoded memory control (`mem_ctrl_i`).
  *
  * Convention:
  * - `mem_ctrl_i[3] == 1'b0` → READ
  * - `mem_ctrl_i[3] == 1'b1` → WRITE (size encoded by `mem_ctrl_i`)
  *
  * READ:
  *   - Assert `m_rden`, deassert `m_wren`, apply full byte mask (some RAMs
  *     reuse the mask path on reads).
  *
  * WRITE:
  *   - Assert `m_wren`, deassert `m_rden`, shift `op3_i` according to the
  *     byte offset, and set the byte mask for the requested size.
  */
  generate
    if (DATA_WIDTH == 32) begin : gen_mem_controller_32
      always_comb begin : mem_controller
        if (mem_ctrl_i != MEM_IDLE) begin
          m_addr = exe_out_i;
          if (mem_ctrl_i[3] == 1'b0) begin  // Read
            m_rden  = 1'b1;
            m_wren  = 1'b0;
            m_wmask = {DATA_WIDTH / 8{1'b1}};
            m_wdata = '0;
          end
          else begin  // Write
            m_rden = 1'b0;
            m_wren = 1'b1;

            case (mem_ctrl_i)
              MEM_WB: begin
                m_wdata = ({{DATA_WIDTH - 8{1'b0}}, op3_i[7:0]}) << m_addr_offset * BYTE_LENGTH;
                m_wmask = 1'b1 << m_addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MEM_WH: begin
                m_wdata = ({{DATA_WIDTH - 16{1'b0}}, op3_i[15:0]}) << m_addr_offset * BYTE_LENGTH;
                m_wmask = 3 << m_addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              default: begin
                m_wdata = op3_i;
                m_wmask = {DATA_WIDTH / 8{1'b1}};
              end
            endcase
          end
        end
        else begin
          m_addr  = '0;
          m_rden  = 1'b0;
          m_wren  = 1'b0;
          m_wmask = {DATA_WIDTH / 8{1'b1}};
          m_wdata = '0;
        end
      end

    end
    else begin : gen_mem_controller_64

      always_comb begin : mem_controller
        if (mem_ctrl_i != MEM_IDLE) begin
          m_addr = exe_out_i;
          if (mem_ctrl_i[3] == 1'b0) begin  // Read
            m_rden  = 1'b1;
            m_wren  = 1'b0;
            m_wmask = {DATA_WIDTH / 8{1'b1}};
            m_wdata = '0;
          end
          else begin  // Write
            m_rden = 1'b0;
            m_wren = 1'b1;

            case (mem_ctrl_i)
              MEM_WB: begin
                m_wdata = ({{DATA_WIDTH - 8{1'b0}}, op3_i[7:0]}) << m_addr_offset * BYTE_LENGTH;
                m_wmask = 1'b1 << m_addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MEM_WH: begin
                m_wdata = ({{DATA_WIDTH - 16{1'b0}}, op3_i[15:0]}) << m_addr_offset * BYTE_LENGTH;
                m_wmask = 3 << m_addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MEM_WW: begin
                m_wdata = ({{DATA_WIDTH - 32{1'b0}}, op3_i[31:0]}) << m_addr_offset * BYTE_LENGTH;
                m_wmask = 15 << m_addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              default: begin
                m_wdata = op3_i;
                m_wmask = {DATA_WIDTH / 8{1'b1}};
              end
            endcase
          end
        end
        else begin
          m_addr  = '0;
          m_rden  = 1'b0;
          m_wren  = 1'b0;
          m_wmask = {DATA_WIDTH / 8{1'b1}};
          m_wdata = '0;
        end
      end
    end
  endgenerate

  /// Address offset computation for correct alignment during write requests
  assign m_addr_offset = exe_out_i[ADDR_OFFSET_WIDTH-1 : 0];


  /// Output driven by mem_controller
  assign d_m_wdata_o   = m_wdata;
  /// Output driven by mem_controller
  assign d_m_addr_o    = {m_addr[ADDR_WIDTH-1:ADDR_OFFSET_WIDTH], {ADDR_OFFSET_WIDTH{1'b0}}};
  /// Output driven by mem_controller
  assign d_m_rden_o    = m_rden;
  /// Output driven by mem_controller
  assign d_m_wren_o    = m_wren;
  /// Output driven by mem_controller
  assign d_m_wmask_o   = m_wmask;

endmodule

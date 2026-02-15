// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       mem_unit.sv
\brief      SCHOLAR RISC-V core memory unit
\author     Kawanami
\date       15/02/2026
\version    1.2

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
| 1.1     | 03/02/2026 | Kawanami   | Use local package import instead of global. |
| 1.2     | 15/02/2026 | Kawanami   | Replace custom interface with OBI standard. |
********************************************************************************
*/

module mem_unit

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

#(
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
    /// Address transfer request
    output wire                           req_o,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Grant: Ready to accept address transfert
    input  wire                           gnt_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// Address for memory access
    output wire [    ADDR_WIDTH  - 1 : 0] addr_o,
    /// Write enable (1: write - 0: read)
    output wire                           we_o,
    /// Write data
    output wire [     DATA_WIDTH - 1 : 0] wdata_o,
    /// Byte enable
    output wire [ (DATA_WIDTH/8) - 1 : 0] be_o,
    /// Response transfer valid
    input  wire                           rvalid_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Error response
    input  wire                           err_i
    /* verilator lint_on UNUSEDSIGNAL */
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  /* functions */

  /* wires */
  /// Address used for memory access (read or write)
  logic [  ADDR_WIDTH      - 1 : 0] addr;
  /// Byte offset within the accessed word (used for write alignment)
  wire  [ADDR_OFFSET_WIDTH - 1 : 0] m_addr_offset;
  /// Address transfer request
  logic                             req;
  /// Byte enable
  logic [  (DATA_WIDTH/8)  - 1 : 0] be;
  /// Write enable (1: write - 0: read)
  logic                             we;
  /// Write data
  logic [  DATA_WIDTH      - 1 : 0] wdata;
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
  *   - A memory transaction is required and validated by the memory (`rvalid_i`),
  *   - OR no memory transaction is required and EXE provided a valid input
  *     in the previous cycle (`exe_valid_q`).
  *
  * `ready` is asserted when:
  *   - A memory transaction is required and the memory acknowledges (`rvalid_i`),
  *   - OR no memory transaction is required (always ready in that case).
  */
  always_comb begin : ctrl
    if (!rstn_i) begin
      ready = 1'b0;
      valid = 1'b0;
    end
    else if (mem_ctrl_i != MEM_IDLE) begin
      ready = rvalid_i;
      valid = rvalid_i;
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
  * Generates the access signals (`addr`, `req`, `we`, `be`, `wdata`)
  * from the decoded memory control (`mem_ctrl_i`).
  *
  * Convention:
  * - `mem_ctrl_i[3] == 1'b0` → READ
  * - `mem_ctrl_i[3] == 1'b1` → WRITE (size encoded by `mem_ctrl_i`)
  *
  * READ:
  *   - Assert `req` and deassert `we`, apply full byte mask (some RAMs
  *     reuse the mask path on reads).
  *
  * WRITE:
  *   - Assert `req` and `we`, shift `op3_i` according to the
  *     byte offset, and set the byte mask for the requested size.
  */
  generate
    if (DATA_WIDTH == 32) begin : gen_mem_controller_32
      always_comb begin : mem_controller
        if (mem_ctrl_i != MEM_IDLE) begin
          addr = exe_out_i;
          req  = 1'b1;
          if (mem_ctrl_i[3] == 1'b0) begin  // Read
            we    = 1'b0;
            be    = {DATA_WIDTH / 8{1'b1}};
            wdata = '0;
          end
          else begin  // Write
            we = 1'b1;

            case (mem_ctrl_i)
              MEM_WB: begin
                wdata = ({{DATA_WIDTH - 8{1'b0}}, op3_i[7:0]}) << m_addr_offset * BYTE_LENGTH;
                be    = 1'b1 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MEM_WH: begin
                wdata = ({{DATA_WIDTH - 16{1'b0}}, op3_i[15:0]}) << m_addr_offset * BYTE_LENGTH;
                be    = 3 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              default: begin
                wdata = op3_i;
                be    = {DATA_WIDTH / 8{1'b1}};
              end
            endcase
          end
        end
        else begin
          addr  = '0;
          req   = 1'b0;
          we    = 1'b0;
          be    = {DATA_WIDTH / 8{1'b1}};
          wdata = '0;
        end
      end

    end
    else begin : gen_mem_controller_64

      always_comb begin : mem_controller
        if (mem_ctrl_i != MEM_IDLE) begin
          addr = exe_out_i;
          req  = 1'b1;
          if (mem_ctrl_i[3] == 1'b0) begin  // Read
            we    = 1'b0;
            be    = {DATA_WIDTH / 8{1'b1}};
            wdata = '0;
          end
          else begin  // Write
            we = 1'b0;

            case (mem_ctrl_i)
              MEM_WB: begin
                wdata = ({{DATA_WIDTH - 8{1'b0}}, op3_i[7:0]}) << m_addr_offset * BYTE_LENGTH;
                be    = 1'b1 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MEM_WH: begin
                wdata = ({{DATA_WIDTH - 16{1'b0}}, op3_i[15:0]}) << m_addr_offset * BYTE_LENGTH;
                be    = 3 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              MEM_WW: begin
                wdata = ({{DATA_WIDTH - 32{1'b0}}, op3_i[31:0]}) << m_addr_offset * BYTE_LENGTH;
                be    = 15 << addr[ADDR_OFFSET_WIDTH-1 : 0];
              end

              default: begin
                wdata = op3_i;
                be    = {DATA_WIDTH / 8{1'b1}};
              end
            endcase
          end
        end
        else begin
          addr  = '0;
          req   = 1'b0;
          we    = 1'b0;
          be    = {DATA_WIDTH / 8{1'b1}};
          wdata = '0;
        end
      end
    end
  endgenerate

  /// Address offset computation for correct alignment during write requests
  assign m_addr_offset = exe_out_i[ADDR_OFFSET_WIDTH-1 : 0];


  /// Output driven by mem_controller
  assign wdata_o       = wdata;
  /// Output driven by mem_controller
  assign addr_o        = {addr[ADDR_WIDTH-1:ADDR_OFFSET_WIDTH], {ADDR_OFFSET_WIDTH{1'b0}}};
  /// Output driven by mem_controller
  assign req_o         = req;
  /// Output driven by mem_controller
  assign we_o          = we;
  /// Output driven by mem_controller
  assign be_o          = be;

endmodule

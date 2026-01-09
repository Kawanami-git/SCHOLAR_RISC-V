// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       decode.sv
\brief      SCHOLAR RISC-V core decode stage
\author     Kawanami
\date       15/12/2025
\version    1.0

\details
  Instruction Decode (ID) stage of the SCHOLAR RISC-V core pipeline.

  The decode stage receives the fetched instruction/PC from the IF stage and
  produces the micro-operation (uop) control fields and operands for EXE/MEM/WB.

  This stage is split into two parts:
    - `decode.sv` (this file): stage wrapper and IF->ID input register
    - `decode_unit`: actual instruction decoding, operand selection and
      readiness / hazard gating.

  The IF->ID payload is captured only when:
    - fetch provides a valid instruction (`fetch_valid_i`)
    - the decode stage is ready to accept it (`ready_o`)

\remarks
  - TODO: .

\section decode_version_history Version history
| Version | Date       | Author     | Description                    |
|:-------:|:----------:|:-----------|:-------------------------------|
| 1.0     | 15/12/2025 | Kawanami   | Initial version of the module. |
********************************************************************************
*/

/*!
* Import useful packages.
*/
import if2id_pkg::if2id_t;
import id2exe_pkg::id2exe_t;
import core_pkg::RF_ADDR_WIDTH;
import core_pkg::DATA_WIDTH;
import core_pkg::CSR_ADDR_WIDTH;
/**/

module decode #(
) (
    /// System clock
    input  wire                              clk_i,
    /// System active low reset
    input  wire                              rstn_i,
    /// Decode stage ready (1: can accept a new IF->ID payload)
    output wire                              ready_o,
    /// IF stage valid flag
    input  wire                              fetch_valid_i,
    /// EXE stage ready flag (back-pressure from the next stage)
    input  wire                              exe_ready_i,
    /// Register file port 0 read address (rs1 index)
    output wire     [RF_ADDR_WIDTH  - 1 : 0] rs1_o,
    /// Register file port 0 read data (rs1 value)
    input  wire     [DATA_WIDTH     - 1 : 0] rs1_data_i,
    /// Register file rs1 dependency flag (1: data not ready / pending write)
    input  wire                              rs1_dirty_i,
    /// Register file port 1 read address (rs2 index)
    output wire     [RF_ADDR_WIDTH  - 1 : 0] rs2_o,
    /// Register file port 1 read data (rs2 value)
    input  wire     [DATA_WIDTH     - 1 : 0] rs2_data_i,
    /// Register file rs2 dependency flag (1: data not ready / pending write)
    input  wire                              rs2_dirty_i,
    /// CSR file read address
    output wire     [CSR_ADDR_WIDTH - 1 : 0] csr_raddr_o,
    /// CSR file read data
    input  wire     [DATA_WIDTH     - 1 : 0] csr_data_i,
    /// Decoded instruction valid flag (1: `id2exe_o` fields are valid)
    output wire                              valid_o,
    /// IF->ID payload (instruction + PC)
    input  if2id_t                           if2id_i,
    /// ID->EXE payload: operands + control micro-ops
    output id2exe_t                          id2exe_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// Ready flag
  wire    ready;
  /* registers */
  /// IF->ID Payload register
  if2id_t if2id_q;
  /********************             ********************/

  /// IF->ID pipeline register
  /*!
  * Captures the instruction and PC from the fetch stage when:
  *  - the incoming payload is valid (`fetch_valid_i`)
  *  - decode is ready to accept it (`ready`)
  *
  * When stalled, the register holds its previous value.
  */
  always_ff @(posedge clk_i) begin : if_id
    if (!rstn_i) begin
      if2id_q <= '0;
    end
    else if (fetch_valid_i && ready) begin
      if2id_q <= if2id_i;
    end
  end

  /// Output driven by the decode unit
  assign ready_o = ready;

  /// Decode unit instantiation
  /*!
  * `decode_unit` consumes the registered instruction/PC and:
  *  - requests register file rs1 & rs2 data
  *  - selects/forwards operands (op1/op2/op3)
  *  - generates control fields for EXE/MEM/WB/PC
  *  - asserts `valid_o` when the decoded payload is valid
  *  - provides `ready_o` back-pressure toward fetch
  */
  decode_unit #() decode_unit (
      .rstn_i     (rstn_i),
      .exe_ready_i(exe_ready_i),
      .ready_o    (ready),
      .pc_i       (if2id_q.pc),
      .instr_i    (if2id_q.instr),
      .rs1_o      (rs1_o),
      .rs1_data_i (rs1_data_i),
      .rs1_dirty_i(rs1_dirty_i),
      .rs2_o      (rs2_o),
      .rs2_data_i (rs2_data_i),
      .rs2_dirty_i(rs2_dirty_i),
      .csr_raddr_o(csr_raddr_o),
      .csr_data_i (csr_data_i),
      .op1_o      (id2exe_o.op1),
      .op2_o      (id2exe_o.op2),
      .op3_o      (id2exe_o.op3),
      .rd_o       (id2exe_o.rd),
      .pc_o       (id2exe_o.pc),
      .exe_ctrl_o (id2exe_o.exe_ctrl),
      .mem_ctrl_o (id2exe_o.mem_ctrl),
      .csr_ctrl_o (id2exe_o.csr_ctrl),
      .gpr_ctrl_o (id2exe_o.gpr_ctrl),
      .pc_ctrl_o  (id2exe_o.pc_ctrl),
      .valid_o    (valid_o)
  );

endmodule

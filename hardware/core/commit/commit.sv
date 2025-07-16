/*!
********************************************************************************
*  \file      commit.sv
*  \module    commit
*  \brief     SCHOLAR RISC-V core commit module
*
*  \author    Kawanami
*  \version   1.0
*  \date      08/07/2025
*
********************************************************************************
*  \details
* This module implements the commit unit of the SCHOLAR RISC-V processor core.
*
* The commit unit is the final step in instruction execution. It is responsible for:
* - Writing results to the general-purpose register file (GPR), if applicable
* - Performing memory writes for STORE instructions
* - Updating control and status registers (CSR), if needed
* - Updating the program counter (GPR_PC) based on control flow (e.g., jump, branch)
*
* This unit receives:
* - Results from the execution (EXE) unit
* - The `DECODE_OP3` operand from the decode unit (used for STORE and CSR instructions)
* - Control signals (`DECODE_GPR_CTRL`, `DECODE_MEM_CTRL`, `DECODE_PC_CTRL`, `DECODE_CSR_CTRL`, etc.)
*   that determine which updates are to be applied
*
* Although commit logic is triggered in the same cycle as execution, the actual writes
* to memory, GPR, and CSR occur on the next clock edge. This ensures proper synchronization
* and consistency across all architectural state updates.
*
* These synchronized writes do not introduce additional latency in the core,
* since the GPRs, GPR_PC, and CSRs are read combinatorially. Therefore, the next instruction
* can use updated values without waiting an extra cycle.
*
* However, external memory accesses (e.g., data memory) are managed over two cycles:
* - The first cycle emits the memory request,
* - The second cycle completes the operation:
*   - Either by writing the read result to the GPR (in case of a LOAD),
*   - Or by ensuring the memory write is completed (STORE).
*
* Even though STORE operations could be completed in a single cycle (as memory is always ready),
* both LOAD and STORE are handled in two cycles for simplification and consistency.
********************************************************************************
*  \parameters
*    - ADDR_WIDTH       : Number of bits for addressing
*    - DATA_WIDTH       : Width of data paths (in bits)
*    - START_ADDR       : Core boot/start address
*
*  \inputs
*    - CLK              : System clock signal
*    - RSTN             : Active-low system reset
*    - DECODE_VALID     : Decode unit valid signal (1: valid, 0: not valid)
*    - EXE_OUT          : Result from the execute (EXE) unit
*    - DECODE_OP3       : Operand 3 from decode unit (used for STOREs and branches)
*    - DECODE_RD        : Destination register index
*    - DECODE_PC_CTRL   : Program counter control signal
*    - DECODE_GPR_CTRL  : General-purpose register file control signal
*    - DECODE_CSR_CTRL  : Control and status register (CSR) control signal
*    - DECODE_MEM_CTRL  : Memory control signal
*    - GPR_PC           : Current program counter value
*    - M_DOUT           : Data read from memory
*    - M_HIT            : Memory hit flag (1: valid, 0: not valid)
*
*  \outputs
*    - RD               : Register index to be written (GPR destination)
*    - RD_VALID         : Write enable for GPR destination register (1: valid, 0: not valid)
*    - RD_VAL           : Data to write to the destination register
*    - PC_NEXT          : Next program counter value
*    - CSR_WADDR        : Write address for CSR file
*    - CSR_VAL          : Data to write to CSR
*    - CSR_VALID        : CSR write enable signal (1: enable, 0: disable)
*    - M_ADDR           : Memory address for LOAD or STORE
*    - M_RDEN           : Memory read enable (1: enable, 0: disable)
*    - M_WREN           : Memory write enable (1: enable, 0: disable)
*    - M_WMASK          : Byte-level write mask for STOREs (1 bit per byte)
*
*  \inouts
*    - None
********************************************************************************
*  \versioning
*
*  Version   Date          Author          Description
*  -------   ----------    ------------    --------------------------------------
*  1.0       08/07/2025    Kawanami        Initial version of the module
*  1.1       [Date]        [Author]        Description
*  1.2       [Date]        [Author]        Description
*
********************************************************************************
*  \remarks
*  - This implementation complies with [reference or standard].
*  - TODO: [possible improvements or future features]
********************************************************************************
*/

`include "packages.sv"

module commit
    import archi_pkg::*;
#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter START_ADDR  = {ADDR_WIDTH{1'b0}}
)
(
    input  wire                           CLK              ,
    input  wire                           RSTN             ,

    input  wire                           DECODE_VALID     ,
    input  wire [DATA_WIDTH      - 1 : 0] EXE_OUT          ,
    input  wire [DATA_WIDTH      - 1 : 0] DECODE_OP3       ,
    input  wire [RF_ADDR_WIDTH   - 1 : 0] DECODE_RD        ,
    input  wire [PC_CTRL_WIDTH   - 1 : 0] DECODE_PC_CTRL   ,
    input  wire [GPR_CTRL_WIDTH  - 1 : 0] DECODE_GPR_CTRL  ,
    /* verilator lint_off UNUSED */                                     // Disable Verilator warning `Signal is not used`
    input  wire [CSR_CTRL_WIDTH  - 1 : 0] DECODE_CSR_CTRL  ,
    /* verilator lint_on UNUSED */                                      // Re-enable Verilator warning `Signal is not used`
    input  wire [MEM_CTRL_WIDTH  - 1 : 0] DECODE_MEM_CTRL  ,

    output wire [RF_ADDR_WIDTH   - 1 : 0] RD               ,
    output wire                           RD_VALID         ,
    output wire [DATA_WIDTH      - 1 : 0] RD_VAL           ,
    input  wire [ADDR_WIDTH      - 1 : 0] GPR_PC           ,
    output wire [ADDR_WIDTH      - 1 : 0] PC_NEXT          ,

    output wire [CSR_ADDR_WIDTH - 1 : 0]  CSR_WADDR        ,
    output wire [DATA_WIDTH     - 1 : 0]  CSR_VAL          ,
    output wire                           CSR_VALID         ,

    input  wire [DATA_WIDTH      - 1 : 0] M_DOUT           ,
    output wire [DATA_WIDTH      - 1 : 0] M_DIN            ,
    input  wire                           M_HIT            ,
    output wire [ADDR_WIDTH      - 1 : 0] M_ADDR           ,
    output wire                           M_RDEN           ,
    output wire                           M_WREN           ,
    output wire [(DATA_WIDTH/8)  - 1 : 0] M_WMASK
);


/******************** PARAMETERS VERIFICATION ********************/
/********************                         ********************/


/******************** LOCAL PARAMETERS ********************/
localparam ADDR_OFFSET       = ADDR_WIDTH / BYTE_LENGTH;    // Address granularity in bytes (e.g., 4 bytes for 32-bit, 8 for 64-bit)
localparam ADDR_OFFSET_WIDTH = $clog2(ADDR_OFFSET);         // Number of bits needed to encode byte offset within a word
/********************                  ********************/


/******************** TYPES DEFINITION ********************/
/********************                  ********************/


/******************** WIRES ********************/
// Machine state wires

// Control wires
logic [ADDR_WIDTH      - 1 : 0] m_addr;                     // Address used for memory access (read or write)
logic                           m_wren;                     // Memory write enable (1 = write)
logic [(DATA_WIDTH/8)  - 1 : 0] m_wmask;                    // Byte-wise write mask for memory store operations
logic                           m_rden;                     // Memory read enable (1 = read)
logic                           rd_valid;                   // Destination register validity flag

// Data wires
logic [                 15 : 0] mem_rdata;                  // Data read from memory (for load byte and load half)
logic [DATA_WIDTH      - 1 : 0] m_din;                      // Data to write into memory
logic [DATA_WIDTH      - 1 : 0] gpr_din;                    // Data to write into GPR (register file)
logic [ADDR_WIDTH      - 1 : 0] pc_next;                    // Next value for the program counter (GPR_PC)
/********************       ********************/

/******************** REGISTERS ********************/
// Machine state register

// Control registers
reg [ADDR_OFFSET_WIDTH - 1 : 0] m_addr_offset_reg;          // Byte offset within the accessed word (used for alignment and masking)
reg                             m_req_done_reg;             // Indicates that the current memory request has been completed


// Data registers
/********************           ********************/


/******************** MACHINE STATE ********************/

/********************               ********************/


/*
* These blocks generate and control memory access signals (`m_addr`, `m_wren`,
* `m_rden`, `m_wmask`, `m_addr_offset_reg` and `m_din`) based on the validity of the decode unit
* (`DECODE_VALID`) and the memory control signal (`DECODE_MEM_CTRL`).
* The 5th bit of `DECODE_MEM_CTRL` signal is used to detect if a memory operation must be executed.
*
* They support both LOAD and STORE instructions:
* - For LOAD: a read request is triggered (`m_rden`), and a full write mask is applied.
*   (Some memories use write masks for read access as well, so we use the same mask logic.)
*
* - For STORE: a write request is triggered (`m_wren`) and the write mask (`m_wmask`)
*   and the data to write (`m_din`) are generated based on the access size 
*   (byte, halfword, word) and the address offset.
*
* Memory request completion is tracked via `m_req_done_reg`, which is set when the memory reports a hit (`M_HIT`).
*
* Notes:
* - Read/write assertion is done combinatorially to avoid stalling the core,
*   while deassertion is done synchronously to ensure proper timing with the memory.
*
* - The memory address (`m_addr`) must remain stable during the entire memory access.
*   This is ensured by keeping the GPR_PC constant in a separate block until the request is completed.
*
* - For LOAD instructions: even after the memory returns data, one additional cycle is needed
*   to write-back the value into the GPR file. During that cycle, the EXE unit may already
*   have moved to the next instruction and modified `EXE_OUT`.
*   To avoid incorrect masking due to address change, the byte offset is saved in `m_addr_offset_reg`
*   (registered on the `negedge` of the clock) and reused for proper data alignment during write-back.
*
* - The synchronized nature of write-back introduces no visible latency,
*   since register and CSR reads are combinational.
*/
always_comb begin : mem_request
    if(DECODE_MEM_CTRL[4]) m_addr = EXE_OUT;
    else m_addr = {ADDR_WIDTH{1'b0}};

    if(DECODE_MEM_CTRL[4] && m_req_done_reg == 1'b0) begin
        if(!DECODE_MEM_CTRL[3]) begin
            m_rden  = 1'b1;
            m_wren  = 1'b0;
            m_wmask = {DATA_WIDTH/8{1'b1}};
            m_din   = {DATA_WIDTH{1'b0}};
        end else         begin
            m_rden  = 1'b0;
            m_wren  = 1'b1;

            case(DECODE_MEM_CTRL[2:1])
                2'b00:   m_din = ({{DATA_WIDTH-8{1'b0}},  DECODE_OP3[7:0]})  << m_addr_offset_reg * BYTE_LENGTH;
                2'b01:   m_din = ({{DATA_WIDTH-16{1'b0}}, DECODE_OP3[15:0]}) << m_addr_offset_reg * BYTE_LENGTH;
                default: m_din = DECODE_OP3;
            endcase

            if     (DECODE_MEM_CTRL[2]) m_wmask = {DATA_WIDTH/8{1'b1}};
            else if(DECODE_MEM_CTRL[1]) m_wmask = 3    << m_addr[ADDR_OFFSET_WIDTH - 1 : 0];
            else                 m_wmask = 1'b1 << m_addr[ADDR_OFFSET_WIDTH - 1 : 0];
        end
    end else begin
        m_din  = {DATA_WIDTH{1'b0}};
        m_wren = 1'b0;
        m_rden = 1'b0;
        m_wmask = {DATA_WIDTH/8{1'b1}};
    end
end

always_ff @(posedge CLK) begin : mem_ack
    if( (m_wren || m_rden) && M_HIT)  m_req_done_reg <= 1'b1;
    else                              m_req_done_reg <= 1'b0;
end

always_ff @(negedge CLK) begin : mem_offset
        if(m_wren || m_rden)              m_addr_offset_reg  <= EXE_OUT[ADDR_OFFSET_WIDTH - 1 : 0];
end

assign M_DIN     = m_din;
assign M_ADDR    = {m_addr[ADDR_WIDTH-1:2], 2'b00};
assign M_RDEN    = m_rden;
assign M_WREN    = m_wren;
assign M_WMASK   = m_wmask;
/**/


/*
* Since only the `mcycle` register is implemented in the CSR file,
* and it is read-only, there is no need to perform any write to the CSRs.
*
* - `CSR_VALID` is permanently set to 0 to disable CSRs write operations.
* - `CSR_WADDR` is tied to zero since no write will occur.
*/
assign CSR_VALID = 1'b0;
assign CSR_WADDR = {CSR_ADDR_WIDTH{1'b0}};
/**/






/*
* This block determines the final data to be written back to the general-purpose register file (`gpr_din`),
* depending on the `DECODE_GPR_CTRL` control signal.
*
* The possible sources are:
* - `EXE_OUT`               (DECODE_GPR_CTRL = 2'b01): result from the exe unit
* - `GPR_PC + ADDR_OFFSET`  (DECODE_GPR_CTRL = 2'b10): return address for jump instructions (JAL, JALR)
* - `DECODE_OP3`            (DECODE_GPR_CTRL = 2'b11): used for CSR instructions (data from CSR read)
* - `M_DOUT`                (DECODE_GPR_CTRL = 2'b00): data loaded from memory
*
* For LOAD instructions (`DECODE_GPR_CTRL = 2'b00`), memory data from `M_DOUT` is extracted
* and sign- or zero-extended based on `DECODE_MEM_CTRL`:
* - `DECODE_MEM_CTRL[2:1]` specifies the data width:
*     - 2'b00   → load byte
*     - 2'b01   → load half-word
*     - default → load word (full `DATA_WIDTH`)
*
* - `DECODE_MEM_CTRL[0]` specifies whether the load is unsigned (1) or signed (0).
*
* The byte/half-word is selected from `M_DOUT` using the saved offset (`m_addr_offset_reg`)
* and extended appropriately.
*
* If `DECODE_GPR_CTRL[2]` is not set, no write-back occurs and `gpr_din` is cleared.
*
* Notes:
* - `CSR_VAL` is set to 0 since no CSR write is used in this design.
*/
always_comb begin : rd_gen   
    if(DECODE_GPR_CTRL[2]) begin
        rd_valid = 1'b1;
            if(DECODE_GPR_CTRL[1:0] == 2'b01) gpr_din = EXE_OUT;
        else if(DECODE_GPR_CTRL[1:0] == 2'b10) gpr_din = GPR_PC + ADDR_OFFSET;
        else if(DECODE_GPR_CTRL[1:0] == 2'b11) gpr_din = DECODE_OP3;
        else begin
            rd_valid = m_req_done_reg;
            case(DECODE_MEM_CTRL[2:1])

                2'b00: begin // Read byte
                    mem_rdata = {8'b00000000, M_DOUT[(m_addr_offset_reg*8) +: 8]};
                    if(DECODE_MEM_CTRL[0]) gpr_din = {{DATA_WIDTH-8{1'b0}}, mem_rdata[7:0]};
                    else            gpr_din = mem_rdata[7] == 1 ? {{DATA_WIDTH-8{1'b1}}, mem_rdata[7:0]} : {{DATA_WIDTH-8{1'b0}}, mem_rdata[7:0]};
                end

                2'b01: begin // read half
                    mem_rdata = M_DOUT[(m_addr_offset_reg* 8) +: 16];
                    if(DECODE_MEM_CTRL[0]) gpr_din = {{DATA_WIDTH-16{1'b0}}, mem_rdata[15:0]};
                    else            gpr_din = mem_rdata[15] == 1 ? {{DATA_WIDTH-16{1'b1}}, mem_rdata[15:0]} : {{DATA_WIDTH-16{1'b0}}, mem_rdata[15:0]};
                end

                default: gpr_din = M_DOUT;
            endcase
        end
    end else begin 
        gpr_din = {DATA_WIDTH{1'b0}};
        rd_valid = 1'b0;
    end
end

assign RD               = DECODE_RD;
assign RD_VALID         = rd_valid;
assign RD_VAL           = gpr_din;
assign CSR_VAL          = {DATA_WIDTH{1'b0}};
/**/


/*
* This block computes the next value of the program counter (`pc_next`) based on:
* - The current GPR_PC                  (`GPR_PC`)
* - The reset signal                    (`RSTN`)
* - The decode/execute validity         (`DECODE_EXE_VALID`)
* - The memory state                    (`DECODE_MEM_CTRL[4]` and `m_req_done_reg`)
* - The program counter control signal  (`DECODE_PC_CTRL`)
*
* On reset (`RSTN` low): the GPR_PC is initialized to `START_ADDR`.
*
* If an instruction is valid (`DECODE_EXE_VALID`):
*   - If it's a memory instruction (`DECODE_MEM_CTRL[4]` set):
*     - If the memory access is complete (`m_req_done_reg`), advance the GPR_PC.
*     - Otherwise, hold the GPR_PC to stall execution.
*
*   - For non-memory instructions, `DECODE_PC_CTRL` determines the update mode:
*     - `PC_INC`  → Increment GPR_PC by `ADDR_OFFSET` (sequential execution)
*     - `PC_SET`  → Load GPR_PC with `EXE_OUT`, typically for JALR (address is already computed and aligned)
*     - `PC_ADD`  → Perform a GPR_PC-relative jump: GPR_PC + `EXE_OUT` (used for JAL)
*     - `PC_COND` → Conditional branch: if `EXE_OUT[0]` is set (condition true), GPR_PC += `DECODE_OP3`;
*                   otherwise, continue sequentially.
*
* - If the instruction is not valid, hold GPR_PC.
*
* This logic ensures proper handling of all control flow instructions, including jumps,
* branches, and returns, while maintaining memory consistency.
*/
always_comb begin : pc_gen
    if(!RSTN) begin
        pc_next = START_ADDR;
    end else if(DECODE_VALID) begin
        if(DECODE_MEM_CTRL[4]) begin
            if(m_req_done_reg) pc_next = GPR_PC + ADDR_OFFSET;
            else pc_next = GPR_PC;
        end else begin
            case(DECODE_PC_CTRL)
                PC_INC:  pc_next = GPR_PC + ADDR_OFFSET;
                PC_SET:  pc_next = {EXE_OUT[DATA_WIDTH-1:1], 1'b0};
                PC_ADD:  pc_next = GPR_PC + EXE_OUT;
                PC_COND: pc_next = EXE_OUT[0] ? GPR_PC + DECODE_OP3 : GPR_PC + ADDR_OFFSET;
            endcase
        end
    end else begin
        pc_next = GPR_PC;
    end
end

assign PC_NEXT = pc_next;
/**/


endmodule

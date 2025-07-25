/*!
********************************************************************************
*  \file      dpram.sv
*  \module    dpram
*  \brief     Dual-Port RAM (simulation-only)
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/06/2025
*
********************************************************************************
*  \details
*  This module implements a dual-port RAM intended exclusively for simulation.
*  It is not synthesizable as-is and is designed to be used with Verilator.
*
*  The interface mimics the one generated by Microchip’s Libero for the
*  PolarFire SoC/FPGA Dual-Port Large SRAM IP.
*
*  The full memory array is exposed at the top SystemVerilog level (`MEM`)
*  to allow direct access from C++ testbenches via DPI or Verilator tracing.
*
*  This model uses behavioral constructs and may exhibit unsafe multidrive behavior,
*  which is not suitable for FPGA synthesis. It must be replaced with a proper
*  instantiated memory IP in production or hardware deployment contexts.
********************************************************************************
*  \parameters
*    - DATA_WIDTH   : Width of the data bus, in bits
*    - SIZE         : Total size of the RAM, in bytes
*
*  \inputs
*    - A_CLK        : Clock signal for port A
*    - A_ADDR       : Address for port A
*    - A_DIN        : Data input for port A
*    - A_WBYTE_EN   : Byte-wise write mask for port A
*    - A_WEN        : Write enable for port A (1: write, 0: no write)
*    - A_REN        : Read enable for port A  (1: read,  0: no read)
*
*    - B_CLK        : Clock signal for port B
*    - B_ADDR       : Address for port B
*    - B_DIN        : Data input for port B
*    - B_WBYTE_EN   : Byte-wise write mask for port B
*    - B_WEN        : Write enable for port B (1: write, 0: no write)
*    - B_REN        : Read enable for port B  (1: read,  0: no read)
*
*  \outputs
*    - A_DOUT       : Data output for port A
*    - B_DOUT       : Data output for port B
*
*  \inouts
*    - None.
********************************************************************************
*  \versioning
*
*  Version   Date          Author          Description
*  -------   ----------    ------------    --------------------------------------
*  1.0       02/06/2025    Kawanami        Initial version of the module
*  1.1       [Date]        [Author]        Description
*  1.2       [Date]        [Author]        Description
*
********************************************************************************
*  \remarks
*  - This implementation complies with [reference or standard].
*  - TODO: [possible improvements or future features]
********************************************************************************
*/
module dpram
#(
    parameter                                       DATA_WIDTH  = 32,
    parameter                                       SIZE        = 1024
)
(

    output      logic [DATA_WIDTH-1:0]              MEM [0:DEPTH-1] ,

    input       logic                               A_CLK           ,
    /* verilator lint_off UNUSEDSIGNAL */                               // Disable Verilator warning `Bits of signal are not used`
    input       logic [ADDR_WIDTH   - 1 : 0]        A_ADDR          ,
    /* verilator lint_on UNUSEDSIGNAL */                                // Re-enable Verilator warning `Bits of signal are not used`
    input       logic [DATA_WIDTH   - 1 : 0]        A_DIN           ,
    input       logic [DATA_WIDTH/8 - 1 : 0]        A_WBYTE_EN      ,
    input       logic                               A_WEN           ,
    input       logic                               A_REN           ,
    output      logic [DATA_WIDTH   - 1 : 0]        A_DOUT          ,

    input       logic                               B_CLK           ,
    /* verilator lint_off UNUSEDSIGNAL */                               // Disable Verilator warning `Bits of signal are not used`
    input       logic [ADDR_WIDTH   - 1 : 0]        B_ADDR          ,
    /* verilator lint_on UNUSEDSIGNAL */                                // Re-enable Verilator warning `Bits of signal are not used`
    input       logic [DATA_WIDTH   - 1 : 0]        B_DIN           ,
    input       logic [DATA_WIDTH/8 - 1 : 0]        B_WBYTE_EN      ,
    input       logic                               B_WEN           ,
    input       logic                               B_REN           ,
    output      logic [DATA_WIDTH   - 1 : 0]        B_DOUT
);


localparam BYTE_LENGTH  = 8;                                            // Number of bits per byte
localparam DEPTH        = SIZE / (DATA_WIDTH / BYTE_LENGTH);            // Number of DATA_WIDTH-bit words in the memory
localparam ADDR_WIDTH   = $clog2(SIZE);                                 // Address width required to address each byte in memory
localparam OFFSET_WIDTH = $clog2(DATA_WIDTH / BYTE_LENGTH);             // Number of bits used to select the byte offset within a word

wire [ADDR_WIDTH - 1 : OFFSET_WIDTH] a_index;                           // Word index computed from A_ADDR (port A write path)
wire [ADDR_WIDTH - 1 : OFFSET_WIDTH] b_index;                           // Word index computed from B_ADDR (port B write path)
reg  [ADDR_WIDTH - 1 : OFFSET_WIDTH] a_rd_index_reg;                    // Registered word index for port A read (keeps stable address when REN=0)
reg  [ADDR_WIDTH - 1 : OFFSET_WIDTH] b_rd_index_reg;                    // Registered word index for port B read (keeps stable address when REN=0)


/* verilator lint_off MULTIDRIVEN */                                    // Disable Verilator warning `Signal has multiple driving blocks with different clocking`
logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];                                 // Memory
/* verilator lint_on MULTIDRIVEN */                                     // Re-enable Verilator warning `Signal has multiple driving blocks with different clocking`


assign a_index = A_ADDR[ADDR_WIDTH - 1 : OFFSET_WIDTH];                 // Extract word-aligned index from port A address
assign b_index = B_ADDR[ADDR_WIDTH - 1 : OFFSET_WIDTH];                 // Extract word-aligned index from port B address


/*
* Port A memory access logic.
*
* This block handles both write and read operations on port A.
*
* - On a write (`A_WEN` asserted), each byte in the word is conditionally updated
*   based on the byte enable mask (`A_WBYTE_EN`). The appropriate bytes of `A_DIN`
*   are stored in memory at the index derived from `A_ADDR`.
*
* - On a read (`A_REN` asserted), the word index derived from `A_ADDR` is latched
*   into `a_rd_index_reg`, so that the read output remains stable even when
*   `A_REN` is deasserted.
*
* The read output (`A_DOUT`) is driven combinatorially using the registered index.
*/
always_ff @(posedge A_CLK) begin
    if (A_WEN) begin
        for (int i = 0; i < DATA_WIDTH/8; i++) begin
            if (A_WBYTE_EN[i])
                mem[a_index][i*8 +: 8] <= A_DIN[i*8 +: 8];
        end
    end else if (A_REN) begin
        a_rd_index_reg <= a_index;
    end
end

assign A_DOUT = mem[a_rd_index_reg];
/**/

/*
* Port B memory access logic.
*
* This block is symmetrical to port A and handles both write and read operations
* on port B independently.
*
* - On a write (`B_WEN` asserted), selected bytes of the input word (`B_DIN`)
*   are written to memory based on the byte enable mask (`B_WBYTE_EN`).
*
* - On a read (`B_REN` asserted), the corresponding word index from `B_ADDR` is
*   stored in `b_rd_index_reg` to ensure consistent read output.
*
* The read output (`B_DOUT`) is driven combinatorially from the registered index.
*/
always_ff @(posedge B_CLK) begin
    if (B_WEN) begin
        for (int i = 0; i < DATA_WIDTH/8; i++) begin
            if (B_WBYTE_EN[i])
                mem[b_index][i*8 +: 8] <= B_DIN[i*8 +: 8];
        end
    end else if (B_REN) begin
        b_rd_index_reg <= b_index;
    end
end

assign B_DOUT = mem[b_rd_index_reg];
/**/

/*
* Memory exposure for simulation.
*
* The entire memory array (`mem`) is assigned to the `MEM` output,
* allowing C++ code (via Verilator DPI) to inspect or preload contents.
* This feature is meant for simulation only.
*/
assign MEM = mem;
/**/



endmodule

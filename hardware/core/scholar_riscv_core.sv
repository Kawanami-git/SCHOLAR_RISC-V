/*!
********************************************************************************
*  \file      scholar_riscv_core.sv
*  \module    scholar_riscv_core
*  \brief     SCHOLAR RISC-V Core Module
*
*  \author    Kawanami
*  \version   1.0
*  \date      01/06/2025
*
********************************************************************************
*  \details
* This module is the top-level module of the SCHOLAR RISC-V core.
* The SCHOLAR RISC-V core is an education-oriented 32-bit RISC-V implementation.
*
* ISA: RV32I base integer instruction set + 32-bit cycle counter (Zicntr subset).
*
* Limitations:
* - No operating system support:
*     - `ECALL` is treated as a NOP (no operation).
* - No debug support:
*     - `EBREAK` is treated as a NOP.
* - No support for multicore or memory consistency operations:
*     - `FENCE` and `FENCE.I` are treated as NOPs.
********************************************************************************
*  \parameters
*    - ARCHI      : Architecture (currently, only 32-bit version is supported)
*    - START_ADDR : Core boot address
*
*  \inputs
*    - CLK        : System clock
*    - RSTN       : System active low reset
*    - M_DOUT     : Memory output data
*    - M_HIT      : Memory HIT/MISS flag (1: hit, 0: miss)
*
*  \outputs
*    - M_ADDR     : Memory address requested by the core
*    - M_RDEN     : Memory read enable flag (1: read request, 0: idle)
*    - M_WREN     : Memory write enable flag (1: write request, 0: idle)
*    - M_WMASK    : Memory Byte-write mask (for partial word writes).
*    - M_DIN      : Memory input data
*
*  \inouts
*    - None.
*
********************************************************************************
*  \versioning
*
*  Version   Date          Author          Description
*  -------   ----------    ------------    --------------------------------------
*  1.0       01/06/2025    Kawanami        Initial version of the module
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

module scholar_riscv_core
    import archi_pkg::*;
#(
    parameter ARCHI         = 32,
    parameter START_ADDR    = {ARCHI{1'b0}}
)
(
`ifdef DUT
    input  wire                            GPR_EN                      ,
    input  wire [RF_ADDR_WIDTH - 1 : 0]    GPR_ADDR                    ,
    input  wire [ARCHI         - 1 : 0]    GPR_DATA                    ,
    output wire [ARCHI         - 1 : 0]    GPR_MEMORY [0:NB_GPR-1]     ,
    output wire [ARCHI         - 1 : 0]    GPR_PC_REG                  ,
    output wire [ARCHI         - 1 : 0]    CSR_MCYCLE                  ,
`endif

    input  wire                            CLK                         ,
    input  wire                            RSTN                        ,

    input  wire [ARCHI         - 1 : 0]    I_M_DOUT                    ,
    input  wire                            I_M_HIT                     ,
    output wire [ARCHI         - 1 : 0]    I_M_ADDR                    ,
    output wire                            I_M_RDEN                    ,

    input  wire [ARCHI         - 1 : 0]    D_M_DOUT                    ,
    input  wire                            D_M_HIT                     ,
    output wire [ARCHI         - 1 : 0]    D_M_ADDR                    ,
    output wire                            D_M_RDEN                    ,
    output wire                            D_M_WREN                    ,
    output wire [(ARCHI/8)     - 1 : 0]    D_M_WMASK                   ,
    output wire [ARCHI         - 1 : 0]    D_M_DIN
);

/******************** PARAMETERS VERIFICATION ********************/
if(ARCHI != 32) begin : gen_archi_check
    $fatal("FATAL ERROR: Only 32 bits architecture is supported.");
end
/********************                         ********************/

/******************** LOCAL PARAMETERS ********************/
/* verilator lint_off UNUSEDSIGNAL */
/********************                  ********************/

/******************** TYPES DEFINITION ********************/

/********************                  ********************/


/******************** WIRES ********************/

/*
* General purpose register file.
*/
wire [RF_ADDR_WIDTH  - 1 : 0] decode_rs1;
wire [RF_ADDR_WIDTH  - 1 : 0] decode_rs2;
wire [ARCHI          - 1 : 0] gpr_rs1_val;
wire [ARCHI          - 1 : 0] gpr_rs2_val;
wire [ARCHI          - 1 : 0] gpr_pc;
wire [ARCHI          - 1 : 0] commit_rd_val;
/**/

/*
* CSR file.
*/
wire [CSR_ADDR_WIDTH - 1 : 0] commit_csr_waddr;
wire [ARCHI          - 1 : 0] commit_csr_val;
wire                          commit_csr_valid;
wire [CSR_ADDR_WIDTH - 1 : 0] decode_csr_raddr;
wire [ARCHI          - 1 : 0] csr_val;
/**/

/*
* fetch.
*/
wire [INSTR_WIDTH    - 1 : 0] fetch_instr;
wire                          fetch_valid;
/**/


/*
* decode.
*/
wire [ARCHI          - 1 : 0] decode_op1;
wire [ARCHI          - 1 : 0] decode_op2;
wire [EXE_CTRL_WIDTH - 1 : 0] decode_exe_ctrl;
wire [ARCHI          - 1 : 0] decode_op3;
wire [RF_ADDR_WIDTH  - 1 : 0] decode_rd;
wire [PC_CTRL_WIDTH  - 1 : 0] decode_pc_ctrl;
wire [MEM_CTRL_WIDTH - 1 : 0] decode_mem_ctrl;
wire [GPR_CTRL_WIDTH - 1 : 0] decode_gpr_ctrl;
wire [CSR_CTRL_WIDTH - 1 : 0] decode_csr_ctrl;
wire                          decode_valid;
/**/

/*
* exe.
*/
wire [ARCHI          - 1 : 0] exe_out;
wire                          exe_valid;
/**/

/*
* commit.
*/
wire [RF_ADDR_WIDTH  - 1 : 0] commit_rd;
wire                          commit_rd_valid;
wire [ARCHI          - 1 : 0] commit_pc_next;
/**/

/********************       ********************/


/******************** REGISTERS ********************/

/********************           ********************/

/******************** MACHINE STATE ********************/

/********************               ********************/


/******************** CONTROL ********************/

/********************         ********************/

GPR
#(
    .ADDR_WIDTH             (ARCHI)                     ,
    .DATA_WIDTH             (ARCHI)                     ,
    .START_ADDR             (START_ADDR)
) GPR
(
`ifdef DUT
    .GPR_EN                 (GPR_EN)                    ,
    .GPR_ADDR               (GPR_ADDR)                  ,
    .GPR_DATA               (GPR_DATA)                  ,
    .GPR_MEMORY             (GPR_MEMORY)                ,
    .GPR_PC_REG             (GPR_PC_REG)                ,
`endif

    .CLK                    (CLK)                       ,
    .RSTN                   (RSTN)                      ,

    .DECODE_RS1             (decode_rs1)                ,
    .DECODE_RS2             (decode_rs2)                ,
    .COMMIT_RD              (commit_rd)                 ,
    .COMMIT_RD_VAL          (commit_rd_val)             ,
    .COMMIT_RD_VALID        (commit_rd_valid)           ,
    .RS1_VAL                (gpr_rs1_val)               ,
    .RS2_VAL                (gpr_rs2_val)               ,

    .COMMIT_PC_NEXT         (commit_pc_next)            ,
    .PC                     (gpr_pc)
);

CSR
#(
    .DATA_WIDTH         (ARCHI)
) CSR
(
`ifdef DUT
    .MCYCLE             (CSR_MCYCLE)                ,
`endif

    .CLK                (CLK)                       ,
    .RSTN               (RSTN)                      ,

    .COMMIT_CSR_WADDR   (commit_csr_waddr)          ,
    .COMMIT_CSR_VAL     (commit_csr_val)            ,
    .COMMIT_CSR_VALID   (commit_csr_valid)          ,
    .DECODE_RADDR       (decode_csr_raddr)          ,
    .CSR_VAL            (csr_val)
);

fetch
#(
    .ADDR_WIDTH         (ARCHI)
) fetch_unit
(
    .CLK                (CLK)                       ,
    .RSTN               (RSTN)                      ,

    .COMMIT_PC_NEXT     (commit_pc_next)            ,
    .INSTR              (fetch_instr)               ,
    .VALID              (fetch_valid)               ,

    .M_ADDR             (I_M_ADDR)                  ,
    .M_RDEN             (I_M_RDEN)                  ,
    .M_DOUT             (I_M_DOUT)                  ,
    .M_HIT              (I_M_HIT)
);

decode
#(
    .ADDR_WIDTH         (ARCHI)                     ,
    .DATA_WIDTH         (ARCHI)
) decode_unit
(
    .RSTN               (RSTN)                      ,

    .FETCH_INSTR        (fetch_instr)               ,
    .FETCH_VALID        (fetch_valid)               ,

    .RS1                (decode_rs1)                ,
    .GPR_RS1_VAL        (gpr_rs1_val)               ,
    .RS2                (decode_rs2)                ,
    .GPR_RS2_VAL        (gpr_rs2_val)               ,
    .GPR_PC             (gpr_pc)                    ,

    .CSR_RADDR          (decode_csr_raddr)          ,
    .CSR_VAL            (csr_val)                   ,

    .OP1                (decode_op1)                ,
    .OP2                (decode_op2)                ,
    .EXE_CTRL           (decode_exe_ctrl)           ,

    .OP3                (decode_op3)                ,
    .RD                 (decode_rd)                 ,
    .PC_CTRL            (decode_pc_ctrl)            ,
    .MEM_CTRL           (decode_mem_ctrl)           ,
    .GPR_CTRL           (decode_gpr_ctrl)           ,
    .CSR_CTRL           (decode_csr_ctrl)           ,

    .VALID              (decode_valid)
);

exe
#(
    .DATA_WIDTH         (ARCHI)
) exe_unit
(
    .DECODE_OP1         (decode_op1)                ,
    .DECODE_OP2         (decode_op2)                ,
    .DECODE_EXE_CTRL    (decode_exe_ctrl)           ,

    .OUT                (exe_out)
);

commit
#(
    .ADDR_WIDTH         (ARCHI)                     ,
    .DATA_WIDTH         (ARCHI)                     ,
    .START_ADDR         (START_ADDR)
) commit_unit
(
    .CLK                (CLK)                       ,
    .RSTN               (RSTN)                      ,

    .DECODE_VALID       (decode_valid)              ,
    .EXE_OUT            (exe_out)                   ,
    .DECODE_OP3         (decode_op3)                ,
    .DECODE_RD          (decode_rd)                 ,
    .DECODE_PC_CTRL     (decode_pc_ctrl)            ,
    .DECODE_MEM_CTRL    (decode_mem_ctrl)           ,
    .DECODE_GPR_CTRL    (decode_gpr_ctrl)           ,
    .DECODE_CSR_CTRL    (decode_csr_ctrl)           ,

    .RD_VAL             (commit_rd_val)             ,

    .RD                 (commit_rd)                 ,
    .RD_VALID           (commit_rd_valid)           ,
    .GPR_PC             (gpr_pc)                    ,
    .PC_NEXT            (commit_pc_next)            ,

    .CSR_WADDR          (commit_csr_waddr)          ,
    .CSR_VAL            (commit_csr_val)            ,
    .CSR_VALID          (commit_csr_valid)          ,

    .M_ADDR             (D_M_ADDR)                  ,
    .M_RDEN             (D_M_RDEN)                  ,
    .M_WREN             (D_M_WREN)                  ,
    .M_WMASK            (D_M_WMASK)                 ,
    .M_DIN              (D_M_DIN)                   ,
    .M_DOUT             (D_M_DOUT)                  ,
    .M_HIT              (D_M_HIT)
);

endmodule

#include "clocks_resets.h"
#include "Vriscv_env.h"

extern Vriscv_env*  dut;

void set_clk_signal(uint8_t CLK)
{
    dut->CORE_CLK = CLK;
    dut->AXI_CLK  = CLK;
}

void clock_tick()
{
    dut->CORE_CLK ^= 1;
    dut->AXI_CLK  ^= 1;
}

void set_core_reset_signal(uint8_t RSTN)
{
    dut->CORE_RSTN = RSTN;
}

void set_ram_reset_signal(uint8_t RSTN)
{
    dut->AXI_RSTN = RSTN;
}
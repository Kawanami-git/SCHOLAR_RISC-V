#include "defines.h"
#include "memory.h"

void main(void)
{
    int32_t integer = -123456789;
    uint32_t uinteger = 123456789;
    uint32_t luinteger = 987654321;
    uint32_t hex = 0xabcdef11;
    char s[] = "eprintf arguments test end.\n";

    mem_reset(SOFTCORE_0_CTP_RAM_START_ADDR, SOFTCORE_0_CTP_RAM_SIZE, 0);

    eprintf("Hi, i have been load correclty.\n");
    eprintf("Beginning eprintf arguments test.\n");

    eprintf("Integer (-123456789): %d\n", integer);
    eprintf("Unsigned Integer (123456789): %u\n", uinteger);
    eprintf("long unsigned Integer (987654321): %lu\n", luinteger);
    eprintf("Hex (0xabcdef11): 0x%x\n", hex);

    eprintf("String: %s", s);
    return;
}

#include "memory.h"
#include "axi4.h"
#include "defines.h"

/*
* These headers are shared between the simulation environment (C++)
* and the PolarFire Linux target (C). The following lines ensure
* proper linkage and compilation in both environments.
*/
#ifdef __cplusplus

extern "C" {
#include <cstdio>
#include <cstdlib>
}

#else

#include <stdio.h>
#include <stdlib.h>

#endif
/**/

uint32_t mem_write(uintptr_t addr, uint32_t* data, uint32_t size)
{
    uint32_t alignedSize;

    alignedSize     = (size + 3) & ~0x3;
    axi4_write(addr, data, alignedSize);

    return SUCCESS;
}

uint32_t mem_read(uintptr_t addr, uint32_t* data, uint32_t size)
{
    uint32_t alignedSize;

    alignedSize     = (size + 3) & ~0x3;
    axi4_read(addr, data, alignedSize);

    return SUCCESS;
}

void mem_reset(uint32_t addr, uint32_t size, uint32_t value)
{
    for(int i = 0; i < size; i+=4)
    {
        axi4_write(addr + i, &value, NB_BYTES_IN_WORD);
    }
}


uint32_t shared_write_ready()
{
    static uint32_t icount = 0;
    uint32_t count = 0;

    mem_read(SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR, &count, NB_BYTES_IN_WORD);

    if(icount == count) { icount++; return 1; }

    return 0;
}

uint32_t shared_read_ready()
{
    static uint32_t icount = 0;
    uint32_t count = 0;

    mem_read(SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR, &count, NB_BYTES_IN_WORD);

    if(count > icount)
    {
        icount++;
        mem_read(SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR, &count, NB_BYTES_IN_WORD);
        return count;
    }
    else { return 0; }
}

void shared_read_ack()
{
    static uint32_t icount = 0;
    icount++;
    mem_write(SOFTCORE_0_PTC_RAM_CORE_COUNT_ADDR, &icount, NB_BYTES_IN_WORD);
}

void shared_write_ack()
{
    static uint32_t icount = 0;
    icount++;
    mem_write(SOFTCORE_0_PTC_RAM_PLATFORM_COUNT_ADDR, &icount, NB_BYTES_IN_WORD);
}
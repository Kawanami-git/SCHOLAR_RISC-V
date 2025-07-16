#include "defines.h"
#include "memory.h"

void main(void) 
{
    uint32_t size = 0, alignedSize = 0;
    uint32_t  buf[128];

    mem_reset(SOFTCORE_0_CTP_RAM_START_ADDR, SOFTCORE_0_CTP_RAM_SIZE, 0);

    while(1)
    {
        while( (size = shared_read_ready()) == 0)
        {
            for(int i = 0; i < 10; i++) {}
        }

        alignedSize = (size + 3) & ~3;
        
        /*
        * Read + acknowledge
        */
        mem_read(SOFTCORE_0_PTC_RAM_DATA_ADDR, buf, alignedSize);
        shared_read_ack();    
        /**/

        /*
        * Write
        */
        mem_write(SOFTCORE_0_CTP_RAM_DATA_ADDR, buf, alignedSize);
        mem_write(SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR, (uint32_t*)&alignedSize, NB_BYTES_IN_WORD);
        shared_write_ack();
    }
}

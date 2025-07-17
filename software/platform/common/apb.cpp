#ifdef DUT

#include "apb.h"
#include "sim.h"
#include "defines.h"
#include "Vriscv_env.h"

extern Vriscv_env* dut;

void apb_write(uint32_t addr, uint32_t* data, uint32_t size)
{
    uint32_t localAddr = addr;

    for(int i = 0; i < size / NB_BYTES_IN_WORD; i++)
    {
        /*
        * Initialize transaction.
        * First select the APB bus, then enable it.
        * Wait for the bus to be ready (write completed).
        */
	    // dut->APB_ADDR   = localAddr;
	    // dut->APB_ENABLE = 0b0;
	    // dut->APB_SEL    = 0b1;
	    // dut->APB_WDATA  = data[i];
        // dut->APB_WMASK  = 0b1111;
	    // dut->APB_WE     = 0b1;
	    // cycle();

	    // dut->APB_ADDR   = localAddr;
	    // dut->APB_ENABLE = 0b1;
	    // dut->APB_SEL    = 0b1;
	    // dut->APB_WDATA  = data[i];
        // dut->APB_WMASK  = 0b1111;
	    // dut->APB_WE     = 0b1;
	    // while(dut->APB_READY == 0) { cycle(); }
		// cycle();
        /**/
        
        /*
        * Free the bus.
        */
	    // dut->APB_ADDR   = localAddr;
	    // dut->APB_ENABLE = 0b0;
	    // dut->APB_SEL    = 0b0;
	    // dut->APB_WDATA  = data[i];
        // dut->APB_WMASK  = 0b1111;
	    // dut->APB_WE     = 0b1;
	    // cycle();
        /**/
        
        localAddr += NB_BYTES_IN_WORD;     
    }
}

void apb_read(uint32_t addr, uint32_t* data, uint32_t size)
{
    uint32_t localAddr = addr;

    for(int i = 0; i < size / NB_BYTES_IN_WORD; i++)
    {
        /*
        * Initialize transaction.
        * First select the APB bus, then enable it.
        * Wait for the bus to be ready (data available).
        */
	    // dut->APB_ADDR   = localAddr;
	    // dut->APB_ENABLE = 0b0;
	    // dut->APB_SEL    = 0b1;
	    // dut->APB_WDATA  = 0x00000000;
	    // dut->APB_WE     = 0b0;
	    // cycle();

	    // dut->APB_ADDR   = localAddr;
	    // dut->APB_ENABLE = 0b1;
	    // dut->APB_SEL    = 0b1;
	    // dut->APB_WDATA  = 0x00000000;
	    // dut->APB_WE     = 0b0;
	    // while(dut->APB_READY == 0) { cycle(); }
		// cycle();
        /**/
        
        /*
        * Free the bus and retreive the data.
        */
	    // dut->APB_ADDR   = localAddr;
	    // dut->APB_ENABLE = 0b0;
	    // dut->APB_SEL    = 0b0;
	    // dut->APB_WDATA  = 0x00000000;
	    // dut->APB_WE     = 0b0;
	    // cycle();
	    // data[i] = dut->APB_RDATA;
        /**/
        
        localAddr += NB_BYTES_IN_WORD;     
    }
}

#endif
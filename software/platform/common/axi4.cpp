#include "axi4.h"
#include "defines.h"

#ifdef __cplusplus

extern "C"
{
    #include <stdio.h>
    #include <stdlib.h>
    #include <unistd.h>
}

#else

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#endif


#ifdef DUT // Simulation
#include "sim.h"
#include "Vriscv_env.h"

extern Vriscv_env* dut;

void axi4_write(uintptr_t addr, uint32_t* data, uint32_t size)
{
    uint32_t localAddr = addr;

    for(int i = 0; i < size / NB_BYTES_IN_WORD; i++)
    {
        dut->S_AXI_AWADDR  = localAddr;
        dut->S_AXI_AWBURST = 0b00;
        dut->S_AXI_AWSIZE  = 0b010;
        dut->S_AXI_AWLEN   = 0;
        dut->S_AXI_AWVALID = 0b1;

        while (dut->S_AXI_AWREADY == 0) { cycle(); }
        cycle();

        dut->S_AXI_AWVALID = 0x00000000;

        dut->S_AXI_WDATA  = data[i];
        dut->S_AXI_WVALID = 0b1;
        dut->S_AXI_WLAST  = 0b1;
        dut->S_AXI_WSTRB  = 0b1111;

        while (dut->S_AXI_WREADY == 0) { cycle(); }
        cycle();

        dut->S_AXI_WVALID = 0b0;
        dut->S_AXI_BREADY = 0b1;

        while (dut->S_AXI_BVALID == 0) { cycle(); }
        cycle();

        dut->S_AXI_AWVALID = 0b0;
        dut->S_AXI_BREADY = 0b0;
        cycle();

        localAddr += NB_BYTES_IN_WORD;
    }
}

void axi4_read(uintptr_t addr, uint32_t* data, uint32_t size)
{
    uint32_t localAddr = addr;

    for(int i = 0; i <  size/NB_BYTES_IN_WORD; i++) //size = 4 NB_BYTES_IN_WORD
    {
        dut->S_AXI_ARADDR  = localAddr;
        dut->S_AXI_ARBURST = 0b00;
        dut->S_AXI_ARSIZE  = 0b010;
        dut->S_AXI_ARLEN   = 0;
        dut->S_AXI_ARVALID = 0b1;
        while (dut->S_AXI_ARREADY == 0) { cycle(); }
        cycle();

        dut->S_AXI_ARVALID = 0b0;

        dut->S_AXI_RREADY = 0b1;
        while (dut->S_AXI_RVALID == 0) { cycle(); }
        data[i] = dut->S_AXI_RDATA;
        cycle();

        dut->S_AXI_ARADDR  = 0x00000000;



        dut->S_AXI_ARVALID = 0b0;
        dut->S_AXI_RREADY = 0b0;
        cycle();

        localAddr += NB_BYTES_IN_WORD;
    }
}

#else // PolarFire

#include <sys/mman.h>
#include <fcntl.h>

static uint32_t* axi_start_address;

void setup_axi4(uint32_t start_addr, uint32_t size)
{
  int fd = open("/dev/mem", O_RDWR|O_SYNC);
  if (fd < 0)
  {
    printf("Error. Could not open /dev/mem. Try running with 'sudo'. \n");
    exit(-1);
  }

  axi_start_address = (uint32_t*)mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, start_addr);
  close(fd);

  if (axi_start_address == MAP_FAILED)
  {
    printf("Error: axi_start_address mapping failed\n");
    exit(-1);
  }
}

void finalize_axi4(uint32_t size)
{
    munmap((void*)axi_start_address, size);
}

void axi4_write(uintptr_t addr, uint32_t* data, uint32_t size)
{
    uint32_t* localaddr = axi_start_address + (addr/4);
    for(int i = 0; i < size / NB_BYTES_IN_WORD; i++) { *localaddr = *data; localaddr++; data++; }
}

void axi4_read(uintptr_t addr, uint32_t* data, uint32_t size)
{
    uint32_t* localaddr = axi_start_address + (addr/4);
    for(int i = 0; i < size / NB_BYTES_IN_WORD; i++) { *data = *localaddr; localaddr++; data++;}
}

#endif
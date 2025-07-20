#include "Vriscv_env.h"
#include <sys/file.h>

#include "defines.h"
#include "sim.h"
#include "sim_log.h"
#include "log.h"
#include "clocks_resets.h"
#include "memory.h"
#include "spike_parser.h"
#include "simulation.h"
#include "args_parser.h"

extern Vriscv_env*  dut;
extern uint64_t     errors;


uint32_t load_firmware(char* filename)
{
    uint32_t data, buf;
    uint32_t addr = 0;
    uint32_t flag = 0;
    uint32_t nbErrors = 0;
    char line[256];

    FILE* f = fopen(filename, "r");
    if(f == NULL) { printf("Error: Unable to open firmware %s.\n", filename); return -1; }

    /*
    * Firmware format is address:instruction.
    */
    while (fgets(line, sizeof(line), f))
    {
      line[strcspn(line, "\n")] = 0;

      if (sscanf(line, "%x:%x", &addr, &data) == 2)
      {
        if( (flag = mem_write(addr, &data, NB_BYTES_IN_WORD)) != SUCCESS)
        {
          printf("Error: Unable to write %u bytes at address %08x. Error code: %u\n", NB_BYTES_IN_WORD, addr, flag);
          nbErrors++;
          continue;
        }
      }
      else
      {
          printf("Erreur de parsing dans la ligne: %s\n", line);
      }
    }
    fclose(f);
    /**/

    /*
    * Unreset the core if the firmware has been loaded correctly.
    */
    if(nbErrors == 0)
    {
        set_core_reset_signal(1);
    }
    /**/

    return nbErrors;
}

uint32_t run(char* firmwarefile, char* spikefile)
{
    uint32_t flag = SUCCESS;

    // Parse spike log
    SpikeLog* spike = parse_spike(spikefile);
    if(spike == NULL) { return FAILURE; }

    // Reset RAMs and load firmware
    set_ram_reset_signal(1);
    if(load_firmware(firmwarefile) != SUCCESS) { return FAILURE; }

    Instr* instr = spike->instructions;
    cycle(); // Send fetch request
    cycle(); // Instruction available in fetch register

    while(memcmp(instr->instr, "ebreak", strlen("ebreak")) != 0)
    {
        // Check instruction fetch address
        if(dut->GPR_PC_REG != instr->addr)
        {
            flag = FAILURE;
            log_printf("Instruction %s error: Instruction address shall be %08x but it %08x.\n", instr->instr, instr->addr, dut->GPR_PC_REG);
        }

        // Commit current instruction, fetch next
        cycle();

        // Extra cycle for memory access (load/store)
        if((instr->instr_bin & 0b1111111) == 0b0000011 || (instr->instr_bin & 0b1111111) == 0b0100011)
        {
            cycle();
        }

        // Check next instruction PC value
        if(dut->GPR_PC_REG != instr->next->addr)
        {
            flag = FAILURE;
            log_printf("Instruction %s error: PC value should be %08x but is %08x.\n", instr->instr, instr->next->addr, dut->GPR_PC_REG);
        }

        // Handle store instructions (memory writes)
        if((instr->instr_bin & 0b1111111) == 0b0100011)
        {
            uint32_t data = (dut->DATA_DPRAM_MEM[(instr->mem_addr & 0xffff) / 4]) >> ((instr->mem_addr & 0b11) * 8);

            if(((instr->instr_bin >> 12) & 0b111) == 0b000) // SB
            {
                if((data & 0xff) != instr->mem_data)
                {
                    flag = FAILURE;
                    log_printf("Instruction %s error: Written data at address %08x should be %08x but is %08x.\n",
                               instr->instr, instr->mem_addr, instr->mem_data, data & 0xff);
                }
            }
            else if(((instr->instr_bin >> 12) & 0b111) == 0b001) // SH
            {
                if((data & 0xffff) != instr->mem_data)
                {
                    flag = FAILURE;
                    log_printf("Instruction %s error: Written data at address %08x should be %08x but is %08x.\n",
                               instr->instr, instr->mem_addr, instr->mem_data, data & 0xffff);
                }
            }
            else
            {
                if(data != instr->mem_data) // SW
                {
                    flag = FAILURE;
                    log_printf("Instruction %s error: Written data at address %08x should be %08x but is %08x.\n",
                               instr->instr, instr->mem_addr, instr->mem_data, data);
                }
            }
        }

        // Handle register write (or CSR)
        else
        {
            if((instr->instr_bin & 0b1111111) == 0b1110011) // CSR (e.g. mcycle)
            {
                if(dut->GPR_MEMORY[instr->rd] != dut->CSR_MCYCLE - 1)
                {
                    flag = FAILURE;
                    log_printf("Instruction %s error: Data in RD %02u should be %08x but is %08x.\n",
                               instr->instr, instr->rd, dut->CSR_MCYCLE, dut->GPR_MEMORY[instr->rd]);
                }

                // Force RD to match Spike (one cycle per instruction)
                dut->GPR_ADDR = instr->rd;
                dut->GPR_DATA = instr->rd_data;
                dut->GPR_EN   = 1;
                comb();
                dut->GPR_EN   = 0;
            }
            else
            {
                if(dut->GPR_MEMORY[instr->rd] != instr->rd_data)
                {
                    flag = FAILURE;
                    log_printf("Instruction %s error: Data in RD %02u should be %08x but is %08x.\n",
                               instr->instr, instr->rd, instr->rd_data, dut->GPR_MEMORY[instr->rd]);
                }
            }
        }

        if(flag != SUCCESS) break;
        instr = instr->next;
    }

    cycle(); // Final commit
    return flag;
}


int main(int argc, char** argv, char** env)
{
    uint32_t flag = SUCCESS;
    Arguments args = {0, NULL, NULL, NULL, NULL, NULL};

    parse_args(argc, argv, &args);
    if(args.logfile == NULL)
    {
        fprintf(stderr, "Invalid Arguments. Usage: %s --logfile <file> --firmware <file> --spike <file> --waveform <file>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    if(args.firmwarefile == NULL || args.spikefile == NULL || args.waveformfile == NULL)
    {
        log_printf("Invalid Arguments. Usage: %s --logfile <file> --firmware <file> --spike <file> --waveform <file>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    if( set_log_file(args.logfile) != SUCCESS)
    { 
        printf("Error: unable to open log file: %s\n", args.logfile);      
        #ifndef DUT
            finalize_axi4(FIC0_SIZE);
        #endif
        return FAILURE;
    }

    init_sim(args.waveformfile);

    flag = run(args.firmwarefile, args.spikefile);

    if(flag != SUCCESS) { log_printf("FAILURE\n");  }
    else                { log_printf("SUCCESS\n"); }

    finalize_sim();
    if(flag == SUCCESS) { exit(EXIT_SUCCESS); }
    else { exit(EXIT_FAILURE); }
}

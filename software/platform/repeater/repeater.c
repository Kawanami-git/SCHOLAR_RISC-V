#ifdef DUT
#include "clocks_resets.h"
#include "sim.h"
#endif

#include "defines.h"
#include "memory.h"
#include "axi4.h"
#include "args_parser.h"
#include "log.h"

/*
* These headers are shared between the simulation environment (C++)
* and the PolarFire Linux target (C). The following lines ensure
* proper linkage and compilation in both environments.
*/
#ifdef __cplusplus

extern "C"
{
    #include <unistd.h>
    #include <stdlib.h>
    #include <string.h>
    #include <stdio.h>
    #include <sys/select.h>
    #include <time.h>
}

#else

#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/select.h>
#include <time.h>

#endif
/**/

uint32_t load_firmware(char* filename)
{
    uint32_t addr = 0, data = 0;
    uint32_t flag = 0;
    uint32_t nbErrors = 0;
    char line[256];

    log_printf("Writting firmware in softcore RAM...\n");

    /*
    * On the polarFire, reset the SCHOLAR RISC-V core
    * by writting in a GPIO (connected to both the SCHOLAR RISC-V and a led)
    */
    #ifndef DUT
        FILE *file = fopen("/sys/devices/platform/leds/leds/led1/brightness", "w");
        if(file == NULL) { log_printf("Error: Unable to open reset file to reset softcore."); return -1; }
        fprintf(file, "0");
        fclose(file);
        sleep(1);
    #endif
    /**/

    /*
    * Reset instr/data mem
    */
    mem_reset(SOFTCORE_0_INSTR_RAM_START_ADDR, SOFTCORE_0_INSTR_RAM_SIZE, data);
    mem_reset(SOFTCORE_0_DATA_RAM_START_ADDR, SOFTCORE_0_DATA_RAM_SIZE, data);
    /**/

    /*
    * Open the firmware and load it.
    * Firmware format: addr:data.
    */
    FILE* f = fopen(filename, "r");
    if(f == NULL) { log_printf("Error: Unable to open firmware %s.\n", filename); return -1; }

    while (fgets(line, sizeof(line), f))
    {
        line[strcspn(line, "\n")] = 0;

        if (sscanf(line, "%x:%x", &addr, &data) == 2)
        {
            if( (flag = mem_write(addr, &data, NB_BYTES_IN_WORD)) != SUCCESS)
            {
                log_printf("Error: Unable to write %u bytes at address %08x. Error code: %u\n", NB_BYTES_IN_WORD, addr, flag);
                nbErrors++;
                continue;
            }
        }
        else
        {
            log_printf("Parsing error in line: %s\n", line);
        }
    }
    fclose(f);
    /**/

    /*
    * If no error is detected, unreset the SCHOLAR RISC-V core.
    */
    if(nbErrors == 0)
    {
        #ifdef DUT
            set_core_reset_signal(1);
        #else
            FILE *file = fopen("/sys/devices/platform/leds/leds/led1/brightness", "w");
            if(file == NULL) { log_printf("Error: Unable to open reset file to unreset softcore."); return -1; }
            fprintf(file, "1");
            fclose(file);
            sleep(1);
        #endif
    }
    /**/

    log_printf("Done.\n\n");
    return nbErrors;
}


#ifdef DUT
unsigned int run(int argc, char** argv)
{
    set_ram_reset_signal(1);
#else
unsigned int main(int argc, char** argv)
{
    setup_axi4(FIC0_START_ADDR, FIC0_SIZE);
    mem_reset(SOFTCORE_0_PTC_RAM_START_ADDR, SOFTCORE_0_PTC_RAM_SIZE, 0);
#endif

    Arguments args = {0, NULL, NULL, NULL, NULL, NULL};
    parse_args(argc, argv, &args);

    if( set_log_file(args.logfile) != SUCCESS)
    { 
        printf("Error: unable to open log file: %s\n", args.logfile);      
        #ifndef DUT
            finalize_axi4(FIC0_SIZE);
        #endif
        return FAILURE;
    }
    
    if( load_firmware(args.firmwarefile) != SUCCESS) 
    { 
        log_printf("Error: unable to open firmware: %s\n", args.firmwarefile); 
        #ifndef DUT
            finalize_axi4(FIC0_SIZE);
        #endif
        return FAILURE;
    }



    // User can modify program from here.
    uint32_t stdin_size = 0, ctp_size = 0;
    unsigned char buf[1024] = { 0 };

    struct timeval tv;
    fd_set fds;
    tv.tv_sec = 0;
    tv.tv_usec = 10000;

    printf("Repeater is ready.\nPleaser enter a text or use 'q' to quit.\n\n");

    /*
    * Main polling loop:
    *
    * Continuously monitors:
    *   - stdin for user input
    *   - core-to-platform shared memory (CTP RAM) for messages from the core
    *
    * Behavior:
    *   - If user types 'q' + Enter, exits the program.
    *   - Otherwise, input is padded to 4-byte alignment and written to
    *     the platform-to-core shared RAM (PTC RAM). A write acknowledge is sent.
    *   - If the core returns a message in the CTP RAM, it is read, printed,
    *     acknowledged, and the buffer is cleared.
    *   - In simulation (DUT defined), if no activity is detected,
    *     the DUT simulation is advanced by 100 clock cycles.
    */
    while(1)
    {
        FD_ZERO(&fds);
        FD_SET(STDIN_FILENO, &fds);
        tv.tv_usec = 10000;

        if(select(fileno(stdin) + 1, &fds, NULL, NULL, &tv))
        {
            stdin_size = read(STDIN_FILENO, buf, sizeof(buf) - 1);
            if(stdin_size == 2 && buf[0] == 'q') { goto RETURN; }
            buf[stdin_size] = '\0';

            log_printf("Input data: %s", buf);
            stdin_size = (stdin_size + 3) & ~3;

            mem_write(SOFTCORE_0_PTC_RAM_DATA_ADDR, (uint32_t*)buf, stdin_size);
            mem_write(SOFTCORE_0_PTC_RAM_DATA_SIZE_ADDR, &stdin_size, NB_BYTES_IN_WORD);

            shared_write_ack();

            memset(buf, 0, 1024);
        }
        else if((ctp_size = shared_read_ready()) != 0)
        {
            mem_read(SOFTCORE_0_CTP_RAM_DATA_ADDR, (uint32_t*)buf, ctp_size);
            shared_read_ack();
            buf[ctp_size] = '\0';
            log_printf("Output data: %s\n", buf);
            printf("%s", buf);
            memset(buf, 0, 1024);
        }
        #ifdef DUT
        else
        {
            for(int i = 0; i < 100; i++) { cycle();}
        }
        #endif
    }

RETURN:
    #ifndef DUT
        finalize_axi4(FIC0_SIZE);
    #endif
    return SUCCESS;
}
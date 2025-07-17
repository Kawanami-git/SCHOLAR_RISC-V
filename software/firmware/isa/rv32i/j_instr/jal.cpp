#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#include "args_parser.h"

uint32_t generate_jal(Arguments* args)
{
    uint8_t  rd;

    FILE *file = fopen(args->out, "w");
    if (!file)
    {
        printf("Error, unable to open %s\n", args->out);
        return 0x01;
    }

    fprintf(file,
        ".global _start\n"
        "_start:\n"
        "   addi x5, x0, 0\n"
        "   addi x10, x0, 0\n"
        "   addi x11, x0, 0\n"
    );

    // taken jal to jump to begin
    fprintf(file,
    "   jal x2, begin  # Instruction under test.\n\n"
    );

    fprintf(file,
    "back:\n"
    "   jal x2, _end  # Instruction under test.\n\n"
    );

    // Set of not taken jal
    fprintf(file,
    "begin:\n"
    );

    for(uint8_t i = 0; i < args->nb_instr - 3; i++)
    {
        fprintf(file,
        "   addi x0, x0, 0\n"
        );
    }

    rd = (rand() % 31) + 1;

    fprintf(file,
    "   jal x%hhu, back  # Instruction under test.\n\n",
    rd
    );

    fprintf(file,
        "_end:\n"
        "   la      t1, tohost\n"
        "   li      t2, 1\n"
        "   sw      t2, 0(t1)\n"
        "   ebreak\n"
        "exit_loop:   \n"
        "   j exit_loop\n\n"
    );

    /*
    * Generate 128 bytes of data that can be used if necessary.
    * Also generate tohost and fromhost data for spike communication.
    */
    fprintf(file,
    ".section .data\n"
    ".global data\n\n"
    "data:\n");
    for (int j = 0; j < 128/4; j++) { fprintf(file, "   .word 0x%08X\n", rand()); }
    fprintf(file, "\n");
    fprintf(file,
        "tohost: .dword 0\n"
        "fromhost: .dword 0\n\n"
    );
    /**/


    fclose(file);

    return 0x00;
}

int main(int argc, char** argv)
{
    srand(time(NULL));

    Arguments args;

    parse_args(argc, argv, &args);
    if(generate_jal(&args) != 0x00) { exit(EXIT_FAILURE); }


    exit(EXIT_SUCCESS);
}

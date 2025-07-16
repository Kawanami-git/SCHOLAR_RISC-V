#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#include "args_parser.h"

uint32_t generate_jalr(Arguments* args)
{
    uint8_t  rd;
    uint8_t  rs1;
    int16_t  imm;

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

    // taken jalr to jump to begin
    fprintf(file,
    "   la x1, begin\n"
    "   jalr x2, x1, 0  # Instruction under test.\n\n"
    );

    fprintf(file,
    "back:\n"
    "   la x1, _end\n"
    "   jalr x2, x1, 0  # Instruction under test.\n\n"
    );

    // Set of not taken jalr
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
    rs1 = (rand() % 31) + 1;
    imm = 0x18;

    fprintf(file,
    "   lui  x%hhu, 0x80000\n"
    "   jalr x%hhu, x%hhu, %hd  # Instruction under test.\n\n",
    rs1, rd, rs1, imm
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
    if(generate_jalr(&args) != 0x00) { exit(EXIT_FAILURE); }

    return 0;
}

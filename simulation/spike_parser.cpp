#include "spike_parser.h"
#include "defines.h"

#include <stdio.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
    #include <cstring>
    }

    #else

    #include <string.h>

    #endif

/*
* Skip leading spaces in [buf, endptr].
* Returns pointer to first non-space char or endptr.
*/
char* remove_spaces(char* buf, char* endptr)
{
    char* ptr = buf;
    while(ptr != endptr && *ptr == ' ') { ptr++; }
    return ptr;
}

/*
* Skip non-space chars in [buf, endptr].
* Returns pointer to first space char or endptr.
*/
char* move_to_next_space(char* buf, char* endptr)
{
    char* ptr = buf;
    while(ptr != endptr && *ptr != ' ') { ptr++; }
    return ptr;
}

/*
* Parse core information.
*/
char* parse_core(Instr* instruction, char* ptr, char* lfptr)
{
    ptr = move_to_next_space(ptr, lfptr);
    ptr = remove_spaces(ptr, lfptr);
    sscanf(ptr, "%hhu", &(instruction->core));
    ptr = move_to_next_space(ptr, lfptr);
    ptr = remove_spaces(ptr, lfptr);
    return ptr;
}

/*
* Parse instruction address information.
*/
char* parse_addr(Instr* instruction, char* ptr, char* lfptr)
{
    sscanf(ptr, "%x", &(instruction->addr));
    ptr = move_to_next_space(ptr, lfptr);
    ptr = remove_spaces(ptr, lfptr);
    return ptr;
}

/*
* Parse the instruction (binary format).
*/
char* parse_instr_bin(Instr* instruction, char* ptr, char* lfptr)
{
    ptr++; // remove '('
    sscanf(ptr, "%x", &(instruction->instr_bin));
    ptr = move_to_next_space(ptr, lfptr);
    ptr = remove_spaces(ptr, lfptr);
    return ptr;
}

/*
* Parse the instructions (string format).
*/
char* parse_instr(Instr* instruction, char* ptr, char* lfptr)
{
    memcpy(instruction->instr, ptr, lfptr - ptr);
    return lfptr;
}

/*
* Parse destination register.
*/
char* parse_rd(Instr* instruction, char* ptr, char* lfptr)
{
    ptr++; // skip 'x'
    sscanf(ptr, "%hhu", &(instruction->rd));
    ptr = move_to_next_space(ptr, lfptr);
    ptr = remove_spaces(ptr, lfptr);
    return ptr;
}

/*
* Parse destination register data.
*/
char* parse_rd_data(Instr* instruction, char* ptr, char* lfptr)
{
    sscanf(ptr, "%x", &(instruction->rd_data));
    ptr = move_to_next_space(ptr, lfptr);
    ptr = remove_spaces(ptr, lfptr);

    return ptr;
}

/*
* Parse memory address and memory data (in case of load/store).
*/
char* parse_mem(Instr* instruction, char* ptr, char* lfptr)
{
    ptr = move_to_next_space(ptr, lfptr); // Skip 'mem'
    ptr = remove_spaces(ptr, lfptr);

    sscanf(ptr, "%x", &(instruction->mem_addr));

    ptr = move_to_next_space(ptr, lfptr);
    ptr = remove_spaces(ptr, lfptr);
    if(ptr != lfptr)
    {
        sscanf(ptr, "%x", &(instruction->mem_data));
    }

    return lfptr;
}

uint32_t parse(SpikeLog* spike, FILE* file)
{
    char line[1024];

    spike->instructions = (Instr*)calloc(1, sizeof(Instr));
    Instr* next = NULL;
    Instr* current  = spike->instructions;

    while (fgets(line, sizeof(line), file) != NULL)
    {
        // Parse first line (instruction line)
        char* ptr = line;
        char* lfptr = ptr;
        while(*lfptr != '\0') { lfptr++; }

        ptr = parse_core(current, ptr, lfptr);
        ptr = parse_addr(current, ptr, lfptr);
        ptr = parse_instr_bin(current, ptr, lfptr);
        ptr = parse_instr(current, ptr, lfptr);

        // Stop on ebreak (end of spike execution)
        if(memcmp(current->instr, "ebreak", strlen("ebreak")) == 0) { break; }

        // Parse second line (result/output line)
        if(fgets(line, sizeof(line), file) == NULL) { return 0; }
        ptr = line;
        lfptr = ptr;
        while(*lfptr != '\0') { lfptr++; }

        // Skip to content after ')'
        while(*ptr != ')') { ptr++; }
        ptr++; // skip ')'
        ptr = remove_spaces(ptr, lfptr);

        // Check GPR writeback
        if(*ptr == 'x')
        {
            ptr = parse_rd(current, ptr, lfptr);
            ptr = parse_rd_data(current, ptr, lfptr);
        }

        // Check memory access
        if(memcmp(ptr, "mem", 3) == 0)
        {
            ptr = parse_mem(current, ptr, lfptr);
        }

        // Skip non-user instructions (e.g., spike internals)
        if(current->addr < 0x80000000 ) { continue; }

        // Allocate next instruction node
        next  = (Instr*)calloc(1, sizeof(Instr));
        current->next = next;
        current = next;
    }
    return SUCCESS;
}

SpikeLog* parse_spike(const char* filename)
{
    SpikeLog*   spike = NULL;
    FILE*       file  = NULL;

    file = fopen(filename, "r");
    if(file == NULL)
    {
        printf("Error, unable to open file: %s\n", filename);
        goto RETURN;
    }

    spike = (SpikeLog*)calloc(1, sizeof(SpikeLog));
    if(spike == NULL)
    {
        printf("Error, unable to allocate memory for SpikeLog structure\n");
        goto RETURN;
    }
    parse(spike, file);

RETURN:
    if(file) { fclose(file); }
    return spike;
}

void free_spike(SpikeLog* spike)
{
    Instr* current = spike->instructions;
    Instr* next    = spike->instructions->next;
    while(current)
    {
        free(current);
        current = next;
        if(next) { next = next->next; }
    }
    free(spike);
}
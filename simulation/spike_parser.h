/*!
********************************************************************************
*  \files     spike_parser.h / spike_parser.cpp
*  \brief     Spike logs parser
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/06/2025
*
********************************************************************************
*  \details
*  These files provide functions for parsing spike logs, allowing to compare
*  the SCHOLAR RISC-V core (DUT) execution with the spike trace.
********************************************************************************
*  \defines
*    - None
*
*  \typedefs
*    - SpikeLog     : Structure used to store a spike log in memory
*    - Instr        : Structure used to store a spike log instruction in memory
*
*  \structures
*    - SpikeLog     : Structure used to store a spike log in memory
*    - Instr        : Structure used to store a spike log instruction in memory
*
*  \functions
*    - parse_spike  : Parses a spike log and return a pointer to the trace in memory
*    - free_spike   : Free the spike log from memory
********************************************************************************
*  \versioning
*
*  Version   Date        Author          Description
*  -------   ----------  ------------    --------------------------------------
*  1.0       02/06/2025  Kawanami        Initial version
*  1.1       [Date]      [Author]        Description
********************************************************************************
*  \remarks
*  - This implementation complies with [reference or standard].
*  - TODO: .
********************************************************************************
*/


#ifndef __SPIKE_PARSER_H__
#define __SPIKE_PARSER_H__

#include <stdint.h>

typedef struct Instr
{
    uint8_t     core;           // Core Id (unused as DUT is single core)
    uint32_t    addr;           // Address of the instruction
    uint32_t    instr_bin;      // Instruction (binary format)
    char        instr[32];      // Instruction (asm format)
    int8_t      rd;             // Destination register
    uint32_t    rd_data;        // Data to set in the destination register

    uint32_t    mem_addr;       // Memory address (if memory access)
    uint32_t    mem_data;       // Memory data (data read or written in memory)

    struct      Instr* next;    // Next instruction.
}Instr;

typedef struct SpikeLog
{
    Instr* instructions;
}SpikeLog;

/*!
********************************************************************************
*  \brief   Parse a spike log file
********************************************************************************
*  - FILE / FUNCTION NAME       : spike_parser.cpp / parse_spike
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    filename      : The path to the spike log file to be parsed
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       SpikeLog*     : A pointer to the parsed spike trace in memory
*                                Returns NULL if parsing fails
********************************************************************************
*  \remarks
*  This function opens the specified spike log file, parses its contents, and
*  returns a pointer to a structure (`SpikeLog`) that holds the parsed trace.
*  If an error occurs during parsing (e.g., file not found),
*  the function returns NULL.
********************************************************************************
*/
SpikeLog* parse_spike(const char* filename);

/*!
********************************************************************************
*  \brief   Free memory allocated for the spike log
********************************************************************************
*  - FILE / FUNCTION NAME       : spike_parser.cpp / free_spike
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    spike         : Pointer to the `SpikeLog` structure to be freed
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function frees the memory allocated for the spike log, which was
*  previously obtained by the `parse_spike` function.
*  After calling this function, the `spike` pointer should not be used.
********************************************************************************
*/
void free_spike(SpikeLog* spike);


#endif // __SPIKE_PARSER_H__
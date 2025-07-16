/*!
********************************************************************************
*  \file       args_parser.h / args_parser.cpp
*  \brief      Command-line argument parser for simulation runtime.
*
*  \author     Kawanami
*  \version    1.0
*  \date       02/06/2025
*
********************************************************************************
*  \details
*  These files define a lightweight argument parser used to process command-line
*  inputs provided at simulation runtime. It extracts user-defined configuration
*  options such as firmware path, log output, waveform generation, and the number
*  of instructions to execute (ISA tests), making them accessible through a
*  simple C struct.
********************************************************************************
*  \defines
*    - None.
*
*  \typedefs
*    - Arguments    : Type definition of the Arguments structure
*
*  \structures
*    - Arguments    : Holds all relevant user-defined simulation parameters
*
*  \functions
*    - parse_args   : Parses `argc` and `argv[]` and fills an `Arguments` structure
*
********************************************************************************
*  \versioning
*
*  Version   Date        Author          Description
*  -------   ----------  ------------    --------------------------------------
*  1.0       02/06/2025  Kawanami        Initial version
*  1.1       [Date]      [Author]        Description
*
********************************************************************************
*  \remarks
*  - This implementation complies with [reference or standard].
*  - TODO: .
********************************************************************************
*/

#ifndef __ARGS_PARSER__
#define __ARGS_PARSER__

#include <stdint.h>

typedef struct
{
    int32_t nb_instr;
    char*   out;

    char*   logfile;
    char*   firmwarefile;
    char*   spikefile;
    char*   waveformfile;
} Arguments;

/*!
********************************************************************************
*  \brief       Command-line argument parser
********************************************************************************
*  - FILE / FUNCTION NAME : args_parser.cpp / parse_args
*  - SPECIFICATION        : Parses command-line arguments and fills
*                           an `Arguments` structure.
*
********************************************************************************
*  \param[in]    argc    Number of arguments provided to the program
*  \param[in]    argv    Array of argument strings
*
*  \param[out]   args    Pointer to a structure that will be
*                        populated with parsed arguments
*
*  \param[inout] None
*
*  \return       void
*
********************************************************************************
*  \remarks
*  This function parses user-provided input arguments (e.g., via the command line)
*  and stores the values in a simple structure for easy use throughout
*  the simulation runtime.
*  It does not perform deep validation or error checking beyond basic format parsing.
********************************************************************************
*/
void parse_args(int argc, char* argv[], Arguments* args);


#endif
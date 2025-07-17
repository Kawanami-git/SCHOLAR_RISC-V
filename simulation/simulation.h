/*!
********************************************************************************
*  \files     simulation.h / simulation.cpp / simulation_vs_spike.cpp
*  \brief     Simulation entry points
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/06/2025
*
********************************************************************************
*  \details
*  These files are the main entry points for simulation of the SCHOLAR RISC-V.
*
*  - `simulation_vs_spike.cpp` is used for ISA-level validation. It compares,
*    cycle by cycle, the DUT (SCHOLAR RISC-V) execution against a Spike golden trace,
*    verifying RAM contents, CSR state, and GPR values.
*
*  - `simulation.cpp` is used to run standalone programs. It initializes the
*    simulation environment and logging, then delegates execution to a user-defined
*    `run()` function implemented in the `platform/` directory.
*    The behavior of `run()` depends on the selected program (e.g., loader, repeater, cyclemark).
*    Typically, it begins by loading the firmware into the SCHOLAR RISC-V instruction RAM,
*    then enables communication with the core, either to receive data or perform read/write exchanges.
*
*  The overall environment is designed for test automation, functional coverage,
*  and debugging via waveform traces and structured logs.
********************************************************************************
*  \defines
*    - None
*
*  \typedefs
*    - None
*
*  \structures
*    - None
*
*  \functions
*    - run          : Entry point to the user-defined simulation logic
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

#ifndef __SIMULATION_H__
#define __SIMULATION_H__

#include "args_parser.h"

/*!
********************************************************************************
*  \brief   Entry point of the user simulation logic
********************************************************************************
*  - FILE / FUNCTION NAME       : simulation.cpp / run
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    args           : Array of input argument strings
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       int            : Exit code (0 for success, others for failure)
********************************************************************************
*  \remarks
*  The actual implementation of this function is defined by the user
*  in the `platform/` directory. It depends on the simulated program.
********************************************************************************
*/
unsigned int run(int argc, char** argv);


#endif
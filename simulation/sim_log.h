/*!
********************************************************************************
*  \files     sim_log.h / sim_log.cpp
*  \brief     Logs management for simulation debugging
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/06/2025
*
********************************************************************************
*  \details
*  These files provide functions for managing simulation logs, primarily for
*  waveform analysis and debugging. Logs are written to a designated file
*  and can be used to trace the state of signals over time.
*  The logging system ensures structured and timestamped recording of events.
********************************************************************************
*  \defines
*    - logs_write(args...)  : Macro wrapping `fprintf` to format and write logs to a file
*
*  \typedefs
*    - None.
*
*  \structures
*    - None.
*
*  \functions
*    - init_logs            : Initializes the logging system and opens the log file
*    - finalize_logs        : Finalizes the logging system and closes the log file
*    - trace                : Captures the current values of all monitored signals
*                             and writes them to the log file
*
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


#ifndef __SIM_LOG_H__
#define __SIM_LOG_H__

#include <verilated_vcd_c.h>

#define logs_write(args...) fprintf(logs, args)

/*!
********************************************************************************
*  \brief   Initializes the log system
********************************************************************************
*  - FILE / FUNCTION NAME       : sim_log.cpp / init_logs
*  - SPECIFICATION              :
********************************************************************************.
*  \param[in]    traceFilename  Path/filename of the waveform trace file (signal values).
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function initializes the log system used by the simulation to log simulation
*  data, such as signals values.
*  It must be called at the beginning of the program, before testing the DUT.
********************************************************************************/
void init_logs(const char* traceFilename);

/*!
********************************************************************************
*  \brief   Finalizes the log system
********************************************************************************
*  - FILE / FUNCTION NAME       : sim_log.cpp / finalize_logs
*  - SPECIFICATION              :
********************************************************************************
*  \param[out]   None
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function finalizes the log system used by the simulation to log simulation
*  data, such as signal values.
*  It must be called at the end of the program, after DUT testing, to ensure the
*  conformity and integrity of the log files.
********************************************************************************/
void finalize_logs();

/*!
*  \brief   Prints the current DUT signals value
********************************************************************************
*  - FILE / FUNCTION NAME       : sim_log.cpp / trace
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    simTime   : The elapsed time of the simulation.
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       Void
********************************************************************************
*  \remarks
*  This function prints all the current signals value of the DUT in the
*  waveform log file.
*  This function does not need to be called manually, as it is automatically
*  invoked inside the tick() function (sim.h).
********************************************************************************/
void trace(uint64_t simTime);


#endif
/*
*  \file       log.h
*  \brief      Logging utility functions
*
*  \author     Kawanami
*  \version    1.0
*  \date       07/06/2025
*
********************************************************************************
*  \details
*  This file declares utility functions for logging information to files.
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
*    - set_log_file()        : Sets the path/filename for the log file.
*    - log_printf()          : Equivalent to printf, but writes to the log file.
********************************************************************************
*  \versioning
*
*  Version   Date        Author          Description
*  -------   ----------  ------------    --------------------------------------
*  1.0       07/06/2025  Kawanami        Initial version
*  1.1       [Date]      [Author]        Description
********************************************************************************
*  \remarks
*  - This implementation complies with [reference or standard].
*  - TODO:
********************************************************************************
*/

#ifndef __LOG_H__
#define __LOG_H__

#include <stdint.h>

/*!
********************************************************************************
*  \brief   Set the log file filename into a local variable
********************************************************************************
*  - FILE / FUNCTION NAME       : log.cpp / set_log_file
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    filename       : Path/name of the log file
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function set the log file filename into a local variable, used by the
*  `log_printf` function to print logs.
********************************************************************************
*/
uint32_t set_log_file(char* filename);

/*!
********************************************************************************
*  \brief   Formatted log printing to the simulation log file
********************************************************************************
*  - FILE / FUNCTION NAME       : log.cpp / log_printf
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    format         : Format string (like printf)
*                ...            : Variable arguments for formatted output
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function redirects formatted output to the simulation log file.
*  It mimics the standard printf interface.
********************************************************************************
*/
void log_printf(const char* format, ...);

#endif
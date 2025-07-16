#include "log.h"
#include "defines.h"
/*
* These headers are shared between the simulation environment (C++)
* and the PolarFire Linux target (C). The following lines ensure
* proper linkage and compilation in both environments.
*/
#ifdef __cplusplus

extern "C"
{
    #include <stdlib.h>
    #include <string.h>
    #include <stdio.h>
    #include <sys/file.h>
    #include <stdarg.h>
}

#else

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/file.h>
#include <stdarg.h>

#endif
/**/

char* logfile;

uint32_t set_log_file(char* filename)
{
    FILE* log_file = fopen(filename, "a");
    if(!log_file) {return FAILURE; }
    fclose(log_file);
    logfile = filename;
    return SUCCESS;
}

void log_printf(const char* format, ...)
{
    FILE* log_file = fopen(logfile, "a");
    if (!log_file) { return; }

    flock(fileno(log_file), LOCK_EX);

    va_list args;
    va_start(args, format);

    vfprintf(log_file, format, args);

    va_end(args);

    flock(fileno(log_file), LOCK_UN);

    fclose(log_file);
}

 
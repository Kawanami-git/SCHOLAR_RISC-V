
#include "args_parser.h"
#include <stdlib.h>
#include <getopt.h>

void parse_args(int argc, char *argv[], Arguments *args)
{
    static struct option long_options[] =
    {
        {"nb_instr", required_argument, 0, 'n'},
        {"out",      required_argument, 0, 'o'},
        {"logfile",  required_argument, 0, 'l'},
        {"firmware", required_argument, 0, 'f'},
        {"spike",    required_argument, 0, 's'},
        {"waveform", required_argument, 0, 'w'},
        {0, 0, 0, 0}
    };

    int opt;
    optind = 1;
    while ((opt = getopt_long(argc, argv, "n:o:l:f:s:w:", long_options, NULL)) != -1)
    {
        if(optarg == NULL) continue;
        switch (opt)
        {
            case 'n':
                args->nb_instr     = atoi(optarg);
                break;
            case 'o':
                args->out           = optarg;
                break;
            case 'l':
                args->logfile       = optarg;
                break;
            case 'f':
                args->firmwarefile  = optarg;
                break;
            case 's':
                args->spikefile     = optarg;
                break;
            case 'w':
                args->waveformfile  = optarg;
                break;
            default:
                break;
        }
    }
}

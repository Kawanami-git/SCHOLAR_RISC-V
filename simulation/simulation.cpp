#include "defines.h"
#include "sim.h"
#include "sim_log.h"
#include "simulation.h"
#include "args_parser.h"

extern uint64_t     errors;

int main(int argc, char** argv, char** env)
{
    Arguments args = {0, NULL, NULL, NULL, NULL, NULL};

    parse_args(argc, argv, &args);

    if(args.waveformfile == NULL)
    {
        fprintf(stderr, "Invalid Arguments. Usage: %s --logfile <file> --firmware <file> --waveform <file>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    init_sim(args.waveformfile);

    run(argc, argv);

    finalize_sim();
    exit(EXIT_SUCCESS);
}

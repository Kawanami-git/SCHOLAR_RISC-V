#include "sim.h"
#include "Vriscv_env.h"
#include "clocks_resets.h"
#include "sim_log.h"

static uint64_t    simTime = 0;
static uint64_t    ticks   = 0;
static uint64_t    errors  = 0;
static uint32_t    waves   = 0;

Vriscv_env* dut = NULL;

void init_sim(const char* traceFilename)
{
    dut = new Vriscv_env;
    if(traceFilename != NULL) { init_logs(traceFilename); waves = 1; }
    cycle();
    tick();
}

void finalize_sim()
{
    if(waves) { finalize_logs(); }
    delete dut;
}

void tick()
{
    /*
    * Simulation timeout.
    */
    if(simTime >= MAX_SIM_TIME)
    {
        printf("SIMULATION TIMEOUT. %lu ERRORS DETECTED.\n", errors);
        finalize_logs();
        delete dut;
        exit(0);
    }
    /**/

    simTime += SIM_STEP/100;
    dut->eval();
    if(waves) { trace(simTime); }

    simTime += 99*(SIM_STEP/100);
    ticks++;
    clock_tick();
    dut->eval();
    if(waves) { trace(simTime); }

}

void cycle()
{
    tick();
    tick();
}

void comb()
{
    dut->eval();
}
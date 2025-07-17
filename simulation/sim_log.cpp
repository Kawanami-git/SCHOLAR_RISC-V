#include "sim_log.h"
#include "Vriscv_env.h"

extern Vriscv_env*   dut;

VerilatedVcdC*       mTrace = NULL;

void init_logs(const char* traceFilename)
{
    Verilated::traceEverOn(true);
    mTrace = new VerilatedVcdC;
    dut->trace(mTrace, 5);
    mTrace->open(traceFilename);
}

void finalize_logs()
{
    mTrace->close();
    delete mTrace;
}

void trace(vluint64_t simTime)
{
    mTrace->dump(simTime);
}
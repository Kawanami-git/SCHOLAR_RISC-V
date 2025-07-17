/*!
********************************************************************************
*  \files     sim.h / sim.cpp
*  \brief     Simulation management
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/06/2025
*
********************************************************************************
*  \details
*  These files provide functions for managing the simulation.
********************************************************************************
*  \defines
*    - VERILATOR_DEFAULT_CLOCK      : Default Verilator clock is 1e12 Hz
*    - CLOCK                        : Simulation clock
*    - SIM_STEP                     : Simulation step (time between two signals capture)
*    - MAX_CYCLES                   : Maximum number of cycles for the simulation
*    - MAX_SIM_TIME                 : Maximum time of simulation
*
*  \typedefs
*    - None.
*
*  \structures
*    - None.
*
*  \functions
*    - init_sim                     : Initializes the simulation
*    - finalize_sim                 : Finalizes the simulation
*    - tick                         : Makes the simulation progress by one tick, evaluate
*                                     the DUT signals and logs them
*    - cycle                        : Executes two ticks
*    - comb                         : Evaluates the DUT signals without making the simulation
*                                     progress (simulate combinational logic).
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

#ifndef __SIM_H__
#define __SIM_H__

#include <verilated.h>

#define VERILATOR_DEFAULT_CLOCK         1000000000000
#define CLOCK                           1000000
#define SIM_STEP                        VERILATOR_DEFAULT_CLOCK / CLOCK

#ifndef MAX_CYCLES
#define MAX_CYCLES                      2000000
#endif

#define MAX_SIM_TIME                    SIM_STEP*MAX_CYCLES


/*!
********************************************************************************
*  \brief   Initializes the simulation
********************************************************************************
*  - FILE / FUNCTION NAME       : sim.cpp / init_sim
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    traceFilename  Path/filename of the waveform trace file (signal values)
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function initializes the simulation by instantiating the Vriscv_env class,
*  which represents the Vriscv_env hardware model.
*  This function should be called at the start of the program before any simulation steps.
********************************************************************************/
void init_sim(const char* traceFilename);

/*!
********************************************************************************
*  \brief   Finalizes the simulation
********************************************************************************
*  - FILE / FUNCTION NAME       : sim.cpp / finalize_sim
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    None
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function finalizes the simulation by closing the logs and freeing
*  the Vriscv_env object instantiated.
*  This function must be called at the end of the program,
*  after all simulation steps have been executed.
********************************************************************************/
void finalize_sim();

/*!
*  \brief   Simulation trigger (half cycle)
********************************************************************************
*  - FILE / FUNCTION NAME       : tb/sim.cpp / tick
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    None
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function advances the simulation by half a cycle.
*  Each call moves the simulation forward by SIM_STEPS/100 picoseconds (ps),
*  then evaluates the DUT signals to mimic combinational behavior.
*
*  It then advances the simulation by the remaining (99 * SIM_STEPS)/100 ps,
*  toggles the clock signal (rising or falling edge), and re-evaluates the signals
*  to complete the half-cycle simulation step.
*
*  At each call, the clock is inverted to emulate a full clock waveform over two calls.
*
*  Additionally, this function records the signal values into a waveform trace file
*  by invoking the `trace` function defined in logs.h.
********************************************************************************/
void tick();



/*!
*  \brief   Simulation trigger (full cycle)
********************************************************************************
*  - FILE / FUNCTION NAME       : tb/sim.cpp / cycle
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    None
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function advances the simulation by one full cycle.
*  It calls the "tick()" function twice to simulate
*  both the rising and falling edges of the clock.
********************************************************************************/
void cycle();

/*!
*  \brief   Evaluate the DUT signals without progressing the simulation
********************************************************************************
*  - FILE / FUNCTION NAME       : tb/sim.cpp / comb
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    None
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function evaluates the DUT signals without advancing
*  the simulation time.
*  It is typically used to apply changes to DUT internal values
*  (e.g., forcing a register or signal) without affecting simulation timing.
********************************************************************************/
void comb();


#endif
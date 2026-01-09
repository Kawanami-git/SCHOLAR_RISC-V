// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       sim.h
\brief      Verilator simulation control API (init, time advance, finalize)
\author     Kawanami
\version    1.0
\date       19/12/2025

\details
  Public API to drive the Verilator simulation:
  - Create/destroy the DUT top (\ref InitSim, \ref FinalizeSim)
  - Advance time with clock toggles (\ref Tick, \ref Cycle)
  - Evaluate combinational logic without time advance (\ref Comb)

  Tracing (VCD) is enabled when a non-empty filename is passed to \ref InitSim.

\remarks
  - This header intentionally avoids including the heavy Verilated model.
    Code that needs the DUT class should include "Vriscv_env.h" directly.

\section sim_h_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami   | Initial version.                          |
********************************************************************************
*/

#ifndef SIM_H
#define SIM_H

#include <string>
#include <verilated.h>

/* ===== Timing & limits ===================================================== */
/*!
 * \def VERILATOR_TICK
 * \brief Verilator base time quantum in picoseconds (1e12 ps per “tick”).
 */
#define VERILATOR_TICK 1000000000000ULL

/*!
 * \def VERILATOR_CLOCK
 * \brief Convenience divider: one full period equals two ticks.
 */
#define VERILATOR_CLOCK (VERILATOR_TICK / 2ULL)

/*!
 * \def CLOCK
 * \brief Simulation target clock in Hz (default 1 MHz).
 */
#define CLOCK 1000000UL

/*!
 * \def SIM_STEP
 * \brief Half-cycle step in picoseconds computed from \ref CLOCK.
 */
#define SIM_STEP (VERILATOR_CLOCK / (CLOCK))

#ifndef MAX_CYCLES
/*!
 * \def MAX_CYCLES
 * \brief Global limit on cycles before timeout.
 */
#define MAX_CYCLES 6000000UL
#endif

/*!
 * \def MAX_SIM_TIME
 * \brief Absolute simulation timeout in picoseconds.
 */
#define MAX_SIM_TIME (SIM_STEP * (MAX_CYCLES))

/* ===== API ================================================================= */

/*!
 * \brief Initialize the simulation and optionally enable VCD tracing.
 *
 * Creates the Verilated top instance, enables tracing if \p traceFilename is
 * non-empty, and performs a short settling sequence so the initial waveform
 * captures are meaningful.
 *
 * \param[in] traceFilename  Path to the VCD file; empty string disables tracing.
 */
void InitSim(const std::string& traceFilename);

/*!
 * \brief Finalize the simulation and release resources.
 *
 * Closes the VCD file (if enabled) and deletes the Verilated top instance.
 */
void FinalizeSim();

/*!
 * \brief Advance the simulation by one half-cycle.
 *
 * Performs a small pre-edge settle/eval, dumps (if tracing), toggles the clock,
 * evaluates again, and dumps (if tracing). Also enforces a global timeout
 * based on \ref MAX_SIM_TIME.
 */
void Tick();

/*!
 * \brief Advance the simulation by one full cycle (two half-cycles).
 *
 * Equivalent to calling \ref Tick twice (rising + falling edges).
 */
void Cycle();

/*!
 * \brief Evaluate the DUT without advancing time (pure combinational settle).
 *
 * Useful after forcing inputs when you don’t want to advance the clock.
 */
void Comb();

#endif

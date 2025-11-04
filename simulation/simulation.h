// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       simulation.h
\brief      Simulation entry points
\author     Kawanami
\version    1.1
\date       25/10/2025

\details
  Declarations for the simulation entry points used by the SCHOLAR RISC-V
  environment.

  - `simulation.cpp` hosts the generic standalone runner that initializes the TB
    and calls the user scenario.
  - `simulation_vs_spike.cpp` can host ISA-level validation against a Spike
    trace (not declared here).

\remarks
  - The `run()` symbol is implemented by the user scenario under `platform/`.

\section simulation_h_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/06/2025 | Kawanami   | Initial version.                          |
| 1.1     | 24/10/2025 | Kawanami   | Update the whole file for coding style compliance.<br>Update
the whole file comments for doxygen support. |
********************************************************************************
*/

#ifndef SIMULATION_H
#define SIMULATION_H

/*!
 * \brief Entry point of the user-defined simulation logic.
 *
 * The implementation lives in `platform/` and typically:
 * - loads firmware,
 * - sets up shared-memory handshakes,
 * - runs the main I/O or test loop.
 *
 * \param[in] argc  Argument count.
 * \param[in] argv  Argument vector.
 * \return \ref SUCCESS on success, or an error code (see \ref defines.h).
 */
unsigned int run(int argc, char** argv);

#endif

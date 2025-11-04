// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       platform.cpp
\brief      Entry point for driving SCHOLAR RISC-V on SIM or PolarFire Linux target
\author     Kawanami
\version    1.0
\date       25/10/2025

\details
  Unified main loop for two environments, selected at compile time:

  - SIM (Verilator)
    * Entry function is `run(argc, argv)` (called by the simulation harness).
    * Uses `cycle()` to advance time and optional reset helpers from sim headers.
    * AXI helpers write directly into the simulated model (no /dev/mem).

  - Platform (PolarFire Linux target)
    * Entry function is `main(argc, argv)`.
    * Maps AXI regions with `/dev/mem` via `SetupInstrAxi4()` / `SetupAxi4()`.

  Behavior:
    * Parses CLI options (log file, firmware path, etc.) with `Arguments`.
    * Configures the logger (append mode).
    * Loads the firmware text file (addr:data) into INSTR/DATA RAMs.
    * Enters a polling loop to relay stdin to the core and print core messages.

  All AXI addresses passed to helpers are **window-relative** offsets
  (consistent with the rest of the software stack).

\remarks
  - On SIM builds, `run()` is exported (instead of `main()`) for the harness.
  - Use 'q' + Enter in the console to quit the loop gracefully.

\section platform_cpp_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 25/10/2025 | Kawanami   | Initial version.                          |
| 1.1     | xx/xx/xxxx | Author     |                                           |
********************************************************************************
*/

#ifdef SIM
#include "clocks_resets.h"
#include "sim.h"
#endif

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <sys/select.h>
#include <unistd.h>

#include "args_parser.h"
#include "axi4.h"
#include "defines.h"
#include "load.h"
#include "log.h"
#include "memory.h"

/*------------------------------------------------------------------------------
 * Helpers
 *----------------------------------------------------------------------------*/

/// Align up 'x' to the next multiple of 'a' (a must be power of 2).
static inline uword_t AlignUp(uword_t x, uword_t a) { return (x + (a - 1)) & ~(a - 1); }

/*------------------------------------------------------------------------------
 * Entry point(s)
 *----------------------------------------------------------------------------*/

#ifdef SIM
/**
 * \brief Simulation entry (called by the harness).
 */
unsigned int run(int argc, char** argv)
{
  // Optional: assert RAM reset (provided by your sim integration).
  SetRamResetSignal(1);
#else
/**
 * \brief Platform entry (PolarFire Linux target).
 */
int main(int argc, char** argv)
{
  // Map the AXI regions we'll use. Errors are handled by return codes.
  if (SetupInstrAxi4(FIC0_START_ADDR, FIC0_SIZE) != SUCCESS)
  {
    std::cout << "Error: SetupInstrAxi4 failed." << std::endl;
    return FAILURE;
  }
  if (SetupAxi4(FIC0_START_ADDR, FIC0_SIZE) != SUCCESS)
  {
    std::cout << "Error: SetupAxi4 failed." << std::endl;
    FinalizeInstrAxi4();
    return FAILURE;
  }

  // Clear PTC region at boot to a known state.
  (void)MemReset(SOFTCORE_0_PTC_RAM_START_ADDR, SOFTCORE_0_PTC_RAM_SIZE, 0);
#endif

  // Parse CLI options
  Arguments args;
  args.Parse(argc, argv);

  // Init logger (append mode)
  if (SetLogFile(args.GetLogFile()) != SUCCESS)
  {
    std::cout << "Error: unable to open log file: " << args.GetLogFile() << std::endl;
#ifndef SIM
    FinalizeAxi4();
    FinalizeInstrAxi4();
#endif
    return FAILURE;
  }

  // Load firmware into INSTR/DATA RAMs
  if (LoadFirmware(args.GetFirmwareFile()) != SUCCESS)
  {
    LogPrintf("Error: unable to load firmware: %s\n", args.GetFirmwareFile().c_str());
#ifndef SIM
    FinalizeAxi4();
    FinalizeInstrAxi4();
#endif
    return FAILURE;
  }

  /*----------------------------------------------------------------------------
   * Main polling loop
   *
   * Monitors:
   *  - stdin: user input to send to PTC RAM (platform → core)
   *  - CTP RAM: messages from core → platform
   *----------------------------------------------------------------------------*/
  uword_t stdinSize = 0;
  uword_t ctpSize   = 0;

  // Note: buffer is 1KB; messages longer than that will be truncated.
  unsigned char buf[1024] = {0};

  std::printf("Starting %s...\n\n",
#ifdef SIM
              "simulation"
#else
              "platform session"
#endif
  );

  while (true)
  {
    // Setup poll on STDIN with a short timeout
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);

    timeval tv{};
    tv.tv_sec  = 0;
    tv.tv_usec = 10000; // 10ms

    const int ready = select(STDIN_FILENO + 1, &fds, nullptr, nullptr, &tv);

    if (ready > 0 && FD_ISSET(STDIN_FILENO, &fds))
    {
      // Read user input
      const ssize_t n = ::read(STDIN_FILENO, buf, sizeof(buf) - 1);
      if (n <= 0)
      {
        // EOF or error; treat as graceful exit.
        break;
      }

      // 'q' + Enter (n == 2 and buf[0] == 'q') -> exit
      if (n == 2 && buf[0] == 'q')
      {
        break;
      }

      // Null-terminate for logging / printf
      buf[n] = '\0';
      LogPrintf("Send: %s", buf);

      // Pad to word boundary for MMIO write
      stdinSize = AlignUp(static_cast<uword_t>(n), 4);

      // Write into PTC RAM (platform → core)
      (void)MemWrite(SOFTCORE_0_PTC_RAM_DATA_ADDR, reinterpret_cast<uword_t*>(buf), stdinSize);
      (void)MemWrite(SOFTCORE_0_PTC_RAM_DATA_SIZE_ADDR, &stdinSize, NB_BYTES_IN_WORD);

      // Signal "data available" to the core
      SharedWriteAck();

      // Clear local buffer
      std::memset(buf, 0, sizeof(buf));
    }
    else if ((ctpSize = SharedReadReady()) != 0)
    {
      // Core has placed a message in CTP RAM
      (void)MemRead(SOFTCORE_0_CTP_RAM_DATA_ADDR, reinterpret_cast<uword_t*>(buf), ctpSize);
      SharedReadAck();

      // Null-terminate and relay
      if (ctpSize < sizeof(buf))
      {
        buf[ctpSize] = '\0';
      }
      LogPrintf("Receive: %s\n", buf);
      std::printf("%s", buf);

      // Clear local buffer
      std::memset(buf, 0, sizeof(buf));
    }
#ifdef SIM
    else
    {
      // In simulation, tick the DUT when idle to keep things moving.
      for (int i = 0; i < 50; ++i)
      {
        Cycle();
      }
    }
#endif
  }

#ifndef SIM
  // Clean unmap on platform builds
  FinalizeAxi4();
  FinalizeInstrAxi4();
#endif

  return SUCCESS;
}

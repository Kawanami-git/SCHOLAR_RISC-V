// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       load.cpp
\brief      Firmware loader for SCHOLAR RISC-V (parses addr:data and writes RAM)
\author     Kawanami
\version    1.0
\date       25/10/2025

\details
  Loads a text firmware file containing lines of the form:
    addr_hex:data_hex

  Addresses may come from SPIKE traces (user-space 0x8... addresses). We
  normalize them into the AXI fabric offset by masking to the lower 24 bits
  (tag + offset) before deciding which RAM to target and performing the write.

  Writes go through the AXI helpers:
    - InstrMemWrite() for the instruction RAM (4B beats),
    - MemWrite()      for the data RAM     (NB_BYTES_IN_WORD beats).

  The function resets the RAMs before programming, and finally releases the
  core reset if no errors occurred.

\remarks
  - Addresses passed to the AXI helpers are **window-relative** (offsets),
    not absolute physical addresses.
  - This loader enforces region membership (INSTR vs DATA). Any address outside
    those ranges is treated as DATA by default, but you may tighten it.

\section load_cpp_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 25/10/2025 | Kawanami   | Initial version.                          |
| 1.1     | xx/xx/xxxx | Author     |                                           |
********************************************************************************
*/

#include "load.h"

#include <cerrno>
#include <chrono>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <string>
#include <thread>

#include "clocks_resets.h"
#include "log.h"
#include "memory.h"

using std::string;

/*------------------------------------------------------------------------------
 * Helpers
 *----------------------------------------------------------------------------*/

/*!
 * \brief Normalize a SPIKE/user-space address into an AXI fabric offset.
 *
 * We keep only the lower 24 bits (tag[23:20] + offset[19:0]) used by the fabric.
 * This makes 0x8___ addresses comparable to our region constants and usable
 * as window-relative offsets for the AXI backends.
 */
static inline uintptr_t NormalizeAxiOffset(uintptr_t a) { return (a & 0x00FFFFFFu); }

/*!
 * \brief Range check with [base, base+size) semantics.
 */
static inline bool InRange(uintptr_t x, uintptr_t base, uintptr_t size)
{
  return (x >= base) && (x < (base + size));
}

/*------------------------------------------------------------------------------
 * Public API
 *----------------------------------------------------------------------------*/

/*!
 * \brief Load a firmware text file into the RISC-V RAMs.
 *
 * \param[in] filename  Path to the firmware file ("addr:data" per line, hex).
 * \return number of lines that failed to write (0 on success), or FAILURE if
 *         the file couldn't be opened or a fatal step failed.
 */
uword_t LoadFirmware(const string& filename)
{
  uword_t addr     = 0;
  uword_t data     = 0;
  uword_t flag     = 0;
  uword_t nbErrors = 0;
  char    line[256];

  LogPrintf("Writing firmware into softcore RAM...\n");

  // Open firmware text file
  std::FILE* f = std::fopen(filename.c_str(), "r");
  if (f == nullptr)
  {
    LogPrintf(
        "Error: unable to open firmware '%s' (%s).\n", filename.c_str(), std::strerror(errno));
    return FAILURE;
  }

#ifndef SIM
  // Platform reset: drive a sysfs LED tied to the core reset (active-low/high depends on wiring).
  {
    std::FILE* rf = std::fopen("/sys/devices/platform/leds/leds/led1/brightness", "w");
    if (rf == nullptr)
    {
      LogPrintf("Error: unable to open platform reset handle (sysfs).\n");
      std::fclose(f);
      return FAILURE;
    }
    std::fprintf(rf, "0"); // assert reset (as designed in your wiring)
    std::fclose(rf);
    std::this_thread::sleep_for(std::chrono::seconds{1});
  }

  // Clear both INSTR/DATA memories before programming
  {
    const uword_t zero = 0;
    if (InstrMemReset(SOFTCORE_0_INSTR_RAM_START_ADDR, SOFTCORE_0_INSTR_RAM_SIZE, 0u) != SUCCESS)
    {
      LogPrintf("Error: failed to reset INSTR RAM.\n");
    }
    if (MemReset(SOFTCORE_0_DATA_RAM_START_ADDR, SOFTCORE_0_DATA_RAM_SIZE, zero) != SUCCESS)
    {
      LogPrintf("Error: failed to reset DATA RAM.\n");
    }
  }
#endif

  // Parse firmware lines: "<addr_hex>:<data_hex>"
  while (std::fgets(line, sizeof(line), f))
  {
    // strip trailing newline
    line[std::strcspn(line, "\n")] = 0;

    // skip blank/comment lines
    if (line[0] == '\0' || line[0] == '#' || (line[0] == '/' && line[1] == '/'))
    {
      continue;
    }

    // parse (WORD_SCAN_FMT uses 32/64 based on XLEN / defines.h)
    if (std::sscanf(line, WORD_SCAN_FMT ":" WORD_SCAN_FMT, &addr, &data) == 2)
    {
      const uintptr_t rel = NormalizeAxiOffset(static_cast<uintptr_t>(addr));

      if (InRange(rel, SOFTCORE_0_INSTR_RAM_START_ADDR, SOFTCORE_0_INSTR_RAM_SIZE))
      {
        // INSTR region: 4B write
        flag = InstrMemWrite(rel, reinterpret_cast<const uint32_t*>(&data), 4);
        if (flag != SUCCESS)
        {
          LogPrintf("Error: write 4 bytes @ 0x" WORD_PRINT_FMT " failed, code=" WORD_PRINT_FMT "\n",
                    (uword_t)rel,
                    flag);
          ++nbErrors;
          continue;
        }
      }
      else if (InRange(rel, SOFTCORE_0_DATA_RAM_START_ADDR, SOFTCORE_0_DATA_RAM_SIZE))
      {
        // DATA region: full word write (4B on RV32, 8B on RV64)
        flag = MemWrite(rel, &data, NB_BYTES_IN_WORD);
        if (flag != SUCCESS)
        {
          LogPrintf("Error: write %u bytes @ 0x" WORD_PRINT_FMT " failed, code=" WORD_PRINT_FMT
                    "\n",
                    (unsigned)NB_BYTES_IN_WORD,
                    (uword_t)rel,
                    flag);
          ++nbErrors;
          continue;
        }
      }
      else
      {
        // Out-of-known ranges: you can choose to treat as error or fallback.
        // Here we fallback to DATA region semantics.
        LogPrintf("Error: out-of-range write. Address: " WORD_PRINT_FMT " size: %u\n",
                  (uword_t)rel,
                  (unsigned)NB_BYTES_IN_WORD);
        ++nbErrors;
        continue;
      }
    }
    else
    {
      LogPrintf("Parsing error in line: %s\n", line);
      ++nbErrors;
    }
  }
  std::fclose(f);

  // If no error, release core reset
  if (nbErrors == 0)
  {
#ifdef SIM
    SetCoreResetSignal(1);
#else
    std::FILE* rf = std::fopen("/sys/devices/platform/leds/leds/led1/brightness", "w");
    if (rf == nullptr)
    {
      LogPrintf("Error: unable to open platform reset handle to release reset.\n");
      return FAILURE;
    }
    std::fprintf(rf, "1"); // de-assert reset
    std::fclose(rf);
    std::this_thread::sleep_for(std::chrono::seconds{1});
#endif
  }

  LogPrintf("Done. Errors: %u\n\n", nbErrors);
  return nbErrors ? FAILURE : SUCCESS;
}

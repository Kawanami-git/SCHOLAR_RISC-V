// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       simulation_vs_spike.cpp
\brief      ISA-level simulation against Spike golden trace
\author     Kawanami
\version    1.0
\date       25/10/2025

\details
  This program:
  - parses a Spike log,
  - resets and loads firmware into the DUT,
  - steps the simulation and compares PC, GPR/CSR and memory effects
    against the Spike trace.

  It relies on the TB helpers (InitSim/FinalizeSim, Cycle/Comb, clocks_resets)
  and the memory/loader utilities.

\remarks
  - Uses single-core Spike traces (core field kept for completeness).
  - Assumes the parser produces, for each non-`ebreak` instruction, a valid
    `next` node (the next instruction), so we can check the post-commit PC.

\section simulation_vs_spike_cpp_version_history Version history
| Version | Date       | Author     | Description                                |
|:-------:|:----------:|:-----------|:-------------------------------------------|
| 1.0     | 25/10/2025 | Kawanami   | Initial version.                           |
| 1.1     | xx/xx/xxxx | Author     |                                            |
********************************************************************************
*/

#include <cstdio>
#include <cstdlib>
#include <cstring> // memcmp, strlen
#include <string>

#include "Vriscv_env.h"
#include "args_parser.h"
#include "clocks_resets.h"
#include "defines.h"
#include "load.h"
#include "log.h"
#include "memory.h"
#include "sim.h"
#include "sim_log.h"
#include "simulation.h"
#include "spike_parser.h"

/// Provided by the Verilator harness (DUT instance).
extern Vriscv_env* dut;

/*------------------------------------------------------------------------------
 * Local helpers
 *----------------------------------------------------------------------------*/

/*!
 * \brief Return true if opcode corresponds to a LOAD (0000011) or STORE (0100011).
 *
 * We only need this to allow one extra Cycle() for memory transactions.
 */
static inline bool IsLoadOrStore(uint32_t instr_bin)
{
  const uint32_t opcode = instr_bin & 0x7F;
  return (opcode == 0b0000011) || (opcode == 0b0100011);
}

/*!
 * \brief Read the written data back from DATA RAM image, shifted by address LSBs.
 *
 * The DATA RAM is exposed as word-wide entries (`NB_BYTES_IN_WORD` per entry).
 * We reconstruct the exact byte/half/word/dword as Spike reports it by shifting
 * according to the byte offset (ADDR_OFFSET).
 */
static inline uword_t ReadBackAlignedData(uword_t mem_addr)
{
  const uword_t word_index = (mem_addr & 0xFFFF) / NB_BYTES_IN_WORD;
  const uword_t raw        = dut->DataDpramMem[word_index];
  const uword_t byte_off   = (mem_addr & ADDR_OFFSET) * 8; // shift in bits
  return (raw >> byte_off);
}

/*------------------------------------------------------------------------------
 * Spike-vs-DUT check driver
 *----------------------------------------------------------------------------*/

/*!
 * \brief Execute and check a firmware run against a Spike trace.
 *
 * Steps:
 *  - Parse Spike log
 *  - Reset and program the DUT memories
 *  - Step the DUT and compare PC, GPR/CSR, and memory effects
 *
 * \return SUCCESS on pass, FAILURE otherwise.
 */
static uint32_t run(const std::string& firmwarefile, const std::string& spikefile)
{
  uint32_t flag = SUCCESS;

  // Parse Spike log (ownership returned; FreeSpike when done)
  SpikeLog* spike = ParseSpike(spikefile);
  if (spike == nullptr)
  {
    return FAILURE;
  }

  // Reset RAMs and load firmware into INSTR/DATA
  SetRamResetSignal(1);
  if (LoadFirmware(firmwarefile) != SUCCESS)
  {
    FreeSpike(spike);
    return FAILURE;
  }

  // Fetch first instruction into the IF register (two cycles as your TB expects)
  Instr* instr = spike->instructions;
  Cycle(); // issue fetch
  Cycle(); // IF stage holds the instruction

  // Main check loop until encountering "ebreak" in ASM field
  while (std::memcmp(instr->instr, "ebreak", std::strlen("ebreak")) != 0)
  {
    // Check current fetch PC equals Spike's address for this instruction
    if (dut->GprPcReg != instr->addr)
    {
      flag = FAILURE;
      LogPrintf("Instruction %s error: fetch PC should be 0x" WORD_PRINT_FMT
                " but is 0x" WORD_PRINT_FMT ".\n",
                instr->instr,
                (uword_t)instr->addr,
                (uword_t)dut->GprPcReg);
    }

    // Commit current instruction and fetch the next one
    Cycle();

    // Allow an extra cycle if this is a memory access (load/store)
    if (IsLoadOrStore(instr->instr_bin))
    {
      Cycle();
    }

    // We expect a valid 'next' pointer to check the post-commit PC
    if (instr->next == nullptr)
    {
      flag = FAILURE;
      LogPrintf("Trace error: missing next instruction after %s @ 0x" WORD_PRINT_FMT ".\n",
                instr->instr,
                (uword_t)instr->addr);
      break;
    }

    // Check next PC value against the next Spike address
    if (dut->GprPcReg != instr->next->addr)
    {
      flag = FAILURE;
      LogPrintf("Instruction %s error: next PC should be 0x" WORD_PRINT_FMT
                " but is 0x" WORD_PRINT_FMT ".\n",
                instr->instr,
                (uword_t)instr->next->addr,
                (uword_t)dut->GprPcReg);
    }

    const uint32_t opcode = instr->instr_bin & 0x7F;

    if (opcode == 0b0100011)
    {
      // STORE: verify written memory data (SB/SH/SW/SD)
      const uword_t rb = ReadBackAlignedData(instr->mem_addr);

      const uint32_t funct3 = (instr->instr_bin >> 12) & 0x7;
      if (funct3 == 0b000)
      { // SB
        if ((rb & 0xFFu) != (instr->mem_data & 0xFFu))
        {
          flag = FAILURE;
          LogPrintf("Instruction %s error: SB @ 0x" WORD_PRINT_FMT " expected 0x" WORD_PRINT_FMT
                    " got 0x" WORD_PRINT_FMT ".\n",
                    instr->instr,
                    (uword_t)instr->mem_addr,
                    (uword_t)(instr->mem_data & 0xFFu),
                    (uword_t)(rb & 0xFFu));
        }
      }
      else if (funct3 == 0b001)
      { // SH
        if ((rb & 0xFFFFu) != (instr->mem_data & 0xFFFFu))
        {
          flag = FAILURE;
          LogPrintf("Instruction %s error: SH @ 0x" WORD_PRINT_FMT " expected 0x" WORD_PRINT_FMT
                    " got 0x" WORD_PRINT_FMT ".\n",
                    instr->instr,
                    (uword_t)instr->mem_addr,
                    (uword_t)(instr->mem_data & 0xFFFFu),
                    (uword_t)(rb & 0xFFFFu));
        }
      }
      else if (funct3 == 0b010)
      { // SW
        if ((rb & 0xFFFFFFFFull) != (instr->mem_data & 0xFFFFFFFFull))
        {
          flag = FAILURE;
          LogPrintf("Instruction %s error: SW @ 0x" WORD_PRINT_FMT " expected 0x" WORD_PRINT_FMT
                    " got 0x" WORD_PRINT_FMT ".\n",
                    instr->instr,
                    (uword_t)instr->mem_addr,
                    (uword_t)(instr->mem_data & 0xFFFFFFFFull),
                    (uword_t)(rb & 0xFFFFFFFFull));
        }
      }
      else
      { // SD (or wider on RV64)
        if (rb != instr->mem_data)
        {
          flag = FAILURE;
          LogPrintf("Instruction %s error: SD @ 0x" WORD_PRINT_FMT " expected 0x" WORD_PRINT_FMT
                    " got 0x" WORD_PRINT_FMT ".\n",
                    instr->instr,
                    (uword_t)instr->mem_addr,
                    (uword_t)instr->mem_data,
                    (uword_t)rb);
        }
      }
    }
    else
    {
      // Non-store: register writeback or CSR
      if (opcode == 0b1110011)
      {
        // CSR read (e.g., mcycle). DUT writes mcycle to RD with a known off-by-1 timing.
        if (dut->GprMemory[instr->rd] != (dut->CsrMcycle - 1))
        {
          flag = FAILURE;
          LogPrintf("Instruction %s error: CSR writeback x%02u expected 0x" WORD_PRINT_FMT
                    " got 0x" WORD_PRINT_FMT ".\n",
                    instr->instr,
                    (unsigned)instr->rd,
                    (uword_t)(dut->CsrMcycle - 1),
                    (uword_t)dut->GprMemory[instr->rd]);
        }

        // Force RD to match Spike (one-cycle-per-instruction model)
        dut->GprAddr = instr->rd;
        dut->GprData = instr->rd_data;
        dut->GprEn   = 1;
        Comb();
        dut->GprEn = 0;
      }
      else
      {
        // Regular GPR writeback: compare RD contents to Spike
        if (instr->rd >= 0)
        {
          if (dut->GprMemory[instr->rd] != instr->rd_data)
          {
            flag = FAILURE;
            LogPrintf("Instruction %s error: GPR x%02u expected 0x" WORD_PRINT_FMT
                      " got 0x" WORD_PRINT_FMT ".\n",
                      instr->instr,
                      (unsigned)instr->rd,
                      (uword_t)instr->rd_data,
                      (uword_t)dut->GprMemory[instr->rd]);
          }
        }
      }
    }

    if (flag != SUCCESS)
    {
      break;
    }
    instr = instr->next;
  }

  // Final commit edge before reporting
  Cycle();

  FreeSpike(spike);
  return flag;
}

/*------------------------------------------------------------------------------
 * Program main()
 *----------------------------------------------------------------------------*/

int main(int argc, char** argv, char** /*env*/)
{
  Arguments args;
  args.Parse(argc, argv);

  // Minimal CLI validation
  if (args.GetLogFile().empty() || args.GetFirmwareFile().empty() || args.GetSpikeFile().empty() ||
      args.GetWaveformFile().empty())
  {
    args.PrintUsage(argv[0]);
    return EXIT_FAILURE;
  }

  if (SetLogFile(args.GetLogFile()) != SUCCESS)
  {
    std::fprintf(stderr, "Error: unable to open log file: %s\n", args.GetLogFile().c_str());
    return EXIT_FAILURE;
  }

  // Initialize TB + waves, then run the Spike-vs-DUT checker
  InitSim(args.GetWaveformFile());

  const uint32_t flag = run(args.GetFirmwareFile(), args.GetSpikeFile());

  if (flag != SUCCESS)
  {
    LogPrintf("FAILURE\n");
  }
  else
  {
    LogPrintf("SUCCESS\n");
  }

  FinalizeSim();
  return (flag == SUCCESS) ? EXIT_SUCCESS : EXIT_FAILURE;
}

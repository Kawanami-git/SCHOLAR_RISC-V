// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       simulation_vs_spike.cpp
\brief      ISA-level simulation against Spike golden trace
\author     Kawanami
\version    1.0
\date       19/12/2025

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
| 1.0     | 19/12/2025 | Kawanami   | Initial version.                           |
| 1.1     | xx/xx/xxxx | Author     |                                            |
********************************************************************************
*/

#include <cstdio>
#include <cstdlib>
#include <cstring> // memcmp, strlen
#include <iostream>
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
 * \brief Return true if opcode corresponds to a LOAD (0000011).
 */
static inline bool IsLoad(uint32_t instr_bin)
{
  const uint32_t opcode = instr_bin & 0x7F;
  return (opcode == 0b0000011);
}

/*!
 * \brief Return true if opcode corresponds to a STORE (0100011).
 */
static inline bool IsStore(uint32_t instr_bin)
{
  const uint32_t opcode = instr_bin & 0x7F;
  return (opcode == 0b0100011);
}

/*!
 * \brief Return true if opcode corresponds to a CSR (1110011).
 */
static inline bool IsCSR(uint32_t instr_bin)
{
  const uint32_t opcode = instr_bin & 0x7F;
  return (opcode == 0b1110011);
}

/*!
 * \brief Return true if opcode corresponds to a Branch (1100011).
 */
static inline bool IsBranch(uint32_t instr_bin)
{
  const uint32_t opcode = instr_bin & 0x7F;
  return (opcode == 0b1100011);
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

static inline uword_t verify_mem(Instr* instr)
{
  const uword_t rb = ReadBackAlignedData(instr->mem_addr);

  const uint32_t funct3 = (instr->instr_bin >> 12) & 0x7;
  if (funct3 == 0b000)
  { // SB
    if ((rb & 0xFFu) != (instr->mem_data & 0xFFu))
    {
      LogPrintf("Instruction %s (pc: 0x%x) error: SB @ 0x" WORD_PRINT_FMT
                " expected 0x" WORD_PRINT_FMT " got 0x" WORD_PRINT_FMT ".\n",
                instr->instr,
                instr->addr,
                (uword_t)instr->mem_addr,
                (uword_t)(instr->mem_data & 0xFFu),
                (uword_t)(rb & 0xFFu));
      return FAILURE;
    }
  }
  else if (funct3 == 0b001)
  { // SH
    if ((rb & 0xFFFFu) != (instr->mem_data & 0xFFFFu))
    {
      LogPrintf("Instruction %s (pc: 0x%x) error: SH @ 0x" WORD_PRINT_FMT
                " expected 0x" WORD_PRINT_FMT " got 0x" WORD_PRINT_FMT ".\n",
                instr->instr,
                instr->addr,
                (uword_t)instr->mem_addr,
                (uword_t)(instr->mem_data & 0xFFFFu),
                (uword_t)(rb & 0xFFFFu));
      return FAILURE;
    }
  }
  else if (funct3 == 0b010)
  { // SW
    if ((rb & 0xFFFFFFFFull) != (instr->mem_data & 0xFFFFFFFFull))
    {
      LogPrintf("Instruction %s (pc: 0x%x) error: SW @ 0x" WORD_PRINT_FMT
                " expected 0x" WORD_PRINT_FMT " got 0x" WORD_PRINT_FMT ".\n",
                instr->instr,
                instr->addr,
                (uword_t)instr->mem_addr,
                (uword_t)(instr->mem_data & 0xFFFFFFFFull),
                (uword_t)(rb & 0xFFFFFFFFull));
      return FAILURE;
    }
  }
  else
  { // SD (or wider on RV64)
    if (rb != instr->mem_data)
    {
      LogPrintf("Instruction %s (pc: 0x%x) error: SD @ 0x" WORD_PRINT_FMT
                " expected 0x" WORD_PRINT_FMT " got 0x" WORD_PRINT_FMT ".\n",
                instr->instr,
                instr->addr,
                (uword_t)instr->mem_addr,
                (uword_t)instr->mem_data,
                (uword_t)rb);
      return FAILURE;
    }
  }

  return SUCCESS;
}

static inline uword_t verify_gpr(Instr* instr)
{
  // Non-store: register writeback or CSR
  if (IsCSR(instr->instr_bin))
  {
    if((instr->instr_bin >> 20) == 0xb00) // mhpmcounter0
    {
      if (dut->GprMemory[instr->rd] != (dut->mhpmcounter0_q - 4)) // exe/stage/wb/effective write
      {
        LogPrintf("Instruction %s (pc: 0x%x) error: CSR writeback x%02u expected 0x" WORD_PRINT_FMT
                  " got 0x" WORD_PRINT_FMT ".\n",
                  instr->instr,
                  instr->addr,
                  (unsigned)instr->rd,
                  (uword_t)(dut->mhpmcounter0_q - 4),
                  (uword_t)dut->GprMemory[instr->rd]);
        return FAILURE;
      }

      // Force RD to match Spike (one-cycle-per-instruction model)
      dut->GprAddr = instr->rd;
      dut->GprData = instr->rd_data;
      dut->GprEn   = 1;
      Comb();
      dut->GprEn = 0;
      return SUCCESS;
    }
    else if((instr->instr_bin >> 20) == 0xb03) // mhpmcounter4
    {
      if (dut->GprMemory[instr->rd] != dut->mhpmcounter3_q - 2) // final li + sw add two stalled cycles
      {
        LogPrintf("Instruction %s (pc: 0x%x) error: CSR writeback x%02u expected 0x" WORD_PRINT_FMT
                  " got 0x" WORD_PRINT_FMT ".\n",
                  instr->instr,
                  instr->addr,
                  (unsigned)instr->rd,
                  (uword_t)(dut->mhpmcounter3_q - 2),
                  (uword_t)dut->GprMemory[instr->rd]);
        return FAILURE;
      }
    }
    else if((instr->instr_bin >> 20) == 0xb04) // mhpmcounter4
    {
      if (dut->GprMemory[instr->rd] != dut->mhpmcounter4_q)
      {
        LogPrintf("Instruction %s (pc: 0x%x) error: CSR writeback x%02u expected 0x" WORD_PRINT_FMT
                  " got 0x" WORD_PRINT_FMT ".\n",
                  instr->instr,
                  instr->addr,
                  (unsigned)instr->rd,
                  (uword_t)(dut->mhpmcounter3_q),
                  (uword_t)dut->GprMemory[instr->rd]);
        return FAILURE;
      }
    }
    else
    {
      LogPrintf("Instruction %s (pc: 0x%x) error: Unsupported CSR operation.\n",
                instr->instr,
                instr->addr);
      return FAILURE;
    }
  }
  else
  {
    // Regular GPR writeback: compare RD contents to Spike
    if (instr->rd >= 0)
    {
      if (dut->GprMemory[instr->rd] != instr->rd_data)
      {
        LogPrintf("Instruction %s error: GPR x%02u expected 0x" WORD_PRINT_FMT
                  " got 0x" WORD_PRINT_FMT ".\n",
                  instr->instr,
                  (unsigned)instr->rd,
                  (uword_t)instr->rd_data,
                  (uword_t)dut->GprMemory[instr->rd]);
        return FAILURE;
      }
    }
  }

  return SUCCESS;
}

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
  while (std::memcmp(instr->instr, "ebreak", std::strlen("ebreak")) != 0)
  {
    if (dut->wb_valid)
    {
      Cycle();

      if (IsStore(instr->instr_bin))
      {
        flag = verify_mem(instr);
        if (flag != SUCCESS)
        {
          break;
        }
      }
      else
      {
        flag = verify_gpr(instr);
        if (flag != SUCCESS)
        {
          break;
        }
      }

      instr = instr->next;
    }
    else
    {
      Cycle();
    }
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

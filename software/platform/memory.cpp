// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       memory.cpp
\brief      Thin, safe helpers on top of the AXI4 backend (impl)
\author     Kawanami
\date       24/10/2025
\version    1.0

\details
  See \ref memory.h. This layer:
  - Enforces alignment (AXI can only access word-aligned words),
  - Delegates to \ref InstrAxi4Write / \ref Axi4Write / \ref Axi4Read,
  - Implements a tiny PTC/CTP mailbox with consistent local counters.

\remarks
  - All addresses are \b window-relative for the AXI backend.
  - The shared-memory helpers rely on the address constants from \ref defines.h.

\section memory_cpp_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 24/10/2025 | Kawanami   | Initial version.                          |
| 1.1     | xx/xx/xxxx | Author     |                                           |
********************************************************************************
*/

#include "memory.h"

#include <cstdio>
#include <cstdlib>

#include "axi4.h"

/*------------------------------------------------------------------------------
 * Small helpers
 *----------------------------------------------------------------------------*/

static inline bool IsAligned(const uintptr_t addr, const uword_t size, const uword_t granule)
{
  return ((addr % granule) == 0u) && ((size % granule) == 0u);
}

/*------------------------------------------------------------------------------
 * Basic memory I/O
 *----------------------------------------------------------------------------*/

uword_t InstrMemWrite(const uintptr_t addr, const uint32_t* data, const uword_t size)
{
  uword_t alignedSize;
  alignedSize = (size + 3) & ~3;

  return InstrAxi4Write(addr, data, alignedSize);
}

uword_t MemWrite(const uintptr_t addr, const uword_t* data, const uword_t size)
{
  uword_t alignedSize;
  alignedSize = (size + (NB_BYTES_IN_WORD - 1)) & ~(NB_BYTES_IN_WORD - 1);
  return Axi4Write(addr, data, alignedSize);
}

uword_t MemRead(const uintptr_t addr, uword_t* data, const uword_t size)
{
  uword_t alignedSize;
  alignedSize = (size + (NB_BYTES_IN_WORD - 1)) & ~(NB_BYTES_IN_WORD - 1);

  return Axi4Read(addr, data, alignedSize);
}

uword_t InstrMemReset(const uintptr_t addr, const uword_t size, const uint32_t value)
{
  uword_t flag = SUCCESS;
  for (int i = 0; i < size; i += 4)
  {
    if ((flag = InstrAxi4Write(addr + i, &value, 4)) != SUCCESS)
    {
      return flag;
    }
  }
  return SUCCESS;
}

uword_t MemReset(const uintptr_t addr, const uword_t size, const uword_t value)
{
  uword_t flag = SUCCESS;
  for (int i = 0; i < size; i += NB_BYTES_IN_WORD)
  {
    if ((flag = Axi4Write(addr + i, &value, NB_BYTES_IN_WORD)) != SUCCESS)
    {
      return flag;
    }
  }
  return SUCCESS;
}

/*------------------------------------------------------------------------------
 * Shared-memory mailbox (PTC / CTP)
 *
 * Protocol summary (as used by the platform side here):
 * - CTP (Core→Platform) contains PLATFORM_COUNT and CORE_COUNT + DATA_SIZE/DATA.
 *   * SharedWriteReady() consults CTP PLATFORM_COUNT to decide if the platform
 *     may publish a new message (token-based).
 *   * SharedReadReady() checks CTP CORE_COUNT to detect a new message and, if
 *     present, returns DATA_SIZE.
 * - PTC (Platform→Core) contains PLATFORM_COUNT and CORE_COUNT mirrored for acks.
 *   * SharedReadAck() increments PTC CORE_COUNT once the platform consumed a msg.
 *   * SharedWriteAck() increments PTC PLATFORM_COUNT after writing a msg.
 *----------------------------------------------------------------------------*/

uword_t SharedWriteReady()
{
  static uword_t icount = 0;
  uword_t        count  = 0;

  MemRead(SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR, &count, NB_BYTES_IN_WORD);

  if (icount == count)
  {
    icount++;
    return 1;
  }

  return 0;
}

uword_t SharedReadReady()
{
  static uword_t icount = 0;
  uword_t        count  = 0;

  MemRead(SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR, &count, NB_BYTES_IN_WORD);

  if (count > icount)
  {
    icount++;
    MemRead(SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR, &count, NB_BYTES_IN_WORD);
    return count;
  }
  else
  {
    return 0;
  }
}

uword_t SharedReadAck()
{
  static uword_t icount = 0;
  icount++;
  return MemWrite(SOFTCORE_0_PTC_RAM_CORE_COUNT_ADDR, &icount, NB_BYTES_IN_WORD);
}

uword_t SharedWriteAck()
{
  static uword_t icount = 0;
  icount++;
  return MemWrite(SOFTCORE_0_PTC_RAM_PLATFORM_COUNT_ADDR, &icount, NB_BYTES_IN_WORD);
}

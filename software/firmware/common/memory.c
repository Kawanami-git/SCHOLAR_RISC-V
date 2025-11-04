// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       memory.c
\brief      Low-level memory & shared-RAM helpers (bare-metal).
\author     Kawanami
\version    1.0
\date       25/10/2025

\details

\section memory_c_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 25/10/2025 | Kawanami   | Initial version.                          |
| 1.1     | xx/xx/xxxx | Author     |                                           |
********************************************************************************
*/

#include "memory.h"

#include "defines.h"

/* Internal alignment helpers (compile-time friendly where possible). */
static inline int IsAlignedUintptr(uintptr_t v, uword_t g) { return ((v % g) == 0u); }
static inline int IsAlignedSize(uword_t v, uword_t g) { return ((v % g) == 0u); }

/*------------------------------------------------------------------------------
 * Raw memory access
 *----------------------------------------------------------------------------*/

void MemWrite(uintptr_t addr, const uword_t* data, uword_t size)
{
  /* Word granularity contract. */
  if (!IsAlignedUintptr(addr, NB_BYTES_IN_WORD) || !IsAlignedSize(size, NB_BYTES_IN_WORD))
  {
    return; /* silently ignore in bare-metal; caller must pass aligned args */
  }

  volatile uword_t* p     = (volatile uword_t*)addr;
  const size_t      beats = (size_t)(size / NB_BYTES_IN_WORD);

  for (size_t i = 0; i < beats; ++i)
  {
    p[i] = data[i];
  }
}

void MemRead(uintptr_t addr, uword_t* data, uword_t size)
{
  if (!IsAlignedUintptr(addr, NB_BYTES_IN_WORD) || !IsAlignedSize(size, NB_BYTES_IN_WORD))
  {
    return;
  }

  volatile const uword_t* p     = (volatile const uword_t*)addr;
  const size_t            beats = (size_t)(size / NB_BYTES_IN_WORD);

  for (size_t i = 0; i < beats; ++i)
  {
    data[i] = p[i];
  }
}

void MemReset(uword_t addr, uword_t size, word_t value)
{
  if (!IsAlignedUintptr(addr, NB_BYTES_IN_WORD) || !IsAlignedSize(size, NB_BYTES_IN_WORD))
  {
    return;
  }

  volatile uword_t* p     = (volatile uword_t*)addr;
  const size_t      beats = (size_t)(size / NB_BYTES_IN_WORD);

  for (size_t i = 0; i < beats; ++i)
  {
    p[i] = (uword_t)value;
  }
}

uword_t SharedWriteReady(void)
{
  volatile const uword_t* ctp_core_cnt =
      (volatile const uword_t*)SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR;
  volatile const uword_t* ptc_core_cnt =
      (volatile const uword_t*)SOFTCORE_0_PTC_RAM_CORE_COUNT_ADDR;
  return (*ctp_core_cnt == *ptc_core_cnt) ? 1u : 0u;
}

uword_t SharedReadReady(void)
{
  volatile const uword_t* ctp_plat_cnt =
      (volatile const uword_t*)SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR;
  volatile const uword_t* ptc_plat_cnt =
      (volatile const uword_t*)SOFTCORE_0_PTC_RAM_PLATFORM_COUNT_ADDR;

  if (*ptc_plat_cnt > *ctp_plat_cnt)
  {
    volatile const uword_t* sizep = (volatile const uword_t*)SOFTCORE_0_PTC_RAM_DATA_SIZE_ADDR;
    return *sizep;
  }
  return 0u;
}

void SharedReadAck(void)
{
  volatile uword_t* ctp_plat_cnt = (volatile uword_t*)SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR;
  *ctp_plat_cnt                  = *ctp_plat_cnt + 1u;
}

void SharedWriteAck(void)
{
  volatile uword_t* ctp_core_cnt = (volatile uword_t*)SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR;
  *ctp_core_cnt                  = *ctp_core_cnt + 1u;
}

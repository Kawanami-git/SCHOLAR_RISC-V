// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       csr.h
\brief      Low-level CSRs access helpers for bare-metal firmware.

\author     Kawanami
\version    1.0
\date       29/12/2025

\details
  Minimal primitives to core CSRs.
  Only mhpmcounter0 (mcycle), mhpmcounter3 (stall counter) and
  mhpmcounter4 (taken branches counter) are implemented.

\remarks
  - ToDo: Implements all CSRs access.

\section firmware_csr_h_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 29/12/2025 | Kawanami   | Initial version.                          |
********************************************************************************
*/
#include <stdint.h>

/*!
 * \brief Read mhpmcounter0 (mcycle) csr.
 *
 * \return The mcycle register value.
 */
static inline uint32_t read_mhpmcounter0(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB00" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter3 (stall) csr.
 *
 * \return The number of cycle the core has been stalled.
 */
static inline uint32_t read_mhpmcounter3(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB03" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter3 (taken branches) csr.
 *
 * \return The number of taken branches.
 */
static inline uint32_t read_mhpmcounter4(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB04" : "=r"(v));
  return v;
}

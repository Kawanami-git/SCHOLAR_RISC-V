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
 * \brief Read mhpmcounter4 (taken branches) csr.
 *
 * \return The number of taken branches.
 */
static inline uint32_t read_mhpmcounter4(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB04" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter5 (Exe -> Decode bypass - op1/op2) csr.
 *
 * \return The number of used of the Exe -> Decode bypass for op1/op2.
 */
static inline uint32_t read_mhpmcounter5(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB05" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter6 (Exe -> Decode bypass - op3) csr.
 *
 * \return The number of used of the Exe -> Decode bypass for op3.
 */
static inline uint32_t read_mhpmcounter6(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB06" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter7 (Mem -> Decode bypass - op1/op2) csr.
 *
 * \return The number of used of the Mem -> Decode bypass for op1/op2.
 */
static inline uint32_t read_mhpmcounter7(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB07" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter8 (Mem -> Decode bypass - op3) csr.
 *
 * \return The number of used of the Mem -> Decode bypass for op3.
 */
static inline uint32_t read_mhpmcounter8(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB08" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter9 (Writeback -> Decode bypass - op1/op2) csr.
 *
 * \return The number of used of the Writeback -> Decode bypass for op1/op2.
 */
static inline uint32_t read_mhpmcounter9(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB09" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter10 (Writeback -> Decode bypass - op3) csr.
 *
 * \return The number of used of the Writeback -> Decode bypass for op3.
 */
static inline uint32_t read_mhpmcounter10(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB0a" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter11 (Writeback -> Exe bypass - op1/op2) csr.
 *
 * \return The number of used of the Writeback -> Exe bypass for op1/op2.
 */
static inline uint32_t read_mhpmcounter11(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB0b" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter12 (Writeback -> Exe bypass - op3) csr.
 *
 * \return The number of used of the Writeback -> Exe bypass for op3.
 */
static inline uint32_t read_mhpmcounter12(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB0c" : "=r"(v));
  return v;
}

/*!
 * \brief Read mhpmcounter13 (Writeback -> Mem bypass - op3) csr.
 *
 * \return The number of used of the Writeback -> Mem bypass for op3.
 */
static inline uint32_t read_mhpmcounter13(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, 0xB0d" : "=r"(v));
  return v;
}

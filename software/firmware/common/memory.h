// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       memory.h
\brief      Low-level memory & shared-RAM helpers for bare-metal firmware.

\author     Kawanami
\version    1.1
\date       25/10/2025

\details
  Minimal primitives to read/write memory-mapped regions and to synchronize
  with the platform via the two shared RAMs:

    - PTC (Platform → Core): the platform publishes messages for the core.
      * Platform increments PTC_PLATFORM_COUNT after writing a message.
      * Core reads the message size at PTC_DATA_SIZE, then data at PTC_DATA.
      * Core acknowledges by incrementing PTC_CORE_COUNT.

    - CTP (Core → Platform): the core publishes messages for the platform.
      * Core increments CTP_CORE_COUNT after writing a message.
      * Platform reads size/data, then acknowledges by incrementing
        CTP_PLATFORM_COUNT.
      * Core is allowed to send a new message when CTP_PLATFORM_COUNT == CTP_CORE_COUNT.

\remarks
  - All addresses and sizes are assumed word-aligned (NB_BYTES_IN_WORD).
  - Use volatile when touching MMIO/shared RAM to avoid compiler reordering.

\section firmware_memory_h_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/06/2025 | Kawanami   | Initial version.                          |
| 1.1     | 25/10/2025 | Kawanami   | Add RV64I support.<br>Update the whole file for coding style
compliance.<br>Update the whole file comments for doxygen support. |
********************************************************************************
*/

#ifndef MEMORY_H
#define MEMORY_H

#include <stddef.h>
#include <stdint.h>

#include "defines.h"

/*!
 * \brief Write a byte-size region (word-granular) to memory.
 *
 * \param addr  Byte address to start writing (must be word-aligned).
 * \param data  Pointer to the source words.
 * \param size  Number of bytes to write (multiple of NB_BYTES_IN_WORD).
 */
void MemWrite(uintptr_t addr, const uword_t* data, uword_t size);

/*!
 * \brief Read a byte-size region (word-granular) from memory.
 *
 * \param addr  Byte address to start reading (must be word-aligned).
 * \param data  Pointer to the destination words.
 * \param size  Number of bytes to read (multiple of NB_BYTES_IN_WORD).
 */
void MemRead(uintptr_t addr, uword_t* data, uword_t size);

/*!
 * \brief Fill a region with a constant word value.
 *
 * \param addr   Byte address to start (must be word-aligned).
 * \param size   Number of bytes to write (multiple of NB_BYTES_IN_WORD).
 * \param value  Word value to write.
 */
void MemReset(uword_t addr, uword_t size, word_t value);

/*!
 * \brief True if the CTP buffer is free to accept a new message from the core.
 *
 * Condition: CTP_PLATFORM_COUNT == CTP_CORE_COUNT.
 *
 * \return 1 if ready to publish, 0 otherwise.
 */
uword_t SharedWriteReady(void);

/*!
 * \brief Check if a new PTC message is available for the core.
 *
 * Condition: PTC_PLATFORM_COUNT > PTC_CORE_COUNT.
 * If available, the function returns the message size in bytes (from PTC_DATA_SIZE),
 * otherwise returns 0.
 */
uword_t SharedReadReady(void);

/*!
 * \brief Core acknowledges it consumed the current PTC message.
 *
 * Action: increment PTC_CORE_COUNT.
 */
void SharedReadAck(void);

/*!
 * \brief Core acknowledges it published a new CTP message.
 *
 * Action: increment CTP_CORE_COUNT.
 */
void SharedWriteAck(void);

/*!
 * \brief Embedded printf: format into the CTP shared buffer and notify platform.
 *
 * Supported specifiers: %s, %d, %u, %lu, %x
 *
 * \return Number of characters written.
 */
uword_t Eprintf(const char* fmt, ...);

#endif

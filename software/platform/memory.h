
// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       memory.h
\brief      Thin, safe helpers on top of the AXI4 backend (reads/writes, mailbox)
\author     Kawanami
\date       24/10/2025
\version    1.1

\details
  Convenience functions layered atop axi4.h:
  - Word-aligned DATA reads/writes,
  - 32-bit INSTR writes,
  - Simple shared-memory mailbox (PTC/CTP counters + size handshakes).

  Notes:
  - All \b addresses are interpreted as \b relative to the AXI window mapped
    by the backend (\ref SetupAxi4 / \ref SetupInstrAxi4). If you hold absolute
    addresses, convert to the proper window-relative offset beforehand (or use
    a higher wrapper that does it for you).

\remarks
  - TODO: .

\section memory_h_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 02/06/2025 | Kawanami   | Initial version.                          |
| 1.1     | 24/10/2025 | Kawanami   | Add RV64I support.<br>Update the whole file for coding style
compliance.<br>Update the whole file comments for doxygen support. |
********************************************************************************
*/

#ifndef MEMORY_H
#define MEMORY_H

#include <cstdint>

#include "defines.h"

/*!
 * \brief Write 32-bit instruction words via the INSTR window.
 *
 * \param[in] addr  Window-relative byte address (must be 4B aligned).
 * \param[in] data  Source buffer of 32-bit words (non-null if \p size > 0).
 * \param[in] size  Number of bytes to write (multiple of 4).
 *
 * \retval SUCCESS            OK
 * \retval ADDR_NOT_ALIGNED   \p addr or \p size is not 4B aligned
 * \retval FAILURE            Backend error
 */
uword_t InstrMemWrite(const uintptr_t addr, const uint32_t* data, const uword_t size);

/*!
 * \brief Word-wide write on the DATA window.
 *
 * \param[in] addr  Window-relative byte address (aligned to NB_BYTES_IN_WORD).
 * \param[in] data  Source buffer (non-null if \p size > 0).
 * \param[in] size  Number of bytes (multiple of NB_BYTES_IN_WORD).
 *
 * \retval SUCCESS            OK
 * \retval ADDR_NOT_ALIGNED   \p addr or \p size misaligned
 * \retval FAILURE            Backend error
 */
uword_t MemWrite(const uintptr_t addr, const uword_t* data, const uword_t size);

/*!
 * \brief Word-wide read on the DATA window.
 *
 * \param[in]  addr  Window-relative byte address (aligned to NB_BYTES_IN_WORD).
 * \param[out] data  Destination buffer (non-null if \p size > 0).
 * \param[in]  size  Number of bytes (multiple of NB_BYTES_IN_WORD).
 *
 * \retval SUCCESS            OK
 * \retval ADDR_NOT_ALIGNED   \p addr or \p size misaligned
 * \retval FAILURE            Backend error
 */
uword_t MemRead(const uintptr_t addr, uword_t* data, const uword_t size);

/*!
 * \brief Fill a region of the INSTR window with the same 32-bit value.
 *
 * \param[in] addr   Window-relative start address (4B aligned).
 * \param[in] size   Number of bytes (multiple of 4).
 * \param[in] value  32-bit pattern.
 *
 * \retval See InstrMemWrite
 */
uword_t InstrMemReset(const uintptr_t addr, const uword_t size, const uint32_t value);

/*!
 * \brief Fill a region of the DATA window with the same word value.
 *
 * \param[in] addr   Window-relative start address (aligned to NB_BYTES_IN_WORD).
 * \param[in] size   Number of bytes (multiple of NB_BYTES_IN_WORD).
 * \param[in] value  Word pattern.
 *
 * \retval See MemWrite
 */
uword_t MemReset(const uintptr_t addr, const uword_t size, const uword_t value);

/*-------------------------- Mailbox (PTC/CTP) -------------------------------*/
/*!
 * \brief Check whether the platform is allowed to write a new message.
 *
 * Reads the platform counter in CTP and compares it with the locally tracked
 * platform sequence. If equal, the slot is considered free; we consume the
 * token and return 1.
 *
 * \retval 1  Ready (token consumed; next write may proceed)
 * \retval 0  Not ready
 */
uword_t SharedWriteReady();

/*!
 * \brief Check whether a new message from the core is available to read.
 *
 * Compares the core counter in CTP with our local core-seen counter. If newer,
 * latches the new size from CTP and returns it (>0). Otherwise returns 0.
 *
 * \return 0 if nothing new, or the payload size in bytes if a message is ready.
 */
uword_t SharedReadReady();

/*!
 * \brief Acknowledge that the platform has read the current message (PTC side).
 *
 * Increments the platform→core CORE counter in PTC.
 *
 * \retval See MemWrite
 */
uword_t SharedReadAck();

/*!
 * \brief Acknowledge that the platform has completed writing (PTC side).
 *
 * Increments the platform→core PLATFORM counter in PTC.
 *
 * \retval See MemWrite
 */
uword_t SharedWriteAck();

#endif

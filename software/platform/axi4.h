// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       axi4.h
\brief      AXI4 memory access interface for the SCHOLAR RISC-V test environment.
\author     Kawanami
\version    1.0
\date       19/12/2025

\details
  Read and write helpers for the AXI4 memory-mapped bus.

  The API is portable across:
  - Simulation (C++): direct memory pokes/peeks.
  - PolarFire Linux target (C): /dev/mem-style mapping via setup/finalize.

  Only basic single-beat transactions are intended; bursts are not implemented.

\remarks
  - TODO: .

\section axi4_h_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami   | Initial version.                          |
********************************************************************************
*/

#ifndef AXI4_H
#define AXI4_H

#include <cstdint>

#include "defines.h"

/*!
 * \brief Prepare the AXI mapping/window for instruction RAM writes (platform).
 *
 * Sets up the AXI window used to load instruction memory from the host.
 * Should be called before \ref InstrAxi4Write on the PolarFire Linux target.
 * In simulation, the implementation may be a no-op.
 *
 * \param[in] start_addr  Absolute AXI base address of the instruction RAM window.
 * \param[in] size        Window size in bytes.
 *
 * \retval SUCCESS            Mapping created successfully.
 * \retval ADDR_NOT_ALIGNED   \p start_addr or \p size is not aligned to 4 bytes.
 * \retval FAILURE            Mapping failed (/dev/mem open or mmap error).
 */
uword_t SetupInstrAxi4(const uint32_t start_addr, const uint32_t size);

/*!
 * \brief Tear down the instruction RAM AXI window previously created.
 *
 * Releases resources created by SetupInstrAxi4.
 * No-op in simulation.
 */
void FinalizeInstrAxi4();

/*!
 * \brief Map a generic AXI space into the process address space (platform).
 *
 * Must be called before any \ref Axi4Write / \ref Axi4Read on PolarFire Linux.
 * Not required in simulation (implementation may be a no-op).
 *
 * \param[in] start_addr  Absolute AXI base address of the target window.
 * \param[in] size        Window size in bytes.
 *
 * \retval SUCCESS            Mapping created successfully.
 * \retval ADDR_NOT_ALIGNED   \p start_addr or \p size is not aligned to NB_BYTES_IN_WORD.
 * \retval FAILURE            Mapping failed (/dev/mem open or mmap error).
 */
uword_t SetupAxi4(const uword_t start_addr, const uword_t size);

/*!
 * \brief Unmap AXI space previously mapped by SetupAxi4 (platform).
 *
 * Call once you are done with AXI transactions. No-op in simulation.
 */
void FinalizeAxi4();

/*!
 * \brief Write instruction words via the instruction AXI window.
 *
 * This helper specifically targets the instruction memory writer path.
 * On the platform target, \ref SetupInstrAxi4 must have been called first.
 *
 * \param[in] addr   Start byte address (AXI space relative to the instr window).
 * \param[in] data   Pointer to 32-bit words to write (source buffer). Must be non-null if \p size >
 * 0. \param[in] size   Number of bytes to write (must be a multiple of 4).
 *
 * \retval SUCCESS            Transfer completed.
 * \retval ADDR_NOT_ALIGNED   \p addr or \p size not 4-byte aligned.
 * \retval INVALID_ADDR       Instruction window not mapped on platform target.
 * \retval FAILURE            Invalid data pointer or size.
 */
uword_t InstrAxi4Write(const uintptr_t addr, const uint32_t* data, const uword_t size);

/*!
 * \brief Generic AXI4 write (single-beat style).
 *
 * Performs word-aligned writes to the AXI-mapped memory region. On the platform
 * target, ensure \ref SetupAxi4 was called beforehand. In simulation, the backend
 * drives the DUT AXI directly.
 *
 * \param[in] addr   Start byte address (AXI space relative to the mapped window).
 * \param[in] data   Pointer to words to write (source buffer). Must be non-null if \p size > 0.
 * \param[in] size   Number of bytes to write (must be a multiple of NB_BYTES_IN_WORD).
 *
 * \retval SUCCESS            Transfer completed.
 * \retval ADDR_NOT_ALIGNED   \p addr or \p size not aligned to NB_BYTES_IN_WORD.
 * \retval INVALID_ADDR       AXI window not mapped on platform target.
 * \retval FAILURE            Invalid data pointer or size.
 */
uword_t Axi4Write(const uintptr_t addr, const uword_t* data, const uword_t size);

/*!
 * \brief Generic AXI4 read (single-beat style).
 *
 * Reads word-aligned data from the AXI-mapped memory region. On the platform
 * target, ensure \ref SetupAxi4 was called beforehand. In simulation, the backend
 * drives the DUT AXI directly.
 *
 * \param[in]  addr   Start byte address (AXI space relative to the mapped window).
 * \param[in]  size   Number of bytes to read (must be a multiple of NB_BYTES_IN_WORD).
 * \param[out] data   Destination buffer for read words. Must be non-null if \p size > 0.
 *
 * \retval SUCCESS            Transfer completed (buffer filled).
 * \retval ADDR_NOT_ALIGNED   \p addr or \p size not aligned to NB_BYTES_IN_WORD.
 * \retval INVALID_ADDR       AXI window not mapped on platform target.
 * \retval FAILURE            Backend-specific failure.
 */
uword_t Axi4Read(const uintptr_t addr, uword_t* data, const uword_t size);

#endif

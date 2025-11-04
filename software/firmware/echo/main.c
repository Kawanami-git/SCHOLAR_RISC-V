// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       main.c
\brief      Echo firmware: mirrors PTC messages back to CTP shared memory.
\author     Kawanami
\version    1.0
\date       25/10/2025

\details
  Bare-metal loop that:
    1) waits for a message in Platform→Core (PTC) shared RAM,
    2) reads it, acknowledges the read,
    3) writes the same payload into Core→Platform (CTP) shared RAM,
    4) sets the size and acknowledges the write.

  The transfer is performed in word-aligned chunks. A small on-chip buffer
  is used to stage the copy; larger messages are handled in multiple chunks.

\section echo_main_c_version_history Version history
| Version | Date       | Author     | Description      |
|:-------:|:----------:|:-----------|:-----------------|
| 1.0     | 25/10/2025 | Kawanami   | Initial version. |
********************************************************************************
*/

#include "defines.h"
#include "memory.h"

int main(void)
{
  // Small staging buffer; large messages are processed in chunks.
  uword_t buf[128];

  // Clear the CTP region to a known state before starting.
  MemReset(SOFTCORE_0_CTP_RAM_START_ADDR, SOFTCORE_0_CTP_RAM_SIZE, 0);

  while (1)
  {
    // --- Wait for a message from the platform (PTC side) ---
    uword_t size = 0;
    while ((size = SharedReadReady()) == 0)
    {
      // Tiny busy-wait to keep the core occupied but simple.
      for (int i = 0; i < 16; ++i)
      { /* nop */
      }
    }

    // Process the incoming payload in chunks that fit our local buffer.
    const uword_t maxChunkBytes = (uword_t)sizeof(buf);
    uword_t       remaining     = size;

    while (remaining > 0)
    {
      // Compute the current chunk size (word-aligned).
      uword_t chunk        = remaining > maxChunkBytes ? maxChunkBytes : remaining;
      uword_t alignedChunk = (chunk + (NB_BYTES_IN_WORD - 1)) & ~(NB_BYTES_IN_WORD - 1);

      // --- Read from PTC data window, then ack the read ---
      MemRead(SOFTCORE_0_PTC_RAM_DATA_ADDR, buf, alignedChunk);
      SharedReadAck();

      // --- Write into CTP window and publish the size, then ack the write ---
      MemWrite(SOFTCORE_0_CTP_RAM_DATA_ADDR, buf, alignedChunk);
      MemWrite(SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR, &alignedChunk, NB_BYTES_IN_WORD);
      SharedWriteAck();

      // If the message is larger than our buffer, advance source pointer
      // by updating the PTC/CTP data base addresses for the next slice.
      // Here the windows are fixed; the platform will re-post remaining bytes.
      remaining -= chunk;
    }
  }

  // Unreachable; start.s loops after return anyway.
  return 0;
}

// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       axi4.cpp
\brief      AXI4 access backend (simulation & PolarFire Linux target)

\author     Kawanami
\version    1.0
\date       24/10/2025

\details
  Implementation of the AXI4 memory helper API declared in \ref axi4.h.

  Two backends are provided via conditional compilation:
  - SIM (Verilator simulation): cycles accurate handshakes on the DUT AXI pins.
  - Platform (PolarFire Linux target): /dev/mem mapping and plain loads/stores.

  Only single-beat style transactions are modeled. Bursts are not implemented.

\remarks
  - In simulation, the API performs explicit AW/W/B and AR/R handshakes and
    advances time using cycle().
  - On hardware, the mapped addresses are accessed through volatile pointers to
    prevent the compiler from optimizing MMIO accesses.

\section axi4_cpp_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 24/10/2025 | Kawanami   | Initial version.                          |
| 1.1     | xx/xx/xxxx | Author     |                                           |
********************************************************************************
*/

#include "axi4.h"

#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <inttypes.h>
#include <unistd.h>

/*------------------------------------------------------------------------------
 * Small helpers
 *----------------------------------------------------------------------------*/

/*!
 * \brief Quick alignment check for both address and size.
 * \param addr    Base address (byte address).
 * \param size    Transfer size in bytes.
 * \param granule Alignment granularity (bytes).
 * \return true if both \p addr and \p size are multiples of \p granule.
 */
static inline bool IsAligned(uintptr_t addr, uword_t size, uword_t granule)
{
  return ((addr % granule) == 0u) && ((size % granule) == 0u);
}

#ifdef SIM

/*==============================================================================
 *                          SIMULATION (Verilator)
 *============================================================================*/

#include "Vriscv_env.h"
#include "sim.h"

/// Provided by the simulation harness.
extern Vriscv_env* dut;

/*!
 * \brief Instruction write through the INSTR AXI slave of the DUT.
 *
 * Drives AW → W → B for a sequence of single-beat writes (no bursts). Each
 * transfer advances the simulation clock using \ref cycle().
 */
uword_t InstrAxi4Write(const uintptr_t addr, const uint32_t* data, const uword_t size)
{
  if (data == nullptr || size == 0u)
  {
    return FAILURE;
  }

  if (!IsAligned(addr, size, 4))
  {
    return ADDR_NOT_ALIGNED;
  }

  uint32_t     localAddr = static_cast<uint32_t>(addr);
  const size_t beats     = static_cast<size_t>(size / 4);

  for (size_t i = 0; i < beats; i++)
  {
    // --- AW phase (single-beat, 4-byte) ---
    dut->s_instr_axi_awaddr_i  = localAddr;
    dut->s_instr_axi_awburst_i = 0b00;
    dut->s_instr_axi_awsize_i  = 0b010; // 4 bytes
    dut->s_instr_axi_awlen_i   = 0;
    dut->s_instr_axi_awvalid_i = 1;
    while (dut->s_instr_axi_awready_o == 0)
    {
      Cycle();
    }
    Cycle();
    dut->s_instr_axi_awvalid_i = 0;

    // --- W phase (data + strobes) ---
    dut->s_instr_axi_wdata_i  = data[i];
    dut->s_instr_axi_wstrb_i  = 0xF;
    dut->s_instr_axi_wlast_i  = 1;
    dut->s_instr_axi_wvalid_i = 1;
    while (dut->s_instr_axi_wready_o == 0)
    {
      Cycle();
    }
    Cycle();
    dut->s_instr_axi_wvalid_i = 0;

    // --- B phase (response) ---
    dut->s_instr_axi_bready_i = 1;
    while (dut->s_instr_axi_bvalid_o == 0)
    {
      Cycle();
    }
    Cycle();
    dut->s_instr_axi_bready_i = 0;

    localAddr += 4;
  }

  return SUCCESS;
}

/*!
 * \brief Generic AXI write through the DATA/SHARED AXI slave of the DUT.
 *
 * Drives AW → W → B handshakes for word-wide single-beat writes.
 */
uword_t Axi4Write(const uintptr_t addr, const uword_t* data, const uword_t size)
{
  if (data == nullptr || size == 0u)
  {
    return FAILURE;
  }

  if (!IsAligned(addr, size, NB_BYTES_IN_WORD))
  {
    return ADDR_NOT_ALIGNED;
  }

  uword_t      localAddr = static_cast<uword_t>(addr);
  const size_t beats     = static_cast<size_t>(size / NB_BYTES_IN_WORD);

  for (size_t i = 0; i < beats; i++)
  {
    // --- AW phase (single-beat, 4B or 8B) ---
    dut->s_axi_awaddr_i  = localAddr;
    dut->s_axi_awburst_i = 0b00;
#ifdef XLEN64
    dut->s_axi_awsize_i = 0b011; // 8 bytes
#else
    dut->s_axi_awsize_i = 0b010; // 4 bytes
#endif
    dut->s_axi_awlen_i   = 0;
    dut->s_axi_awvalid_i = 1;
    while (dut->s_axi_awready_o == 0)
    {
      Cycle();
    }
    Cycle();
    dut->s_axi_awvalid_i = 0;

    // --- W phase ---
    dut->s_axi_wdata_i  = data[i];
    dut->s_axi_wlast_i  = 1;
    dut->s_axi_wvalid_i = 1;
#ifdef XLEN64
    dut->s_axi_wstrb_i = 0xFF;
#else
    dut->s_axi_wstrb_i = 0x0F;
#endif
    while (dut->s_axi_wready_o == 0)
    {
      Cycle();
    }
    Cycle();
    dut->s_axi_wvalid_i = 0;

    // --- B phase ---
    dut->s_axi_bready_i = 1;
    while (dut->s_axi_bvalid_o == 0)
    {
      Cycle();
    }
    Cycle();
    dut->s_axi_bready_i = 0;

    localAddr += NB_BYTES_IN_WORD;
  }

  return SUCCESS;
}

/*!
 * \brief Generic AXI read through the DATA/SHARED AXI slave of the DUT.
 *
 * Drives AR → R handshakes for word-wide single-beat reads.
 */
uword_t Axi4Read(const uintptr_t addr, uword_t* data, const uword_t size)
{
  if (data == nullptr || size == 0u)
  {
    return FAILURE;
  }

  if (!IsAligned(addr, size, NB_BYTES_IN_WORD))
  {
    return ADDR_NOT_ALIGNED;
  }

  uword_t      localAddr = static_cast<uword_t>(addr);
  const size_t beats     = static_cast<size_t>(size / NB_BYTES_IN_WORD);

  for (size_t i = 0; i < beats; i++)
  {
    // --- AR phase (single-beat, 4B or 8B) ---
    dut->s_axi_araddr_i  = localAddr;
    dut->s_axi_arburst_i = 0b00;
#ifdef XLEN64
    dut->s_axi_arsize_i = 0b011; // 8 bytes
#else
    dut->s_axi_arsize_i = 0b010; // 4 bytes
#endif
    dut->s_axi_arlen_i   = 0;
    dut->s_axi_arvalid_i = 1;
    while (dut->s_axi_arready_o == 0)
    {
      Cycle();
    }
    Cycle();
    dut->s_axi_arvalid_i = 0;

    // --- R phase ---
    dut->s_axi_rready_i = 1;
    while (dut->s_axi_rvalid_o == 0)
    {
      Cycle();
    }
    data[i] = dut->s_axi_rdata_o;
    Cycle();
    dut->s_axi_rready_i = 0;

    localAddr += NB_BYTES_IN_WORD;
  }

  return SUCCESS;
}

#else
/*==============================================================================
 *                          PLATFORM (PolarFire Linux)
 *============================================================================*/

#include <fcntl.h>
#include <iostream>
#include <sys/mman.h>

/// Instruction AXI Mapped base addresses (volatile to prevent compiler reordering/merging).
static volatile uint32_t* gInstrAxiBase = nullptr;
/// Data AXI Mapped base addresses (volatile to prevent compiler reordering/merging).
static volatile uword_t* gAxiBase = nullptr;

/// Tracked mmap sizes (used on unmap).
static uint32_t gInstrAxiSize = 0;
/// Tracked mmap sizes (used on unmap).
static uword_t gAxiSize = 0;

/*!
 * \brief Open /dev/mem with O_RDWR|O_SYNC or exit with a clear error message.
 */
static int OpenDevMem()
{
  int fd = ::open("/dev/mem", O_RDWR | O_SYNC);
  return fd;
}

/*--------------------------- Instruction window mapping ----------------------*/

uword_t SetupInstrAxi4(const uint32_t start_addr, const uint32_t size)
{
  if (!IsAligned(start_addr, size, 4))
  {
    return ADDR_NOT_ALIGNED;
  }

  int fd = OpenDevMem();
  if (fd < 0)
  {
    return FAILURE;
  }
  void* base = ::mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, start_addr);
  ::close(fd);

  if (base == MAP_FAILED)
  {
    return FAILURE;
  }

  gInstrAxiBase = reinterpret_cast<volatile uint32_t*>(base);
  gInstrAxiSize = size;

  return SUCCESS;
}

void FinalizeInstrAxi4()
{
  if (gInstrAxiBase)
  {
    ::munmap((void*)gInstrAxiBase, gInstrAxiSize);
    gInstrAxiBase = nullptr;
    gInstrAxiSize = 0;
  }
}

uword_t InstrAxi4Write(const uintptr_t addr, const uint32_t* data, const uword_t size)
{
  if (gInstrAxiBase == nullptr)
  {
    return INVALID_ADDR;
  }
  if (data == nullptr || size == 0u)
  {
    return FAILURE;
  }
  if (!IsAligned(addr, size, 4))
  {
    return ADDR_NOT_ALIGNED;
  }

  volatile uint32_t* p     = gInstrAxiBase + static_cast<uintptr_t>(addr) / 4;
  const size_t       beats = static_cast<size_t>(size / 4);
  for (size_t i = 0; i < beats; ++i)
  {
    p[i] = data[i];
  }

  return SUCCESS;
}

/*------------------------------- Generic AXI mapping -------------------------*/

uword_t SetupAxi4(const uword_t start_addr, const uword_t size)
{
  if (!IsAligned(start_addr, size, NB_BYTES_IN_WORD))
  {
    return ADDR_NOT_ALIGNED;
  }

  int fd = OpenDevMem();
  if (fd < 0)
  {
    return FAILURE;
  }
  void* base = ::mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, start_addr);
  ::close(fd);

  if (base == MAP_FAILED)
  {
    return FAILURE;
  }

  gAxiBase = reinterpret_cast<volatile uword_t*>(base);
  gAxiSize = size;

  return SUCCESS;
}

void FinalizeAxi4()
{
  if (gAxiBase)
  {
    ::munmap((void*)(gAxiBase), gAxiSize);
    gAxiBase = nullptr;
    gAxiSize = 0;
  }
}

/*!
 * \brief Generic word-wide write on the mapped AXI window.
 *
 * Writes NB_BYTES_IN_WORD per iteration starting from \p addr.
 */
uword_t Axi4Write(const uintptr_t addr, const uword_t* data, const uword_t size)
{
  if (gAxiBase == nullptr)
  {
    return INVALID_ADDR;
  }
  if (data == nullptr || size == 0u)
  {
    return FAILURE;
  }
  if (!IsAligned(addr, size, NB_BYTES_IN_WORD))
  {
    return ADDR_NOT_ALIGNED;
  }

  volatile uword_t* p     = gAxiBase + static_cast<uintptr_t>(addr) / NB_BYTES_IN_WORD;
  const size_t      beats = static_cast<size_t>(size / NB_BYTES_IN_WORD);
  for (size_t i = 0; i < beats; ++i)
  {
    p[i] = data[i];
  }

  return SUCCESS;
}

/*!
 * \brief Generic word-wide read on the mapped AXI window.
 *
 * Reads NB_BYTES_IN_WORD per iteration starting from \p addr.
 */
uword_t Axi4Read(const uintptr_t addr, uword_t* data, const uword_t size)
{
  if (gAxiBase == nullptr)
  {
    return INVALID_ADDR;
  }
  if (data == nullptr || size == 0u)
  {
    return FAILURE;
  }
  if (!IsAligned(addr, size, NB_BYTES_IN_WORD))
  {
    return ADDR_NOT_ALIGNED;
  }

  volatile const uword_t* p     = gAxiBase + static_cast<uintptr_t>(addr) / NB_BYTES_IN_WORD;
  const size_t            beats = static_cast<size_t>(size / NB_BYTES_IN_WORD);
  for (size_t i = 0; i < beats; ++i)
  {
    data[i] = p[i];
  }

  return SUCCESS;
}

#endif // SIM / Platform

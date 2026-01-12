// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       defines.h
\brief      Global constants and memory map for the test environment.
\author     Kawanami
\date       12/01/2026
\version    1.1

\details
  This file provides shared definitions used throughout the SCHOLAR RISC-V
  test environment.
  It includes return codes, address boundaries, memory sizes, and AXI mapping
  for the simulation and hardware platforms (e.g., PolarFire SoC/FPGA).

  Constants defined in this file ensure consistency across simulation, firmware,
  and runtime components. Key system-level values include:
    - Standard return/error codes
    - PolarFire SoC/FPGA FIC (Fabric Interface Controller) regions
    - Tag encoding/decoding for FPGA memory map
    - SCHOLAR RISC-V core RAM base addresses and sizes
    - Shared memory regions for platform/core communication (PTC/CTP)

\remarks
  - TODO: .

\section defines_h_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami   | Initial version.                          |
| 1.1     | 12/01/2026 | Kawanami   | Change softcore tag for Spike compatibility.|
********************************************************************************
*/

#ifndef DEFINES_H
#define DEFINES_H

#include <stdint.h>

/******************** RETURN CODES ********************/
/// Successful operation
#define SUCCESS 0x00
/// Operation failure
#define FAILURE 0x01
/// Unaligned address
#define ADDR_NOT_ALIGNED 0x02
/// Out-of-bounds address
#define INVALID_ADDR 0x03
/// Unaligned size
#define INVALID_SIZE 0x04
/// Address + size exceeds bounds
#define OVERFLOW 0x05

/******************** ARCHITECTURE WIDTH ********************/
#ifdef XLEN32
/// Size of a word (32-bit)
typedef int32_t word_t;
/// Size of an unsigned word (32-bit)
typedef uint32_t uword_t;
/// Word-aligned address granularity (32-bit)
#define ADDR_OFFSET 0b11
/// Number of bytes in a word (32-bit)
#define NB_BYTES_IN_WORD 0x00000004
/// Format used to scan 32-bit words
#define WORD_SCAN_FMT "%x"
/// Format used to print a 32-bit word
#define WORD_PRINT_FMT "%08x"
#endif

#ifdef XLEN64
/// Size of a word (64-bit)
typedef int64_t word_t;
/// Size of an unsigned word (64-bit)
typedef uint64_t uword_t;
/// Word-aligned address granularity (64-bit)
#define ADDR_OFFSET 0b111
/// Number of bytes in a word (64-bit)
#define NB_BYTES_IN_WORD 0x00000008
/// Format used to scan 64-bit words
#define WORD_SCAN_FMT "%lx"
/// Format used to print a 64-bit word
#define WORD_PRINT_FMT "%016lx"
#endif

/******************** POLARFIRE FIC WINDOWS ********************/
/// FIC0 AXI4 start address (PolarFire SoC/FPGA)
#define FIC0_START_ADDR 0x60000000
/// Number of addressable bytes for the AXI4 (PolarFire SoC/FPGA)
#define FIC0_SIZE 0x20000000
/// AXI4 start address (PolarFire SoC/FPGA)
#define FIC1_START_ADDR 0xe0000000
/// Number of addressable bytes for the AXI4 (PolarFire SoC/FPGA)
#define FIC1_SIZE 0x20000000

/******************** FPGA FABRIC: TOP-LEVEL TAGGING ********************/
/// Most significant bit of the address used to select memory-mapped regions
#define FPGA_FABRIC_TAG_MSB 23
/// Least significant bit of the address used to select memory-mapped regions
#define FPGA_FABRIC_TAG_LSB 20
/// Number of address bits used to define the memory region tag
#define FPGA_FABRIC_TAG_SIZE ((FPGA_FABRIC_TAG_MSB - FPGA_FABRIC_TAG_LSB) + 1)
/// Bitmask used to extract or compare the region tag from an address
#define FPGA_FABRIC_TAG_MASK ((1 << FPGA_FABRIC_TAG_SIZE) - 1)

/******************** GPIO REGION ********************/
/// Tag value identifying the GPIO memory region
#define GPIO_TAG 0b0000
/// GPIO memory start address
#define GPIO_START_ADDR (GPIO_TAG << FPGA_FABRIC_TAG_LSB)
/// GPIO memory size (in bytes)
#define GPIO_SIZE 4096

/******************** SOFTCORE 0: SECOND-LEVEL TAGGING ********************/
/// Tag value used to identify memory-mapped regions belonging to SOFTCORE 0
#define SOFTCORE_0_TAG 0b0001
/// SOFTCORE 0 memory regions start address
#define SOFTCORE_0_START_ADDR (SOFTCORE_0_TAG << FPGA_FABRIC_TAG_LSB)
/// Most significant bit of the tag field used to address memory-mapped regions within SOFTCORE 0
#define SOFTCORE_0_TAG_MSB 19
/// Least significant bit of the tag field used to address memory-mapped regions within SOFTCORE 0
#define SOFTCORE_0_TAG_LSB 16
/// Number of address bits used to define the memory region tag within SOFTCORE 0
#define SOFTCORE_0_TAG_SIZE ((SOFTCORE_0_TAG_MSB - SOFTCORE_0_TAG_LSB) + 1)
/// Bitmask used to extract or compare the SOFTCORE 0 region tag from an address
#define SOFTCORE_0_TAG_MASK ((1 << SOFTCORE_0_TAG_SIZE) - 1)

/******************** INSTR RAM (Softcore-0) ********************/
/// Tag value identifying the SOFTCORE 0 instruction memory region
#define SOFTCORE_0_INSTR_RAM_TAG 0b0000
/// Start address of the SOFTCORE 0 instruction memory region
#define SOFTCORE_0_INSTR_RAM_START_ADDR \
  (SOFTCORE_0_START_ADDR + (SOFTCORE_0_INSTR_RAM_TAG << SOFTCORE_0_TAG_LSB))
/// Size of the SOFTCORE 0 instruction memory region (in bytes)
#define SOFTCORE_0_INSTR_RAM_SIZE 0x00004000
/// End address of the SOFTCORE 0 instruction memory region
#define SOFTCORE_0_INSTR_RAM_END_ADDR \
  (SOFTCORE_0_INSTR_RAM_START_ADDR + SOFTCORE_0_INSTR_RAM_SIZE - 4)

/******************** DATA RAM (Softcore-0) ********************/
/// Tag value identifying the SOFTCORE 0 data memory region
#define SOFTCORE_0_DATA_RAM_TAG 0b0001
/// Start address of the SOFTCORE 0 data memory region
#define SOFTCORE_0_DATA_RAM_START_ADDR \
  (SOFTCORE_0_START_ADDR + (SOFTCORE_0_DATA_RAM_TAG << SOFTCORE_0_TAG_LSB))
/// Size of the SOFTCORE 0 data memory region (in bytes)
#define SOFTCORE_0_DATA_RAM_SIZE 0x00004000

/******************** PTC SHARED RAM (Softcore-0) ********************/
/// Tag value identifying the SOFTCORE 0 platform-to-core shared memory region
#define SOFTCORE_0_PTC_RAM_TAG 0b0010
/// Start address of the SOFTCORE 0 platform-to-core shared memory region
#define SOFTCORE_0_PTC_RAM_START_ADDR \
  (SOFTCORE_0_START_ADDR + (SOFTCORE_0_PTC_RAM_TAG << SOFTCORE_0_TAG_LSB))
/// Size of the SOFTCORE 0 platform-to-core shared memory region (in bytes)
#define SOFTCORE_0_PTC_RAM_SIZE 0x00000400
/// Address of the platform counter in the platform-to-core shared memory region
#define SOFTCORE_0_PTC_RAM_PLATFORM_COUNT_ADDR (SOFTCORE_0_PTC_RAM_START_ADDR)
/// Address of the core counter in the platform-to-core shared memory region
#define SOFTCORE_0_PTC_RAM_CORE_COUNT_ADDR \
  (SOFTCORE_0_PTC_RAM_PLATFORM_COUNT_ADDR + NB_BYTES_IN_WORD)
/// Address of the data size in the platform-to-core shared memory region
#define SOFTCORE_0_PTC_RAM_DATA_SIZE_ADDR (SOFTCORE_0_PTC_RAM_CORE_COUNT_ADDR + NB_BYTES_IN_WORD)
/// Start address of the data in the platform-to-core shared memory region
#define SOFTCORE_0_PTC_RAM_DATA_ADDR (SOFTCORE_0_PTC_RAM_DATA_SIZE_ADDR + NB_BYTES_IN_WORD)

/******************** CTP SHARED RAM (Softcore-0) ********************/
/// Tag value identifying the SOFTCORE 0 core-to-platform shared memory region
#define SOFTCORE_0_CTP_RAM_TAG 0b0011
/// Start address of the SOFTCORE 0 core-to-platform shared memory region
#define SOFTCORE_0_CTP_RAM_START_ADDR \
  (SOFTCORE_0_START_ADDR + (SOFTCORE_0_CTP_RAM_TAG << SOFTCORE_0_TAG_LSB))
/// Size of the SOFTCORE 0 core-to-platform shared memory region (in bytes)
#define SOFTCORE_0_CTP_RAM_SIZE 0x00000400
/// Address of the platform counter in the core-to-platform shared memory region
#define SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR (SOFTCORE_0_CTP_RAM_START_ADDR)
/// Address of the core counter in the core-to-platform shared memory region
#define SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR \
  (SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR + NB_BYTES_IN_WORD)
/// Address of the data size in the core-to-platform shared memory region
#define SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR (SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR + NB_BYTES_IN_WORD)
/// Start address of the data in the core-to-platform shared memory region
#define SOFTCORE_0_CTP_RAM_DATA_ADDR (SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR + NB_BYTES_IN_WORD)

#endif

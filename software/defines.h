/*!
********************************************************************************
*  \file      defines.h
*  \brief     Global constants and memory map for the test environment.
*
*  \author    Kawanami
*  \version   1.0
*  \date      04/06/2025
*
********************************************************************************
*  \details
*  This file provides shared definitions used throughout the RISC-V test environment.
*  It includes return codes, address boundaries, memory sizes, and AXI mapping
*  for the simulation and hardware platforms (e.g., PolarFire SoC/FPGA).
*
*  Constants defined in this file ensure consistency across simulation, firmware,
*  and runtime components. Key system-level values include:
*    - Standard return/error codes
*    - PolarFire SoC/FPGA FIC (Fabric Interface Controller) regions
*    - Tag encoding/decoding for FPGA memory map
*    - SCHOLAR RISC-V core RAM base addresses and sizes
*    - Shared memory regions for platform/core communication (PTC/CTP)
********************************************************************************
*  \defines
*     - SUCCESS                                 : Successful operation
*     - FAILURE                                 : Operation failure
*     - ADDR_NOT_ALIGNED                        : Unaligned address
*     - INVALID_ADDR                            : Out-of-bounds address
*     - INVALID_SIZE                            : Unaligned size
*     - OVERFLOW                                : Address + size exceeds bounds
*     - NB_BYTES_IN_WORD                        : Number of bytes in a word
*     - FIC0_START_ADDR                         : FIC0 AXI4 start address (PolarFire SoC/FPGA)
*     - FIC0_SIZE                               : Number of addressable bytes for the AXI4 (PolarFire SoC/FPGA)
*     - FIC1_START_ADDR                         : AXI4 start address (PolarFire SoC/FPGA)
*     - FIC1_SIZE                               : Number of addressable bytes for the AXI4 (PolarFire SoC/FPGA)
*     - FPGA_FABRIC_TAG_MSB                     : Most significant bit of the address used to select memory-mapped regions
*     - FPGA_FABRIC_TAG_LSB                     : Least significant bit of the address used to select memory-mapped regions
*     - FPGA_FABRIC_TAG_SIZE                    : Number of address bits used to define the memory region tag
*     - FPGA_FABRIC_TAG_MASK                    : Bitmask used to extract or compare the region tag from an address
*     - GPIO_TAG                                : Tag value identifying the GPIO memory region
*     - GPIO_START_ADDR                         : GPIO memory start address
*     - GPIO_SIZE                               : GPIO memory size (in bytes)
*     - SOFTCORE_0_TAG                          : Tag value used to identify memory-mapped regions belonging to SOFTCORE 0
*     - SOFTCORE_0_START_ADDR                   : SOFTCORE 0 memory regions start address
*     - SOFTCORE_0_TAG_MSB                      : Most significant bit of the tag field used to address memory-mapped regions
*                                                 within SOFTCORE 0
*     - SOFTCORE_0_TAG_LSB                      : Least significant bit of the tag field used to address memory-mapped regions
*                                                 within SOFTCORE 0
*     - SOFTCORE_0_TAG_SIZE                     : Number of address bits used to define the memory region tag within SOFTCORE 0
*     - SOFTCORE_0_TAG_MASK                     : Bitmask used to extract or compare the SOFTCORE 0 region tag from an address
*     - SOFTCORE_0_INSTR_RAM_TAG                : Tag value identifying the SOFTCORE 0 instruction memory region
*     - SOFTCORE_0_INSTR_RAM_START_ADDR         : Start address of the SOFTCORE 0 instruction memory region
*     - SOFTCORE_0_INSTR_RAM_SIZE               : Size of the SOFTCORE 0 instruction memory region (in bytes)
*     - SOFTCORE_0_DATA_RAM_TAG                 : Tag value identifying the SOFTCORE 0 data memory region
*     - SOFTCORE_0_DATA_RAM_START_ADDR          : Start address of the SOFTCORE 0 data memory region
*     - SOFTCORE_0_DATA_RAM_SIZE                : Size of the SOFTCORE 0 data memory region (in bytes)
*     - SOFTCORE_0_PTC_RAM_TAG                  : Tag value identifying the SOFTCORE 0 platform-to-core shared memory region
*     - SOFTCORE_0_PTC_RAM_START_ADDR           : Start address of the SOFTCORE 0 platform-to-core shared memory region
*     - SOFTCORE_0_PTC_RAM_SIZE                 : Size of the SOFTCORE 0 platform-to-core shared memory region (in bytes)
*     - SOFTCORE_0_PTC_RAM_PLATFORM_COUNT_ADDR  : Address of the platform counter in the platform-to-core shared memory region
*     - SOFTCORE_0_PTC_RAM_CORE_COUNT_ADDR      : Address of the core counter in the platform-to-core shared memory region
*     - SOFTCORE_0_PTC_RAM_DATA_SIZE_ADDR       : Address of the data size in the platform-to-core shared memory region
*     - SOFTCORE_0_PTC_RAM_DATA_ADDR            : Start address of the data in the platform-to-core shared memory region
*     - SOFTCORE_0_CTP_RAM_TAG                  : Tag value identifying the SOFTCORE 0 core-to-platform shared memory region
*     - SOFTCORE_0_CTP_RAM_START_ADDR           : Start address of the SOFTCORE 0 core-to-platform shared memory region
*     - SOFTCORE_0_CTP_RAM_SIZE                 : Size of the SOFTCORE 0 core-to-platform shared memory region (in bytes)
*     - SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR  : Address of the platform counter in the core-to-platform shared memory region
*     - SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR      : Address of the core counter in the core-to-platform shared memory region
*     - SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR       : Address of the data size in the core-to-platform shared memory region
*     - SOFTCORE_0_CTP_RAM_DATA_ADDR            : Start address of the data in the core-to-platform shared memory region
*     - SOFTCORE_1_TAG                          : Tag value used to identify memory-mapped regions belonging to SOFTCORE 1
*     - SOFTCORE_1_START_ADDR                   : SOFTCORE 1 memory regions start address
*     - SOFTCORE_2_TAG                          : Tag value used to identify memory-mapped regions belonging to SOFTCORE 2
*     - SOFTCORE_2_START_ADDR                   : SOFTCORE 1 memory regions start address
********************************************************************************
*  \typedefs
*    - None.
*
*  \structures
*    - None.
*
*  \functions
*    - None.
*
********************************************************************************
*  \versioning
*
*  Version   Date        Author          Description
*  -------   ----------  ------------    --------------------------------------
*  1.0       04/06/2025  Kawanami        Initial version
*  1.1       [Date]      [Author]        Description
*
********************************************************************************
*  \remarks
*  - This implementation complies with [reference or standard].
*  - TODO: .
********************************************************************************
*/

#ifndef __DEFINES_H__
#define __DEFINES_H__

#define SUCCESS                                 0x00
#define FAILURE                                 0x01
#define ADDR_NOT_ALIGNED                        0x02
#define INVALID_ADDR                            0x03
#define INVALID_SIZE                            0x04
#define OVERFLOW                                0x05

#define NB_BYTES_IN_WORD                        0x00000004

#define FIC0_START_ADDR                         0x60000000
#define FIC0_SIZE                               0x20000000

#define FIC1_START_ADDR                         0xe0000000
#define FIC1_SIZE                               0x20000000


/*
* FPGA FABRIC
*/
#define FPGA_FABRIC_TAG_MSB                     23
#define FPGA_FABRIC_TAG_LSB                     20
#define FPGA_FABRIC_TAG_SIZE                    ((FPGA_FABRIC_TAG_MSB - FPGA_FABRIC_TAG_LSB) + 1)
#define FPGA_FABRIC_TAG_MASK                    ((1 << FPGA_FABRIC_TAG_SIZE) - 1)

// GPIOS
#define GPIO_TAG                                0b0000
#define GPIO_START_ADDR                         (GPIO_TAG << FPGA_FABRIC_TAG_LSB)
#define GPIO_SIZE                               4096

// SOFTCORE 0
#define SOFTCORE_0_TAG                          0b0000
#define SOFTCORE_0_START_ADDR                   (SOFTCORE_0_TAG << FPGA_FABRIC_TAG_LSB)

#define SOFTCORE_0_TAG_MSB                      19
#define SOFTCORE_0_TAG_LSB                      16
#define SOFTCORE_0_TAG_SIZE                     ((SOFTCORE_0_TAG_MSB - SOFTCORE_0_TAG_LSB) + 1)
#define SOFTCORE_0_TAG_MASK                     ((1 << SOFTCORE_0_TAG_SIZE) - 1)

#define SOFTCORE_0_INSTR_RAM_TAG                0b0000
#define SOFTCORE_0_INSTR_RAM_START_ADDR         (SOFTCORE_0_START_ADDR + (SOFTCORE_0_INSTR_RAM_TAG << SOFTCORE_0_TAG_LSB))
#define SOFTCORE_0_INSTR_RAM_SIZE               0x00004000

#define SOFTCORE_0_DATA_RAM_TAG                 0b0001
#define SOFTCORE_0_DATA_RAM_START_ADDR          (SOFTCORE_0_START_ADDR + (SOFTCORE_0_DATA_RAM_TAG << SOFTCORE_0_TAG_LSB))
#define SOFTCORE_0_DATA_RAM_SIZE                0x00003000

#define SOFTCORE_0_PTC_RAM_TAG                  0b0010
#define SOFTCORE_0_PTC_RAM_START_ADDR           (SOFTCORE_0_START_ADDR + (SOFTCORE_0_PTC_RAM_TAG << SOFTCORE_0_TAG_LSB))
#define SOFTCORE_0_PTC_RAM_SIZE                 0x00000400
#define SOFTCORE_0_PTC_RAM_PLATFORM_COUNT_ADDR  (SOFTCORE_0_PTC_RAM_START_ADDR)
#define SOFTCORE_0_PTC_RAM_CORE_COUNT_ADDR      (SOFTCORE_0_PTC_RAM_PLATFORM_COUNT_ADDR + NB_BYTES_IN_WORD)
#define SOFTCORE_0_PTC_RAM_DATA_SIZE_ADDR       (SOFTCORE_0_PTC_RAM_CORE_COUNT_ADDR + NB_BYTES_IN_WORD)
#define SOFTCORE_0_PTC_RAM_DATA_ADDR            (SOFTCORE_0_PTC_RAM_DATA_SIZE_ADDR + NB_BYTES_IN_WORD)

#define SOFTCORE_0_CTP_RAM_TAG                  0b0011
#define SOFTCORE_0_CTP_RAM_START_ADDR           (SOFTCORE_0_START_ADDR + (SOFTCORE_0_CTP_RAM_TAG << SOFTCORE_0_TAG_LSB))
#define SOFTCORE_0_CTP_RAM_SIZE                 0x00000400
#define SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR  (SOFTCORE_0_CTP_RAM_START_ADDR)
#define SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR      (SOFTCORE_0_CTP_RAM_PLATFORM_COUNT_ADDR + NB_BYTES_IN_WORD)
#define SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR       (SOFTCORE_0_CTP_RAM_CORE_COUNT_ADDR + NB_BYTES_IN_WORD)
#define SOFTCORE_0_CTP_RAM_DATA_ADDR            (SOFTCORE_0_CTP_RAM_DATA_SIZE_ADDR + NB_BYTES_IN_WORD)

// SOFTCORE 1
#define SOFTCORE_1_TAG                          0b0010
#define SOFTCORE_1_START_ADDR                   (SOFTCORE_1_TAG << FPGA_FABRIC_TAG_LSB)

// SOFTCORE 2
#define SOFTCORE_2_TAG                          0b0011
#define SOFTCORE_2_START_ADDR                   (SOFTCORE_2_TAG << FPGA_FABRIC_TAG_LSB)



#endif
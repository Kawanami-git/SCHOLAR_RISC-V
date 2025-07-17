/*
*  \file       memory.h
*  \brief      Memory access primitives
*
*  \author     Kawanami
*  \version    1.0
*  \date       02/06/2025
*
********************************************************************************
*  \details
*  This file declares utility functions for interacting with the memories
*  used in the SCHOLART RISC-V environment. These functions facilitate
*  memory operations such as writing, reading, and synchronization between the
*  core and platform through shared memories.
********************************************************************************
*  \defines
*    - None
*
*  \typedefs
*    - None
*
*  \structures
*    - None
*
*  \functions
*    - mem_write()           : Write `size` bytes to memory at `addr`
*    - mem_reset()           : Fill memory at `addr` with `value`, over `size` bytes
*    - shared_write_ready()  : Returns 1 if the platform is ready to receive new data
*    - shared_read_ready()   : Returns the size of available data to be read, or 0 if none
*    - mem_write_ack()       : Acknowledge a write operation to core-to-platform shared memory
*    - mem_read_ack()        : Acknowledge a read operation from platform-to-core shared memory
********************************************************************************
*  \versioning
*
*  Version   Date        Author          Description
*  -------   ----------  ------------    --------------------------------------
*  1.0       02/06/2025  Kawanami        Initial version
*  1.1       [Date]      [Author]        Description
********************************************************************************
*  \remarks
*  - This implementation complies with [reference or standard].
*  - TODO: Add address validation in each function to prevent invalid memory access
*    and overflow.
********************************************************************************
*/

#ifndef __MEMORY_H__
#define __MEMORY_H__

#include <stdint.h>

/*!
*  \brief   Writes data in a memory
********************************************************************************
*  - FILE / FUNCTION NAME    : memory.c / mem_write
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    addr  : Start address for the write operation
*                data  : Pointer to the buffer containing data to be written
*                size  : Number of bytes to write (must be word-aligned, i.e., multiple of 4)
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function writes `size` bytes of data in the mem at `addr`.
*  Both `addr` and `size` must be aligned to a 4-byte boundary.
********************************************************************************/
uint32_t mem_write(uintptr_t addr, uint32_t* data, uint32_t size);

/*!
*  \brief   Reads data in a memory
********************************************************************************
*  - FILE / FUNCTION NAME    : memory.c / mem_read
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    addr  : Start address for the read operation.
*  \param[in]    size  : Number of bytes to read (must be word-aligned, i.e., multiple of 4)
*
*  \param[out]   data  : Pointer to the buffer where the read data will be written
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function reads `size` bytes of data from the mem at `addr`.
*  Both `addr` and `size` must be aligned to a 4-byte boundary.
********************************************************************************/
uint32_t mem_read(uintptr_t addr, uint32_t* data, uint32_t size);

/*!
*  \brief   Resets the mem by filling it with a provided value
********************************************************************************
*  - FILE / FUNCTION NAME    : memory.c / mem_reset
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    addr  : Start address for the write operation
*                size  : Number of bytes to write (must be word-aligned, i.e., multiple of 4)
*                value : Data to be written
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       Void
********************************************************************************
*  \remarks
*  This function resets the entire mem by writing a provided value
*  to each word of memory.
*  It ensures that all memory locations are cleared.
********************************************************************************/
void mem_reset(uint32_t addr, uint32_t size, uint32_t value);

/*!
*  \brief   Checks if the platform-to-core shared memory is ready
*           for a new write transaction
********************************************************************************
*  - FILE / FUNCTION NAME    : memory.c / shared_write_ready
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    None
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       uint32_t
*                - 1 if the core can safely write new data into the shared memory
*                - 0 otherwise
********************************************************************************
*  \remarks
*  This function compares the platform counter of the core-to-platform shared memeory
*  and an internal reference value.
*  If both counters are equal, the platform-to-core is considered ready
*  for a new write transaction by the platform and the internal counter is
*  incremented.
********************************************************************************/
uint32_t shared_write_ready();

/*!
*  \brief   Checks if new data is available to read
*           from the core-to-platform shared memory
********************************************************************************
*  - FILE / FUNCTION NAME    : memory.c / shared_read_ready
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    None
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       uint32_t
*                - Size in bytes of the available data if new data is present
*                - 0 if no new data is available
********************************************************************************
*  \remarks
*  This function compares the core counter of the core-to-platformshared memory
*  and an internal reference value
*  If `ctp_count > ref`, it means unread data is available, and
*  the function returns the size of that data. Otherwise, it returns 0.
********************************************************************************/
uint32_t shared_read_ready();

/*!
*  \brief   Acknowledges that a core-to-platform shared memory read has been processed
********************************************************************************
*  - FILE / FUNCTION NAME    : memory.c / shared_read_ack
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    None
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function increments the platform-to-core core counter (`PTC_RAM_CORE_COUNT_ADDR`),
*  signaling that the current read transaction from the core-to-platform shared memory
*  has been completed.
********************************************************************************/
void shared_read_ack();

/*!
*  \brief   Acknowledges that a platform-to-core shared memory write has been processed
********************************************************************************
*  - FILE / FUNCTION NAME    : memory.c / shared_write_ack
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    None
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function increments the platform-to-core platform counter (`PTC_RAM_PLATFORM_COUNT_ADDR`),
*  signaling that the current write transaction to the platform-to-core shared memory
*  has been completed.
********************************************************************************/
void shared_write_ack();
#endif
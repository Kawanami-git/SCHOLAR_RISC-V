/*!
********************************************************************************
*  \files     axi4.h / axi4.cpp
*  \brief     AXI4 memory access interface for the SCHOLAR RISC-V test environment.
*
*  \author    Kawanami
*  \version   1.0
*  \date      04/06/2025
*
********************************************************************************
*  \details
*  These files provide read and write access to the AXI4 memory-mapped bus.
*  Functions are designed to be portable between simulation (C++) and
*  embedded execution on PolarFire Linux (C), using conditional compilation.
*
*  Only basic AXI4 single-beat transactions are supported. Burst transfers
*  are not implemented.
********************************************************************************
*  \defines
*    - None.
*
*  \typedefs
*    - None.
*
*  \structures
*    - None.
*
*  \functions
*    - axi4_write : Writes `size` bytes of data to the specified `addr`.
*    - axi4_read  : Reads `size` bytes of data from the specified `addr`.
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

#ifndef __AXI4_H__
#define __AXI4_H__

#include <stdint.h>

/*
* These headers are shared between the simulation environment (C++)
* and the PolarFire Linux target (C). The following lines ensure
* proper linkage and compilation in both environments.
*/
#ifndef DUT

#ifdef __cplusplus

extern "C" {
    void setup_axi4();
    void finalize_axi4();
}

#else

#endif

/*!
*  \brief   Maps the virtual memory for AXI4 access
********************************************************************************
*  - FILE / FUNCTION NAME    : axi4.cpp / setup_axi4
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
*  This function maps a virtual memory region to the physical AXI4 address
*  space. It must be called before any AXI4 read or write on the PolarFire Linux target.
*
*  This setup is not required in simulation mode, where memory access is handled directly.
********************************************************************************/
void setup_axi4();


/*!
*  \brief   Unmaps the virtual memory used for AXI4 access.
********************************************************************************
*  - FILE / FUNCTION NAME    : axi4.cpp / finalize_axi4
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
*  This function releases the virtual memory mapping previously created by
*  `setup_axi4`. It must be called at the end of execution to cleanly unmap the
*  AXI4 address space on the PolarFire Linux target.
*
*  This function is not required in simulation mode.
********************************************************************************/
void finalize_axi4();

#endif
/**/


/*!
*  \brief   Write data to memory via AXI4 interface
********************************************************************************
*  - FILE / FUNCTION NAME    : axi4.cpp / axi4_write
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    addr   Start address for the write operation
*  \param[in]    data   Pointer to the buffer containing data to be written
*  \param[in]    size   Number of bytes to write (must be word-aligned, i.e., multiple of 4)
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function performs an AXI4-compliant write to the specified memory region.
*  Both `addr` and `size` must be aligned to 4 bytes.
*  The AXI4 interface used does not support burst transfers—only single transactions.
********************************************************************************/
void axi4_write(uintptr_t addr, uint32_t* data, uint32_t size);


/*!
*  \brief   Read data from memory via AXI4 interface
********************************************************************************
*  - FILE / FUNCTION NAME    : axi4.cpp / axi4_read
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    addr   Start address for the read operation.
*  \param[in]    size   Number of bytes to read (must be word-aligned, i.e., multiple of 4)
*
*  \param[out]   data   Pointer to the buffer where the read data will be stored
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function performs an AXI4-compliant memory read from the specified address.
*  Both `addr` and `size` must be aligned to 4 bytes.
*  The AXI4 interface used supports only single-beat transactions (no bursts).
********************************************************************************/
void axi4_read(uintptr_t addr, uint32_t* data, uint32_t size);



#endif
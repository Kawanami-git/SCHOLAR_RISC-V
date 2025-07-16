/*!
********************************************************************************
*  \files     apb.h / apb.cpp
*  \brief     APB bus communication interface for the RISC-V test environment.
*
*  \author    Kawanami 
*  \version   1.0  
*  \date      17/03/2025
*
********************************************************************************
*  \details  
*  These files provide functions to perform write and read requests on the APB bus. 
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
*    - apb_write : Writes `size` bytes of data at the specified `addr`
*    - apb_read  : Reads `size` bytes of data at the specified `addr`.
*
********************************************************************************
*  \versioning   
*
*  Version   Date        Author          Description  
*  -------   ----------  ------------    --------------------------------------
*  1.0       17/03/2025  Kawanami        Initial version  
*  1.1       [Date]      [Author]        Description  
*
********************************************************************************
*  \remarks  
*  - This implementation complies with [reference or standard].  
*  - TODO: .  
*
********************************************************************************
*/

#ifndef __APB_H__
#define __APB_H__

#include <stdint.h>

/*!
*  \brief   Writes data using APB.
********************************************************************************
*  - FILE / FUNCTION NAME    : apb.cpp / apb_write
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    addr   Start address for the write operation.
*  \param[in]    data   Pointer to the buffer containing data to be written.
*  \param[in]    size   Number of bytes to write (must be word-aligned, i.e., multiple of 4).
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks  
*  This function writes `size` bytes of data at `addr`.  
*  Both `addr` and `size` must be aligned to a 4-byte boundary.  
********************************************************************************/
void apb_write(uint32_t addr, uint32_t* data, uint32_t size);

/*!
*  \brief   Reads data using APB.
********************************************************************************
*  - FILE / FUNCTION NAME    : apb.cpp / apb_read
*  - FUNCTION TYPE           : Public
*  - SPECIFICATION           :
********************************************************************************
*  \param[in]    addr   Start address for the read operation.
*  \param[in]    size   Number of bytes to read (must be word-aligned, i.e., multiple of 4).
*
*  \param[out]   data   Pointer to the buffer where the read data will be written.
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks  
*  This function reads `size` bytes of data at `addr`.   
*  Both `addr` and `size` must be aligned to a 4-byte boundary.  
********************************************************************************/
void apb_read(uint32_t addr, uint32_t* data, uint32_t size);

#endif
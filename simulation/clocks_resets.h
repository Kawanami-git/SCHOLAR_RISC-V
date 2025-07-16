/*!
********************************************************************************
*  \files     clocks_resets.h / clocks_resets.cpp
*  \brief     Simulation clocks and resets management
*
*  \author    Kawanami
*  \version   1.0
*  \date      02/06/2025
*
********************************************************************************
*  \details
*  These files implement utility functions to manage clock and reset signals
*  during simulation. They provide a simple interface to drive and manipulate
*  the DUT's clocking and reset behavior using Verilator’s VPI/DPI interface.
*
*  It aims to emulate the behavior of a real clock and reset management system,
*  such as those typically implemented in FPGA SoC platforms.
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
*    - set_clk_signal()              : Sets the value of the clock signal (0 or 1).
*    - clock_tick()                  : Toggles the DUT clock to simulate an edge.
*    - set_core_reset_signal()       : Drives the SCHOLAR RISC-V core reset signal.
*    - set_ram_reset_signal()        : Drives the RAMs reset signal.
********************************************************************************
*  \versioning
*
*  Version   Date        Author          Description
*  -------   ----------  ------------    --------------------------------------
*  1.0       02/06/2025  Kawanami        Initial version
*  1.1       [Date]      [Author]        [Description of changes]
*
********************************************************************************
*  \remarks
*  - This implementation complies with [reference or standard].
*  - TODO: .
*
********************************************************************************
*/

#ifndef __CLOCKS_RESETS_H__
#define __CLOCKS_RESETS_H__

#include <stdint.h>

/*!
********************************************************************************
*  \brief   Clock value setter
********************************************************************************
*  - FILE / FUNCTION NAME       : clocks_resets.cpp / set_clk_signal
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    CLK   : The clock value to set (0 or 1).
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function allows to set the clock value of the DUT.
*  The clock value can be either `0` (low) or `1` (high), and this function
*  directly modifies the DUT's clock signal for simulation purposes.
********************************************************************************/
void set_clk_signal(uint8_t CLK);

/*!
********************************************************************************
*  \brief   Tick the DUT clock
********************************************************************************
*  - FILE / FUNCTION NAME       : clocks_resets.cpp / clock_tick
*  - SPECIFICATION              :
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
*  This function changes the clock edge of the DUT.
*  It toggles the clock from rising edge to falling edge or vice versa.
********************************************************************************/
void clock_tick();

/*!
********************************************************************************
*  \brief   SCHOLAR RISC-V core reset setter
********************************************************************************
*  - FILE / FUNCTION NAME       : clocks_resets.cpp / set_core_reset_signal
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    RSTN   The reset value to set (active low). A value of `0` will
*                       assert the reset, and a value of `1` will deassert it.
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function allows to set the reset signal value of the DUT (SCHOLAR RISC-V core).
*  The reset is active low, meaning that a value of `0` will activate the reset,
*  and a value of `1` will release it.
********************************************************************************/
void set_core_reset_signal(uint8_t RSTN);


/*!
********************************************************************************
*  \brief   DUT RAMs reset setter
********************************************************************************
*  - FILE / FUNCTION NAME       : clocks_resets.cpp / set_core_reset_signal
*  - SPECIFICATION              :
********************************************************************************
*  \param[in]    RSTN   The reset value to set (active low). A value of `0` will
*                       assert the reset, and a value of `1` will deassert it.
*
*  \param[out]   None
*
*  \param[inout] None
*
*  \return       void
********************************************************************************
*  \remarks
*  This function allows to set the reset signal value of the DUT RAMs.
*  The reset is active low, meaning that a value of `0` will activate the reset,
*  and a value of `1` will release it.
********************************************************************************/
void set_ram_reset_signal(uint8_t RSTN);


#endif



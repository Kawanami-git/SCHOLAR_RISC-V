// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       clocks_resets.cpp
\brief      Clock and reset control implementation for the Verilator DUT
\author     Kawanami
\version    1.0
\date       25/10/2025

\details
  Implementation of the helpers declared in \ref clocks_resets.h.

  Notes:
  - These functions only drive DUT pins; they do NOT call eval() nor advance
    time. Keep a single time authority in your bench (e.g., cycle()).
  - Core and AXI clocks are intentionally kept in phase.
  - Resets are active-low.

\section clocks_resets_cpp_version_history Version history
| Version | Date       | Author     | Description      |
|:-------:|:----------:|:-----------|:-----------------|
| 1.0     | 25/10/2025 | Kawanami   | Initial version. |
| 1.1     | xx/xx/xxxx | Author     |                  |
********************************************************************************
*/

#include "clocks_resets.h"

#include "Vriscv_env.h"

/// Provided by the simulation harness (top-level testbench)
extern Vriscv_env* dut;

void SetClkSignal(uint8_t clk)
{
  // Drive both clocks to the same level; any non-zero value is treated as '1'.
  const uint8_t level = (clk != 0u) ? 1u : 0u;
  dut->core_clk_i     = level;
  dut->axi_clk_i      = level;
}

void ClockTick()
{
  // Keep core and AXI clocks in phase by toggling both together.
  dut->core_clk_i ^= 1u;
  dut->axi_clk_i ^= 1u;
}

void SetCoreResetSignal(uint8_t rstn)
{
  // Active-low reset: 0 = assert, 1 = de-assert.
  dut->core_rstn_i = (rstn != 0u) ? 1u : 0u;
}

void SetRamResetSignal(uint8_t rstn)
{
  // Active-low reset: 0 = assert, 1 = de-assert.
  dut->axi_rstn_i = (rstn != 0u) ? 1u : 0u;
}

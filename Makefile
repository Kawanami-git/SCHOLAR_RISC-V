#!/bin/sh
# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       Makefile
# \brief      Makefile targets to install environments and change branches
# \author     Kawanami
# \version    1.2
# \date       12/04/2026
#
# \details
#   Run the installers using 'make install_sim_env',
#	'make install_microchip_env' or 'make install_xilinx_env'.
#   Access to RISC-V implemented feature branch with 'make branch'.
#
# \remarks
#
# \section makefile_version_history Version history
# | Version | Date       | Author     | Description      |
# |:-------:|:----------:|:-----------|:-----------------|
# | 1.0     | 11/11/2025 | Kawanami   | Initial version. |
# | 1.1     | 11/12/2025 | Kawanami   | Add a default target. |
# | 1.2     | 12/04/2026 | Kawanami   | Add a CORA_Z7_07S support. |
# ********************************************************************************
# */

.PHONY: default
default: install_sim_env

.PHONY: install_sim_env
install_sim_env:
	@chmod +x simulation_env/install_sim_env.sh
	@cd simulation_env/ && ./install_sim_env.sh

.PHONY: install_microchip_env
install_microchip_env:
	@chmod +x board_support/MPFS_DISCOVERY_KIT/install_microchip_env.sh
	@cd board_support/MPFS_DISCOVERY_KIT && ./install_microchip_env.sh

.PHONY: install_xilinx_env
install_xilinx_env:
	@chmod +x board_support/CORA_Z7_07S/install_xilinx_env.sh
	@cd board_support/CORA_Z7_07S && ./install_xilinx_env.sh
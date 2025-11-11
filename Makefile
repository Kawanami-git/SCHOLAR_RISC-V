#!/bin/sh
# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       Makefile
# \brief      Makefile targets to install environments and change branches
# \author     Kawanami
# \version    1.0
# \date       11/11/2025
#
# \details
#   Run the installers using 'make install_sim_env' or 
#	'make install_microchip_env'.
#   Access to RISC-V implemented feature branch with 'make branch'.
#
# \remarks
#
# \section makefile_version_history Version history
# | Version | Date       | Author     | Description      |
# |:-------:|:----------:|:-----------|:-----------------|
# | 1.0     | 11/11/2025 | Kawanami   | Initial version. |
# ********************************************************************************
# */

.PHONY: install_sim_env
install_sim_env:
	@chmod +x simulation_env/install_sim_env.sh
	@cd simulation_env/ && ./install_sim_env.sh

.PHONY: install_microchip_env
install_microchip_env:
	@chmod +x board_support/MPFS_DISCOVERY_KIT/install_microchip_env.sh
	@cd board_support/MPFS_DISCOVERY_KIT && ./install_microchip_env.sh
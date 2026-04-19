# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       Makefile
# \brief      Top-level build & run orchestration for SCHOLAR RISC-V.
# \author     Kawanami
# \version    2.0
# \date       02/04/2026
#
# \details
#   This Makefile is intentionally thin. It only:
#     - defines the project root,
#     - includes common variables,
#     - includes simulation targets,
#     - includes MPFS Discovery Kit targets,
#     - includes Cora z7-07s targets (if availables),
#     - exposes generic helper targets (if availables).
#
# \remarks
#   - Requires the Makefiles in the 'mk' directory and, depending on the
#     configuration, the Makefiles in the supported board directories.
#   - See `make help` for a friendly summary of targets and variables.
#
# \section makefile_toplevel_version_history Version history
# | Version | Date       | Author   | Description                                                     |
# |:-------:|:----------:|:---------|:----------------------------------------------------------------|
# | 1.0     | 04/11/2025 | Kawanami | Initial version.                                                |
# | 1.1     | 11/11/2025 | Kawanami | Update tools default directories.                               |
# | 1.2     | 23/12/2025 | Kawanami | Fix Linux/SDK fetching.                                         |
# | 1.3     | 12/02/2026 | Kawanami | Add non-perfect memory support.                                 |
# | 1.4     | 14/02/2026 | Kawanami | Update SDK fetching and use.                                    |
# | 1.5     | 28/03/2026 | Kawanami | Add targets to compare loader/cyclemark with Spike trace.       |
# | 1.6     | 29/03/2026 | Kawanami | Pass 'Archi' in simulation and add 'core_pkg' for readability.  |
# | 2.0     | 02/04/2026 | Kawanami | Split all targets into dedicated Makefiles.                     |
# ********************************************************************************
# */

#################################### Directories ####################################
# Root directory for the project
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/

# Project Makefiles directory
MK_DIR := $(ROOT_DIR)mk/
####################################             ####################################

#################################### Included Makefiles ####################################
# Common Makefile
COMMON_MK := $(MK_DIR)common.mk

# Simulation Makefile
SIM_MK    := $(MK_DIR)sim.mk

# MPFS Discovery Kit Makefile
MPFS_MK   := $(ROOT_DIR)MPFS_DISCOVERY_KIT/mpfs_disco_kit.mk

# Cora z7-07s Makefile
CORA_MK   := $(ROOT_DIR)CORA_Z7_07S/cora_z7_07s.mk

# Include common targets
include $(COMMON_MK)

# Include simulation targets
include $(SIM_MK)

# Include MPFS Discovery Kit targets
-include $(MPFS_MK)

# Include Cora Z7-07S targets
-include $(CORA_MK)
####################################                    ####################################

# Default target
.DEFAULT_GOAL := help

# Global help
.PHONY: help
help: common_help sim_help

# Global clean
.PHONY: clean_all
clean_all:
	@rm -rf $(WORK_DIR)

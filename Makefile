# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       Makefile
# \brief      Top-level build & run orchestration for SCHOLAR RISC-V.
# \author     Kawanami
# \version    2.2
# \date       30/04/2026
#
# \details
#   This Makefile is the main entry point for the SCHOLAR RISC-V single-cycle
#   branch. It keeps only the core sources and delegates the common build,
#   firmware, simulation, and board-support flows to the riscv-core-harness
#   submodule.
#
#   It provides:
#     - project root and work directory definitions,
#     - riscv-core-harness submodule path definition,
#     - sv-tools submodule path definition,
#     - RISC-V core RTL directory definition,
#     - default Libero place-and-route exploration parameters,
#     - default RISC-V ISA selection,
#     - inclusion of the riscv-core-harness top-level Makefile,
#     - project-level documentation, formatting, and linting targets,
#     - project-level help entry point.
#
# \remarks
#   - Requires the `riscv-core-harness` submodule to be present and initialized.
#   - Requires the `sv-tools` submodule to be present and initialized for local
#     formatting and linting targets.
#   - The RISC-V core RTL sources are expected to be located under `DUT_DIR`.
#   - Board support and simulation flows are provided by riscv-core-harness.
#   - See `make help` for the available target groups.
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
# | 2.1     | 23/04/2026 | Kawanami | Add 'mpfs_disco_kit_help' to the 'help' Target.                 |
# | 2.2     | 30/04/2026 | Kawanami | Delegate shared flows to core harness.   						  |
# ********************************************************************************
# */

#################################### Directories ####################################

# Absolute path to the SCHOLAR RISC-V project root directory.
ROOT_DIR 				:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/

# Path to the riscv-core-harness submodule used to provide shared flows.
RISCV_CORE_HARNESS_DIR 	:= $(ROOT_DIR)riscv-core-harness/

# Path to the sv-tools submodule used for local formatting and linting.
SV_TOOLS_DIR 			:= $(ROOT_DIR)sv-tools/

# Path to the RISC-V core RTL directory to validate.
DUT_DIR 				?= $(ROOT_DIR)risc-v/

# Path to the working directory used for generated files and build artifacts.
WORK_DIR 				?= $(ROOT_DIR)work/

####################################             ####################################


#################################### Microchip Build Configuration ####################################

# First Libero place-and-route seed used for timing exploration.
PNR_SEED 				?= 3

# Number of Libero place-and-route passes to run.
PNR_PASSES 				?= 1

####################################                               ####################################


#################################### RISC-V Configuration ####################################

# GCC-compatible RISC-V ISA string used by firmware and simulation flows.
ISA 					?= rv32i_zicntr

#
ENABLE_PERF_COUNTERS	?= 1

####################################                      ####################################


#################################### Included Makefiles ####################################

# Top-level Makefile provided by the riscv-core-harness submodule.
RISCV_CORE_HARNESS_MK := $(RISCV_CORE_HARNESS_DIR)riscv-core-harness.mk

# Stop early if the riscv-core-harness submodule is missing or not initialized.
ifeq ($(wildcard $(RISCV_CORE_HARNESS_MK)),)
$(error Missing riscv-core-harness submodule. Run: git submodule update --init --recursive)
endif

# Include shared harness variables and targets.
include $(RISCV_CORE_HARNESS_MK)

####################################                    ####################################

#################################### Targets ####################################

# Default target displayed when running plain `make`.
.DEFAULT_GOAL := help

# Project-level help entry point.
.PHONY: help
help: riscv_help riscv_core_harness_help

# Display help for SCHOLAR RISC-V local targets.
.PHONY: riscv_help
riscv_help:
	@echo
	@echo "SCHOLAR RISC-V — local project helper"
	@echo "Usage: make <target>"
	@echo
	@printf "Targets:\n"
	@printf "  %-35s %s\n" "riscv_documentation"       "Generate the project code documentation."
	@printf "  %-35s %s\n" "clean_riscv_documentation" "Clean the generated project code documentation."
	@printf "  %-35s %s\n" "riscv_format"              "Format project HDL and C/C++ source files."
	@printf "  %-35s %s\n" "riscv_lint"                "Lint project HDL source files."
	@echo

# Generate the project code documentation.
.PHONY: riscv_documentation
riscv_documentation:
	@doxygen $(ROOT_DIR)docs/Doxyfile

# Clean the generated project code documentation.
.PHONY: clean_riscv_documentation
clean_riscv_documentation:
	@rm -rf $(ROOT_DIR)docs/doxygen
	@rm -f $(ROOT_DIR)docs/doxygen.warnings

# Format project HDL and C/C++ source files.
.PHONY: riscv_format
riscv_format:
	@bash $(SV_TOOLS_DIR)format_hdl.sh $(ROOT_DIR)

# Lint project HDL source files.
.PHONY: riscv_lint
riscv_lint:
	@bash $(SV_TOOLS_DIR)lint.sh $(ROOT_DIR)

####################################                 ####################################

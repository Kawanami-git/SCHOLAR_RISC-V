# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       common.mk
# \brief      Common variables and helper targets for SCHOLAR RISC-V.
# \author     Kawanami
# \version    1.0
# \date       15/04/2026
#
# \details
#   This Makefile fragment contains the variables, file lists, and helper targets
#   shared across the different SCHOLAR RISC-V flows.
#
#   It provides:
#     - architecture-related parameters
#     - common project directories
#     - shared RTL, firmware, and platform file lists
#     - firmware build helper targets
#     - generic utility targets such as firmware build, UART transfer,
#       minicom, documentation, formatting, and linting
#
#   This file is intended to be included by the top-level Makefile and by
#   platform-specific Makefile fragments.
#
# \remarks
#   - Requires Python 3 and a RISC-V cross-compilation toolchain.
#   - Some helper targets additionally require Doxygen, minicom, and the
#     repository utility scripts.
#   - Relies on variables defined by the including Makefile, such as `ROOT_DIR`.
#   - See `make help` for a summary of available targets and variables.
#
# \section common_mk_version_history Version history
# | Version | Date       | Author   | Description                                |
# |:-------:|:----------:|:---------|:-------------------------------------------|
# | 1.0     | 15/04/2026 | Kawanami | Initial split from the top-level Makefile. |
# ********************************************************************************
# */

#################################### Architecture parameters ###################################
# Target architecture selection
XLEN 							              ?= XLEN32

ifeq ($(XLEN),XLEN32)
CPU_XLEN						            ?= 32
ISA 							              := rv32i_zicntr
ABI								              := ilp32
else ifeq ($(XLEN),XLEN64)
CPU_XLEN						            ?= 64
ISA 							              := rv64i_zicntr
ABI								              := lp64
endif

# Select whether the simulation/model uses a perfect memory
PERFECT_MEMORY					        ?= YES
ifeq ($(PERFECT_MEMORY)ss,YES)
NOT_PERFECT_MEMORY				      = "1'b0"
else
NOT_PERFECT_MEMORY				      = "1'b1"
endif
####################################						###################################

#################################### Directories ####################################
# Hardware directory
HW_DIR 							            = $(ROOT_DIR)hardware/

# Design under test environment directory
DUT_DIR		        	            = $(HW_DIR)core/

# Design under test environement directory
ENV_FILES_DIR				            = $(HW_DIR)env/

# Software directory (contains platform & firmware directories)
SOFTWARE_DIR				            = $(ROOT_DIR)software/

# Firmware directory
FIRMWARE_DIR 				            = $(SOFTWARE_DIR)firmware/

# ISA YAML directory
ISA_YAML_DIR   			            = $(FIRMWARE_DIR)isa/

# LOADER firmware directory
LOADER_DIR   				            = $(FIRMWARE_DIR)loader/

# ECHO firmware directory
ECHO_DIR   					            = $(FIRMWARE_DIR)echo/

# CYCLEMARK firmware directory
CYCLEMARK_DIR   		            = $(FIRMWARE_DIR)cyclemark/

# Platform directory shared between simulation and hardware board flows.
PLATFORM_DIR 				            = $(SOFTWARE_DIR)/platform/

# Working directory
WORK_DIR                        = $(ROOT_DIR)work/

# Firmware working directory
FIRMWARE_WORK_DIR		            = $(WORK_DIR)firmware/

# Firmware build directory
FIRMWARE_BUILD_DIR 	            = $(FIRMWARE_WORK_DIR)build/

# Firmware build log directory
FIRMWARE_LOG_DIR 		            = $(FIRMWARE_WORK_DIR)log/
#################################### 			 ####################################

#################################### Hardware Files ####################################
# Common RTL files shared across the different build flows
COMMON_RTL_FILES					      = $(HW_DIR)common/target_pkg.sv

# RTL files of the SCHOLAR RISC-V core
DUT_FILES						            = $(DUT_DIR)common/core_pkg.sv \
								                  $(DUT_DIR)scholar_riscv_core.sv \
								                  $(DUT_DIR)gpr/gpr.sv \
								                  $(DUT_DIR)csr/csr.sv \
								                  $(DUT_DIR)fetch/fetch.sv \
								                  $(DUT_DIR)decode/decode.sv \
								                  $(DUT_DIR)exe/exe.sv \
								                  $(DUT_DIR)writeback/writeback.sv


# Design under test environment files
ENV_FILES 						          = $(ENV_FILES_DIR)dpram.sv \
								                  $(ENV_FILES_DIR)microchip/dpram_64w.sv \
								                  $(ENV_FILES_DIR)microchip/dpram_32w.sv \
								                  $(ENV_FILES_DIR)microchip/dpram_40x1024.sv \
								                  $(ENV_FILES_DIR)microchip/dpram_20x1024.sv \
						    	                $(ENV_FILES_DIR)sys_reset.sv \
						    	                $(ENV_FILES_DIR)waxi_dpram.sv \
						    	                $(ENV_FILES_DIR)raxi_dpram.sv \
						    	                $(ENV_FILES_DIR)bus_fabric.sv \
						    	                $(ENV_FILES_DIR)riscv_env.sv

# Top-level module used for simulation
TOP								              = riscv_env
#################################### 	   ####################################

#################################### Software Files ####################################
# Common firmware source files
COMMON_FILES			              = $(FIRMWARE_DIR)common/eprintf.c \
						                      $(FIRMWARE_DIR)common/memory.c \
						                      $(FIRMWARE_DIR)common/start.S

# Loader firmware source files
LOADER_FILES 					          = $(LOADER_DIR)main.c

# Echo firmware source files
ECHO_FILES 						          = $(ECHO_DIR)main.c

# Cyclemark firmware source files
CYCLEMARK_FILES 				        = $(CYCLEMARK_DIR)core_list_join.c \
								                  $(CYCLEMARK_DIR)core_main.c \
								                  $(CYCLEMARK_DIR)core_matrix.c \
								                  $(CYCLEMARK_DIR)core_portme.c \
								                  $(CYCLEMARK_DIR)core_state.c \
								                  $(CYCLEMARK_DIR)core_util.c

# Firmware linker script
LINKER                          ?= $(FIRMWARE_DIR)linker/linker.ld

# Common platform-side C++ source files
PLATFORM_FILES					        = $(PLATFORM_DIR)args_parser.cpp \
								                  $(PLATFORM_DIR)axi4.cpp \
								                  $(PLATFORM_DIR)log.cpp \
								                  $(PLATFORM_DIR)memory.cpp \
								                  $(PLATFORM_DIR)load.cpp \
								                  $(PLATFORM_DIR)platform.cpp
#################################### 	   ####################################

#################################### Firmware Toolchain ###################################
# Path to the RISC-V GCC binary directory
EGCC_DIR		  	                ?= /opt/riscv-gnu-toolchain/$(ISA)/bin/

# RISC-V C compiler
ECC 					                  ?= $(EGCC_DIR)riscv$(CPU_XLEN)-unknown-elf-gcc

# RISC-V linker
ELD						                  ?= $(EGCC_DIR)riscv$(CPU_XLEN)-unknown-elf-ld

# RISC-V objdump
EOBJDUMP				                ?= $(EGCC_DIR)riscv$(CPU_XLEN)-unknown-elf-objdump

# RISC-V objcopy
EOBJCOPY				                ?= $(EGCC_DIR)riscv$(CPU_XLEN)-unknown-elf-objcopy

# Path to the libgcc directory
ELIBGCC_DIR 		                ?= /opt/riscv-gnu-toolchain/$(ISA)/lib/gcc/riscv$(CPU_XLEN)-unknown-elf/14.2.0/

# Static libgcc archive
ELGCC					                  ?= $(ELIBGCC_DIR)libgcc.a

# Directory containing firmware helper scripts
TOOLS_DIR  			                ?= $(ROOT_DIR)scripts/

# ELF-to-HEX conversion script
MAKE_HEX				                ?= $(TOOLS_DIR)makehex.py

# Select whether Spike-specific firmware options are enabled
WITH_SPIKE			                ?= NO_SPIKE

# Number of iterations used by generated tests and benchmark firmware
ITERATIONS          			      ?= 1

# Firmware compiler flags
ECFLAGS  				                ?= -I$(FIRMWARE_DIR)common/ -I$(SOFTWARE_DIR) \
						                       -DITERATIONS=$(ITERATIONS) -D$(XLEN) -D$(WITH_SPIKE) \
                                   -march=$(ISA) -mabi=$(ABI) -Wall -nostdlib \
						                       -ffreestanding -O3 -ffunction-sections -fdata-sections

# Firmware linker flag
ELDFLAGS 				                ?= -T $(LINKER) -nostdlib -static --gc-sections
#################################### 	 				####################################

# Display help for simulation-related targets
.PHONY: common_help
common_help:
	@echo
	@echo "SCHOLAR RISC-V — simulation Makefile helper"
	@echo "Usage: make <target>"
	@echo
	@printf "Targets:\n"
	@printf "  %-35s %s\n" "clean_firmware"     "Clean the firmware working directory."
	@printf "  %-35s %s\n" "documentation" 			"Build the doxygen documentation."
	@printf "  %-35s %s\n" "format"    		      "Format HDL and software source files."
	@printf "  %-35s %s\n" "lint"    		        "Lint HDL files."
	@echo
	@printf "Key variables:\n"
	@echo
	@echo "Examples:"
	@echo "  make documentation"
	@echo "  make clean_firmware"
	@echo
	@echo

# Create the firmware working directories
.PHONY: firmware_work
firmware_work:
	@echo "➡️  Creating firmware working environment..."
	@mkdir -p $(FIRMWARE_BUILD_DIR)
	@mkdir -p $(FIRMWARE_LOG_DIR)
	@echo "✅ Done."
	@echo

# Build the selected firmware and generate ELF/BIN/DUMP/HEX outputs
.PHONY: firmware
firmware: firmware_work

	@echo "➡️  Building $(FIRMWARE) firmware..."

	@for source in $(FIRMWARE_FILES); do \
		echo $(ECC) $(ECFLAGS) -c $$source -o $(FIRMWARE_BUILD_DIR)$$(basename $$source .c).o >> $(FIRMWARE_LOG_DIR)log.txt; \
		echo "" >> $(FIRMWARE_LOG_DIR)log.txt; \
		$(ECC) $(ECFLAGS) -c $$source -o $(FIRMWARE_BUILD_DIR)$$(basename $$source .c).o; \
	done
	@for source in $(COMMON_FILES); do \
		echo $(ECC) $(ECFLAGS) -c $$source -o $(FIRMWARE_BUILD_DIR)$$(basename $$source .c).o >> $(FIRMWARE_LOG_DIR)log.txt; \
		echo "" >> $(FIRMWARE_LOG_DIR)log.txt; \
		$(ECC) $(ECFLAGS) -c $$source -o $(FIRMWARE_BUILD_DIR)$$(basename $$source .c).o; \
	done

	@echo $(ELD) $(ELDFLAGS) $(FIRMWARE_BUILD_DIR)*.o $(ELGCC) -o $(FIRMWARE_BUILD_DIR)$(FIRMWARE).elf >> $(FIRMWARE_LOG_DIR)log.txt
	@echo "" >> $(FIRMWARE_LOG_DIR)log.txt
	@$(ELD) $(ELDFLAGS) $(FIRMWARE_BUILD_DIR)*.o $(ELGCC) -o $(FIRMWARE_BUILD_DIR)$(FIRMWARE).elf

	@rm -rf $(FIRMWARE_BUILD_DIR)*.o

	@echo $(EOBJCOPY) -O binary $(FIRMWARE_BUILD_DIR)$(FIRMWARE).elf $(FIRMWARE_BUILD_DIR)$(FIRMWARE).bin >> $(FIRMWARE_LOG_DIR)log.txt
	@echo "" >> $(FIRMWARE_LOG_DIR)log.txt
	@$(EOBJCOPY) -O binary $(FIRMWARE_BUILD_DIR)$(FIRMWARE).elf $(FIRMWARE_BUILD_DIR)$(FIRMWARE).bin

	@echo "$(EOBJDUMP) -D $(FIRMWARE_BUILD_DIR)$(FIRMWARE).elf > $(FIRMWARE_BUILD_DIR)$(FIRMWARE).dump" >> $(FIRMWARE_LOG_DIR)log.txt
	@echo "" >> $(FIRMWARE_LOG_DIR)log.txt
	@$(EOBJDUMP) -D $(FIRMWARE_BUILD_DIR)$(FIRMWARE).elf > $(FIRMWARE_BUILD_DIR)$(FIRMWARE).dump

	@echo "python3 $(MAKE_HEX) $(FIRMWARE_BUILD_DIR)$(FIRMWARE).elf > $(FIRMWARE_BUILD_DIR)$(FIRMWARE).hex" >> $(FIRMWARE_LOG_DIR)log.txt
	@echo "" >> $(FIRMWARE_LOG_DIR)log.txt
	@python3 $(MAKE_HEX) $(FIRMWARE_BUILD_DIR)$(FIRMWARE).elf > $(FIRMWARE_BUILD_DIR)$(FIRMWARE).hex

	@echo "" >> $(FIRMWARE_LOG_DIR)log.txt

	@echo "✅ Done."
	@echo

# Build the loader firmware
.PHONY: loader_firmware
loader_firmware: FIRMWARE_FILES=$(LOADER_FILES)
loader_firmware: FIRMWARE=loader
loader_firmware: firmware

# Build the echo firmware
.PHONY: echo_firmware
echo_firmware: FIRMWARE_FILES=$(ECHO_FILES)
echo_firmware: FIRMWARE=echo
echo_firmware: firmware

# Build the cyclemark firmware
.PHONY: cyclemark_firmware
cyclemark_firmware: FIRMWARE_FILES=$(CYCLEMARK_FILES)
cyclemark_firmware: FIRMWARE=cyclemark
cyclemark_firmware: firmware

# Clean the firmware directory
.PHONY: clean_firmware
clean_firmware:
	@echo "➡️  Cleaning firmware directory..."
	@rm -rf $(FIRMWARE_WORK_DIR)
	@echo "✅ Done."

# Send a file to the target through the serial link
.PHONY: uart_ft
uart_ft:
	@sudo python3 scripts/uart_ft.py \
		--dev "$(TTY)" --baud $(TTY_BAUDRATE) \
		--login --user root \
		--dest-dir "$(UART_DEST_DIR)" \
		--file "$(UART_FILE)"

# Generate the documentation from the board perspective
.PHONY: documentation
documentation:
	@doxygen ./scripts/Doxyfile

# Format HDL and C/C++ source files
.PHONY: format
format:
	@bash -c "scripts/format_hdl.sh"
	@bash -c "scripts/format_cxx.sh"

# Lint HDL source files
.PHONY: lint
lint:
	@bash -c "scripts/lint.sh"

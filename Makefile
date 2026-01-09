# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       Makefile
# \brief      Top-level build & run orchestration for SCHOLAR RISC-V.
# \author     Kawanami
# \version    1.0
# \date       19/12/2025
#
# \details
#   Drives the complete flow:
#     - Firmware generation (ISA YAML → .s) and build (ELF/BIN/DUMP/HEX)
#     - Verilator DUT build and simulation (optionally vs Spike)
#     - MPFS Discovery Kit utilities (bitstream, HSS, Linux images)
#     - Documentation, formatting, linting, and cleanup helpers
#
#   Main flows:
#     - `make isa`         : Build DUT, generate & build all ISA firmwares, run sim vs Spike
#     - `make loader`      : Build & run the loader firmware on the simulator
#     - `make echo`        : Build & run the echo firmware on the simulator
#     - `make cyclemark`   : Build & run the cyclemark firmware on the simulator
#     - `make documentation` / `make sim_documentation` (with PREDEFINED=SIM)
#
#   Key variables:
#     - XLEN={XLEN32|XLEN64} selects RV32I_Zicntr or RV64I_Zicntr (default: XLEN64)
#     - WORK_DIR / *_WORK_DIR control build & log output paths
#     - VERILATOR_DIR / SPIKE_DIR point to tools
#
# \remarks
#   - Requires Verilator, Spike, Python 3 and a RISC-V toolchain for firmware builds.
#   - See `make help` for a friendly summary of targets and variables.
#
# \section makefile_toplevel_version_history Version history
# | Version | Date       | Author     | Description         |
# |:-------:|:----------:|:-----------|:--------------------|
# | 1.0     | 19/12/2025 | Kawanami   | Initial version.    |
# ********************************************************************************
# */


#################################### Architecture parameters ###################################
XLEN 							?= XLEN32

ifeq ($(XLEN),XLEN32)
CPU_XLEN						?= 32
ISA 							:= rv32i_zicntr
ABI								:= ilp32
else ifeq ($(XLEN),XLEN64)
CPU_XLEN						?= 64
ISA 							:= rv64i_zicntr
ABI								:= lp64
endif

TTYUSB							?= /dev/ttyUSB0
####################################						###################################





#################################### Directories ####################################
# Root directory
ROOT_DIR						= $(CURDIR)/

# Hardware directory
HW_DIR 							= $(ROOT_DIR)hardware/

# Design under test directory
DUT_DIR		        			= $(HW_DIR)core/

# Design under test environement directory
ENV_FILES_DIR					= $(HW_DIR)env/

# Software directory (contains platform & firmware directories)
SOFTWARE_DIR					= $(ROOT_DIR)software/

# Firmware directory
FIRMWARE_DIR 					= $(SOFTWARE_DIR)firmware/

# ISA YAML directory
ISA_YAML_DIR   					= $(FIRMWARE_DIR)isa/

# LOADER firmware directory
LOADER_DIR   					= $(FIRMWARE_DIR)loader/

# ECHO firmware directory
ECHO_DIR   						= $(FIRMWARE_DIR)echo/

# CYCLEMARK firmware directory
CYCLEMARK_DIR   				= $(FIRMWARE_DIR)cyclemark/

# Platform directory (common directory between simulation and Polarfire SoC-FPGA boards)
PLATFORM_DIR 					= $(SOFTWARE_DIR)/platform/

# Simulation files directory
SIM_FILES_DIR       			= $(ROOT_DIR)simulation/

# Spike directory
SPIKE_DIR           			= /opt/spike/bin/

# Verilator directory
VERILATOR_DIR       			= /opt/verilator/bin/

# Working directory
WORK_DIR            			= $(ROOT_DIR)work/

# Firmware working directory
FIRMWARE_WORK_DIR				= $(WORK_DIR)firmware/

# Firmware build directory
FIRMWARE_BUILD_DIR 				= $(FIRMWARE_WORK_DIR)build/

# Firmware build log directory
FIRMWARE_LOG_DIR 				= $(FIRMWARE_WORK_DIR)log/

# Verilator work directory
VERILATOR_WORK_DIR 				= $(WORK_DIR)verilator/

# Verilator build directory
VERILATOR_BUILD_DIR  			= $(VERILATOR_WORK_DIR)build/

# Verilator build log directory
VERILATOR_LOG_DIR  				= $(VERILATOR_WORK_DIR)log/

# Simulation log directory
SIM_LOG_DIR						= $(WORK_DIR)simulation/

# MPFS DISCOVERY KIT root directory
MPFS_DISCO_KIT_ROOT_DIR 		= MPFS_DISCOVERY_KIT/

# MPFS DISCOVERY KIT scripts directory
MPFS_DISCO_KIT_SCRIPTS_DIR  	= $(MPFS_DISCO_KIT_ROOT_DIR)scripts/

# MPFS DISCOVERY KIT HSS directory
MPFS_DISCO_KIT_HSS_DIR  		= $(MPFS_DISCO_KIT_ROOT_DIR)HSS/

# MPFS DISCOVERY KIT FPGA directory
MPFS_DISCO_KIT_FPGA_DIR 		= $(MPFS_DISCO_KIT_ROOT_DIR)FPGA/

# MPFS DISCOVERY KIT Linux directory
MPFS_DISCO_KIT_LINUX_DIR		= $(MPFS_DISCO_KIT_ROOT_DIR)Linux/

# MPFS DISCOVERY KIT yocto directory
MPFS_DISCO_KIT_YOCTO_DIR		= $(MPFS_DISCO_KIT_LINUX_DIR)meta-mchp/

# MPFS DISCOVERY KIT meta files directory
MPFS_DISCO_KIT_LAYER_DIR		= $(MPFS_DISCO_KIT_LINUX_DIR)meta-scholar-risc-v/

# MPFS_DISCOVERY_KIT board directory
MPFS_DISCO_KIT_BOARD			= $(WORK_DIR)board/
#################################### 			 ####################################





#################################### Files ####################################
# Design under test files
DUT_FILES						= $(DUT_DIR)common/core_pkg.sv \
								  $(DUT_DIR)common/if2id_pkg.sv\
								  $(DUT_DIR)common/id2exe_pkg.sv\
								  $(DUT_DIR)common/exe2mem_pkg.sv\
								  $(DUT_DIR)common/exe2pc_pkg.sv\
								  $(DUT_DIR)common/mem2wb_pkg.sv\
								  $(DUT_DIR)scholar_riscv_core.sv \
								  $(DUT_DIR)ctrl/ctrl.sv \
								  $(DUT_DIR)ctrl/pc.sv \
								  $(DUT_DIR)gpr/gpr.sv \
								  $(DUT_DIR)csr/csr.sv \
								  $(DUT_DIR)fetch/fetch.sv \
								  $(DUT_DIR)decode/decode.sv \
								  $(DUT_DIR)decode/decode_unit.sv \
								  $(DUT_DIR)exe/exe.sv \
								  $(DUT_DIR)exe/alu.sv \
								  $(DUT_DIR)mem/mem.sv \
								  $(DUT_DIR)mem/mem_unit.sv \
								  $(DUT_DIR)writeback/writeback.sv \
								  $(DUT_DIR)writeback/writeback_unit.sv


# Design under test environment files
ENV_FILES 						= $(ENV_FILES_DIR)dpram.sv \
								  $(ENV_FILES_DIR)dpram_64w.sv \
								  $(ENV_FILES_DIR)dpram_32w.sv \
								  $(ENV_FILES_DIR)microchip/dpram_40x1024.sv \
								  $(ENV_FILES_DIR)microchip/dpram_20x1024.sv \
						    	  $(ENV_FILES_DIR)waxi_dpram.sv \
						    	  $(ENV_FILES_DIR)raxi_dpram.sv \
						    	  $(ENV_FILES_DIR)bus_fabric.sv \
						    	  $(ENV_FILES_DIR)riscv_env.sv

# TOP file to simulate
TOP								= riscv_env

# LOADER firmware files
LOADER_FILES 					= $(LOADER_DIR)main.c

# ECHO firmware files
ECHO_FILES 						= $(ECHO_DIR)main.c

# CYCLEMARK firmware files
CYCLEMARK_FILES 				= "$(CYCLEMARK_DIR)core_list_join.c \
								  $(CYCLEMARK_DIR)core_main.c \
								  $(CYCLEMARK_DIR)core_matrix.c \
								  $(CYCLEMARK_DIR)core_portme.c \
								  $(CYCLEMARK_DIR)core_state.c \
								  $(CYCLEMARK_DIR)core_util.c"

# Firmware Linker file
LINKER=$(FIRMWARE_DIR)linker/linker.ld

# Platform common files
PLATFORM_FILES					= $(PLATFORM_DIR)args_parser.cpp \
								  $(PLATFORM_DIR)axi4.cpp \
								  $(PLATFORM_DIR)log.cpp \
								  $(PLATFORM_DIR)memory.cpp \
								  $(PLATFORM_DIR)load.cpp \
								  $(PLATFORM_DIR)platform.cpp

# Common simulation files
COMMON_SIM_FILES 				= $(SIM_FILES_DIR)clocks_resets.cpp \
								  $(SIM_FILES_DIR)sim_log.cpp \
								  $(SIM_FILES_DIR)sim.cpp

# Simulation vs spike (to run ISA tests)
SIM_VS_SPIKE 					= $(SIM_FILES_DIR)spike_parser.cpp \
								  $(SIM_FILES_DIR)simulation_vs_spike.cpp

# Simulation (to run custom firmware)
SIM 							:= $(SIM_FILES_DIR)simulation.cpp

# Verilator build log file
VERILATOR_LOG_FILE				= $(VERILATOR_LOG_DIR)log.txt

# Simulation log file
SIM_LOG_FILE					= $(SIM_LOG_DIR)log.txt
#################################### 	   ####################################





#################################### Tools & simulation ####################################
# Spike software
SPIKE							= $(SPIKE_DIR)spike

# Spike flags
SPIKE_FLAGS						= -m2 --isa=$(ISA) -l --log-commits

# Verilator binary
SIMULATOR						= $(VERILATOR_DIR)verilator

# Verilator hardware flags
SIM_FLAGS						= -j $(shell nproc) -D$(XLEN) -DSIM \
								  -I$(DUT_DIR)common/ \
								  --Wno-TIMESCALEMOD -O3 --threads 4 --unroll-count 5120

# Verilator software flags
SIM_CXXFLAGS					= "-O3 -DSIM -D$(XLEN) -DMAX_CYCLES=$(MAX_CYCLES) \
								   -I$(VERILATOR_BUILD_DIR) -I$(SOFTWARE_DIR) \
								   -I$(PLATFORM_DIR) -I$(SIM_FILES_DIR)"

# Maximum number of cycles for the simulation. As core is running at 1MHz, it corresponds to three seconds of simulation.
MAX_CYCLES          			= 10000000

# Parameters used when building the firmware. It can be used, as exemple, to choose the number of iteraton of the CycleMark algorithm.
ITERATIONS          			= 1
#################################### 	   				####################################





#################################### ISA Simulation parameters ####################################


# Firmware generators program name (used to generate one firmware per instruction)
ISA_FIRMWARE_GENERATOR			= $(ROOT_DIR)scripts/gen_isa.py

# ISA firmware files
ifeq ($(XLEN),XLEN32)
ISA_YAML_FILES					= $(ISA_YAML_DIR)i/u_instr/lui.yaml \
								  $(ISA_YAML_DIR)i/u_instr/auipc.yaml \
								  $(ISA_YAML_DIR)i/i_instr/addi.yaml \
								  $(ISA_YAML_DIR)i/i_instr/andi.yaml \
								  $(ISA_YAML_DIR)i/i_instr/ori.yaml \
								  $(ISA_YAML_DIR)i/i_instr/xori.yaml \
								  $(ISA_YAML_DIR)i/i_instr/slli.yaml \
								  $(ISA_YAML_DIR)i/i_instr/srai.yaml \
								  $(ISA_YAML_DIR)i/i_instr/srli.yaml \
								  $(ISA_YAML_DIR)i/i_instr/slti.yaml \
								  $(ISA_YAML_DIR)i/i_instr/sltiu.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lb.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lbu.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lh.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lhu.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lw.yaml \
								  $(ISA_YAML_DIR)i/i_instr/jalr.yaml \
								  $(ISA_YAML_DIR)i/b_instr/beq.yaml \
								  $(ISA_YAML_DIR)i/b_instr/bne.yaml \
								  $(ISA_YAML_DIR)i/b_instr/bge.yaml \
								  $(ISA_YAML_DIR)i/b_instr/bgeu.yaml \
								  $(ISA_YAML_DIR)i/b_instr/blt.yaml \
								  $(ISA_YAML_DIR)i/b_instr/bltu.yaml \
								  $(ISA_YAML_DIR)i/s_instr/sb.yaml \
								  $(ISA_YAML_DIR)i/s_instr/sh.yaml \
								  $(ISA_YAML_DIR)i/s_instr/sw.yaml \
								  $(ISA_YAML_DIR)i/r_instr/add.yaml \
								  $(ISA_YAML_DIR)i/r_instr/sub.yaml \
								  $(ISA_YAML_DIR)i/r_instr/and.yaml \
								  $(ISA_YAML_DIR)i/r_instr/or.yaml \
								  $(ISA_YAML_DIR)i/r_instr/xor.yaml \
								  $(ISA_YAML_DIR)i/r_instr/sll.yaml \
								  $(ISA_YAML_DIR)i/r_instr/slt.yaml \
								  $(ISA_YAML_DIR)i/r_instr/sltu.yaml \
								  $(ISA_YAML_DIR)i/r_instr/sra.yaml \
								  $(ISA_YAML_DIR)i/r_instr/srl.yaml \
								  $(ISA_YAML_DIR)i/j_instr/jal.yaml \
								  $(ISA_YAML_DIR)Zicntr_instr/mhpmcounter0.yaml \
								  $(ISA_YAML_DIR)Zicntr_instr/mhpmcounter3.yaml \
								  $(ISA_YAML_DIR)Zicntr_instr/mhpmcounter4.yaml

else ifeq ($(XLEN),XLEN64)
ISA_YAML_FILES					= $(ISA_YAML_DIR)i/u_instr/lui.yaml \
								  $(ISA_YAML_DIR)i/u_instr/auipc.yaml \
								  $(ISA_YAML_DIR)i/i_instr/addi.yaml \
								  $(ISA_YAML_DIR)i/i_instr/addiw.yaml \
								  $(ISA_YAML_DIR)i/i_instr/andi.yaml \
								  $(ISA_YAML_DIR)i/i_instr/ori.yaml \
								  $(ISA_YAML_DIR)i/i_instr/xori.yaml \
								  $(ISA_YAML_DIR)i/i_instr/slli.yaml \
								  $(ISA_YAML_DIR)i/i_instr/slliw.yaml \
								  $(ISA_YAML_DIR)i/i_instr/srai.yaml \
								  $(ISA_YAML_DIR)i/i_instr/sraiw.yaml \
								  $(ISA_YAML_DIR)i/i_instr/srli.yaml \
								  $(ISA_YAML_DIR)i/i_instr/srliw.yaml \
								  $(ISA_YAML_DIR)i/i_instr/slti.yaml \
								  $(ISA_YAML_DIR)i/i_instr/sltiu.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lb.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lbu.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lh.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lhu.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lw.yaml \
								  $(ISA_YAML_DIR)i/i_instr/lwu.yaml \
								  $(ISA_YAML_DIR)i/i_instr/ld.yaml \
								  $(ISA_YAML_DIR)i/i_instr/jalr.yaml \
								  $(ISA_YAML_DIR)i/b_instr/beq.yaml \
								  $(ISA_YAML_DIR)i/b_instr/bne.yaml \
								  $(ISA_YAML_DIR)i/b_instr/bge.yaml \
								  $(ISA_YAML_DIR)i/b_instr/bgeu.yaml \
								  $(ISA_YAML_DIR)i/b_instr/blt.yaml \
								  $(ISA_YAML_DIR)i/b_instr/bltu.yaml \
								  $(ISA_YAML_DIR)i/s_instr/sb.yaml \
								  $(ISA_YAML_DIR)i/s_instr/sh.yaml \
								  $(ISA_YAML_DIR)i/s_instr/sw.yaml \
								  $(ISA_YAML_DIR)i/s_instr/sd.yaml \
								  $(ISA_YAML_DIR)i/r_instr/add.yaml \
								  $(ISA_YAML_DIR)i/r_instr/addw.yaml \
								  $(ISA_YAML_DIR)i/r_instr/sub.yaml \
								  $(ISA_YAML_DIR)i/r_instr/subw.yaml \
								  $(ISA_YAML_DIR)i/r_instr/and.yaml \
								  $(ISA_YAML_DIR)i/r_instr/or.yaml \
								  $(ISA_YAML_DIR)i/r_instr/xor.yaml \
								  $(ISA_YAML_DIR)i/r_instr/sll.yaml \
								  $(ISA_YAML_DIR)i/r_instr/sllw.yaml \
								  $(ISA_YAML_DIR)i/r_instr/slt.yaml \
								  $(ISA_YAML_DIR)i/r_instr/sltu.yaml \
								  $(ISA_YAML_DIR)i/r_instr/sra.yaml \
								  $(ISA_YAML_DIR)i/r_instr/sraw.yaml \
								  $(ISA_YAML_DIR)i/r_instr/srl.yaml \
								  $(ISA_YAML_DIR)i/r_instr/srlw.yaml \
								  $(ISA_YAML_DIR)i/j_instr/jal.yaml \
								  $(ISA_YAML_DIR)Zicntr_instr/mhpmcounter0.yaml \
								  $(ISA_YAML_DIR)Zicntr_instr/mhpmcounter3.yaml \
								  $(ISA_YAML_DIR)Zicntr_instr/mhpmcounter4.yaml

endif
#################################### 						   ####################################





#################################### MPFS DISCOVERY KIT ####################################
MPFS_DISCO_KIT_LINUX_LINK=https://github.com/Kawanami-git/MPFS_DISCOVERY_KIT/releases/download/2025-11-04/core-image-custom-mpfs-disco-kit.rootfs-20251104145941.wic
MPFS_DISCO_KIT_SDK_LINK=https://github.com/Kawanami-git/MPFS_DISCOVERY_KIT/releases/download/2025-11-04/sdk.zip

# Environnement for MPFS_DISCOVERY_KIT cross-compilation
SDK_ENV ?= $(WORK_DIR)$(MPFS_DISCO_KIT_LINUX_DIR)sdk/environment-setup-riscv64-oe-linux

SDK_BIN ?= $(WORK_DIR)$(MPFS_DISCO_KIT_LINUX_DIR)sdk/sysroots/riscv64-oe-linux/bin/

# Helper to activate the MPFS_DISCOVERY_KIT environment before running the build
define SDK_RUN
bash -lc 'source "$(SDK_ENV)"; export PATH="$$PATH:$(SDK_BIN)"; $(1)'
endef
####################################					####################################





#################################### TARGETS ####################################
# Default target
default: help





# User helper
.PHONY: help
help:
	@echo
	@echo "SCHOLAR RISC-V — top-level Makefile helper"
	@echo "Usage: make <target> [XLEN=XLEN32|XLEN64] [ITERATIONS=N] [MAX_CYCLES=N]"
	@echo
	@printf "Common targets:\n"
	@printf "  %-35s %s\n" "isa"                  				"Run the ISA tests"
	@printf "  %-35s %s\n" "loader" 				  			"Build & run the loader test"
	@printf "  %-35s %s\n" "echo" 				  				"Build & run the echo test"
	@printf "  %-35s %s\n" "cyclemark" 			  				"Build & run the cyclemark test"
	@printf "  %-35s %s\n" "documentation"        				"Doxygen (board perspective)"
	@printf "  %-35s %s\n" "sim_documentation"    				"Doxygen (simulation perspective)"
	@printf "  %-35s %s\n" "format"               				"Format HDL & C/C++ sources"
	@printf "  %-35s %s\n" "lint"                 				"Lint HDL"
	@printf "  %-35s %s\n" "clean | clean_all"    				"Clean work dirs / purge work directory"
	@printf "  %-35s %s\n" "mpfs_disco_kit_license"				"Activate Microchip License"
	@printf "  %-35s %s\n" "mpfs_disco_kit_bitstream"   		"Build the bitstream for the MPFS DISCO KIT"
	@printf "  %-35s %s\n" "mpfs_disco_kit_program_bitstream"   "Program the bitstream in the MPFS DISCO KIT"
	@printf "  %-35s %s\n" "mpfs_disco_kit_hss"   				"Build the First Stage Bootoader for the MPFS DISCO KIT"
	@printf "  %-35s %s\n" "mpfs_disco_kit_program_hss"   		"Program the HSS in the MPFS DISCO KIT"
	@printf "  %-35s %s\n" "mpfs_disco_kit_linux"   			"Build the Linux for the MPFS DISCO KIT"
	@printf "  %-35s %s\n" "mpfs_disco_kit_get_linux"   		"Retreive the Linux for the MPFS DISCO KIT"
	@printf "  %-35s %s\n" "mpfs_disco_kit_program_linux"   	"Program the Linux in the SD card"
	@printf "  %-35s %s\n" "mpfs_disco_kit_ssh_setup"   			"Setup the MPFS DISCO KIT with all the necessary files to run 'loader', 'echo' & 'cyclemark' on the board through ssh"
	@printf "  %-35s %s\n" "mpfs_disco_kit_usb_setup"   			"Setup the MPFS DISCO KIT with all the necessary files to run 'loader', 'echo' & 'cyclemark' on the board through usb"
	@printf "  %-35s %s\n" "mpfs_disco_kit_ssh"   				"Establish an SSH connection with the MPFS DISCO KIT"
	@printf "  %-35s %s\n" "mpfs_disco_kit_minicom"   			"Establish a serial connection with the MPFS DISCO KIT"
	@printf "  %-35s %s\n" "libero"               				"Launch Libero in the MPFS environment"
	@echo
	@printf "Key variables:\n"
	@printf "  %-35s %s\n" "XLEN"         "Architecture (32-bit or 64-bit). Default is 32."
	@printf "  %-35s %s\n" "ITERATIONS"   "Number of iterations for ISA tests ans Cyclemark. More iterations equals more reliable tests. Default is 1."
	@printf "  %-35s %s\n" "MAX_CYCLES"   "Max simulation cycles (default: 3000000 = 3s of simulation)"
	@echo
	@echo "Examples:"
	@echo "  make isa XLEN=XLEN32"
	@echo "  make cyclemark ITERATIONS=3"
	@echo "  make documentation"
	@echo "  make mpfs_disco_kit_usb_setup"
	@echo "  make mpfs_disco_kit_minicom"
	@echo





# work target
.PHONY: work
work:
	@echo "➡️  Creating working environment..."

	@mkdir -p $(WORK_DIR)
	@mkdir -p $(VERILATOR_BUILD_DIR)
	@mkdir -p $(VERILATOR_LOG_DIR)
	@mkdir -p $(FIRMWARE_BUILD_DIR)
	@mkdir -p $(FIRMWARE_LOG_DIR)
	@mkdir -p $(SIM_LOG_DIR)
	@mkdir -p $(MPFS_DISCO_KIT_BOARD)

	@echo "✅ Done."
	@echo





# ISA firmware target
.PHONY: isa_firmware
isa_firmware: work

	@echo "➡️  Building ISA firmware..."
	@for source in $(ISA_YAML_FILES); do \
		base=$$(basename "$$source" .yaml); \
		echo Building $$(basename $$source .yaml)...; \
		python3 $(ISA_FIRMWARE_GENERATOR) --yaml $$source --archi $(XLEN) --iteration $(ITERATIONS) --out $(FIRMWARE_BUILD_DIR)/$$(basename $$source .yaml).s; \
		if [ -f "$(FIRMWARE_BUILD_DIR)/$$(basename $$source .yaml).s" ]; then \
			make -f $(FIRMWARE_DIR)Makefile \
			ROOT_DIR=$(FIRMWARE_DIR) \
			XLEN=$(XLEN) \
			CPU_XLEN=$(CPU_XLEN) \
			ABI=$(ABI) \
			ISA=$(ISA) \
			WORK_DIR=$(WORK_DIR) \
			GLOBAL_DEFINES_DIR=$(SOFTWARE_DIR) \
			FIRMWARE_FILES=$(FIRMWARE_BUILD_DIR)/$$(basename $$source .yaml).s \
			COMMON_FILES=" " \
			LINKER=$(FIRMWARE_DIR)linker/linker_ISA.ld \
			BUILD_DIR=$(FIRMWARE_BUILD_DIR) \
			LOG_DIR=$(FIRMWARE_LOG_DIR) \
			FIRMWARE=$$(basename $$source .yaml); \
			$(SPIKE) $(SPIKE_FLAGS) --log=$(FIRMWARE_BUILD_DIR)$$base.spike $(FIRMWARE_BUILD_DIR)$$base.elf; \
		fi; \
		echo $$(basename $$source .yaml) build done; \
		echo; \
	done >> $(FIRMWARE_LOG_DIR)log.txt

	@echo "✅ ISA firmware build done. See $(FIRMWARE_LOG_DIR)log.txt for details."
	@echo

# ISA target
.PHONY: isa
isa: SIM=$(SIM_VS_SPIKE)
isa: dut isa_firmware
isa:
	@for source in $(ISA_YAML_FILES); do \
		base=$$(basename "$$source" .yaml); \
		$(MAKE) run FIRMWARE=$$base; \
	done





# Firmware target
.PHONY: firmware
firmware: work

	@echo "➡️  Building $(FIRMWARE) firmware..."

	@make -f $(FIRMWARE_DIR)Makefile \
	ROOT_DIR=$(FIRMWARE_DIR) \
	XLEN=$(XLEN) \
	CPU_XLEN=$(CPU_XLEN) \
	ABI=$(ABI) \
	ISA=$(ISA) \
	WORK_DIR=$(WORK_DIR) \
	GLOBAL_DEFINES_DIR=$(SOFTWARE_DIR) \
	FIRMWARE_FILES=$(FIRMWARE_FILES) \
	LINKER=$(LINKER) \
	BUILD_DIR=$(FIRMWARE_BUILD_DIR) \
	LOG_DIR=$(FIRMWARE_LOG_DIR) \
	FIRMWARE=$(FIRMWARE) \
	ITERATIONS=$(ITERATIONS)

	@echo "✅ $(FIRMWARE) firmware build done. See $(FIRMWARE_LOG_DIR)log.txt for details."
	@echo





# Loader firmware target
.PHONY: loader_firmware
loader_firmware: work
loader_firmware: FIRMWARE_FILES=$(LOADER_FILES)
loader_firmware: FIRMWARE=loader
loader_firmware: firmware

# Loader target
.PHONY: loader
loader: FIRMWARE=loader
loader: dut loader_firmware
loader: run

# Echo firmware target
.PHONY: echo_firmware
echo_firmware: work
echo_firmware: FIRMWARE_FILES=$(ECHO_FILES)
echo_firmware: FIRMWARE=echo
echo_firmware: firmware

# Echo target
.PHONY: echo
echo: FIRMWARE=echo
echo: dut echo_firmware
echo: run





# Cyclemark firmware target
.PHONY: cyclemark_firmware
cyclemark_firmware: work
cyclemark_firmware: FIRMWARE_FILES=$(CYCLEMARK_FILES)
cyclemark_firmware: FIRMWARE=cyclemark
cyclemark_firmware: firmware

# cyclemark target
.PHONY: cyclemark
cyclemark: FIRMWARE=cyclemark
cyclemark: dut cyclemark_firmware
cyclemark: run



# DUT target (prepare the simulation)
.PHONY: dut
dut: work
	@echo "➡️  Building Design Under Test..."

	@echo $(SIMULATOR) $(SIM_FLAGS) -cc $(DUT_FILES) $(ENV_FILES) -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_FILES) > $(VERILATOR_LOG_DIR)log.txt

	@$(SIMULATOR) $(SIM_FLAGS) -cc $(DUT_FILES) $(ENV_FILES) -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_FILES) >> $(VERILATOR_LOG_DIR)log.txt

	@echo make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt

	@make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt
	@echo "✅ Done. See $(VERILATOR_LOG_DIR)log.txt for details."
	@echo

# Run target (run the simulation)
.PHONY: run
run:
	@echo "➡️  Running $(FIRMWARE) simulation..."
	@echo "➡️  Running $(FIRMWARE) simulation..." >> $(SIM_LOG_DIR)log.txt

	@echo $(VERILATOR_BUILD_DIR)V$(TOP) --logfile $(SIM_LOG_DIR)log.txt --waveform $(SIM_LOG_DIR)$(FIRMWARE).vcd \
	--firmware $(FIRMWARE_BUILD_DIR)$(FIRMWARE).hex --spike $(FIRMWARE_BUILD_DIR)$(FIRMWARE).spike >> $(SIM_LOG_DIR)log.txt

	@$(VERILATOR_BUILD_DIR)V$(TOP) --logfile $(SIM_LOG_DIR)log.txt --waveform $(SIM_LOG_DIR)$(FIRMWARE).vcd \
	--firmware $(FIRMWARE_BUILD_DIR)$(FIRMWARE).hex --spike $(FIRMWARE_BUILD_DIR)$(FIRMWARE).spike

	@echo "✅ Done." >> $(SIM_LOG_DIR)log.txt

	@echo >> $(SIM_LOG_DIR)log.txt
	@echo >> $(SIM_LOG_DIR)log.txt

	@echo "✅ Done. See $(SIM_LOG_DIR)log.txt for details."
	@echo
#################################### 		 ####################################





#################################### MPFS_DISCOVERY_KIT ####################################
# Activate Microchip License
.PHONY: mpfs_disco_kit_license
mpfs_disco_kit_license:
	@$(MPFS_DISCO_KIT_ROOT_DIR)/scripts/run_license_daemon.sh

#Send a file through serial com
.PHONY: uart_ft
uart_ft:
	@sudo python3 scripts/uart_ft.py \
		--dev "$(TTYUSB)" --baud 115200 \
		--login --user root \
		--dest-dir "$(UART_DEST_DIR)" \
		--file "$(UART_FILE)"


# MPFS_DISCO_KIT: Build the bitstream
.PHONY: mpfs_disco_kit_bitstream
mpfs_disco_kit_bitstream: work
	@echo "➡️  Running bitstream building script..."
	@echo
	@bash -c "source $(MPFS_DISCO_KIT_ROOT_DIR)/scripts/setup_microchip_tools.sh && \
	cd $(MPFS_DISCO_KIT_FPGA_DIR) && \
	libero SCRIPT:MPFS_DISCOVERY_KIT_DESIGN.tcl SCRIPT_ARGS:ARCHI:$(CPU_XLEN)"
	@echo "✅ Done."

# MPFS_DISCO_KIT: Program the bitstream
.PHONY: mpfs_disco_kit_program_bitstream
mpfs_disco_kit_program_bitstream: work
	@echo "➡️  Running bitstream building and programming script..."
	@echo
	@bash -lc 'export program=1; \
		source "$(MPFS_DISCO_KIT_ROOT_DIR)/scripts/setup_microchip_tools.sh"; \
		cd "$(MPFS_DISCO_KIT_FPGA_DIR)"; \
		libero SCRIPT:MPFS_DISCOVERY_KIT_DESIGN.tcl SCRIPT_ARGS:ARCHI:$(CPU_XLEN)'
	@echo "✅ Done."

# MPFS_DISCO_KIT: Clean the bitstream build
.PHONY: clean_mpfs_disco_kit_bitstream
clean_mpfs_disco_kit_bitstream:
	@echo "➡️  Cleaning bitstream directories..."
	@cd $(WORK_DIR) && rm -rf $(MPFS_DISCO_KIT_FPGA_DIR)
	@echo "✅ Done."

# MPFS_DISCO_KIT: Build the Hart Software Service (First Stage Bootloader)
.PHONY: mpfs_disco_kit_hss
mpfs_disco_kit_hss: work
	@echo "➡️  Running HSS building script..."
	@echo
	@bash $(MPFS_DISCO_KIT_SCRIPTS_DIR)build_hss.sh $(WORK_DIR) $(MPFS_DISCO_KIT_HSS_DIR) $(MPFS_DISCO_KIT_ROOT_DIR) $(MPFS_DISCO_KIT_SCRIPTS_DIR)
	@echo "✅ Done."

# MPFS_DISCO_KIT: Program the Hart Software Service
.PHONY: mpfs_disco_kit_program_hss
mpfs_disco_kit_program_hss: work
	@echo "➡️  Running HSS building and programming script..."
	@echo
	@bash $(MPFS_DISCO_KIT_SCRIPTS_DIR)build_hss.sh $(WORK_DIR) $(MPFS_DISCO_KIT_HSS_DIR) $(MPFS_DISCO_KIT_ROOT_DIR) $(MPFS_DISCO_KIT_SCRIPTS_DIR) program=1
	@echo "✅ Done."

# MPFS_DISCO_KIT: Clean the Hart Software Service clean
.PHONY: clean_mpfs_disco_kit_hss
clean_mpfs_disco_kit_hss:
	@echo "➡️  Cleaning HSS directories..."
	@cd $(WORK_DIR) && rm -rf $(MPFS_DISCO_KIT_HSS_DIR)
	@echo "✅ Done."

# MPFS_DISCO_KIT: Build the Linux
.PHONY: mpfs_disco_kit_linux
mpfs_disco_kit_linux: work
	@echo "➡️  Running Linux building script..."
	@echo
	@bash $(MPFS_DISCO_KIT_SCRIPTS_DIR)build_linux.sh $(WORK_DIR) $(MPFS_DISCO_KIT_LINUX_DIR) $(MPFS_DISCO_KIT_YOCTO_DIR) $(MPFS_DISCO_KIT_LAYER_DIR)
	@echo "✅ Done."

# Get Microchip Linux image and sdk
.PHONY: mpfs_disco_kit_get_linux
mpfs_disco_kit_get_linux: work
	@wget -P $(WORK_DIR)$(MPFS_DISCO_KIT_LINUX_DIR) $(MPFS_DISCO_KIT_LINUX_LINK)
	@wget -P $(WORK_DIR)$(MPFS_DISCO_KIT_LINUX_DIR) $(MPFS_DISCO_KIT_SDK_LINK)
	@unzip -d $(WORK_DIR)$(MPFS_DISCO_KIT_LINUX_DIR) $(WORK_DIR)$(MPFS_DISCO_KIT_LINUX_DIR)sdk.zip


# MPFS_DISCO_KIT: Program the Linux
.PHONY: mpfs_disco_kit_program_linux
mpfs_disco_kit_program_linux:
	@echo "➡️  Running Linux programming script..."
	@echo
ifdef path
	@bash $(MPFS_DISCO_KIT_SCRIPTS_DIR)program_linux.sh $(path)
else
	@bash $(MPFS_DISCO_KIT_SCRIPTS_DIR)program_linux.sh $(WORK_DIR)$(MPFS_DISCO_KIT_LINUX_DIR)core-image-custom-mpfs-disco-kit.rootfs-*.wic
endif
	@echo "✅ Done."

# MPFS_DISCO_KIT: Clean the Linux build
.PHONY: clean_mpfs_disco_kit_linux
clean_mpfs_disco_kit_linux:
	@echo "➡️  Cleaning Linux directories..."
	@cd $(WORK_DIR) && rm -rf $(MPFS_DISCO_KIT_YOCTO_DIR)
	@echo "✅ Done."

# MPFS_DISCO_KIT: Establish an SSH connection
.PHONY: mpfs_disco_kit_ssh
mpfs_disco_kit_ssh:
	@ssh root@192.168.7.2

# MPFS_DISCO_KIT: Build firmware & MSS application and send them through ssh
.PHONY: mpfs_disco_kit_ssh_setup
mpfs_disco_kit_ssh_setup: MPFS_DISCO_KIT_FIRMWARE_DIR:=$(patsubst $(WORK_DIR)%,%,$(FIRMWARE_BUILD_DIR))
mpfs_disco_kit_ssh_setup: CXX_FLAGS := -O3 -D$(XLEN) -I$(VERILATOR_BUILD_DIR) -I$(SOFTWARE_DIR) -I$(PLATFORM_DIR) -I$(SIM_FILES_DIR)
mpfs_disco_kit_ssh_setup:
	@$(MAKE) --no-print-directory loader_firmware
	@$(MAKE) --no-print-directory echo_firmware
	@$(MAKE) --no-print-directory cyclemark_firmware
	@ssh -T root@192.168.7.2 "mkdir -p $(MPFS_DISCO_KIT_FIRMWARE_DIR)"
	@scp -T -r $(FIRMWARE_BUILD_DIR)/*.hex root@192.168.7.2:./$(MPFS_DISCO_KIT_FIRMWARE_DIR)
	@$(SDK_ACTIVATE) $$CXX $(CXX_FLAGS) $(PLATFORM_FILES) -o $(MPFS_DISCO_KIT_BOARD)platform
	@scp -T -r $(MPFS_DISCO_KIT_BOARD)platform root@192.168.7.2:./
	@scp -T -r $(PLATFORM_DIR)Makefile root@192.168.7.2:./

# MPFS_DISCO_KIT: Establish a serial connection
.PHONY: mpfs_disco_kit_minicom
mpfs_disco_kit_minicom:
	@sudo minicom -D $(TTYUSB) -b 115200

# MPFS_DISCO_KIT: Build firmware & MSS application and send them through uart
.PHONY: mpfs_disco_kit_usb_setup
mpfs_disco_kit_usb_setup: MPFS_DISCO_KIT_FIRMWARE_DIR:=$(patsubst $(WORK_DIR)%,%,$(FIRMWARE_BUILD_DIR))
mpfs_disco_kit_usb_setup: CXX_FLAGS := -O3 -D$(XLEN) -I$(VERILATOR_BUILD_DIR) -I$(SOFTWARE_DIR) -I$(PLATFORM_DIR) -I$(SIM_FILES_DIR)
mpfs_disco_kit_usb_setup:
	@$(MAKE) --no-print-directory loader_firmware
	@$(MAKE) --no-print-directory echo_firmware
	@$(MAKE) --no-print-directory cyclemark_firmware
	@$(call SDK_RUN,$$CXX $(CXX_FLAGS) $(PLATFORM_FILES) -o $(MPFS_DISCO_KIT_BOARD)platform)

	@for f in $(FIRMWARE_BUILD_DIR)/*.hex; do \
	  $(MAKE) --no-print-directory uart_ft UART_FILE="$$f" \
	  UART_DEST_DIR="./$(MPFS_DISCO_KIT_FIRMWARE_DIR)"; \
	done

	@$(MAKE) --no-print-directory uart_ft UART_FILE=$(MPFS_DISCO_KIT_BOARD)platform \
	UART_DEST_DIR="./"

	@$(MAKE) --no-print-directory uart_ft UART_FILE=$(PLATFORM_DIR)Makefile \
	UART_DEST_DIR="./"

# MPFS_DISCO_KIT: Run Libero
.PHONY: libero
libero:
	@echo "➡️  Running Libero..."
	@echo
	@bash -c "source $(MPFS_DISCO_KIT_SCRIPTS_DIR)setup_microchip_tools.sh && libero"
	@echo "✅ Done."




# Make the documentation from board perspective
.PHONY: documentation
documentation:
	@doxygen ./scripts/Doxyfile

# Make the documentation from simulation perspective
.PHONY: sim_documentation
sim_documentation:
	@DOXY_PREDEFINED="SIM" doxygen ./scripts/Doxyfile

# Format source files
.PHONY: format
format:
	@bash -c "scripts/format_hdl.sh"
	@bash -c "scripts/format_cxx.sh"

# Lint all hardware files
.PHONY: lint
lint:
	@bash -c "scripts/lint.sh"





# Clean the working directory
.PHONY: clean
clean: clean_mpfs_disco_kit_bitstream clean_mpfs_disco_kit_hss clean_mpfs_disco_kit_linux
clean:
	@rm -rf $(VERILATOR_WORK_DIR)
	@rm -rf $(FIRMWARE_WORK_DIR)
	@rm -rf $(SIM_LOG_DIR)
	@rm -rf $(MPFS_DISCO_KIT_BOARD)
	@rm -rf $(WORK_DIR)html/
	@rm -rf $(WORK_DIR)latex/
	@rm -f $(WORK_DIR)doxygen.warnings

# Purge the working directory
.PHONY: clean_all
clean_all:
	@echo "➡️  Cleaning working directories..."
	@rm -rf $(WORK_DIR)
	@echo "✅ Done."




# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       sim.mk
# \brief      Simulation targets for SCHOLAR RISC-V.
# \author     Kawanami
# \version    1.0
# \date       15/04/2026
#
# \details
#   This Makefile fragment contains all targets and variables related to the
#   SCHOLAR RISC-V simulation flow.
#
#   It provides:
#     - Verilator DUT build targets
#     - simulation run targets
#     - Spike golden trace generation
#     - ISA test execution
#     - loader, echo, and cyclemark simulation helpers
#
#   This file is intended to be included by the top-level Makefile and is not
#   meant to be used as a standalone entry point.
#
# \remarks
#   - Requires Verilator, Spike, Python 3.
#   - Relies on variables and file lists defined in the common/top-level Makefile.
#   - See `make help` for a summary of available targets and variables.
#
# \section sim_mk_version_history Version history
# | Version | Date       | Author   | Description                                |
# |:-------:|:----------:|:---------|:-------------------------------------------|
# | 1.0     | 15/04/2026 | Kawanami | Initial split from the top-level Makefile. |
# ********************************************************************************
# */

#################################### Directories ####################################
# Directory containing simulation C++ source files
SIM_FILES_DIR           = $(ROOT_DIR)simulation/

# Directory containing the Spike executable
SPIKE_DIR               = /opt/spike/bin/

# Directory containing the Verilator executable
VERILATOR_DIR           = /opt/verilator/bin/

# Verilator working directory
VERILATOR_WORK_DIR 	    = $(WORK_DIR)verilator/

# Verilator build output directory
VERILATOR_BUILD_DIR     = $(VERILATOR_WORK_DIR)build/

# Verilator build log directory
VERILATOR_LOG_DIR  	    = $(VERILATOR_WORK_DIR)log/

# Simulation runtime log directory
SIM_LOG_DIR					    = $(WORK_DIR)simulation/
#################################### 			 ####################################

#################################### Files ####################################
# Firmware generator script used to create one assembly test per instruction
ISA_FIRMWARE_GENERATOR	= $(ROOT_DIR)scripts/gen_isa.py

# List of ISA YAML descriptions used to generate instruction test firmware
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
								          $(ISA_YAML_DIR)Zicntr_instr/rdcycle.yaml

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
								          $(ISA_YAML_DIR)Zicntr_instr/rdcycle.yaml
endif

# Common simulation source files used to drive simulation
COMMON_SIM_FILES 				= $(SIM_FILES_DIR)clocks_resets.cpp \
								          $(SIM_FILES_DIR)sim_log.cpp \
								          $(SIM_FILES_DIR)sim.cpp

# Standard simulation source used to run custom firmware.
SIM                     = $(SIM_FILES_DIR)simulation.cpp

# Simulation sources used to compare the DUT execution against a Spike golden trace.
SIM_VS_SPIKE            = $(SIM_FILES_DIR)spike_parser.cpp \
                          $(SIM_FILES_DIR)simulation_vs_spike.cpp

# Log file to be used for Verilator build
VERILATOR_LOG_FILE				= $(VERILATOR_LOG_DIR)log.txt

# Log file to be used for runtime simulation
SIM_LOG_FILE					= $(SIM_LOG_DIR)log.txt
#################################### 						   ####################################

#################################### Tools & simulation ####################################
# Spike executable
SPIKE							      = $(SPIKE_DIR)spike

# Spike command-line flags
SPIKE_FLAGS						  = -m0x00100000:0x00100000 --isa=$(ISA) -l --log-commits

# Verilator executable
SIMULATOR						    = $(VERILATOR_DIR)verilator

# Verilator hardware build flags
SIM_FLAGS						    = -j $(shell nproc) -DSIM \
								          -GArchi=$(CPU_XLEN) \
								          -GTarget=0 \
								          -GNoPerfectMemory=$(NOT_PERFECT_MEMORY) \
								          --Wno-TIMESCALEMOD -O3 --threads 4 --unroll-count 5120

# Verilator C++ compilation flags
SIM_CXXFLAGS					  = "-O3 -DSIM -D$(XLEN) -DMAX_CYCLES=$(MAX_CYCLES) \
								          -I$(VERILATOR_BUILD_DIR) -I$(SOFTWARE_DIR) \
								          -I$(PLATFORM_DIR) -I$(SIM_FILES_DIR)"

# Maximum number of simulation cycles.
# The core runs at 1 MHz in simulation, so 3,000,000 cycles correspond to 3 seconds
MAX_CYCLES          		= 3000000
#################################### 	   				####################################

# Display help for simulation-related targets
.PHONY: sim_help
sim_help:
	@echo
	@echo "SCHOLAR RISC-V — simulation Makefile helper"
	@echo "Usage: make <target> [XLEN=XLEN32|XLEN64] [ITERATIONS=N] [MAX_CYCLES=N]"
	@echo
	@printf "Targets:\n"
	@printf "  %-35s %s\n" "isa"              "Run the ISA tests (simulation) using spike golden trace comparison"
	@printf "  %-35s %s\n" "loader" 				  "Build & run the loader simulation"
	@printf "  %-35s %s\n" "loader_spike" 		"Build & run the loader simulation with spike golden trace comparison"
	@printf "  %-35s %s\n" "echo" 				  	"Build & run the echo simulation"
	@printf "  %-35s %s\n" "cyclemark" 			  "Build & run the cyclemark simulation"
	@printf "  %-35s %s\n" "cyclemark_spike" 	"Build & run the cyclemark simulation with spike golden trace comparison"
	@printf "  %-35s %s\n" "clean_sim"    		"Clean the simulation working directory"
	@echo
	@printf "Key variables:\n"
	@printf "  %-35s %s\n" "XLEN"             "Architecture (32-bit or 64-bit). Default is 32."
	@printf "  %-35s %s\n" "ITERATIONS"       "Number of iterations for ISA tests ans Cyclemark. More iterations equals more reliable tests. Default is 1."
	@printf "  %-35s %s\n" "MAX_CYCLES"       "Max simulation cycles (default: 3000000 = 3s of simulation)"
	@echo
	@echo "Examples:"
	@echo "  make isa XLEN=XLEN32"
	@echo "  make cyclemark_spike ITERATIONS=3"
	@echo
	@echo

# Simulation working directory creation
sim_work:
	@echo "➡️  Creating simulation working environment..."

	@mkdir -p $(VERILATOR_BUILD_DIR)
	@mkdir -p $(VERILATOR_LOG_DIR)
	@mkdir -p $(SIM_LOG_DIR)

	@echo "✅ Done."
	@echo

# Build the Verilated design under test
.PHONY: dut
dut: sim_work
	@echo "➡️  Building Design Under Test..."

	@echo $(SIMULATOR) $(SIM_FLAGS) -cc $(COMMON_RTL_FILES) $(DUT_FILES) $(ENV_FILES) -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_FILES) > $(VERILATOR_LOG_DIR)log.txt

	@$(SIMULATOR) $(SIM_FLAGS) -cc $(COMMON_RTL_FILES) $(DUT_FILES) $(ENV_FILES) -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_FILES) >> $(VERILATOR_LOG_DIR)log.txt

	@echo make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt

	@make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt
	@echo "✅ Done. See $(VERILATOR_LOG_DIR)log.txt for details."
	@echo

# Run the simulation with the selected firmware
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

# Generate the Spike golden trace for the selected firmware
.PHONY: spike
spike:
	$(SPIKE) $(SPIKE_FLAGS) \
	--log=$(FIRMWARE_BUILD_DIR)$(FIRMWARE).spike \
	$(FIRMWARE_BUILD_DIR)$(FIRMWARE).elf

# Build ISA firmware from YAML files
.PHONY: isa_firmware
isa_firmware: firmware_work

	@echo "➡️  Building ISA firmware..."

	@for source in $(ISA_YAML_FILES); do \
		base=$$(basename "$$source" .yaml); \
		echo Building $$(basename $$source .yaml)...; \
		python3 $(ISA_FIRMWARE_GENERATOR) --yaml $$source --archi $(XLEN) --iteration $(ITERATIONS) --out $(FIRMWARE_BUILD_DIR)/$$(basename $$source .yaml).s; \
		if [ -f "$(FIRMWARE_BUILD_DIR)/$$(basename $$source .yaml).s" ]; then \
			make -f $(COMMON_MK) firmware \
			FIRMWARE_FILES=$(FIRMWARE_BUILD_DIR)$$(basename $$source .yaml).s \
			COMMON_FILES=" " \
			FIRMWARE=$$(basename $$source .yaml); \
			$(SPIKE) $(SPIKE_FLAGS) --log=$(FIRMWARE_BUILD_DIR)$$base.spike $(FIRMWARE_BUILD_DIR)$$base.elf; \
		fi; \
		echo $$(basename $$source .yaml) build done; \
		echo; \
	done >> $(FIRMWARE_LOG_DIR)log.txt

	@echo "✅ ISA firmware build done. See $(FIRMWARE_LOG_DIR)log.txt for details."
	@echo

# Run the ISA tests in simulation
.PHONY: isa
isa: SIM=$(SIM_VS_SPIKE)
isa: dut isa_firmware
isa:
	@for source in $(ISA_YAML_FILES); do \
		base=$$(basename "$$source" .yaml); \
		$(MAKE) run FIRMWARE=$$base; \
	done

# Run the loader firmware in simulation
.PHONY: loader
loader: FIRMWARE=loader
loader: dut loader_firmware
loader: run

# Run the loader firmware in simulation with Spike golden trace comparison
.PHONY: loader_spike
loader_spike: SIM=$(SIM_VS_SPIKE)
loader_spike: WITH_SPIKE=SPIKE
loader_spike: FIRMWARE=loader
loader_spike: dut loader_firmware spike
loader_spike: run

# Run the echo firmware in simulation
.PHONY: echo
echo: FIRMWARE=echo
echo: dut echo_firmware
echo: run

# Run the cyclemark firmware in simulation
.PHONY: cyclemark
cyclemark: FIRMWARE=cyclemark
cyclemark: dut cyclemark_firmware
cyclemark: run

# Run the cyclemark firmware in simulation with Spike golden trace comparison
.PHONY: cyclemark_spike
cyclemark_spike: SIM=$(SIM_VS_SPIKE)
cyclemark_spike: WITH_SPIKE=SPIKE
cyclemark_spike: FIRMWARE=cyclemark
cyclemark_spike: dut cyclemark_firmware spike
cyclemark_spike: run

# Clean the simulation directory
.PHONY: clean_sim
clean_sim:
	@echo "➡️  Cleaning simulation directory..."
	@rm -rf $(VERILATOR_BUILD_DIR)
	@rm -rf $(VERILATOR_LOG_DIR)
	@rm -rf $(SIM_LOG_DIR)
	@echo "✅ Done."

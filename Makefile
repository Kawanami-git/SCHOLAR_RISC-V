#################################### Firmware Toolchain ###################################
# Path to gcc bin directory
EGCC_DIR		  				= $(HOME)/Desktop/tools/rv32i_zicntr/bin/

# gcc
ECC 							= $(EGCC_DIR)riscv32-unknown-elf-gcc

# ld
ELD								= $(EGCC_DIR)riscv32-unknown-elf-ld

# objdump
EOBJDUMP						= $(EGCC_DIR)riscv32-unknown-elf-objdump

# objcopy
EOBJCOPY						= $(EGCC_DIR)riscv32-unknown-elf-objcopy

# Path to libgcc
ELIBGCC_DIR 					= $(HOME)/Desktop/tools/rv32i_zicntr/lib/gcc/riscv32-unknown-elf/14.2.0/

# libgcc (static)
ELGCC							= $(ELIBGCC_DIR)libgcc.a

# Firmware custom building tools
FIMRWARE_TOOLS_DIR  			= $(FIRMWARE_DIR)tools/

# elf converter (to hex, format -> addr:data)
MAKE_HEX						= $(FIMRWARE_TOOLS_DIR)makehex.py
#################################### 	 				####################################


#################################### Simulation Environement ####################################
ROOT_DIR						=$(shell pwd)/

# Hardware directory
HW_DIR 							= $(shell pwd)/hardware/

# Design under test directory
DUT_DIR		        			= $(HW_DIR)core/

# Design under test files
DUT_FILES						= $(DUT_DIR)scholar_riscv_core.sv \
								  $(DUT_DIR)common/packages.sv \
								  $(DUT_DIR)GPR/GPR.sv \
								  $(DUT_DIR)CSR/CSR.sv \
								  $(DUT_DIR)fetch/fetch.sv \
								  $(DUT_DIR)decode/decode.sv \
								  $(DUT_DIR)exe/exe.sv \
								  $(DUT_DIR)commit/commit.sv

# Design under test environement directory
ENV_FILES_DIR					= $(HW_DIR)env/

# Design under test environment files
ENV_FILES 						= $(ENV_FILES_DIR)dpram.sv \
						    	  $(ENV_FILES_DIR)instr_dpram.sv \
						    	  $(ENV_FILES_DIR)data_dpram.sv \
						    	  $(ENV_FILES_DIR)ptc_dpram.sv \
						    	  $(ENV_FILES_DIR)ctp_dpram.sv \
						    	  $(ENV_FILES_DIR)bus_fabric.sv \
						    	  $(ENV_FILES_DIR)riscv_env.sv

# TOP file to simulate
TOP								= riscv_env

# Working directory
WORK_DIR            			= $(shell pwd)/work/

# Simulation build directory
VERILATOR_BUILD_DIR  			= $(WORK_DIR)verilator/build/

# Simulation log directory
VERILATOR_LOG_DIR  				= $(WORK_DIR)verilator/log/

# Simulation hdl directory
SIM_HDL_DIR  					= $(WORK_DIR)hdl/

# Simulation files directory
SIM_FILES_DIR       			= $(shell pwd)/simulation/

# Common simulation files
COMMON_SIM_FILES 				= $(SIM_FILES_DIR)clocks_resets.cpp \
								  $(SIM_FILES_DIR)sim_log.cpp \
								  $(SIM_FILES_DIR)sim.cpp

# Simulation vs spike (to run ISA tests)
SIM_VS_SPIKE 					= $(SIM_FILES_DIR)spike_parser.cpp \
								  $(SIM_FILES_DIR)simulation_vs_spike.cpp

# Simulation (to run custom firmware)
SIM 							= $(SIM_FILES_DIR)simulation.cpp

# Platform directory (common directory between simulation and Polarfire SoC-FPGA boards)
PLATFORM_DIR 					= $(shell pwd)/software/platform/

# Platform common files directory
PLATFORM_COMMON_FILES_DIR		= $(PLATFORM_DIR)common/

# Platform common files
PLATFORM_COMMON_FILES			= $(wildcard $(PLATFORM_COMMON_FILES_DIR)*.c $(PLATFORM_COMMON_FILES_DIR)*.cpp)

# Firmware directory
FIRMWARE_DIR 					= $(shell pwd)/software/firmware/

# Firmware common files directory
FIRMWARE_COMMON_FILES_DIR		= $(FIRMWARE_DIR)common/

# Firmware common files
FIRMWARE_COMMON_FILES			= $(wildcard $(FIRMWARE_COMMON_FILES_DIR)*.c)

# Firmware linker(s) directory
FIRMWARE_LINKER_DIR				= $(FIRMWARE_DIR)linker/

# Spike directory
SPIKE_DIR           			= $(HOME)/Desktop/tools/spike/bin/

# Spike software
SPIKE							= $(SPIKE_DIR)spike

# Spike flags
SPIKE_FLAGS						= -m2 --isa=rv32i_zicntr -l --log-commits

# Verilator directory
VERILATOR_DIR       			= $(HOME)/Desktop/tools/verilator/bin/

# Verilator binary
SIMULATOR						= $(VERILATOR_DIR)verilator

# Verilator hardware flags
SIM_FLAGS						= -I$(SIM_HDL_DIR) -DARCHI32 -DDUT --Wno-TIMESCALEMOD

# Verilator software flags
SIM_CXXFLAGS					= "-g -O0 -DDUT -DMAX_CYCLES=$(MAX_CYCLES) -I$(VERILATOR_BUILD_DIR) -I$(PLATFORM_DIR)../ -I$(SIM_FILES_DIR) -I$(PLATFORM_COMMON_FILES_DIR)"

# Maximum number of cycles for the simulation. As core is running at 1MHz, it corresponds to three seconds of simulation.
MAX_CYCLES          			= 3000000

# Parameters used when building the firmware. It can be used, as exemple, to choose the number of iteraton of the CycleMark algorithm.
ITERATIONS          			= 1
####################################						 ####################################


#################################### ISA Simulation parameters ####################################
# GCC (used to build the firmware generators)
CC								= gcc

# GCC flags
CFLAGS							= -Wall -I$(ISA_FIRMWARE_DIR) -I$(PLATFORM_DIR)../ -I$(SIM_FILES_DIR) -I$(PLATFORM_COMMON_FILES_DIR)

# ISA log directory
ISA_LOG_DIR    					= $(WORK_DIR)isa/log/

# ISA buid firectory
ISA_BUILD_DIR  					= $(WORK_DIR)isa/build/

# Firmware generators program name (used to generate one firmware per instruction)
ISA_FIRMWARE_GENERATOR			= $(ISA_BUILD_DIR)gen

# ISA firmware directory
ISA_FIRMWARE_DIR   				= $(FIRMWARE_DIR)isa/

# ISA RV32I firmware directory
ISA_FIRMWARE_RV32I_DIR  		= $(ISA_FIRMWARE_DIR)rv32i/

# ISA firmware files
ISA_FIRMWARE_FILES				= $(wildcard $(ISA_FIRMWARE_RV32I_DIR)u_instr/*.cpp) \
								  $(wildcard $(ISA_FIRMWARE_RV32I_DIR)i_instr/*.cpp) \
								  $(wildcard $(ISA_FIRMWARE_RV32I_DIR)j_instr/*.cpp) \
								  $(wildcard $(ISA_FIRMWARE_RV32I_DIR)r_instr/*.cpp) \
								  $(wildcard $(ISA_FIRMWARE_RV32I_DIR)s_instr/*.cpp) \
								  $(wildcard $(ISA_FIRMWARE_RV32I_DIR)b_instr/*.cpp) \
								  $(wildcard $(ISA_FIRMWARE_RV32I_DIR)Zicntr_instr/*.cpp)

# ISA firmware compiler flags
ISA_FIRMWARE_ECFLAGS  			= -I$(FIRMWARE_COMMON_FILES_DIR) -I$(FIRMWARE_DIR)../ \
								   -march=rv32i_zicntr -mabi=ilp32 -Wall -DITERATIONS=$(ITERATIONS)

# ISA firmware linker flags
ISA_FIRMWARE_ELDFLAGS 			= -T $(FIRMWARE_LINKER_DIR)linker_ISA.ld -nostdlib
#################################### 						   ####################################


#################################### LOADER simulation parameters ####################################
# LOADER log directory
LOADER_LOG_DIR    				= $(WORK_DIR)loader/log/

# LOADER build directory
LOADER_BUILD_DIR  				= $(WORK_DIR)loader/build/

# LOADER platform directory
PLATFORM_LOADER_DIR 			= $(PLATFORM_DIR)loader/

# LOADER platform files
PLATFORM_LOADER_FILES 			= $(wildcard $(PLATFORM_LOADER_DIR)*.c $(PLATFORM_LOADER_DIR)*.cpp)

# LOADER firmware directory
FIRMWARE_LOADER_DIR   			= $(FIRMWARE_DIR)loader/

# LOADER firmware files
FIRMWARE_LOADER_FILES 			= $(wildcard $(FIRMWARE_LOADER_DIR)*.c $(FIRMWARE_LOADER_DIR)*.s)

# LOADER firmware compiler flag
FIRMWARE_LOADER_ECFLAGS  		= -I$(FIRMWARE_COMMON_FILES_DIR) -I$(FIRMWARE_DIR)../ \
						   		  -march=rv32i_zicntr -mabi=ilp32 -Wall -nostdlib -ffreestanding -O3 -ffunction-sections -fdata-sections

# LOADER firmware linker flag
FIRMWARE_LOADER_ELDFLAGS 		= -T $(FIRMWARE_LINKER_DIR)linker.ld -nostdlib -static --gc-sections
#################################### 						 	  ####################################


#################################### REPEATER simulation parameters ####################################
# REPEATER log directory
REPEATER_LOG_DIR    			= $(WORK_DIR)repeater/log/

# REPEATER build directory
REPEATER_BUILD_DIR  			= $(WORK_DIR)repeater/build/

# REPEATER platform directory
PLATFORM_REPEATER_DIR 			= $(PLATFORM_DIR)repeater/

# REPEATER platform files
PLATFORM_REPEATER_FILES 		= $(wildcard $(PLATFORM_REPEATER_DIR)*.c $(PLATFORM_REPEATER_DIR)*.cpp)

# REPEATER firmware directory
FIRMWARE_REPEATER_DIR   		= $(FIRMWARE_DIR)repeater/

# REPEATER firmware files
FIRMWARE_REPEATER_FILES 		= $(wildcard $(FIRMWARE_REPEATER_DIR)*.c $(FIRMWARE_REPEATER_DIR)*.s)

# REPEATER firmware compiler flag
FIRMWARE_REPEATER_ECFLAGS   	= -I$(FIRMWARE_COMMON_FILES_DIR) -I$(FIRMWARE_DIR)../ \
							  	  -march=rv32i_zicntr -mabi=ilp32 -Wall -nostdlib -ffreestanding -O3 -ffunction-sections -fdata-sections

# REPEATER firmware linker flag
FIRMWARE_REPEATER_ELDFLAGS  	= -T $(FIRMWARE_LINKER_DIR)linker.ld -nostdlib -static --gc-sections
####################################								####################################


#################################### CYCLEMARK simulation parameters ####################################
# CYCLEMARK log directory
CYCLEMARK_LOG_DIR    			= $(WORK_DIR)cyclemark/log/

# CYCLEMARK build directory
CYCLEMARK_BUILD_DIR  			= $(WORK_DIR)cyclemark/build/

# CYCLEMARK platform directory
PLATFORM_CYCLEMARK_DIR 			= $(PLATFORM_DIR)cyclemark/

# CYCLEMARK platform files
PLATFORM_CYCLEMARK_FILES 		= $(wildcard $(PLATFORM_CYCLEMARK_DIR)*.c $(PLATFORM_CYCLEMARK_DIR)*.cpp)

# CYCLEMARK firmware directory
FIRMWARE_CYCLEMARK_DIR   		= $(FIRMWARE_DIR)cyclemark/

# CYCLEMARK firmware files
FIRMWARE_CYCLEMARK_FILES 		= $(wildcard $(FIRMWARE_CYCLEMARK_DIR)*.c $(FIRMWARE_CYCLEMARK_DIR)*.s)

# CYCLEMARK firmware compiler flag
FIRMWARE_CYCLEMARK_ECFLAGS   	= -I$(FIRMWARE_COMMON_FILES_DIR) -I$(FIRMWARE_DIR)../ \
								  -march=rv32i_zicntr -mabi=ilp32 -Wall -nostdlib -ffreestanding -O3 -ffunction-sections -fdata-sections \
								  -DITERATIONS=$(ITERATIONS)

# CYCLEMARK firmware linker flag
FIRMWARE_CYCLEMARK_ELDFLAGS  	= -T $(FIRMWARE_LINKER_DIR)linker.ld -nostdlib -static --gc-sections
####################################								####################################


#################################### MPFS DISCOVERY KIT parameters ####################################
# MPFS DISCOVERY KIT root directory
MPFS_DISCOVERY_KIT_ROOT_DIR 	= MPFS_DISCOVERY_KIT/

# MPFS DISCOVERY KIT scripts directory
MPFS_DISCOVERY_KIT_SCRIPTS_DIR  = $(MPFS_DISCOVERY_KIT_ROOT_DIR)scripts/

# MPFS DISCOVERY KIT HSS directory
MPFS_DISCOVERY_KIT_HSS_DIR  	= $(MPFS_DISCOVERY_KIT_ROOT_DIR)HSS/

# MPFS DISCOVERY KIT FPGA directory
MPFS_DISCOVERY_KIT_FPGA_DIR 	= $(MPFS_DISCOVERY_KIT_ROOT_DIR)FPGA/

# MPFS DISCOVERY KIT Linux directory
MPFS_DISCOVERY_KIT_LINUX_DIR	= $(MPFS_DISCOVERY_KIT_ROOT_DIR)Linux/

# MPFS DISCOVERY KIT yocto directory
MPFS_DISCOVERY_KIT_YOCTO_DIR	= $(MPFS_DISCOVERY_KIT_LINUX_DIR)yocto/

# MPFS DISCOVERY KIT meta files directory
MPFS_DISCOVERY_KIT_LAYER_DIR	= $(MPFS_DISCOVERY_KIT_LINUX_DIR)meta-scholar-risc-v/
####################################							   ####################################


#################################### DEFAULT TARGET ####################################
default: isa
####################################				####################################


#################################### WORK TARGET ####################################
.PHONY: work
work:
	@echo "➡️  Creating working environment..."

	@mkdir -p $(WORK_DIR)
	@mkdir -p $(VERILATOR_BUILD_DIR)
	@mkdir -p $(VERILATOR_LOG_DIR)
	@mkdir -p $(SIM_HDL_DIR)

	@for source in $(DUT_FILES); do \
		cp $$source $(SIM_HDL_DIR); \
	done >> $(VERILATOR_LOG_DIR)log.txt

	@for source in $(ENV_FILES); do \
		cp $$source $(SIM_HDL_DIR); \
	done >> $(VERILATOR_LOG_DIR)log.txt

	@echo "✅ Done. See $(VERILATOR_LOG_DIR)log.txt for details."
	@echo
####################################			 ####################################


#################################### DUT TARGET ####################################
.PHONY: dut
dut: work
	@echo "➡️  Building Design Under Test..."
	@$(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) > $(VERILATOR_LOG_DIR)log.txt
	@echo "✅ Done. See $(VERILATOR_LOG_DIR)log.txt for details."
	@echo
#################################### 			####################################

#################################### ISA TARGET ####################################
.PHONY: isa_firmwares
isa_firmwares: work

	@mkdir -p $(ISA_BUILD_DIR)
	@mkdir -p $(ISA_LOG_DIR)

	@echo "➡️  Building ISA firmwares..."
	@for source in $(ISA_FIRMWARE_FILES); do \
		echo Building $$(basename $$source .cpp)...; \
		\
		$(CC) $(CFLAGS) -o $(ISA_FIRMWARE_GENERATOR) $(PLATFORM_COMMON_FILES_DIR)args_parser.cpp $$source; \
		\
		$(ISA_FIRMWARE_GENERATOR) --out $(ISA_BUILD_DIR)$$(basename $$source .cpp).s --nb_instr $(ITERATIONS); \
		\
		$(ECC) $(ISA_FIRMWARE_ECFLAGS) -march=rv32i_zicntr -mabi=ilp32 -c $(ISA_BUILD_DIR)$$(basename $$source .cpp).s \
		-o $(ISA_BUILD_DIR)/$$(basename $$source .cpp).o; \
		\
		$(ELD) $(ISA_FIRMWARE_ELDFLAGS) $(ISA_BUILD_DIR)$$(basename $$source .cpp).o -o $(ISA_BUILD_DIR)$$(basename $$source .cpp).elf; \
		\
		$(EOBJCOPY) -O binary $(ISA_BUILD_DIR)$$(basename $$source .cpp).elf $(ISA_BUILD_DIR)$$(basename $$source .cpp).bin; \
		\
		$(EOBJDUMP) -D $(ISA_BUILD_DIR)$$(basename $$source .cpp).elf > $(ISA_BUILD_DIR)$$(basename $$source .cpp).dump; \
		\
		python3 $(MAKE_HEX) $(ISA_BUILD_DIR)$$(basename $$source .cpp).elf > $(ISA_BUILD_DIR)$$(basename $$source .cpp).hex; \
		\
		echo $$(basename $$source .cpp) build done; \
		\
        echo;\
	done >> $(ISA_LOG_DIR)log.txt
	@echo "✅ Done. See $(ISA_LOG_DIR)log.txt for details."
	@echo 

.PHONY: isa
isa: isa_firmwares

	@echo "➡️  Building Design Under Test..."

	@echo $(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM_VS_SPIKE) $(PLATFORM_COMMON_FILES) > $(VERILATOR_LOG_DIR)log.txt

	@$(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM_VS_SPIKE) $(PLATFORM_COMMON_FILES) >> $(VERILATOR_LOG_DIR)log.txt

	@echo make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt

	@make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt
	
	@echo "✅ Done. See $(VERILATOR_LOG_DIR)log.txt for details."
	@echo 

	
	@echo "➡️  Running ISA Tests..."
	@for source in $(ISA_FIRMWARE_FILES); do \
		echo Running $$(basename $$source .cpp) verification...; \
		\
		$(SPIKE) $(SPIKE_FLAGS) --log=$(ISA_BUILD_DIR)$$(basename $$source .cpp).spike $(ISA_BUILD_DIR)$$(basename $$source .cpp).elf; \
		\
		$(VERILATOR_BUILD_DIR)V$(TOP) --logfile $(ISA_LOG_DIR)log.txt --waveform $(ISA_LOG_DIR)$$(basename $$source .cpp).vcd \
		--firmware $(ISA_BUILD_DIR)$$(basename $$source .cpp).hex --spike $(ISA_BUILD_DIR)$$(basename $$source .cpp).spike; \
		\
		echo $$(basename $$source .cpp) verification done; \
		\
        echo;\
	done >> $(ISA_LOG_DIR)log.txt
	@echo "✅ Done. See $(ISA_LOG_DIR)log.txt for details."
	@echo

.PHONY: clean_isa
clean_isa:
	@echo "➡️  Cleaning ISA directories..."
	@rm -rf $(ISA_BUILD_DIR)
	@rm -rf $(ISA_LOG_DIR)
	@echo "✅ Done."
	@echo
####################################			####################################


#################################### LOADER TARGET ####################################
.PHONY: loader_firmware
loader_firmware: work

	@echo "➡️  Building loader firmware..."

	@mkdir -p $(LOADER_BUILD_DIR)
	@mkdir -p $(LOADER_LOG_DIR)

	@for source in $(FIRMWARE_LOADER_FILES); do \
		echo $(ECC) $(FIRMWARE_LOADER_ECFLAGS) -c $$source -o $(LOADER_BUILD_DIR)/$$(basename $$source .c).o >> $(LOADER_LOG_DIR)log.txt; \
		$(ECC) $(FIRMWARE_LOADER_ECFLAGS) -c $$source -o $(LOADER_BUILD_DIR)/$$(basename $$source .c).o; \
	done 
	@for source in $(FIRMWARE_COMMON_FILES); do \
		echo $(ECC) $(FIRMWARE_LOADER_ECFLAGS) -c $$source -o $(LOADER_BUILD_DIR)/$$(basename $$source .c).o >> $(LOADER_LOG_DIR)log.txt; \
		$(ECC) $(FIRMWARE_LOADER_ECFLAGS) -c $$source -o $(LOADER_BUILD_DIR)/$$(basename $$source .c).o; \
	done

	@echo $(ELD) $(FIRMWARE_LOADER_ELDFLAGS) $(LOADER_BUILD_DIR)*.o $(ELGCC) -o $(LOADER_BUILD_DIR)firmware.elf >> $(LOADER_LOG_DIR)log.txt
	@$(ELD) $(FIRMWARE_LOADER_ELDFLAGS) $(LOADER_BUILD_DIR)*.o $(ELGCC) -o $(LOADER_BUILD_DIR)firmware.elf
	
	@echo $(EOBJCOPY) -O binary $(LOADER_BUILD_DIR)firmware.elf $(LOADER_BUILD_DIR)firmware.bin >> $(LOADER_LOG_DIR)log.txt
	@$(EOBJCOPY) -O binary $(LOADER_BUILD_DIR)firmware.elf $(LOADER_BUILD_DIR)firmware.bin

	@echo "$(EOBJDUMP) -D $(LOADER_BUILD_DIR)firmware.elf > $(LOADER_BUILD_DIR)firmware.dump" >> $(LOADER_LOG_DIR)log.txt
	@$(EOBJDUMP) -D $(LOADER_BUILD_DIR)firmware.elf > $(LOADER_BUILD_DIR)firmware.dump

	@echo "python3 $(MAKE_HEX) $(LOADER_BUILD_DIR)firmware.elf > $(LOADER_BUILD_DIR)firmware.hex" >> $(LOADER_LOG_DIR)log.txt
	@python3 $(MAKE_HEX) $(LOADER_BUILD_DIR)firmware.elf > $(LOADER_BUILD_DIR)firmware.hex

	@echo "✅ Done. See $(LOADER_LOG_DIR)log.txt for details."
	@echo

.PHONY: loader
loader: loader_firmware

	@echo "➡️  Building Design Under Test..."

	@echo $(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_COMMON_FILES) $(PLATFORM_LOADER_FILES) > $(VERILATOR_LOG_DIR)log.txt

	@$(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_COMMON_FILES) $(PLATFORM_LOADER_FILES) >> $(VERILATOR_LOG_DIR)log.txt
	
	@echo make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt
	
	@make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt
	@echo "✅ Done. See $(VERILATOR_LOG_DIR)log.txt for details."
	@echo


	@echo "➡️  Running simulation..."
	@echo Running loader... >> $(LOADER_LOG_DIR)log.txt
	@echo >> $(LOADER_LOG_DIR)log.txt

	@echo $(VERILATOR_BUILD_DIR)V$(TOP) --logfile $(LOADER_LOG_DIR)log.txt --waveform $(LOADER_LOG_DIR)waveform.vcd \
	--firmware $(LOADER_BUILD_DIR)firmware.hex >> $(LOADER_LOG_DIR)log.txt

	@$(VERILATOR_BUILD_DIR)V$(TOP) --logfile $(LOADER_LOG_DIR)log.txt --waveform $(LOADER_LOG_DIR)waveform.vcd \
	--firmware $(LOADER_BUILD_DIR)firmware.hex

	@echo >> $(LOADER_LOG_DIR)log.txt

	@echo Done. >> $(LOADER_LOG_DIR)log.txt

	@echo >> $(LOADER_LOG_DIR)log.txt

	@echo "✅ Done. See $(LOADER_LOG_DIR)log.txt for details."
	@echo

.PHONY: clean_loader
clean_loader:
	@echo "➡️  Cleaning loader directories..."
	@rm -rf $(LOADER_BUILD_DIR)
	@rm -rf $(LOADER_LOG_DIR)
	@echo "✅ Done."
#################################### 			   ####################################

#################################### REPEATER ####################################
.PHONY: repeater_firmware
repeater_firmware: work

	@echo "➡️  Building repeater firmware..."

	@mkdir -p $(REPEATER_BUILD_DIR)
	@mkdir -p $(REPEATER_LOG_DIR)

	@for source in $(FIRMWARE_REPEATER_FILES); do \
		echo $(ECC) $(FIRMWARE_REPEATER_ECFLAGS) -c $$source -o $(REPEATER_BUILD_DIR)/$$(basename $$source .c).o >> $(REPEATER_LOG_DIR)log.txt; \
		$(ECC) $(FIRMWARE_REPEATER_ECFLAGS) -c $$source -o $(REPEATER_BUILD_DIR)/$$(basename $$source .c).o; \
	done 
	@for source in $(FIRMWARE_COMMON_FILES); do \
		echo $(ECC) $(FIRMWARE_REPEATER_ECFLAGS) -c $$source -o $(REPEATER_BUILD_DIR)/$$(basename $$source .c).o >> $(REPEATER_LOG_DIR)log.txt; \
		$(ECC) $(FIRMWARE_REPEATER_ECFLAGS) -c $$source -o $(REPEATER_BUILD_DIR)/$$(basename $$source .c).o; \
	done

	@echo $(ELD) $(FIRMWARE_REPEATER_ELDFLAGS) $(REPEATER_BUILD_DIR)*.o $(ELGCC) -o $(REPEATER_BUILD_DIR)firmware.elf >> $(REPEATER_LOG_DIR)log.txt
	@$(ELD) $(FIRMWARE_REPEATER_ELDFLAGS) $(REPEATER_BUILD_DIR)*.o $(ELGCC) -o $(REPEATER_BUILD_DIR)firmware.elf
	
	@echo $(EOBJCOPY) -O binary $(REPEATER_BUILD_DIR)firmware.elf $(REPEATER_BUILD_DIR)firmware.bin >> $(REPEATER_LOG_DIR)log.txt
	@$(EOBJCOPY) -O binary $(REPEATER_BUILD_DIR)firmware.elf $(REPEATER_BUILD_DIR)firmware.bin

	@echo "$(EOBJDUMP) -D $(REPEATER_BUILD_DIR)firmware.elf > $(REPEATER_BUILD_DIR)firmware.dump" >> $(REPEATER_LOG_DIR)log.txt
	@$(EOBJDUMP) -D $(REPEATER_BUILD_DIR)firmware.elf > $(REPEATER_BUILD_DIR)firmware.dump

	@echo "python3 $(MAKE_HEX) $(REPEATER_BUILD_DIR)firmware.elf > $(REPEATER_BUILD_DIR)firmware.hex" >> $(REPEATER_LOG_DIR)log.txt
	@python3 $(MAKE_HEX) $(REPEATER_BUILD_DIR)firmware.elf > $(REPEATER_BUILD_DIR)firmware.hex

	@echo "✅ Done. See $(REPEATER_LOG_DIR)log.txt for details."
	@echo

.PHONY: repeater
repeater: repeater_firmware

	@echo "➡️  Building Design Under Test..."
	@echo $(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_COMMON_FILES) $(PLATFORM_REPEATER_FILES) > $(VERILATOR_LOG_DIR)log.txt

	@$(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_COMMON_FILES) $(PLATFORM_REPEATER_FILES) >> $(VERILATOR_LOG_DIR)log.txt

	@echo make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt

	@make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt
	@echo "✅ Done. See $(VERILATOR_LOG_DIR)log.txt for details."
	@echo


	@echo "➡️  Running simulation..."
	@echo Running repeater... >> $(REPEATER_LOG_DIR)log.txt
	@echo >> $(REPEATER_LOG_DIR)log.txt

	@$(VERILATOR_BUILD_DIR)V$(TOP) --logfile $(REPEATER_LOG_DIR)log.txt --waveform $(REPEATER_LOG_DIR)waveform.vcd \
	--firmware $(REPEATER_BUILD_DIR)firmware.hex

	@echo >> $(REPEATER_LOG_DIR)log.txt

	@echo Done. >> $(REPEATER_LOG_DIR)log.txt

	@echo >> $(REPEATER_LOG_DIR)log.txt

	@echo "✅ Done. See $(REPEATER_LOG_DIR)log.txt for details."
	@echo

.PHONY: clean_repeater
clean_repeater:
	@echo "➡️  Cleaning repeater directories..."
	@rm -rf $(REPEATER_BUILD_DIR)
	@rm -rf $(REPEATER_LOG_DIR)
	@echo "✅ Done."
####################################		  ####################################


#################################### CYCLEMARK ####################################
.PHONY: cyclemark_firmware
cyclemark_firmware: work

	@echo "➡️  Building cyclemark firmware..."

	@mkdir -p $(CYCLEMARK_BUILD_DIR)
	@mkdir -p $(CYCLEMARK_LOG_DIR)

	@for source in $(FIRMWARE_CYCLEMARK_FILES); do \
		echo $(ECC) $(FIRMWARE_CYCLEMARK_ECFLAGS) -c $$source -o $(CYCLEMARK_BUILD_DIR)/$$(basename $$source .c).o >> $(CYCLEMARK_LOG_DIR)log.txt; \
		$(ECC) $(FIRMWARE_CYCLEMARK_ECFLAGS) -c $$source -o $(CYCLEMARK_BUILD_DIR)/$$(basename $$source .c).o; \
	done 
	@for source in $(FIRMWARE_COMMON_FILES); do \
		echo $(ECC) $(FIRMWARE_CYCLEMARK_ECFLAGS) -c $$source -o $(CYCLEMARK_BUILD_DIR)/$$(basename $$source .c).o >> $(CYCLEMARK_LOG_DIR)log.txt; \
		$(ECC) $(FIRMWARE_CYCLEMARK_ECFLAGS) -c $$source -o $(CYCLEMARK_BUILD_DIR)/$$(basename $$source .c).o; \
	done

	@echo $(ELD) $(FIRMWARE_CYCLEMARK_ELDFLAGS) $(CYCLEMARK_BUILD_DIR)*.o $(ELGCC) -o $(CYCLEMARK_BUILD_DIR)firmware.elf >> $(CYCLEMARK_LOG_DIR)log.txt
	@$(ELD) $(FIRMWARE_CYCLEMARK_ELDFLAGS) $(CYCLEMARK_BUILD_DIR)*.o $(ELGCC) -o $(CYCLEMARK_BUILD_DIR)firmware.elf
	
	@echo $(EOBJCOPY) -O binary $(CYCLEMARK_BUILD_DIR)firmware.elf $(CYCLEMARK_BUILD_DIR)firmware.bin >> $(CYCLEMARK_LOG_DIR)log.txt
	@$(EOBJCOPY) -O binary $(CYCLEMARK_BUILD_DIR)firmware.elf $(CYCLEMARK_BUILD_DIR)firmware.bin

	@echo "$(EOBJDUMP) -D $(CYCLEMARK_BUILD_DIR)firmware.elf > $(CYCLEMARK_BUILD_DIR)firmware.dump" >> $(CYCLEMARK_LOG_DIR)log.txt
	@$(EOBJDUMP) -D $(CYCLEMARK_BUILD_DIR)firmware.elf > $(CYCLEMARK_BUILD_DIR)firmware.dump

	@echo "python3 $(MAKE_HEX) $(CYCLEMARK_BUILD_DIR)firmware.elf > $(CYCLEMARK_BUILD_DIR)firmware.hex" >> $(CYCLEMARK_LOG_DIR)log.txt
	@python3 $(MAKE_HEX) $(CYCLEMARK_BUILD_DIR)firmware.elf > $(CYCLEMARK_BUILD_DIR)firmware.hex

	@echo "✅ Done. See $(CYCLEMARK_LOG_DIR)log.txt for details."
	@echo

.PHONY: cyclemark
cyclemark: cyclemark_firmware

	@echo "➡️  Building Design Under Test..."
	@echo $(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_COMMON_FILES) $(PLATFORM_CYCLEMARK_FILES) > $(VERILATOR_LOG_DIR)log.txt

	@$(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_COMMON_FILES) $(PLATFORM_CYCLEMARK_FILES) >> $(VERILATOR_LOG_DIR)log.txt

	@echo make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt

	@make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt
	@echo "✅ Done. See $(VERILATOR_LOG_DIR)log.txt for details."
	@echo


	@echo "➡️  Running simulation..."
	@echo Running cyclemark... >> $(CYCLEMARK_LOG_DIR)log.txt
	@echo >> $(CYCLEMARK_LOG_DIR)log.txt

	@$(VERILATOR_BUILD_DIR)V$(TOP) --logfile $(CYCLEMARK_LOG_DIR)log.txt --waveform $(CYCLEMARK_LOG_DIR)waveform.vcd \
	--firmware $(CYCLEMARK_BUILD_DIR)firmware.hex

	@echo >> $(CYCLEMARK_LOG_DIR)log.txt

	@echo Done. >> $(CYCLEMARK_LOG_DIR)log.txt

	@echo >> $(CYCLEMARK_LOG_DIR)log.txt

	@echo "✅ Done. See $(CYCLEMARK_LOG_DIR)log.txt for details."
	@echo

.PHONY: clean_cyclemark
clean_cyclemark:
	@echo "➡️  Cleaning cyclemark directories..."
	@rm -rf $(CYCLEMARK_BUILD_DIR)
	@rm -rf $(CYCLEMARK_LOG_DIR)
	@echo "✅ Done."
####################################		  ####################################


#################################### MPFS_DISCOVERY_KIT ####################################
.PHONY: mpfs_discovery_kit_hss
mpfs_discovery_kit_hss: work
	@echo "➡️  Running HSS building and programming script..."
	@echo
	@bash $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)build_hss.sh $(WORK_DIR) $(MPFS_DISCOVERY_KIT_HSS_DIR) $(MPFS_DISCOVERY_KIT_ROOT_DIR) $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR) $(program)
	@echo "✅ Done."

.PHONY: clean_mpfs_discovery_kit_hss
clean_mpfs_discovery_kit_hss:
	@echo "➡️  Cleaning HSS directories..."
	@cd $(WORK_DIR) && rm -rf $(MPFS_DISCOVERY_KIT_HSS_DIR)
	@echo "✅ Done."

.PHONY: mpfs_discovery_kit_bitstream
mpfs_discovery_kit_bitstream: work
	@echo "➡️  Running bitstream building and programming script..."
	@echo
ifdef program
	@bash -c "program=1 && \
	source $(MPFS_DISCOVERY_KIT_ROOT_DIR)/scripts/setup_microchip_tools.sh && \
	cd $(MPFS_DISCOVERY_KIT_FPGA_DIR) && \
	LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 libero SCRIPT:MPFS_DISCOVERY_KIT_DESIGN.tcl"
else
	@bash -c "source $(MPFS_DISCOVERY_KIT_ROOT_DIR)/scripts/setup_microchip_tools.sh && \
	cd $(MPFS_DISCOVERY_KIT_FPGA_DIR) && \
	LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 libero SCRIPT:MPFS_DISCOVERY_KIT_DESIGN.tcl"
endif
	@echo "✅ Done."

.PHONY: clean_mpfs_discovery_kit_bitstream
clean_mpfs_discovery_kit_bitstream:
	@echo "➡️  Cleaning bitstream directories..."
	@cd $(WORK_DIR) && rm -rf $(MPFS_DISCOVERY_KIT_FPGA_DIR)
	@echo "✅ Done."

.PHONY: mpfs_discovery_kit_linux
mpfs_discovery_kit_linux: work
	@echo "➡️  Running Linux building script..."
	@echo
	@bash $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)build_linux.sh $(WORK_DIR) $(MPFS_DISCOVERY_KIT_LINUX_DIR) $(MPFS_DISCOVERY_KIT_YOCTO_DIR) $(MPFS_DISCOVERY_KIT_LAYER_DIR)
	@echo "✅ Done."

.PHONY: clean_mpfs_discovery_kit_linux
clean_mpfs_discovery_kit_linux:
	@echo "➡️  Cleaning Linux directories..."
	@cd $(WORK_DIR) && rm -rf $(MPFS_DISCOVERY_KIT_LINUX_DIR)
	@echo "✅ Done."

.PHONY: mpfs_discovery_kit_program_linux
mpfs_discovery_kit_program_linux:
	@echo "➡️  Running Linux programming script..."
	@echo
ifdef path
	@bash $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)load_linux.sh $(path)
else
	@bash $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)load_linux.sh $(WORK_DIR)$(MPFS_DISCOVERY_KIT_YOCTO_DIR)yocto-dev/build/tmp-glibc/deploy/images/mpfs-disco-kit/core-image-custom-mpfs-disco-kit.rootfs.wic
endif
	@echo "✅ Done."

.PHONY: clean_mpfs_discovery_kit
clean_mpfs_discovery_kit:
	@echo "➡️  Cleaning MPFS DISCOVERY KIT directories..."
	@cd $(WORK_DIR) && rm -rf $(MPFS_DISCOVERY_KIT_DIR)
	@echo "✅ Done."

.PHONY: mpfs_discovery_kit_ssh
mpfs_discovery_kit_ssh:
	@chmod +x $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)board_ssh.sh
	@bash -c "$(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)board_ssh.sh"

.PHONY: send_mpfs_discovery_kit_platform_tools
send_mpfs_discovery_kit_platform_tools:
	@echo "➡️  Running platform tools sender script..."
	@echo
	@chmod +x $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)send_platform_tools.sh
	@bash -c "$(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)send_platform_tools.sh"
	@echo "✅ Done."

.PHONY: send_mpfs_discovery_kit_loader_firmware
send_mpfs_discovery_kit_loader_firmware: loader_firmware
	@echo "➡️  Running firmware sender script..."
	@echo
	@chmod +x $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)send_firmware.sh
	@bash -c "$(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)send_firmware.sh $(LOADER_BUILD_DIR)firmware.hex loader.hex"
	@echo "✅ Done."

.PHONY: send_mpfs_discovery_kit_repeater_firmware
send_mpfs_discovery_kit_repeater_firmware: repeater_firmware
	@echo "➡️  Running firmware sender script..."
	@echo
	@chmod +x $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)/send_firmware.sh
	@bash -c "$(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)/send_firmware.sh $(REPEATER_BUILD_DIR)firmware.hex repeater.hex"
	@echo "✅ Done."

.PHONY: send_mpfs_discovery_kit_cyclemark_firmware
send_mpfs_discovery_kit_cyclemark_firmware: cyclemark_firmware
	@echo "➡️  Running firmware sender script..."
	@echo
	@chmod +x $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)send_firmware.sh
	@bash -c "$(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)send_firmware.sh $(CYCLEMARK_BUILD_DIR)firmware.hex cyclemark.hex"
	@echo "✅ Done."
####################################				    ####################################


#################################### LIBERO ####################################
.PHONY: libero
libero:
	@echo "➡️  Running Libero..."
	@echo
	@bash -c "source $(MPFS_DISCOVERY_KIT_SCRIPTS_DIR)setup_microchip_tools.sh && libero"
	@echo "✅ Done."
####################################		####################################


#################################### CLEAN ALL ####################################
.PHONY: clean_all
clean_all:
	@echo "➡️  Cleaning working directories..."
	@rm -rf $(WORK_DIR)
	@echo "✅ Done."
####################################           ####################################




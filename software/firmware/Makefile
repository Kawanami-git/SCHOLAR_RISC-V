# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       Makefile
# \brief      Firmware build pipeline for SCHOLAR RISC-V (ELF → BIN/DUMP/HEX).
# \author     Kawanami
# \version    1.0
# \date       04/11/2025
#
# \details
#   Invokes the RISC-V GNU toolchain to compile and link firmware sources,
#   then produces:
#     - .bin  (objcopy)
#     - .dump (objdump, disassembly)
#     - .hex  (addr:data lines via makehex.py)
#   The build is parameterized by XLEN/CPU_XLEN and toolchain paths. Commands
#   are echoed into a log file for traceability.
#
#   Outputs:
#     - $(BUILD_DIR)firmware.elf / .bin / .dump / .hex
#     - Logs under $(LOG_DIR)
#
#   Flow:
#     1) Compile COMMON_FILES + FIRMWARE_FILES → .o
#     2) Link with linker script + libgcc      → firmware.elf
#     3) Convert to .bin and .dump             → objcopy/objdump
#     4) Generate flat hex "addr:word"         → makehex.py
#
# \remarks
#   - Requires a working RISC-V toolchain in $(EGCC_DIR).
#   - Uses a static libgcc from $(ELIBGCC_DIR).
#   - Python 3 is needed for scripts/makehex.py.
#   - Build, log and output paths are controlled by WORK_DIR/BUILD_DIR/LOG_DIR.
#
# \section makefile_version_history Version history
# | Version | Date       | Author     | Description         |
# |:-------:|:----------:|:-----------|:--------------------|
# | 1.0     | 04/11/2025 | Kawanami   | Initial version.    |
# | 1.1     | 11/11/2025 | Kawanami   | Update tools default directory.    |
# ********************************************************************************
# */

#################################### Firmware Toolchain ###################################
# Architecture
XLEN 					?= XLEN32
# CPU data path width
CPU_XLEN 	 			?= 32

# Root directory
ROOT_DIR 				?= $(shell pwd)/

# Path to gcc bin directory
EGCC_DIR		  		?= /opt/riscv-gnu-toolchain/$(ISA)/bin/

# gcc
ECC 					?= $(EGCC_DIR)riscv$(CPU_XLEN)-unknown-elf-gcc

# ld
ELD						?= $(EGCC_DIR)riscv$(CPU_XLEN)-unknown-elf-ld

# objdump
EOBJDUMP				?= $(EGCC_DIR)riscv$(CPU_XLEN)-unknown-elf-objdump

# objcopy
EOBJCOPY				?= $(EGCC_DIR)riscv$(CPU_XLEN)-unknown-elf-objcopy

# Path to libgcc
ELIBGCC_DIR 			?= /opt/riscv-gnu-toolchain/$(ISA)/lib/gcc/riscv$(CPU_XLEN)-unknown-elf/14.2.0/

# libgcc (static)
ELGCC					?= $(ELIBGCC_DIR)libgcc.a

# Firmware custom building tools
TOOLS_DIR  				?= $(ROOT_DIR)../../scripts/

# elf converter (to hex, format -> addr:data)
MAKE_HEX				?= $(TOOLS_DIR)makehex.py
#################################### 	 				####################################


#################################### FILES ####################################
# Firmware common files directory
COMMON_FILES_DIR		?= $(ROOT_DIR)common/

# Firmware common files
COMMON_FILES			?= $(COMMON_FILES_DIR)eprintf.c \
						  $(COMMON_FILES_DIR)memory.c \
						  $(COMMON_FILES_DIR)start.s

# Firmware linker(s) directory
LINKER_DIR				?= $(ROOT_DIR)linker/
LINKER					?= $(LINKER_DIR)linker.ld

# Firmware compiler flag
ECFLAGS  				?= -I$(COMMON_FILES_DIR) -I$(GLOBAL_DEFINES_DIR) \
						  -DITERATIONS=$(ITERATIONS) \
						  -D$(XLEN) -march=$(ISA) -mabi=$(ABI) -Wall -nostdlib \
						  -ffreestanding -O3 -ffunction-sections -fdata-sections

# Firmware linker flag
ELDFLAGS 				?= -T $(LINKER) -nostdlib -static --gc-sections

# Build directory
BUILD_DIR 				?= $(WORK_DIR)firmware/build/

# Log directory
LOG_DIR 				?= $(WORK_DIR)firmware/log/

# Output firmware filename
FIRMWARE				?=$(BUILD_DIR)firmware.hex
####################################						 ####################################


#################################### DEFAULT TARGET ####################################
default: firmware
####################################				####################################

#################################### FIRMWARE TARGET ####################################
.PHONY: firmware
firmware:

	@echo "➡️  Building firmware..."

	@for source in $(FIRMWARE_FILES); do \
		echo $(ECC) $(ECFLAGS) -c $$source -o $(BUILD_DIR)/$$(basename $$source .c).o >> $(LOG_DIR)log.txt; \
		echo "" >> $(LOG_DIR)log.txt; \
		$(ECC) $(ECFLAGS) -c $$source -o $(BUILD_DIR)/$$(basename $$source .c).o; \
	done
	@for source in $(COMMON_FILES); do \
		echo $(ECC) $(ECFLAGS) -c $$source -o $(BUILD_DIR)/$$(basename $$source .c).o >> $(LOG_DIR)log.txt; \
		echo "" >> $(LOG_DIR)log.txt; \
		$(ECC) $(ECFLAGS) -c $$source -o $(BUILD_DIR)/$$(basename $$source .c).o; \
	done

	@echo $(ELD) $(ELDFLAGS) $(BUILD_DIR)*.o $(ELGCC) -o $(BUILD_DIR)$(FIRMWARE).elf >> $(LOG_DIR)log.txt
	@echo "" >> $(LOG_DIR)log.txt
	@$(ELD) $(ELDFLAGS) $(BUILD_DIR)*.o $(ELGCC) -o $(BUILD_DIR)$(FIRMWARE).elf

	@rm -rf $(BUILD_DIR)*.o

	@echo $(EOBJCOPY) -O binary $(BUILD_DIR)$(FIRMWARE).elf $(BUILD_DIR)$(FIRMWARE).bin >> $(LOG_DIR)log.txt
	@echo "" >> $(LOG_DIR)log.txt
	@$(EOBJCOPY) -O binary $(BUILD_DIR)$(FIRMWARE).elf $(BUILD_DIR)$(FIRMWARE).bin

	@echo "$(EOBJDUMP) -D $(BUILD_DIR)$(FIRMWARE).elf > $(BUILD_DIR)$(FIRMWARE).dump" >> $(LOG_DIR)log.txt
	@echo "" >> $(LOG_DIR)log.txt
	@$(EOBJDUMP) -D $(BUILD_DIR)$(FIRMWARE).elf > $(BUILD_DIR)$(FIRMWARE).dump

	@echo "python3 $(MAKE_HEX) $(BUILD_DIR)$(FIRMWARE).elf > $(BUILD_DIR)$(FIRMWARE).hex" >> $(LOG_DIR)log.txt
	@echo "" >> $(LOG_DIR)log.txt
	@python3 $(MAKE_HEX) $(BUILD_DIR)$(FIRMWARE).elf > $(BUILD_DIR)$(FIRMWARE).hex

	@echo "" >> $(LOG_DIR)log.txt

	@echo "✅ Done."
	@echo
#################################### 			   ####################################

# Simulation Environment

This document outlines the setup and usage of the simulation environment for **SCHOLAR_RISC-V**. It provides instructions on how to configure the environment, run tests, and evaluate the performance of the RISC-V core.

> 📝
>
> The following instructions are written for **Ubuntu**. If you are using another Linux distribution, you can still follow the general steps, but you may need to make slight adjustments to install the required dependencies or tools.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 📚 Table of Contents

- [The Simulation Environment](#🧪-the-simulation-environment)
- [Required Tools](#⚙️-required-tools)
- [Running Existing Simulation](#🏃‍♂️-running-existing-simulation)
- [Running Your Own Firmwares](#🏃‍♂️-running-your-own-firmwares)
- [Known Issues](#🐞-known-issues)

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 🧪 The Simulation Environment
The simulation environment is intended to be used with **Verilator**. It is a set of files designed to load firmware into the **SCHOLAR RISC-V** instruction and data memories, and to enable communication with the core through shared memory.<br>
If you haven't seen the architecture yet, please refer to the [architecture document](../architecture/README.md). <br>
<br>

Users will find, in the header of each simulation source file, information about the file's purpose. Therefore, only a brief overview is provided here:

- **clocks_resets**: Implements utility functions to manage clock and reset signals during simulation.

- **sim**: Provides core functions for managing the simulation itself.

- **sim_log**: Offers logging utilities for simulation, primarily used for waveform analysis and debugging.

- **spike_parser**: Parses Spike logs to enable comparison between SCHOLAR RISC-V execution and Spike traces.

- **simulation_vs_spike**: Main entry point for simulating SCHOLAR RISC-V during ISA tests. This file is never compiled with simulation.cpp, but it shares the simulation.h header with it.

- **simulation**: Main entry point for simulating SCHOLAR RISC-V during all tests except the ISA tests. Like the previous one, it is never compiled alongside simulation_vs_spike.cpp, but they share the same header (simulation.h). It initializes the simulation environment and logging, then delegates execution to a user-defined run() function implemented in the platform/ directory.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## ⚙️ **Required Tools**
To successfully run the simulation and tests, the following tools are required:

- **Python3**
- **Verilator**  
- **RISC-V GNU Toolchain**  
- **Spike** (RISC-V ISA Simulator)

> 📝 A specific version is provided for each tool as a reference. Other versions may work as well, but compatibility is **not guaranteed**.<br>
>
> **Default tools location** is **/home/$USER/Desktop/tools/**. It can be changed, but the following values in the [**Makefile**](../../Makefile) must be updated:
>- **VERILATOR_DIR**: Path to the **bin** folder of Verilator.
>- **EGCC_DIR**: Path to the **bin** folder of the RISC-V GNU Toolchain.
>- **SPIKE_DIR**: Path to the **bin** folder of Spike.<br>
>
> To ensure proper installation behavior, make sure the build-essential package is installed: ```sudo apt install build-essential  ```

<br>
<br>

### Python3

Python 3, pip, and pyelftools are required to convert the compiled firmware from .elf to .hex format using the makehex.py script.<br>
To install them:
```bash
sudo apt install python3
sudo apt install python3-pip
pip3 install pyelftools
```

<br>
<br>

### Verilator
A simulator that translates Verilog code into C++ models. It’s used to run the RISC-V core simulation.

- **Version**: `5.034` (2025-02-24)  

To install Verilator, the following commands can be used:

```bash
sudo apt-get install git help2man perl python3 make autoconf g++ flex bison ccache libgoogle-perftools-dev numactl perl-doc
sudo apt-get install libfl2                   # ignore if gives error
sudo apt-get install libfl-dev                # ignore if gives error
sudo apt-get install zlibc zlib1g zlib1g-dev  # ignore if gives error

git clone https://github.com/verilator/verilator.git
cd verilator
git checkout v5.034

autoconf
./configure --prefix=/home/$USER/Desktop/tools/verilator

make -j$(nproc)

make install
```

<br>
<br>

### RISC-V GNU Toolchain
The compiler toolchain required for building software for the RISC-V architecture.

```bash
sudo apt-get install autoconf automake autotools-dev curl python3 python3-pip libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev libslirp-dev

git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
cd riscv-gnu-toolchain
git checkout 2025.01.20

./configure --prefix=/home/$USER/Desktop/tools/rv32i_zicntr/ --with-arch=rv32i_zicntr --with-abi=ilp32 

make -j$(nproc)
```

> ⚠️ Be aware that this specific compilation of the RISC-V GNU toolchain will only support RV32I_Zicntr, and will not be able to compile software for more advanced versions of the SCHOLAR_RISC-V, which may include support for multiplication, atomic operations, or floating point instructions.

<br>
<br>

### Spike – RISC-V ISA Simulator  
Spike is the official simulator for the RISC-V instruction set architecture (ISA).  
It’s used for verifying and comparing core functionality against a trusted reference model.

```bash
apt-get install device-tree-compiler libboost-regex-dev libboost-system-dev

git clone https://github.com/riscv-software-src/riscv-isa-sim.git
cd riscv-isa-sim

mkdir build
cd build
../configure --prefix=/home/$USER/Desktop/tools/spike/

make -j$(nproc)

make install
```

> ⚠️ Spike log format may vary across versions. To ensure compatibility with the simulation environment, it is recommended to strictly use the version provided by the previous commands.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 🏃‍♂️ Running Existing Simulation 
The simulation environment includes pre-configured tests that can be easily executed to validate the functionality and performances of the RISC-V core.

<br>
<br>

### Running ISA Tests
To validate the RISC-V core's implementation of individual instructions, **ISA** tests are run. These tests perform unit checks on the functionality of each instruction to ensure proper execution and accuracy.<br>
<br>

To run the **ISA** tests, use the following command:

```bash
make isa
```

**ISA** log will be available in **work/isa/log/**.

<br>
<br>

### Running the Loader Test
The loader firmware test is designed to verify the correct behavior of firmware loading into the RISC-V instruction and data memories. <br>
<br>

This test also checks the functionality of the **eprintf** (embedded printf), which writes strings and integer values—similar to a standard printf—into shared memory.
These messages are then retrieved by the platform software and displayed in the console using a classic printf.

To run the loader test, use the following command:
```bash
make loader
```

<br>
<br>

### Running the Repeater Test
The repeater firmware test is designed to verify the proper communication between the platform software and the RISC-V core through shared memory.<br>
<br>

From the platform software console, you can input data that will be written into the platform-to-core shared memory.
The firmware running on the core will read this data and write it back into the core-to-platform memory.
The platform software will then read and display this returned data, validating the full communication loop.

To run the repeater test, use the following command:
```bash
make repeater
```

<br>
<br>

### Running The CycleMark Test
**CycleMark** is based on the CoreMark benchmark, which is designed to evaluate the performance of microcontroller-class processors (see [CycleMark Benchmarking](../benchmarking/CycleMark/)).  
It provides a standardized and architecture-neutral way to measure how efficiently a processor handles common computational tasks such as list processing, matrix operations, and state machine control.<br>

<br>

To run the **CycleMark** test, use the following command:

```bash
make cyclemark
```

**CycleMark** log will be available in **work/cyclemark/log/**.

see the [CycleMark Benchmarking](../benchmarking/CycleMark/) documentation to get information on how analyze **CycleMark** log.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 🏃‍♂️ Running Your Own Firmwares

<br>
<br>

### 📁 Create your firmware directory with your firmware name

In the [**firmware**](../../software/firmware/) directory, copy and paste the [**repeater**](../../software/firmware/repeater/) folder and rename it with the name of your firmware.  
You can modify the content of the directory with your own source files, **except for `start.s`**, which must remain unchanged as it contains essential startup code required for correct execution.

<br>
<br>

### 📁 Create the platform directory with your firmware name

In the [**platform**](../../software/platform/) directory, copy and paste the [**repeater**](../../software/platform/repeater/) folder and rename it with the name of your firmware.  
You can rename the `repeater.c` file to include your own code and, if needed, add other files.

> ⚠️ **Important**: Do not modify `repeater.c` except within the `main` loop, **after the `// User can modify program from here.`** comment.  
> This structure ensures proper inclusion of headers and functions needed to load your firmware into the core, maintaining compatibility with both the simulation environment and the PolarFire SoC-FPGA setup.

<br>
<br>
 
### 🛠️ Modify the main Makefile

For the simulation, the last element to modify is the **Makefile**.

Locate the section:
```
#################################### REPEATER simulation parameters ####################################
```

Copy and paste the entire set of parameters into a new section and replace the word **REPEATER** with your firmware name (in this example, the name is **custom**):
```
#################################### CUSTOM simulation parameters ####################################
# CUSTOM log directory
CUSTOM_LOG_DIR          = $(WORK_DIR)custom/log/

# CUSTOM build directory
CUSTOM_BUILD_DIR        = $(WORK_DIR)custom/build/

# CUSTOM platform directory
PLATFORM_CUSTOM_DIR     = $(PLATFORM_DIR)custom/

# CUSTOM platform files
PLATFORM_CUSTOM_FILES   = $(wildcard $(PLATFORM_CUSTOM_DIR)*.c $(PLATFORM_CUSTOM_DIR)*.cpp)

# CUSTOM firmware directory
FIRMWARE_CUSTOM_DIR     = $(FIRMWARE_DIR)custom/

# CUSTOM firmware files
FIRMWARE_CUSTOM_FILES   = $(wildcard $(FIRMWARE_CUSTOM_DIR)*.c $(FIRMWARE_CUSTOM_DIR)*.s)

# CUSTOM firmware compiler flags
FIRMWARE_CUSTOM_ECFLAGS = -I$(FIRMWARE_COMMON_FILES_DIR) -I$(FIRMWARE_DIR)../                         -march=rv32i_zicntr -mabi=ilp32 -Wall -nostdlib -ffreestanding -O3 -ffunction-sections -fdata-sections

# CUSTOM firmware linker flags
FIRMWARE_CUSTOM_ELDFLAGS = -T $(FIRMWARE_LINKER_DIR)linker.ld -nostdlib -static --gc-sections
####################################                              ####################################
```

<br>
<br>

Next, locate the section:
```
#################################### REPEATER ####################################
```

Copy and paste the entire target into a new section and replace the word **REPEATER** with your firmware name (in this example, the name is **custom**):
```
#################################### CUSTOM ####################################
.PHONY: custom_firmware
custom_firmware: work

	@echo "➡️  Building custom firmware..."

	@mkdir -p $(CUSTOM_BUILD_DIR)
	@mkdir -p $(CUSTOM_LOG_DIR)

	@for source in $(FIRMWARE_CUSTOM_FILES); do \
		echo $(ECC) $(FIRMWARE_CUSTOM_ECFLAGS) -c $$source -o $(CUSTOM_BUILD_DIR)/$$(basename $$source .c).o >> $(CUSTOM_LOG_DIR)log.txt; \
		$(ECC) $(FIRMWARE_CUSTOM_ECFLAGS) -c $$source -o $(CUSTOM_BUILD_DIR)/$$(basename $$source .c).o; \
	done 
	@for source in $(FIRMWARE_COMMON_FILES); do \
		echo $(ECC) $(FIRMWARE_CUSTOM_ECFLAGS) -c $$source -o $(CUSTOM_BUILD_DIR)/$$(basename $$source .c).o >> $(CUSTOM_LOG_DIR)log.txt; \
		$(ECC) $(FIRMWARE_CUSTOM_ECFLAGS) -c $$source -o $(CUSTOM_BUILD_DIR)/$$(basename $$source .c).o; \
	done

	@echo $(ELD) $(FIRMWARE_CUSTOM_ELDFLAGS) $(CUSTOM_BUILD_DIR)*.o $(ELGCC) -o $(CUSTOM_BUILD_DIR)firmware.elf >> $(CUSTOM_LOG_DIR)log.txt
	@$(ELD) $(FIRMWARE_CUSTOM_ELDFLAGS) $(CUSTOM_BUILD_DIR)*.o $(ELGCC) -o $(CUSTOM_BUILD_DIR)firmware.elf
	
	@echo $(EOBJCOPY) -O binary $(CUSTOM_BUILD_DIR)firmware.elf $(CUSTOM_BUILD_DIR)firmware.bin >> $(CUSTOM_LOG_DIR)log.txt
	@$(EOBJCOPY) -O binary $(CUSTOM_BUILD_DIR)firmware.elf $(CUSTOM_BUILD_DIR)firmware.bin

	@echo "$(EOBJDUMP) -D $(CUSTOM_BUILD_DIR)firmware.elf > $(CUSTOM_BUILD_DIR)firmware.dump" >> $(CUSTOM_LOG_DIR)log.txt
	@$(EOBJDUMP) -D $(CUSTOM_BUILD_DIR)firmware.elf > $(CUSTOM_BUILD_DIR)firmware.dump

	@echo "python3 $(MAKE_HEX) $(CUSTOM_BUILD_DIR)firmware.elf > $(CUSTOM_BUILD_DIR)firmware.hex" >> $(CUSTOM_LOG_DIR)log.txt
	@python3 $(MAKE_HEX) $(CUSTOM_BUILD_DIR)firmware.elf > $(CUSTOM_BUILD_DIR)firmware.hex

	@echo "✅ Done. See $(CUSTOM_LOG_DIR)log.txt for details."
	@echo

.PHONY: custom
custom: custom_firmware

	@echo "➡️  Building Design Under Test..."
	@echo $(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_COMMON_FILES) $(PLATFORM_CUSTOM_FILES) > $(VERILATOR_LOG_DIR)log.txt

	@$(SIMULATOR) $(SIM_FLAGS) -cc $(SIM_HDL_DIR)*.*v -Wall --Mdir $(VERILATOR_BUILD_DIR) --trace --assert --top-module $(TOP) \
	--exe $(COMMON_SIM_FILES) $(SIM) $(PLATFORM_COMMON_FILES) $(PLATFORM_CUSTOM_FILES) >> $(VERILATOR_LOG_DIR)log.txt

	@echo make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt

	@make --no-print-directory -C $(VERILATOR_BUILD_DIR) -f V$(TOP).mk V$(TOP) CXXFLAGS=$(SIM_CXXFLAGS) >> $(VERILATOR_LOG_DIR)log.txt
	@echo "✅ Done. See $(VERILATOR_LOG_DIR)log.txt for details."
	@echo


	@echo "➡️  Running simulation..."
	@echo Running custom... >> $(CUSTOM_LOG_DIR)log.txt
	@echo >> $(CUSTOM_LOG_DIR)log.txt

	@$(VERILATOR_BUILD_DIR)V$(TOP) --logfile $(CUSTOM_LOG_DIR)log.txt --waveform $(CUSTOM_LOG_DIR)waveform.vcd \
	--firmware $(CUSTOM_BUILD_DIR)firmware.hex

	@echo >> $(CUSTOM_LOG_DIR)log.txt

	@echo Done. >> $(CUSTOM_LOG_DIR)log.txt

	@echo >> $(CUSTOM_LOG_DIR)log.txt

	@echo "✅ Done. See $(CUSTOM_LOG_DIR)log.txt for details."
	@echo

.PHONY: clean_custom
clean_custom:
	@echo "➡️  Cleaning custom directories..."
	@rm -rf $(CUSTOM_BUILD_DIR)
	@rm -rf $(CUSTOM_LOG_DIR)
	@echo "✅ Done."
####################################		####################################
```

<br>
<br>

You are now ready to use your custom firmware in the simulation environment running (for our example) **make custom**.

<br>
<br>

---

## 🐞 Known Issues

<br>
<br>

---
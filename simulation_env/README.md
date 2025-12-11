# Simulation Environment

This document describes how to set up and use the simulation environment for **SCHOLAR_RISC-V**. It covers prerequisites, typical runs (ISA, loader, echo, CycleMark), and how to plug in your own firmware.

> 📝
>
> The following instructions are written for **Ubuntu 20.04 LTS and Ubuntu 24.04 LTS**. If you are using another Linux distribution or version, you can still follow the general steps, but you may need to make slight adjustments to install the required dependencies or tools.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Table of Contents

- [The Environment](#the-environment)
- [Required Tools](#required-tools)
- [Running Existing Simulation](#running-existing-simulation)
- [Running Your Own Firmware](#running-your-own-firmware)
- [Known Issues](#known-issues)

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## The Environment
The provided environment can be used to build and simulate the RISC-V. It is intended to be used with **Verilator**. It is a set of files designed to load firmware into the **SCHOLAR RISC-V** instruction and data memories, and to enable communication with the core through shared memory.<br>

This environment is available in the different branches of the project, each one corresponding to a specific feature.<br>

Users will find, in the header of each file, information about the file's purpose. Therefore, only a brief overview is provided here:

- **hardware**  
  Main directory holding the RTL design of the SCHOLAR RISC-V core as well as its environment.

  - **core**  
  Verilog source files implementing the SCHOLAR RISC-V processor core.

  - **env**  
  Environment used to simulate and validate the core's functionality.

- **software**  
  Contains both the firmware runnable on the SCHOLAR RISC-V core and the host-side tools to interact with the environment.

  - **firmware**  
  Bare-metal firmware to run on the SCHOLAR RISC-V core.

  - **platform**  
  Host-side software used to communicate with or control the simulation or FPGA platform.

- **simulation**  
  C++-based simulation infrastructure used to:
  - Compare the SCHOLAR RISC-V core execution against **Spike** (the official RISC-V ISA simulator).  
  - Run standalone firmware binaries for functional and performance evaluation.

- **scripts**  
  Usefull scripts use to format files, generate documentations, generate and .hex firmware from an .elf one, etc.

- **img**  
  Images used in the README.md of the branch.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## **Required Tools**
To successfully run the simulation and tests, the following tools are required:

- **Python3**: To convert the compiled firmware from .elf to .hex format using the makehex.py script
- **Verilator**: A simulator that translates Verilog code into C++ models. It’s used to run the RISC-V core simulation.  
- **RISC-V GNU Toolchain**: The compiler toolchain required for building software for the RISC-V architecture.  
- **Spike**: Spike is the official simulator for the RISC-V instruction set architecture (ISA).  
It’s used for verifying and comparing core functionality against a trusted reference model.

These tools can be installed using the provided Makefile target:
```bash
make install_sim_env
```

> 📝 The installation of the tools is done in **/opt**. Thus, root privileges are required.<br>
> Multiple version of the RISC-V GNU toolchain may be installed, to support all the SCHOLAR RISC-V microarchitectures.

> ⚠️ Verilator pre-processing directives may vary across versions. To ensure compatibility with the HDL, it is recommended to strictly install verilator through the install script. <br>
> Spike log format may vary across versions. To ensure compatibility with the simulation, it is recommended to strictly install spike through the install script.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Running Existing Simulation 
The environment includes pre-configured tests that can be easily executed to validate the functionality and performance of the RISC-V core.<br>

From now, the following command must be executed in one of the different branches of the project, such as the **Single-Cycle**.

<br>
<br>

### Running ISA Tests
To validate the RISC-V core's implementation of individual instructions, **ISA** tests are run. These tests perform unit checks on the functionality of each instruction to ensure proper execution and accuracy.<br>

To run the **ISA** tests, use the following command:

```bash
make isa
```

<br>
<br>

### Running the Loader Test
The loader firmware test is designed to verify the correct behavior of firmware loading into the RISC-V instruction and data memories. <br>
<br>

This test also checks the functionality of the **eprintf** (embedded printf), which writes strings and integer values—similar to a standard printf—into shared memory.<br>
These messages are then retrieved by the platform software and displayed in the console using a classic printf.<br>

To run the loader test, use the following command:
```bash
make loader
```

<br>
<br>

### Running the Echo Test
The echo firmware test is designed to verify the proper communication between the platform software and the RISC-V core through shared memory.<br>

From the platform software console, you can input data that will be written into the platform-to-core shared memory.<br>
The firmware running on the core will read this data and write it back into the core-to-platform memory.<br>
The platform software will then read and display this returned data, validating the full communication loop.

To run the echo test, use the following command:
```bash
make echo
```

<br>
<br>

### Running The CycleMark Test
**CycleMark** is based on the CoreMark benchmark, which is designed to evaluate the performance of microcontroller-class processors (see [CycleMark Benchmarking](../benchmarking/CycleMark/)).<br>
It provides a standardized and architecture-neutral way to measure how efficiently a processor handles common computational tasks such as list processing, matrix operations, and state machine control.<br>

To run the **CycleMark** test, use the following command:

```bash
make cyclemark
```

see the [CycleMark Benchmarking](../benchmarking/CycleMark/) documentation to get information on how analyze **CycleMark** log.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Running Your Own Firmware

<br>
<br>

### Create your firmware directory with your firmware name

In the **firmware** directory, copy and paste the **echo** folder and rename it with the name of your firmware. <br>
You can modify the content of the directory with your own source files.

<br>
<br>

### The platform directory

In the **platform** directory, you will find a **platform.cpp** file which has two purposes:
-	Load your firmware into the RISC-V core,
-	Allow communication by checking stdin and displaying messages from the softcore.

This file can be modified, but its functions already provide enough features run and communicate with your firmware.

<br>
<br>
 
### Modify the Makefile

The last element to modify is the **Makefile**. You can use **echo** as example.<br>

Locate the section:
```
#################################### Directories ####################################
```

Add your firmware directory:
```bash
# custom_firmware directory
CUSTOM_FIRMWARE_DIR   						= $(FIRMWARE_DIR)custom_firmware/
```
<br>

Then, locate the section:
```
#################################### Files ####################################
```

You can add here your firmware files:
```bash
# custom firmware files
CUSTOM_FIRMWARE_FILES 						= $(CUSTOM_FIRMWARE_DIR)main.c \
											              $(CUSTOM_FIRMWARE_DIR)custom.c
```
<br>

To finish, locate the section:
```
#################################### TARGETS ####################################
```

Add a target to build your firmware and run the simulation:
```bash
# custom firmware target
.PHONY: custom_firmware
custom_firmware: work # call work to build the work env
custom_firmware: FIRMWARE_FILES=$(CUSTOM_FIRMWARE_FILES) # Set firmware files to build
custom_firmware: FIRMWARE=custom # Set the firmware name (will build custom.hex)
custom_firmware: firmware # Call the firmware builder

# Echo target
.PHONY: custom
custom: FIRMWARE=custom_firmware # Use the firmware name for log files (custom_firmware.log/vcd)
custom: dut custom_firmware # Build the simulation and the firmware
custom: run # Run the simulation
```

<br>
<br>

You are now ready to use your custom firmware in the simulation environment running (for our example) **make custom**.

<br>
<br>

---

## Known Issues

<br>
<br>

---
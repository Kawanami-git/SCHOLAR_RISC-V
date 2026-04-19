# Simulation Environment

This document explains how to use the simulation environment for **SCHOLAR_RISC-V**. It covers common test runs (ISA, loader, echo, and CycleMark), and how to integrate your own firmware.

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
- [Running Existing Simulations](#running-existing-simulations)
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

The provided environment can be used to build and simulate the RISC-V core. It is intended to be used with **Verilator**. It consists of a set of files designed to load firmware into the **SCHOLAR RISC-V** instruction and data memories, and to enable communication with the core through shared memory.

This environment is available in the different branches of the project, each branch corresponding to a specific feature.

Users will find, in the header of each file, information about the file's purpose. Therefore, only a brief overview is provided here:

- **hardware**  
  Main directory containing the RTL design of the **SCHOLAR RISC-V** core and its environment.

  - **core**  
    Verilog source files implementing the **SCHOLAR RISC-V** processor core.

  - **env**  
    Environment used to simulate and validate the core's functionality.

- **software**  
  Contains both the firmware running on the **SCHOLAR RISC-V** core and the host-side tools used to interact with the environment.

  - **firmware**  
    Bare-metal firmware intended to run on the **SCHOLAR RISC-V** core.

  - **platform**  
    Host-side software used to communicate with or control the simulation or FPGA platform.

- **simulation**  
  C++-based simulation infrastructure used to:
  - compare the **SCHOLAR RISC-V** core execution against **Spike** (the official RISC-V ISA simulator),
  - run standalone firmware binaries for functional and performance evaluation.

- **mk**
  Set of Makefiles included by the top-level Makefile to build the design, compile firmware and run simulation.

- **scripts**  
  Useful scripts used to format files, generate documentation, generate a `.hex` firmware image from an `.elf` file, and more.

- **img**  
  Images used in the branch `README.md`.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>


## Running Existing Simulations

The environment includes preconfigured tests that can be executed easily to validate the functionality and performance of the RISC-V core.

The following commands must be executed from one of the project branches, such as the **Single-Cycle** branch.

<br>
<br>

### Running ISA Tests

To validate the RISC-V core implementation instruction by instruction, **ISA** tests are provided. These tests perform unit-level checks on each instruction to ensure correct execution.

To run the **ISA** tests, use the following command:

```bash
make isa
```

<br>
<br>

### Running the Loader Test

The loader firmware test is designed to verify the correct loading of firmware into the RISC-V instruction and data memories.

This test also checks the functionality of **eprintf** (embedded `printf`), which writes strings and integer values into shared memory, similarly to a standard `printf`. These messages are then retrieved by the platform software and displayed in the console using a regular `printf`.

To run the loader test, use the following command:

```bash
make loader
```

<br>
<br>

### Running the Echo Test

The echo firmware test is designed to verify communication between the platform software and the RISC-V core through shared memory.

From the platform software console, you can input data that will be written into the platform-to-core shared memory. The firmware running on the core reads this data and writes it back into the core-to-platform shared memory. The platform software then reads and displays the returned data, validating the full communication loop.

To run the echo test, use the following command:

```bash
make echo
```

<br>
<br>

### Running the CycleMark Test

**CycleMark** is based on the **CoreMark** benchmark, which is designed to evaluate the performance of microcontroller-class processors (see [CycleMark Benchmarking](https://github.com/Kawanami-git/SCHOLAR_RISC-V/tree/main/benchmarking/CycleMark)). It provides a standardized and architecture-neutral way to measure how efficiently a processor handles common computational tasks such as list processing, matrix operations, and state-machine control.

To run the **CycleMark** test, use the following command:

```bash
make cyclemark
```

See the [CycleMark Benchmarking](https://github.com/Kawanami-git/SCHOLAR_RISC-V/tree/main/benchmarking/CycleMark) documentation for information on how to analyze **CycleMark** logs.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Running Your Own Firmware

### Create Your Firmware Directory

In the **firmware** directory, copy the **echo** folder and rename it to match your firmware name.

You can then modify the contents of this directory with your own source files.

<br>
<br>

### The Platform Directory

In the **platform** directory, you will find a **platform.cpp** file, which has two purposes:

- load your firmware into the RISC-V core,
- allow communication by checking `stdin` and displaying messages from the softcore.

This file can be modified, but its existing features are already sufficient to run and communicate with your firmware.

<br>
<br>

### Modify `common.mk`

`common.mk` is available in the **mk** directory. You can use **echo** as an example.

Locate the following section:

```text
#################################### Directories ####################################
```

Add your firmware directory:

```make
# custom_firmware directory
CUSTOM_FIRMWARE_DIR = $(FIRMWARE_DIR)custom_firmware/
```

Then locate the following section:

```text
#################################### Files ####################################
```

Add your firmware files there:

```make
# custom firmware files
CUSTOM_FIRMWARE_FILES = $(CUSTOM_FIRMWARE_DIR)main.c \
                        $(CUSTOM_FIRMWARE_DIR)custom.c
```

Finally, add a target to build your firmware and run the simulation:

```make
# custom firmware target
.PHONY: custom_firmware
custom_firmware: firmware_work
custom_firmware: FIRMWARE_FILES=$(CUSTOM_FIRMWARE_FILES)
custom_firmware: FIRMWARE=custom
custom_firmware: firmware
```

<br>
<br>

### Modify `sim.mk`

The last file to modify is **sim.mk**, also located in the **mk** directory.

Only one additional target is required. This target will build your firmware and the design under test (by calling `custom_firmware` and `dut`) and then run the simulation.

```make
# Custom target
.PHONY: custom
custom: FIRMWARE=custom_firmware
custom: dut custom_firmware
custom: run
```

You are now ready to use your custom firmware in the simulation environment by running:

```bash
make custom
```

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Known Issues

No known issue is currently documented in this section.

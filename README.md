# SCHOLAR_RISC-V

A pedagogical journey into CPU architecture through RISC-V.

![SCHOLAR_RISC-V_architecture](./docs/architecture/img/SCHOLAR_RISC-V_architecture.png)

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 📚 Table of Contents

- [License](#📜-license)
- [Terminology & Vocabulary](#🧾-terminology-&-vocabulary)
- [Overview](#🧠-overview)
- [Current Architecture, Limitations and Next Steps](#🏗️-current-architecture-limitations-and-next-steps)
- [Project Organization](#🧭-project-organization)
- [Structure](#📂-structure)
- [Documentation](#📚-documentation)
- [Dependencies](#📦-dependencies)
- [Quick Start](#🚀-quick-start)
- [Available Makefile Commands](#🛠️-available-makefile-commands)
- [Known Issues](#🐞-known-issues)

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 📜 License

This project is licensed under the **MIT License** – see the [LICENSE](LICENSE) file for details.

However, part of this repository (**CycleMark**) is derived from the **CoreMark** repository, which is distributed under its own license. You can find the original license and related notices in the [CycleMark](docs/benchmarking/CycleMark/) directory.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 🧾 Terminology & Vocabulary

| Term                                   | Definition                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **RISC-V**                             | A free and open standard Instruction Set Architecture (ISA) based on the principles of Reduced Instruction Set Computing (RISC). The "V" stands for the fifth major RISC architecture generation.                                          |
| **ISA (Instruction Set Architecture)** | The set of instructions supported by the processor (e.g., RV32I, RV32IM).                        |
| **Microarchitecture**                  | The specific implementation of the ISA (e.g., pipeline stages, forwarding, buffers).             |
| **Frequency (MHz)**                    | Clock speed: number of cycles per second. Higher frequency generally means faster execution.     |
| **IPC (Instructions Per Cycle)**       | Average number of instructions a processor can execute per clock cycle.                          |
| **Core**                               | An independent processing unit capable of executing instructions.                                |
| **GPR**                                | General Purpose Registers.                                                                       |
| **CSR**                                | Control and Status Registers.                                                                    |
| **single-port**                        | A system with a single access port — only one operation (read or write) can occur at a time.     |
| **dual-port**                          | A system with a two access port — Two operations (read or write) can occur at a time.            |
| **Monocycle**                          | A design where each instruction completes all its stages in a single clock cycle.                |
| **Pipeline**                           | Execution is divided into multiple stages; multiple instructions are overlapped in execution.    |
| **Data Hazard**                        | Situation where instructions depend on the results of previous instructions still in execution.  |
| **Bypass**                             | Technique to forward data directly between pipeline stages to avoid data hazards.                |
| **Branch**                             | 	Instruction that can change the flow of program execution (e.g., if, goto, loops).              |
| **Branch Prediction**                  | Mechanism to guess the outcome of a branch to avoid pipeline stalls.                             |
| **In Order Execution**                 | Instructions are fetched, executed, and completed in the exact order they appear in the program. |
| **Out Of Order Execution**             | Instructions can be executed as soon as operands are ready, not necessarily in program order.    |
| **Register Renaming**                  | Technique to eliminate false data dependencies by using additional physical registers.           |
| **Single-issue**                       | Architecture that issues (fetch/decode/execute) only one instruction per cycle.                  |
| **Multi-issue**                        | Architecture that can issue multiple instructions per cycle (e.g., superscalar).                 |
| **Perfect memory**                     | Simplified model assuming memory always responds in a single cycle (no cache/memory delay).      |
| **Cache**                              | Very fast memory placed between the CPU and main memory to reduce access latency.                |
| **Threads**                            | Independent software execution flows.                                                            |
| **CycleMark/MHz**                      | Performance metric showing the core computation efficiency.                                      |

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 🧠 Overview

**SCHOLAR_RISC-V** is a learning-oriented project designed to guide you step-by-step through the inner workings of a processor, using the **RISC-V architecture** as a foundation.

This repository serves both as a reference and a hands-on exploration of processor design, architecture, and optimization.

The current version represents the most basic implementation of the core — intended as a solid foundation for future enhancements.
It is a **monocycle** and **single-issue** design that supports only the **RV32I instruction set, along with the mcycle CSR** (used for CycleMark benchmarking).<br>
This reflects the minimum functional and performance baseline that a RISC-V core can offer, and serves as the perfect starting point for exploring architectural improvements.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 🏗️ Current Architecture, Limitations and Next Steps

Please refer to the [architecture](docs/architecture/README.md) document for detailed information about the current architecture and what causes its limitations.

<br>
<br>

### Current Architecture

The current architecture represents the most basic implementation of a processor.<br>
It follows a straightforward 4-steps process to execute instructions, without any performance optimizations or parallelism.

It is a **monocycle, single-issue RISC-V core** that supports only the minimal instruction set required to run a program — namely, **RV32I plus the mcycle CSR** (used for CycleMark benchmarking).<br>
For now, and to simplify the learning path, we assume that memory is ideal — able to deliver any instruction or data in a single cycle. Therefore, no cache is currently required.<br>
This assumption is mostly valid for microcontroller-class processors, which typically do not implement complex memory hierarchies.<br>

This version of the processor serves as the starting point of the project and will be progressively enhanced.

<br>
<br>

### Limitations

The current core has the following limitations:

| Max Frequency (MHz) | CycleMark/MHz | Number of Supported Threads |
|---------------------|--------------|-----------------------------|
| 55                  | 1.24         | 1                           |

<br>

Comparison data (CoreMark scores, which CycleMark is derived from) can be found here: [ARM Cortex-M Comparison Table](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/Cortex-A%20R%20M%20datasheets/Arm%20Cortex-M%20Comparison%20Table_v3.pdf).
<br>
<br>

### Next Setps

The first step toward improvement will focus on **reducing the critical path and increasing the maximum operating frequency by inserting additional synchronous elements into the core**.<br>
This technique is known as **pipelining**.

There are two main reasons for this choice:

- First, in my opinion, frequency optimization is the best illustration of the principle that everything comes with a cost. It can be silicon area, power consumption, design complexity, or other trade-offs. We will see that improving frequency has many consequences. Fortunately, as we will see, these challenges can be addressed with appropriate architectural techniques.

- Second, once the frequency has been optimized in a first pass (we will later see that several optimization steps will be needed to reach ~300 MHz), any further enhancements like IPC or instruction set extensions will have a more significant impact — especially since frequency is often the first victim of these upgrades.

---

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 🧭 Project Organization

The repository follows a microarchitecture-based branching model:

- The main branch contains the most advanced version of the RISC-V core, including the latest validated microarchitecture improvements.

- ISA (Instruction Set Architecture) features will not have dedicated branches, as they are independent of the microarchitecture and can be integrated into any implementation developed throughout the project.
Each branch will explicitly specify the supported ISA.

- Branches correspond to specific development steps. Each one isolates a particular microarchitectural enhancement, making it easy to understand design trade-offs and follow the core’s evolution.

- Additional branches may exist for specialized adaptations (e.g., embedded or resource-constrained versions).

- Tags are used to mark major milestones or stable releases for easier navigation and version tracking.

<br>
<br>

### 📊 **Branch Summary**

| **Branch Name** | **Features**  | **CycleMark/MHz** | **FPGA Resources & Performances (PolarFire MPFS095T)**  |
|-----------------|---------------|------------------|---------------------------------------------------------|
| `main (monocycle)` | - Monocycle and single-issue RISC-V core<br>- RV32I + mcycle (Zicntr) | 1.24 | - LEs: 3020 (1061 as FFs)<br>- Fmax: 55MHz<br>- uSRAM: 0<br>- LSRAM: 0<br> - Math blocks: 0       |
| `monocycle`        | - Monocycle and single-issue RISC-V core<br>- RV32I + mcycle (Zicntr) | 1.24 | - LEs: 3020 (1061 as FFs)<br>- Fmax: 55MHz<br>- uSRAM: 0<br>- LSRAM: 0<br> - Math blocks: 0       |

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 📂 Structure

- **[`docs/`](./docs/)**  
  Contains all the detailed documentation for the project, including setup guides, architecture diagrams, and usage instructions.

- **[`hardware/`](./hardware/)**  
  Main directory holding the RTL design of the SCHOLAR RISC-V core as well as its environment.

  - **[`core/`](./hardware/core/)**  
  Verilog source files implementing the SCHOLAR RISC-V processor core.

  - **[`env/`](./hardware/env/)**  
  Environment used to simulate and validate the core's functionality.

- **[`software/`](./software/)**  
  Contains both the firmwares runnable on the SCHOLAR RISC-V core and the host-side tools to interact with the environment.

  - **[`firmware/`](./software/firmware/)**  
  Bare-metal firmwares to run on the SCHOLAR RISC-V core.

  - **[`platform/`](./software/platform/)**  
  Host-side softwares used to communicate with or control the simulation or FPGA platform.

- **[`simulation/`](./simulation/)**  
  C++-based simulation infrastructure used to:
  - Compare the SCHOLAR RISC-V core execution against **Spike** (the official RISC-V ISA simulator).  
  - Run standalone firmware binaries for functional and performance evaluation.

- **[`MPFS_DISCOVERY_KIT/`](./MPFS_DISCOVERY_KIT/)**  
  Set of files allowing to synthesize and test the SCHOLAR RISC-V on the MPFS_DISCOVERY_KIT board from Microchip. <br> 
  👉 See the [`Hardware Integration`](./docs/hardware_integration/) section for more details.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 📚 Documentation

The detailed documentation for the project is located in the **[`docs/`](./docs/)** folder at the root of the repository.

In the **[`docs/`](./docs/)** directory, you will find:

- **[Architecture Overview](./docs/architecture/)**: A comprehensive guide to the design decisions and the structure of the RISC-V core and its environment.
- **[Simulation Environment](./docs/simulation_environment/)**: Step-by-step instructions on how to set up the simulation environment and run tests.
- **[Benchmarking](./docs/benchmarking/)**: Detailed information about the CycleMark benchmark and how to interpret its results.
- **[Hardware Integration](./docs/hardware_integration/)**: Guides on how to integrate the RISC-V core with different boards and generate the corresponding bitstream.

To explore the documentation, simply navigate to the **[`docs/`](./docs/)** folder and browse through the available resources.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 📦 Dependencies

This project was developed on **Ubuntu 20.04 LTS** to ensure compatibility with Microchip’s toolchain.<br>
Few adjustments have been made to also make it work on **Ubuntu 24.04 LTS**.
Other Ubuntu versions will work fine for simulation purposes.<br>
However, to build the bitstream and perform real-case tests on the Microchip PolarFire SoC/FPGA (MPFS DISCOVERY KIT), the Ubuntu version must match the supported ones — **Ubuntu 20.04 LTS** and **Ubuntu 24.04 LTS**.

<br>
<br>

### Simulation Environment

To run any simulation, the following tools are required:

- **Ubuntu packages** `sudo apt install git build-essential libflac-dev python3 python3-pip python3-tk device-tree-compiler autoconf make g++ flex bison libfl2 libfl-dev zlib1g-dev help2man automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk texinfo gperf libtool patchutils bc libexpat-dev ninja-build cmake libglib2.0-dev libslirp-dev repo`

- **Python3 modules** `pip3 install pyelftools` (**Ubuntu 20.04**) or `sudo apt install python3-pyelftools` (**Ubuntu 24.04**)

- **Verilator** version `5.034` (2025-02-24)  

- **RISC-V GNU Toolchain** version `14.2.0` (2025.01.20)

To run ISA tests, the following tools are required:

- **Spike – RISC-V ISA Simulator** version `dev master`

For more information on how to set up and use the simulation environment, refer to the [Simulation Environment](./docs/simulation_environment/) documentation.


> 📝 The given versions are provided as a reference.  
> It may also work with other versions, but compatibility is not guaranteed.

<br>
<br>

### PolarFire SoC-FPGA (Microchip)

To synthesize the SCHOLAR RISC-V core and its environment for the **PolarFire SoC-FPGA** family, the following **Microchip tools** are required:

- [Libero SoC Design Suite](https://www.microchip.com/en-us/products/fpgas-and-plds/fpga-and-soc-design-tools/fpga/libero-software-later-versions) used for FPGA design, place & route, and bitstream generation.

-	[SoftConsole](https://www.microchip.com/en-us/products/fpgas-and-plds/fpga-and-soc-design-tools/soc-fpga/softconsole): Required for HSS compilation.

-	The Linux **dd** command  : Required to flash the Linux image onto a SD card.

- The Linux **ssh** command :  Required to communicate with the board over SSH.


Once installed, you can build the core and its environment using the Makefile.  
For detailed steps, refer to the [Hardware Integration](./docs/hardware_integration/) section.

> ⚠️ **Libero requires Ubuntu 20.04 LTS or Ubuntu 24.04 LTS to function properly.**
> Other versions may not be officially supported or may require workarounds.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 🚀 Quick Start

To get started, clone the repository and navigate to the RISC-V simulation directory:
```bash
git clone --recurse-submodules https://github.com/Kawanami-git/SCHOLAR_RISC-V.git
cd SCHOLAR_RISC-V/
```

You can then choose between the following options:

🧪 Run the ISA tests
```bash
make isa
```

📥 Run the loader firmware
```bash
make loader
```

🔁 Run the repeater firmware
```bash
make repeater
```

⏱️ Run the CycleMark benchmark
```bash
make cyclemark
```
> ⚠️ The CycleMark simulation may take a significant amount of time. Please do not interrupt it until it completes normally or times out.

<br>

> 📝 
>
> Make sure all dependencies listed above are properly installed.

For more information about this environment and its capabilities, please refer to the [simulation documentation](docs/simulation_environment/README.md) and the [hardware integration documentation](docs/hardware_integration/).

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 🛠️ Available Makefile Commands

Below is the list of available make targets to build, test, and interact with the SCHOLAR RISC-V core and the MPFS Discovery Kit.

<br>
<br>

### Simulation

- **make dut**<br>
➤ Builds the Design Under Test (i.e., the SCHOLAR RISC-V core and its simulation environment) without running any test.

- **make isa**<br>
➤ Runs the ISA tests.

- **make clean_isa**<br>
➤ Cleans the ISA test working directory.

- **make loader**<br>
➤ Runs the loader firmware test to validate memory initialization and the embedded printf functionality.

- **make clean_loader**<br>
➤ Cleans the loader test working directory.

- **make repeater**<br>
➤ Runs the repeater firmware test, which echoes data sent to the core (loopback behavior).

- **make clean_repeater**<br>
➤ Cleans the repeater test working directory.

- **make cyclemark**<br>
➤ Runs the CycleMark benchmark.

- **make clean_cyclemark**<br>
➤ Cleans the CycleMark working directory.

<br>
<br>

## MPFS DISCOVERY KIT – FPGA Build & Boot

- **make mpfs_discovery_kit_hss**<br>
➤ Builds the HSS (Hart Software Services) bootloader.<br>
➤ To also program it on the board: **make mpfs_discovery_kit_hss program=1**

- **make clean_mpfs_discovery_kit_hss**<br>
➤ Cleans the HSS build directory.

- **make mpfs_discovery_kit_bitstream**<br>
➤ Builds the FPGA bitstream.<br>
➤ To also program it on the board: **make mpfs_discovery_kit_bitstream program=1**

- **make clean_mpfs_discovery_kit_bitstream**<br>
➤ Cleans the bitstream build directory.

<br>
<br>

## MPFS DISCOVERY KIT – Linux

- **make mpfs_discovery_kit_linux**<br>
➤ Builds the Yocto-based Linux image for the MPFS Discovery Kit.

- **make mpfs_discovery_kit_program_linux**<br>
➤ Writes the built Linux image to the SD card.

- **make mpfs_discovery_kit_program_linux path=path/to/file.wic**<br>
➤ Writes the downloaded Linux image to the SD card.

-  **make clean_mpfs_discovery_kit_linux**<br>
➤ Cleans the Linux build directory.

- **make clean_mpfs_discovery_kit**<br>
➤ Cleans all MPFS-related working directories (HSS, bitstream, Linux).

<br>
<br>

## Remote Interaction with the MPFS DISCOVERY KIT

- **make mpfs_discovery_kit_ssh**<br>
➤ Connects to the MPFS Discovery Kit via SSH.

- **make send_mpfs_discovery_kit_platform_tools**<br>
➤ Sends platform software tools to the board over SSH.

- **make send_mpfs_discovery_kit_loader_firmware**<br>
➤ Sends the loader firmware to the board.

- **make send_mpfs_discovery_kit_repeater_firmware**<br>
➤ Sends the repeater firmware to the board.

- **make send_mpfs_discovery_kit_cyclemark_firmware**<br>
➤ Sends the CycleMark firmware to the board.

<br>
<br>

## Global Cleanup
- **make clean_all**<br>
➤ Cleans all build and test directories for both simulation and hardware.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 🐞 Known Issues

- **Yocto Build Failures** 

While trying to build a Linux image for the MPFS DISCOVERY KIT, Yocto may occasionally fail to fetch some external dependencies, leading to a Linux build failure.<br>
If this happens, simply rerun the build process **without cleaning** it:

```bash
make mpfs_discovery_kit_linux
```

Yocto will resume from where it left off and attempt to fetch the missing files again.

<br>
<br>

- **Firmware Switching and Memory Corruption**

On the MPFS DISCOVERY KIT, running different firmwares successively may cause shared memory corruption between the platform and the core.
If this occurs, reprogramming the FPGA with the latest bitstream usually solves the problem:
```bash
make mpfs_discovery_kit_bitstream program=1
```
⚠️ The issue is under investigation and will be fixed in a future update.

<br>
<br>

---



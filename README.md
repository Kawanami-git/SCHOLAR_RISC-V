# SCHOLAR_RISC-V

*A pedagogical journey into CPU architecture through RISC‑V.*

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## 📚 Table of Contents

- [License](#license)
- [Terminology & Vocabulary](#terminology--vocabulary)
- [Overview](#overview)
- [Project Organization](#project-organization)
- [Branches Structure](#branches-structure)
- [Documentation](#documentation)
- [Dependencies](#dependencies)
- [Quick Start](#quick-start)
- [Known Issues](#known-issues)

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## License

This project is licensed under the **MIT License** – see the [LICENSE](LICENSE) file for details.

Parts of this repository (**CycleMark**) are derived from **CoreMark**, which is distributed under its own license. You can find the original license and notices in the [`benchmarking/CycleMark/`](./benchmarking/CycleMark/) directory.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Terminology & Vocabulary

| Term                                   | Definition |
| -------------------------------------- | ---------- |
| **RISC‑V**                             | A free and open Instruction Set Architecture (ISA) based on RISC principles. The “V” denotes the fifth major RISC lineage. |
| **ISA (Instruction Set Architecture)** | The set of instructions a processor supports (e.g., RV32I, RV32IM). |
| **Microarchitecture**                  | A specific implementation of an ISA (pipeline stages, forwarding, buffers, etc.). |
| **Frequency (MHz)**                    | Clock speed: cycles per second. Higher frequency generally enables faster execution. |
| **IPC (Instructions Per Cycle)**       | Average number of instructions retired per clock cycle. |
| **Core**                               | An independent processing unit capable of executing instructions. |
| **GPR**                                | General-Purpose Registers. |
| **CSR**                                | Control and Status Registers. |
| **Single-port**                        | Memory with one access port — at most one operation (read or write) at a time. |
| **Dual-port**                          | Memory with two access ports — up to two operations (read or write) per cycle. |
| **Single-cycle (monocycle)**           | Each instruction completes all stages within a single clock cycle. |
| **Pipeline**                           | Execution divided into stages; multiple instructions overlap in flight. |
| **Data hazard**                        | An instruction depends on the result of a previous instruction still in execution. |
| **Bypass/forwarding**                  | Technique to route results directly between stages to mitigate hazards. |
| **Branch**                             | Instruction that can change program flow (e.g., conditional jump, loop). |
| **Branch prediction**                  | Heuristic to guess the outcome/target of branches to reduce stalls. |
| **In-order execution**                 | Instructions are fetched, executed, and completed in program order. |
| **Out-of-order execution**             | Instructions execute when operands are ready, not strictly in program order. |
| **Register renaming**                  | Technique to remove false dependencies by mapping to extra physical regs. |
| **Single-issue**                       | At most one instruction issued (fetch/decode/execute) per cycle. |
| **Multi-issue**                        | Multiple instructions may be issued per cycle (e.g., superscalar). |
| **Perfect memory**                     | Simplified model assuming single-cycle memory responses (no cache/DRAM delays). |
| **Cache**                              | Fast memory between CPU and main memory to reduce average latency. |
| **Threads**                            | Independent software execution flows. |
| **SDK**                                | Software Development Kit. |
| **CycleMark/MHz**                      | Performance metric to show core efficiency per MHz. |

---

<br>
<br>
<br>
<br>
<br>

## Overview

**SCHOLAR_RISC‑V** is a learning‑oriented project that walks through the building blocks of a processor using the **RISC‑V architecture** as a foundation. It serves both as a reference and a hands‑on exploration of design, architecture, and optimization.

The repository is organized into multiple branches, each focused on a specific evolution that improves the processor. Every branch includes detailed explanations of *what* was done, *why* it was done, and *what’s next*. Branches are connected in sequence so you can follow the core’s progression.<br>
However, each branch is versioned independently. As a result, files that exist in multiple branches may differ from one branch to another.

The initial branch provides the most basic implementation — a **single‑cycle**, **single‑issue** core supporting **RV32I and RV64I**, with `mcycle` CSR (Zicntr) for CycleMark benchmarking. This branch forms the minimum functional/performance baseline and a clear starting point before exploring more advanced microarchitectural features.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Project Organization

The repository follows a microarchitecture‑based branching model:

- The **main** branch provides entry‑point information (e.g., setup/installation scripts).
- **Development branches** isolate microarchitectural/architectural enhancements to make trade‑offs easy to understand and the core’s evolution easy to track.
- All branches target both **32‑bit** and **64‑bit** variants of the core.
- Additional branches may cover specialized adaptations (e.g., embedded/resource‑constrained variants).
- **Tags** mark major milestones or stable releases for easier navigation.

### Branch Summary

> Only RV32 details are shown here for brevity. See each branch's README for full details (including RV64).

| **Branch**       | **Features** | **CycleMark/MHz** | **FPGA (PolarFire MPFS095T)** |
|------------------|--------------|-------------------|-------------------------------|
| `Single-Cycle`   | Single‑cycle, single‑issue core; **RV32I/RV64I + `mcycle` (Zicntr)** | 1.24 | LEs: 3132 (1061 FFs)<br>Fmax: 69 MHz<br>uSRAM: 0<br>LSRAM: 0<br>Math blocks: 0 |
| `pipeline`   | pipelined single‑issue core; **RV32I/RV64I + `CSR*` (Zicntr)** | 0.55 | LEs: 1999 (702 FFs)<br>Fmax: 120 MHz<br>uSRAM: 6<br>LSRAM: 0<br>Math blocks: 0 |

> 📝
>
> `CSR*`: `mcycle`, `mhpmcounter3` (data hazard counter) and `mhpmcounter4` (branch counter).

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Branches Structure

- **hardware** — RTL for the SCHOLAR RISC‑V core and its environment.  
  - **core** — Verilog sources implementing the processor core.  
  - **env** — Processor environment (memories, interconnects, etc.).

- **software** — Bare‑metal firmware for the core and host‑side tools for sim/FPGA interaction.  
  - **firmware** — Bare‑metal firmware to run on SCHOLAR RISC‑V.  
  - **platform** — Host tools to communicate with simulation or the FPGA platform.

- **simulation** — C++‑based infrastructure to:  
  - Check execution against **Spike** (official RISC‑V ISA simulator).  
  - Run standalone firmware for functional/performance evaluation.

- **MPFS_DISCOVERY_KIT** — Files to synthesize and test on the Microchip **MPFS Discovery Kit**.  
  👉 See [`board_support/MPFS_DISCOVERY_KIT/`](./board_support/MPFS_DISCOVERY_KIT/) for details.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Documentation

Documentation is split between the **main** branch and the **development** branches:

- The **main** branch describes the project, organization, and environment setup.  
- Each **development** branch documents the specific feature implemented there and also support Doxygen documentation.<br>
Doxygen documentation can be generated with:
  ```bash
  make documentation
  ```
  The output is placed in the working directory.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Dependencies

This project is developed on **Ubuntu 24.04 LTS**. Other Ubuntu versions are fine for **simulation** only.

To build a bitstream and run on the PolarFire SoC/FPGA (**MPFS Discovery Kit**), you must use a supported Ubuntu version: **24.04 LTS**.

### Simulation Environment

Install via the main branch makefile:
```bash
make install_sim_env
```

### PolarFire SoC/FPGA (Microchip)

Install the Microchip environment:
```bash
make install_microchip_env
```

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Quick Start

Clone the repository and enter the project directory:
```bash
git clone https://github.com/Kawanami-git/SCHOLAR_RISC-V.git
cd SCHOLAR_RISC_V/
```

Install the simulation environment:
```bash
make install_sim_env
```

And eventually the Microchip environment:
```bash
make install_microchip_env
```

Check out the desired branch (example: Single-Cycle):
```bash
git checkout Single-Cycle
```

Now you can run:

🧪 ISA tests
```bash
make isa
```

📥 Loader firmware
```bash
make loader
```

🔁 Echo firmware
```bash
make echo
```

⏱️ CycleMark benchmark
```bash
make cyclemark
```
> ⚠️ CycleMark simulation can take a long time. Let it finish normally or time out.

For more about the environment and capabilities, see the [simulation docs](./simulation_env/README.md) and the [board support docs](./board_support/).

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Known Issues

### Yocto Build Failures

When building a Linux image for the MPFS Discovery Kit, Yocto may fail to fetch some external sources. If this happens, **rerun without cleaning**:
```bash
make mpfs_disco_kit_linux
```
Yocto will resume and retry the missing fetches.

### Firmware Switching & Memory Corruption

On the MPFS Discovery Kit, running different firmware back‑to‑back may corrupt shared memory between platform and core. Reprogramming the FPGA with the latest bitstream typically fixes it:
```bash
make mpfs_disco_kit_program_bitstream
```
This issue is under investigation and will be fixed in a future update.

<br>
<br>

---
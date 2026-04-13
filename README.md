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

## Table of Contents

- [License](#license)
- [Terminology & Vocabulary](#terminology--vocabulary)
- [Overview](#overview)
- [Project Organization](#project-organization)
- [Learning Path](#learning-path)
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

Some files, generated artifacts, or external components used during the build process may come from Xilinx, Digilent, Yocto, or other third-party projects, and therefore remain subject to their respective licenses.

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

<br>
<br>

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

This project does not claim to present universal truths. First, because although I have experience in this field, my knowledge is still far from the level reached by major processor companies such as ARM, Intel, or AMD.<br>
More importantly, that is not the goal here. The purpose of this project is to provide an accessible entry point into processor architecture. The implemented designs are not intended to be the most advanced or the most optimized, but rather to give learners enough understanding to explore each concept further on their own.

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

<br>
<br>

### Branch Summary

> Only RV32 details are shown here for brevity. See each branch's README for full details (including RV64).

| **Branch**       | **Features** | **CycleMark/MHz** | **FPGA (PolarFire MPFS095T)** |
|------------------|--------------|-------------------|-------------------------------|
| `Single-Cycle`   | Single‑cycle, single‑issue core; **RV32I/RV64I + `mcycle` (Zicntr)** | 1.24 | LEs: 3141 (1062 FFs)<br>Fmax: 74 MHz<br>uSRAM: 0<br>LSRAM: 0<br>Math blocks: 0 |
| `pipeline`   | pipelined single‑issue core; **RV32I/RV64I + `CSR*` (Zicntr)** | 0.55 | LEs: 2023 (782 FFs)<br>Fmax: 192 MHz<br>uSRAM: 6<br>LSRAM: 0<br>Math blocks: 0 |
| `bypass`   | pipelined single‑issue core with forwarding; **RV32I/RV64I + `CSR*` (Zicntr)** | 0.82 | LEs: 2188 (659 FFs)<br>Fmax: 167 MHz<br>uSRAM: 6<br>LSRAM: 0<br>Math blocks: 0 |

> 📝
>
> `CSR*`: `mcycle`.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Learning Path

| **Branch**       | **Features**                                                                   |
|------------------|--------------------------------------------------------------------------------|
| `Single-Cycle`   | Single‑cycle, single‑issue core; **RV32I/RV64I + `mcycle` (Zicntr)**           |
| `pipeline`       | pipelined single‑issue core; **RV32I/RV64I + `CSR*` (Zicntr)**                 |
| `bypass`         | pipelined single‑issue core with forwarding; **RV32I/RV64I + `CSR*` (Zicntr)** |


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
Doxygen documentation can be generated in each branch with:
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

However, to build a bitstream and run on a supported board, you must use the supported Ubuntu version: **24.04 LTS**.

<br>
<br>

### Simulation Environment

Install via the main branch makefile:
```bash
make install_sim_env
```

<br>
<br>

### PolarFire SoC/FPGA (Microchip)

Install the Microchip environment via the main branch makefile:
```bash
make install_microchip_env
```

<br>
<br>

### Cora Z7-07S (Digilent)

Install the AMD/Xilinx environment via the main branch makefile:
```bash
make install_xilinx_env
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
cd SCHOLAR_RISC-V/
```

Install the simulation environment:
```bash
make install_sim_env
```

And eventually the Microchip or Xilinx environment:
```bash
make install_microchip_env
make install_xilinx_env
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

No known issue is currently documented in this section.

---
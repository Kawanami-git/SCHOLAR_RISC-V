# Simulation Environment

This document explains how to set up and use the simulation environment for **SCHOLAR_RISC-V**.

> 📝 The following instructions were written for **Ubuntu 24.04 LTS**. If you are using another Linux distribution or version, you can still follow the general steps, but you may need to make slight adjustments to install the required dependencies or tools.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Table of Contents

- [Required Tools](#required-tools)
- [Known Issues](#known-issues)

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Required Tools

To successfully run the simulations and tests, the following tools are required:

- **Python 3**: used to convert compiled firmware from `.elf` to `.hex` format with the `makehex.py` script
- **Verilator**: a simulator that translates Verilog code into C++ models; it is used to run the RISC-V core simulation
- **RISC-V GNU Toolchain**: the compiler toolchain required to build software for the RISC-V architecture
- **Spike**: the official simulator for the RISC-V instruction set architecture (ISA); it is used to verify and compare the core behavior against a trusted reference model

These tools can be installed using the provided Makefile target:

```bash
make install_sim_env
```

> 📝 The tools are installed in **/opt**. Therefore, root privileges are required.  
> Multiple versions of the **RISC-V GNU Toolchain** may be installed to support the different **SCHOLAR RISC-V** microarchitectures.

> ⚠️ Verilator preprocessing behavior may vary across versions. To ensure compatibility with the HDL, it is recommended to install Verilator through the provided installation script.  
> Spike log formatting may also vary across versions. To ensure compatibility with the simulation environment, it is recommended to install Spike through the provided installation script.

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

<br>
<br>

---
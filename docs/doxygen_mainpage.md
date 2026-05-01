# SCHOLAR RISC-V Single-Cycle Code Documentation

This documentation describes the source code of the **SCHOLAR RISC-V
single-cycle** core.

The goal of this page is to provide a code-oriented entry point: where the RTL
files are located, which module to read first, and how the main hardware blocks
are connected together.

For the global project overview, supported instructions, results, and learning
context, start from the repository `README.md`.

---

## Source Tree Overview {#source_tree_overview}

```text
SCHOLAR_RISC-V/
├── Makefile
├── README.md
├── docs/
├── img/
└── risc-v/
    ├── scholar_riscv_core.sv
    ├── common/
    │   └── core_pkg.sv
    ├── fetch/
    │   └── fetch.sv
    ├── decode/
    │   └── decode.sv
    ├── exe/
    │   └── exe.sv
    ├── writeback/
    │   └── writeback.sv
    ├── gpr/
    │   └── gpr.sv
    └── csr/
        └── csr.sv
```

---

## Main Code Areas {#main_code_areas}

| Area | Purpose |
|:-----|:--------|
| [`risc-v/scholar_riscv_core.sv`](#core_top_level) | Core top-level. |
| [`risc-v/common/`](#common_package) | Shared constants and control encodings. |
| [`risc-v/fetch/`](#fetch_stage) | Instruction fetch logic. |
| [`risc-v/decode/`](#decode_stage) | Instruction decode and control generation. |
| [`risc-v/exe/`](#execute_stage) | ALU, branch, comparison, and execution logic. |
| [`risc-v/writeback/`](#writeback_stage) | Architectural state update and memory access handling. |
| [`risc-v/gpr/`](#gpr_file) | General-purpose register file and program counter storage. |
| [`risc-v/csr/`](#csr_file) | Control and status register file. |

---

## Core top-Level {#core_top_level}

Path:

```text
risc-v/scholar_riscv_core.sv
```

Main module:

```text
scholar_riscv_core
```

This is the main RTL entry point of the single-cycle core.

It instantiates and connects the core internal blocks:

- `fetch`
- `decode`
- `exe`
- `writeback`
- `gpr`
- `csr`

It also exposes the external instruction and data memory OBI interfaces.

---

## Common Package {#common_package}

Path:

```text
risc-v/common/core_pkg.sv
```

Main package:

```text
core_pkg
```

This package centralizes core-wide constants and control encodings.

Typical contents include:

- RISC-V instruction field widths,
- register file constants,
- execution unit control encodings,
- program-counter control encodings,
- memory access control encodings,
- GPR writeback control encodings,
- CSR control encodings.

---

## Fetch Stage {#fetch_stage}

Path:

```text
risc-v/fetch/fetch.sv
```

Main module:

```text
fetch
```

The fetch stage requests the instruction located at the current program counter
from the instruction memory interface.

Its main responsibilities are:

- issue instruction memory requests,
- provide the program counter address to the memory system,
- return the fetched instruction to the decode stage,
- generate a valid flag when the fetched instruction is available.

In the single-cycle core, fetch is part of the global instruction execution path.
The instruction request and response behavior is therefore important for the
overall timing model.

---

## Decode Stage {#decode_stage}

Path:

```text
risc-v/decode/decode.sv
```

Main module:

```text
decode
```

The decode stage interprets the fetched instruction and generates the control
signals required by the rest of the core.

Its main responsibilities are:

- extract instruction fields,
- decode opcodes, `funct3`, and `funct7`,
- select source and destination registers,
- generate immediate values,
- generate execution control signals,
- generate memory control signals,
- generate program-counter control signals,
- generate CSR control signals.

---

## Execute Stage {#execute_stage}

Path:

```text
risc-v/exe/exe.sv
```

Main module:

```text
exe
```

The execute stage performs the computation selected by the decode stage.

Its main responsibilities are:

- arithmetic operations,
- logical operations,
- shifts,
- comparisons,
- branch condition evaluation,
- effective address computation for memory accesses,
- target address computation for jumps and branches.

---

## Writeback Stage {#writeback_stage}

Path:

```text
risc-v/writeback/writeback.sv
```

Main module:

```text
writeback
```

The writeback stage updates the architectural state of the core.

Its main responsibilities are:

- select the value written back to the destination register,
- drive data memory accesses for loads and stores,
- update CSR state when required,
- update the next program counter,
- handle load data returned by the data memory interface.

Although this is a single-cycle microarchitecture, external memory accesses are
handled with a simple request/response interface. This makes the writeback stage
a key place to inspect when debugging load/store behavior.

---

## General-Purpose Register File {#gpr_file}

Path:

```text
risc-v/gpr/gpr.sv
```

Main module:

```text
gpr
```

The GPR block contains the integer register file and the program counter storage.

Its main responsibilities are:

- provide two combinational source-register read ports,
- provide one destination-register write port,
- keep register `x0` hardwired to zero,
- store and update the program counter,
- expose simulation-only register state when `SIM` is enabled.

---

## CSR File {#csr_file}

Path:

```text
risc-v/csr/csr.sv
```

Main module:

```text
csr
```

The CSR block implements the control and status registers currently supported by
the single-cycle core.

In this version, the CSR file is intentionally minimal and mainly provides the
cycle counter used by benchmark and validation firmware.

---

## External Interfaces {#external_interfaces}

The top-level core exposes two memory-facing interfaces:

- instruction memory interface,
- data memory interface.

Both interfaces use the Open Bus Interface (OBI):

- request,
- grant,
- address,
- read-valid,
- read-data,
- write-enable,
- write-data,
- byte-enable,
- error.

The instruction interface is read-oriented, while the data interface supports
loads and stores.

---

## Simulation-Only Signals {#simulation_only_signals}

When `SIM` is defined, the core exposes additional debug and observation signals.

These signals are useful for:

- inspecting the GPR file,
- observing the program counter,
- observing CSR state,
- checking instruction commit events,
- driving testbench-specific CSR overrides.

These signals are not part of the synthesis-oriented functional interface.

---

## Documentation Notes {#documentation_notes}

This Doxygen documentation is intended for source code navigation.

For general project usage, educational explanations, supported instruction lists,
figures, and performance results, refer to the repository `README.md`.

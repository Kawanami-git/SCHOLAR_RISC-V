/* SPDX-License-Identifier: MIT */
/*!
********************************************************************************
\file       start.s
\brief      Minimal RISC-V firmware entry (stack init + call main, then halt).

\author     Kawanami
\version    1.2
\date       14/01/2026

\details
  Sets the stack pointer to `_stack_top`, calls `main`, and then loops forever.
  This file is intended to be linked first and placed at the reset/boot address.

\remarks
  - `_stack_top` must be provided by the linker script.
  - Runs in machine mode by default (platform dependent).

\section start_s_version_history Version history
| Version | Date       | Author     | Description             |
|:-------:|:----------:|:-----------|:------------------------|
| 1.0     | 25/10/2025 | Kawanami   | Initial version.        |
| 1.1     | 12/01/2026 | Kawanami   | Add few instructions to allow using Spike with firmware such as loader or cyclemark.        |
| 1.2     | 14/01/2026 | Kawanami   | Modify start section declaration to ensure that gcc sees the section as executable code.      |
********************************************************************************
*/
.section .start, "ax", @progbits
.globl _start
.globl main

_start:
    # Clear registers that Spike sets
    addi x5, x0, 0
    addi x10, x0, 0
    addi x11, x0, 0

    la      sp, _stack_top       # Initialize stack pointer
    call    main                 # Jump into C entry point

    # End of test sequence
    la t1, tohost
    li t2, 1
    sw t2, 0(t1)
    ebreak

1:
    j       1b                   # If main returns, loop forever

.section .tohost, "aw", @progbits
.globl tohost, fromhost
.balign 8

tohost:   .dword 0
fromhost: .dword 0

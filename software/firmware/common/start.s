/* SPDX-License-Identifier: MIT */
/*!
********************************************************************************
\file       start.s
\brief      Minimal RISC-V firmware entry (stack init + call main, then halt).

\author     Kawanami
\version    1.0
\date       25/10/2025

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
********************************************************************************
*/
    .section .start
    .globl _start
    .globl main

_start:
    la      sp, _stack_top       # Initialize stack pointer
    call    main                 # Jump into C entry point

1:
    j       1b                   # If main returns, loop forever


/* SPDX-License-Identifier: MIT */
/*!
********************************************************************************
\file       linker_ISA.ld
\brief      Linker script for SCHOLAR RISC-V bare-metal ISA firmware.

\author     Kawanami
\version    1.0
\date       25/10/2025

\details
  Defines the on-chip memory layout and section placement:
    - INSTR_RAM : executable code (.start, .text)
    - DATA_RAM  : .data, .rodata, .bss, and a fixed-size stack
    - PTC_MEM   : platform→core shared region (symbol: ptc_memory)
    - CTP_MEM   : core→platform shared region (symbol: cpt_memory)

  Also exports useful symbols:
    _data_start/_data_end, _bss_start/_bss_end,
    _stack_start/_stack_end/_stack_top,
    _heap_start/_heap_end.

\remarks
  - `_stack_top` is used by the start code to initialize `sp`.
  - Adjust `_stack_size` as needed for your firmware.
  - Section names must match the firmware build (start.s places code in `.start`).

\section linker_isa_ld_version_history Version history
| Version | Date       | Author     | Description        |
|:-------:|:----------:|:-----------|:-------------------|
| 1.0     | 25/10/2025 | Kawanami   | Initial version.   |
********************************************************************************
*/

MEMORY {
    INSTR_RAM  (rx)  : ORIGIN = 0x80000000, LENGTH = 16K
    DATA_RAM   (rw)  : ORIGIN = 0x80010000, LENGTH = 16K
    PTC_MEM    (rw)  : ORIGIN = 0x80020000, LENGTH = 1K
    CTP_MEM    (rw)  : ORIGIN = 0x80030000, LENGTH = 1K
}

SECTIONS {
    .text : {
        KEEP(*(.text.start))
        *(.text*)
    } > INSTR_RAM

    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > DATA_RAM

    .rodata : {
        *(.rodata*)
    } > DATA_RAM

    .bss (NOLOAD) : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > DATA_RAM

    .tohost : {
        KEEP(*(.tohost))
    } > DATA_RAM

    .fromhost : {
        KEEP(*(.fromhost))
    } > DATA_RAM

    _stack_size = 1024;
    .stack (NOLOAD) : {
        . = ORIGIN(DATA_RAM) + LENGTH(DATA_RAM) - _stack_size;
        _stack_start = .;
        . = . + _stack_size;
        _stack_end = .;
    } > DATA_RAM


    .ptc_memory ORIGIN(PTC_MEM) :
    {
        PROVIDE(ptc_memory = .);
    } > PTC_MEM

    .cpt_memory ORIGIN(CTP_MEM) :
    {
        PROVIDE(cpt_memory = .);
    } > CTP_MEM

    PROVIDE(_stack_top = _stack_start);
    PROVIDE(_heap_start = _bss_end);
    PROVIDE(_heap_end   = _stack_start);
}

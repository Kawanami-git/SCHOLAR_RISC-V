MEMORY {
    INSTR_RAM  (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DATA_RAM   (rw)  : ORIGIN = 0x00010000, LENGTH = 16K
    PTC_MEM    (rw)  : ORIGIN = 0x00020000, LENGTH = 1K
    CTP_MEM    (rw)  : ORIGIN = 0x00030000, LENGTH = 1K
}

SECTIONS {
    .text : {
        KEEP(*(.start))
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

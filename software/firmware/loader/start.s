    .section .start
    .globl _start
    .globl main

_start:

    la sp, _stack_top

    call main

1:
    j 1b


.section .text.start, "ax"
.global _start
_start:
# Setup stack
    la sp, _estack

# Zero bss
    la a0, _sbss
    la a1, _ebss
    beq a0, a1, zero_bss_loop_end
zero_bss_loop:
    sw x0, 0(a0)
    addi a0, a0, 4
    bne a0, a1, zero_bss_loop
zero_bss_loop_end:

# Call into C program
    call main

# Jump back to bootloader
    jr x0

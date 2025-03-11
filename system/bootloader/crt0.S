
.section .text.start, "ax"
.global _start
_start:
# Setup stack
    la sp, _estack

# Copy data
    la a0, _sdata_rom
    la a1, _sdata_ram
    la a2, _edata_ram
    beq a1, a2, load_data_loop_end
load_data_loop:
    lw a3, 0(a0)
    sw a3, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    bne a1, a2, load_data_loop
load_data_loop_end:

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

# Bootloader returned -> halt
halt_loop:
    j halt_loop

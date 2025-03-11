.global _entry

.section .text._entry
_entry:
# Setup Interrupt Stack
    li sp, 0x10010000
    csrrw sp, mscratch, sp
# Setup Stack
    li sp, 0x1000F000
# Setup Trap Vector
    la x1, trap_handler
    csrrw x1, mtvec, x1
# Write Timer Device
    li a0, 0x80000010
    li a1, 25
    sw a1, 0(a0)
# Enable Interrupts
    csrrs x0, mstatus, 0x8
    call main
l:
    .local halt
    .equ halt, 0x80000000
    la t5, halt;
    sw a0, 0(t5)
    j l

.section .trap_handler, "ax", %progbits
trap_handler:
# Swap to Interrupt Stack and Save some Registers
    csrrw sp, mscratch, sp
    addi sp, sp, -8
    sw a0, 0(sp)
    sw a1, 4(sp)

    csrrs a0, mcause, x0
    blt a0, x0, interrupt_handler
exception_handler:
    csrrw a0, mepc, a0
    addi a0, a0, 4
    csrrw a0, mepc, a0
    j trap_handler_epilog
interrupt_handler:
    li a0, 0x80000010
    lw a1, 0(a0)
    addi a1, a1, 1000
    li a0, 0x80000018
    sw a1, 0(a0)
trap_handler_epilog:
    lw a0, 0(sp)
    lw a1, 4(sp)
    addi sp, sp, 8
    csrrw sp, mscratch, sp
    mret
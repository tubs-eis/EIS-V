MEMORY
{
    RAM (wx) : ORIGIN = 0x10000000, LENGTH = 64K
}

STACK_SIZE = 0x1000;

SECTIONS
{
    .text :
    {
        *(.text.start);
        *(.text);
        *(.text.*);
        *(.rodata);
        *(.rodata.*);
    } > RAM

    .data : 
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data);
        *(.data.*);
        ALIGN(4);
        _edata = .;
    } > RAM

    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss);
        *(.bss.*);
        ALIGN(4);
        _ebss = .;
    } > RAM

    .stack (NOLOAD) :
    {
        . = ALIGN(4);
        _sstack = .;
        . = . + STACK_SIZE;
        . = ALIGN(4);
        _estack = .;
    } > RAM
}

ENTRY(_start)
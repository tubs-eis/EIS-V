MEMORY
{
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 1K
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
    } > ROM

    .data :
    {
        . = ALIGN(4);
        _sdata_ram = .;
        *(.data);
        *(.data.*);
        ALIGN(4);
        _edata_ram = .;
    } > RAM AT>ROM

    _sdata_rom = LOADADDR(.data);

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
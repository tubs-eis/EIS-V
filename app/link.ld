MEMORY
{
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 8K
    RAM (rwx) : ORIGIN = 0x00002000, LENGTH = 4K
}

SECTIONS
{
    .text :
    {
        . = ALIGN(4);
        *(.text._entry)
        *(.text)
        *(.text.*)

        . = ALIGN(4);
        *(.trap_handler)
    } > ROM
}

ENTRY(_entry)
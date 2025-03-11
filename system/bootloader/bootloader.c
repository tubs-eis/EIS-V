/*
 *   Created in May 2023 by Eike Trumann, TU Braunschweig.
 *   FPGA UART Bootloader (bootloader.c)
 *   This bootloader might be used to transfer RISC-V binary code to be run on the EIS-V softcore.
 *   Code needs to be transferred as a hex format in 32 bit little endian byte order.
 */

#include <stdint.h>

#define ROM_START 0x00000000
#define RAM_START 0x10000000

#define UART_REG 0x90000000
#define UART_CTRL_REG 0x90000008
#define UART_STS_REG 0x9000000C

#define UART_STS_RX_COMPLETE 0b10000000
#define UART_STS_TX_COMPLETE 0b00100000
#define UART_CONTROL_RX_EN 0b00010000
#define UART_CONTROL_TX_EN 0b00001000
#define UART_TX_READY_MASK 0x00000020

#define TOTAL_USABLE_MEMORY 0x00010000

#define MAX_PROGRAM_SIZE TOTAL_USABLE_MEMORY
#define PROGRAM_JUMP_OFFSET 0x00
#define END_CHARACTER 'z'

static inline void write_enable() {
    volatile uint8_t *uart_ctrl = (volatile uint8_t *)UART_CTRL_REG;
    *uart_ctrl = (*uart_ctrl | UART_CONTROL_TX_EN);
}

static inline void write_disable() {
    volatile uint8_t *uart_ctrl = (volatile uint8_t *)UART_CTRL_REG;
    *uart_ctrl = (*uart_ctrl & ~UART_CONTROL_TX_EN);
}

static inline void read_enable() {
    volatile uint8_t *uart_ctrl = (volatile uint8_t *)UART_CTRL_REG;
    *uart_ctrl = (*uart_ctrl | UART_CONTROL_RX_EN);
}

static inline void read_disable() {
    volatile uint8_t *uart_ctrl = (volatile uint8_t *)UART_CTRL_REG;
    *uart_ctrl = (*uart_ctrl & ~UART_CONTROL_RX_EN);
}

static inline void wait_indefinetely_for_rx_complete() {
    volatile uint8_t *uart_sts = (volatile uint8_t *)UART_STS_REG;
    while (!(*uart_sts & UART_STS_RX_COMPLETE)) {
    };
}

static inline void wait_indefinetely_for_tx_complete() {
    volatile uint8_t *uart_sts = (volatile uint8_t *)UART_STS_REG;
    while (!(uart_sts && UART_STS_TX_COMPLETE)) {
    };
}

uint8_t read_byte() {
    wait_indefinetely_for_rx_complete();
    volatile uint32_t *received = (volatile uint32_t *)UART_REG;
    uint32_t result = *received;
    return (uint8_t)result;
}

uint8_t hex_to_binary(const uint8_t hex_msb, const uint8_t hex_lsb) {
    uint8_t result = 0;
    if (hex_msb >= '0' && hex_msb <= '9') {
        result = (hex_msb - '0') << 4;
    } else if (hex_msb >= 'A' && hex_msb <= 'F') {
        result = (hex_msb - 'A' + 10) << 4;
    } else if (hex_msb >= 'a' && hex_msb <= 'f') {
        result = (hex_msb - 'a' + 10) << 4;
    }

    if (hex_lsb >= '0' && hex_lsb <= '9') {
        result |= hex_lsb - '0';
    } else if (hex_lsb >= 'A' && hex_lsb <= 'F') {
        result |= hex_lsb - 'A' + 10;
    } else if (hex_lsb >= 'a' && hex_lsb <= 'f') {
        result |= hex_lsb - 'a' + 10;
    }

    return result;
}

static inline int is_hex(uint8_t c) {
    return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
}

int write_string(const char *cptr, int len) {
    write_enable();
    const void *eptr = cptr + len;
    while (cptr != eptr)
        if (*(volatile int *)UART_STS_REG & UART_TX_READY_MASK)
            *(volatile int *)UART_REG = *cptr++;
    write_disable();
    return len;
}

#ifdef DEBUG
static inline char to_hex_char(uint8_t quadruplet) {
    if (quadruplet == 0)
        return '0';
    if (quadruplet == 1)
        return '1';
    if (quadruplet == 2)
        return '2';
    if (quadruplet == 3)
        return '3';
    if (quadruplet == 4)
        return '4';
    if (quadruplet == 5)
        return '5';
    if (quadruplet == 6)
        return '6';
    if (quadruplet == 7)
        return '7';
    if (quadruplet == 8)
        return '8';
    if (quadruplet == 9)
        return '9';
    if (quadruplet == 10)
        return 'A';
    if (quadruplet == 11)
        return 'B';
    if (quadruplet == 12)
        return 'C';
    if (quadruplet == 13)
        return 'D';
    if (quadruplet == 14)
        return 'E';
    if (quadruplet == 15)
        return 'F';
    return 'X';
}

void dump_hex(uint8_t *content, int counter) {
    for (int i = 0; i < counter; i++) {
        uint8_t hex_msb = *(content + i) >> 4;
        uint8_t hex_lsb = *(content + i) & 0x0F;
        char hex_msb_char = to_hex_char(hex_msb);
        char hex_lsb_char = to_hex_char(hex_lsb);
        write_string(&hex_msb_char, 1);
        write_string(&hex_lsb_char, 1);
    }
}
#endif

/**
 * The bootloader has reduced error handling, move user application handler to start of memory
 */
// void copy_vector_table() {
//     uint8_t *start = (uint8_t *)0;
//     uint8_t *received = (uint8_t *)PROGRAM_START;
//     for (int i = 0; i < 0x80; i++) {
//         *(start + i) = *(received + i);
//     }
// }

int main(int argc, char *argv[]) {
    read_disable();

    write_string("Bootloader Ready\r\n", 18);

    uint8_t *program = (uint8_t *)RAM_START;
    uint32_t counter = 0;

    read_enable();
    while (counter < MAX_PROGRAM_SIZE) {
        uint8_t hex_buffer[2] = {0};

        for (int hexchars = 0; hexchars < 2;) {
            uint8_t received = read_byte();

            if (received == END_CHARACTER) {
                goto start_program;
            }

            if (is_hex(received)) {
                hex_buffer[hexchars] = received;
                hexchars++;
            }
        }

        uint8_t decoded_byte = hex_to_binary(hex_buffer[0], hex_buffer[1]);
        *(program + counter) = decoded_byte;
        counter++;
    }

start_program:
    read_disable();
    // copy_vector_table();
#ifdef DEBUG
    dump_hex((uint8_t *)0, TOTAL_USABLE_MEMORY);
#endif
    write_string("\r\nStarting Program\r\n", 20);
    write_enable();

    void volatile *jump_target = (void *)(RAM_START + PROGRAM_JUMP_OFFSET);

    __asm__ volatile("jr %[jump_target]" : : [jump_target] "r"(jump_target));
    __builtin_unreachable();

    return 0;
}

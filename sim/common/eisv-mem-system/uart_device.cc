#include "uart_device.h"

#include <fstream>

constexpr size_t DATA_REG_ADDR = 0;
constexpr size_t BAUD_REG_ADDR = 1;
constexpr size_t CTRL_REG_ADDR = 2;
constexpr size_t STATUS_REG_ADDR = 3;

constexpr size_t CONTROL_RX_EN = 4;
constexpr size_t CONTROL_TX_EN = 3;

constexpr size_t STATUS_TX_READY = 5;
constexpr size_t STATUS_RX_COMPLETE = 7;

UartDevice::UartDevice() {}

UartDevice::UartDevice(char const* out_file_path) {
    out_file = std::fopen(out_file_path, "w");
}

bool UartDevice::write(uint32_t local_address, uint32_t value, uint8_t byte_enable) {
    size_t word_addr = local_address >> 2;
    char c;

    switch (word_addr) {
        case DATA_REG_ADDR:
            c = (char)(value & 0xFF);
            if (out_file != nullptr) {
                fputc(c, out_file);
                fflush(out_file);
            } else {
                putc(c, stdout);
            }
            break;
        case BAUD_REG_ADDR:
            break;
        case CTRL_REG_ADDR:
            control_rx_en = (value >> CONTROL_RX_EN) & 0x01;
            control_tx_en = (value >> CONTROL_TX_EN) & 0x01;
            break;
        case STATUS_REG_ADDR:
            break;
        default:
            return false;
    }

    return true;
}

bool UartDevice::read(uint32_t local_address, uint32_t& value_out, uint8_t byte_enable) {
    size_t word_addr = local_address >> 2;

    switch (word_addr) {
        case DATA_REG_ADDR:
            value_out = 0;
            if (!write_data.empty()) {
                value_out |= write_data.front();
                printf("%c", write_data.front());
                write_data.pop();
            }
            break;
        case BAUD_REG_ADDR:
            break;
        case CTRL_REG_ADDR:
            value_out = (control_rx_en << CONTROL_RX_EN) | (control_tx_en << CONTROL_TX_EN);
            break;
        case STATUS_REG_ADDR:
            value_out = (1 << STATUS_TX_READY);
            if (!write_data.empty()) {
                value_out |= (1 << STATUS_RX_COMPLETE);
            }
            break;
        default:
            return false;
    }

    return true;
}

void UartDevice::tick() {}

void UartDevice::write_char_to_uart(uint8_t c) {
    write_data.push(c);
}

void UartDevice::write_string_to_uart(char const* str) {
    for (char const* c = str; *c != '\0'; c++) {
        write_data.push(*c);
    }
}

void UartDevice::write_file_to_uart(char const* path) {
    std::ifstream ifile(path, std::ios::binary);
    if (!ifile.is_open()) {
        return;
    }

    while (!ifile.eof()) {
        char c;
        ifile.read(&c, sizeof(c));
        write_data.push((uint8_t)c);
    }

    ifile.close();
}

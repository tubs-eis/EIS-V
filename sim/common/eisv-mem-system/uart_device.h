#ifndef UART_DEVICE_H
#define UART_DEVICE_H

#include <cstdio>
#include <queue>

#include "device.h"

class UartDevice : public Device {
   public:
    UartDevice();
    UartDevice(char const* out_file_path);

    virtual bool write(uint32_t local_address, uint32_t value, uint8_t byte_enable) override;
    virtual bool read(uint32_t local_address, uint32_t& value_out, uint8_t byte_enable) override;
    virtual void tick() override;

    void write_char_to_uart(uint8_t c);
    void write_string_to_uart(char const* str);
    void write_file_to_uart(char const* path);

   private:
    std::queue<uint8_t> write_data;

    std::FILE* out_file;

    bool control_rx_en;
    bool control_tx_en;
};

#endif

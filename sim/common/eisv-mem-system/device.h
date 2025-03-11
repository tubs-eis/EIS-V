#ifndef DEVICE_H
#define DEVICE_H

#include <cstdint>

class Device {
   public:
    virtual bool write(uint32_t local_address, uint32_t value, uint8_t byte_enable) = 0;
    virtual bool read(uint32_t local_address, uint32_t& value_out, uint8_t byte_enable) = 0;
    virtual void tick();

   private:
};

#endif

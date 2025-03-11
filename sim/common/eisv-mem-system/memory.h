#ifndef MEMORY_H
#define MEMORY_H

#include <cstddef>
#include <fstream>
#include <iomanip>
#include <vector>

#include "device.h"

class Memory : public Device {
   public:
    Memory(size_t size);

    bool init_from_file(char const* path, int offset);
    void init_random();

    bool write_to_file(char const* path);

    virtual bool write(uint32_t local_address, uint32_t value, uint8_t byte_enable) override;
    virtual bool read(uint32_t local_address, uint32_t& value_out, uint8_t byte_enable) override;

   private:
    std::vector<uint32_t> memory;
};

#endif

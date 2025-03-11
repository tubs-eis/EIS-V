#ifndef SYSTEM_H
#define SYSTEM_H

#include <cstdint>
#include <vector>

#include "device.h"

class System {
    struct Segment {
        int prefix_length;
        uint32_t addr_prefix;
        Device* device;
    };

   public:
    void add_device(Device* device, int prefix_length, uint32_t addr_prefix);

    bool write(uint32_t global_address, uint32_t value, uint8_t byte_enable);
    bool read(uint32_t global_address, uint32_t& value_out, uint8_t byte_enable);

    void tick_all();

   private:
    bool map_address(uint32_t global_address, Segment& segment_out, uint32_t& local_address_out);

    std::vector<Segment> memory_map;
};

#endif

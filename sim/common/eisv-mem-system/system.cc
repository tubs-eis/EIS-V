#include "system.h"

#include "cstdio"

void System::add_device(Device* device, int prefix_length, uint32_t addr_prefix) {
    memory_map.push_back(Segment{
        .prefix_length = prefix_length,
        .addr_prefix = addr_prefix,
        .device = device,
    });
}

bool System::write(uint32_t global_address, uint32_t value, uint8_t byte_enable) {
    Segment segment;
    uint32_t local_address;
    if (map_address(global_address, segment, local_address)) {
        return segment.device->write(local_address, value, byte_enable);
    }

    printf("WARN: Write to unmapped memory at %08x\n", global_address);
    return false;
}

bool System::read(uint32_t global_address, uint32_t& value_out, uint8_t byte_enable) {
    Segment segment;
    uint32_t local_address;
    if (map_address(global_address, segment, local_address)) {
        return segment.device->read(local_address, value_out, byte_enable);
    }

    printf("WARN: Read from unmapped memory at %08x\n", global_address);
    return false;
}

bool System::map_address(uint32_t global_address, Segment& segment_out,
                         uint32_t& local_address_out) {
    for (Segment& segment : memory_map) {
        uint32_t prefix_mask = ~((1 << (32 - segment.prefix_length)) - 1);
        if ((global_address & prefix_mask) == segment.addr_prefix) {
            segment_out = segment;
            local_address_out = global_address & ~prefix_mask;
            return true;
        }
    }
    return false;
}

void System::tick_all() {
    for (Segment segment : memory_map) {
        segment.device->tick();
    }
}

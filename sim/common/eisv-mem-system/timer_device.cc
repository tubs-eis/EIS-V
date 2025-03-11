#include "timer_device.h"

#include <cstdio>

TimerDevice::TimerDevice(bool &timer_interrupt_pending, uint32_t ticks_per_mtime_tick)
    : timer_interrupt_pending(timer_interrupt_pending),
      ticks_per_mtime_tick(ticks_per_mtime_tick) {}

bool TimerDevice::write(uint32_t local_address, uint32_t value, uint8_t byte_enable) {
    size_t word_addr = local_address >> 2;

    switch (word_addr) {
        case 0:
            mtime = (mtime & 0x00000000ffffffff) | value;
            break;
        case 1:
            mtime = (mtime & 0xffffffff00000000) | ((uint64_t)value << 32);
        case 2:
            mtimecmp = (mtimecmp & 0x00000000ffffffff) | value;
            break;
        case 3:
            mtimecmp = (mtimecmp & 0xffffffff00000000) | ((uint64_t)value << 32);
            break;
        default:
            return false;
    }

    return true;
}

bool TimerDevice::read(uint32_t local_address, uint32_t &value_out, uint8_t byte_enable) {
    size_t word_addr = local_address >> 2;

    switch (word_addr) {
        case 0:
            value_out = mtime & 0x00000000ffffffff;
            break;
        case 1:
            value_out = mtime >> 32;
            break;
        case 2:
            value_out = mtimecmp & 0x00000000ffffffff;
            break;
        case 3:
            value_out = mtimecmp >> 32;
            break;
        default:
            return false;
    }

    return true;
}

void TimerDevice::tick() {
    ticks++;
    if (ticks >= ticks_per_mtime_tick) {
        mtime++;
        ticks = 0;
    }

    timer_interrupt_pending = mtime >= mtimecmp;
}

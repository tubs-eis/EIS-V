#ifndef TIMER_DEVICE_H
#define TIMER_DEVICE_H

#include "device.h"

class TimerDevice : public Device {
   public:
    TimerDevice(bool& timer_interrupt_pending, uint32_t ticks_per_mtime_tick);

    virtual bool write(uint32_t local_address, uint32_t value, uint8_t byte_enable) override;
    virtual bool read(uint32_t local_address, uint32_t& value_out, uint8_t byte_enable) override;
    virtual void tick() override;

   private:
    uint64_t mtime;
    uint64_t mtimecmp;
    bool& timer_interrupt_pending;

    uint32_t ticks_per_mtime_tick;
    uint32_t ticks;
};

#endif

#ifndef STOP_SIMULATION_DEVICE_H
#define STOP_SIMULATION_DEVICE_H

#include "device.h"

class StopSimulationDevice : public Device {
   public:
    StopSimulationDevice(bool& stop_requested);

    virtual bool write(uint32_t local_address, uint32_t value, uint8_t byte_enable) override;
    virtual bool read(uint32_t local_address, uint32_t& value_out, uint8_t byte_enable) override;

    uint32_t get_return_value() const;

   private:
    uint32_t return_value;
    bool& stop_requested;
};

#endif

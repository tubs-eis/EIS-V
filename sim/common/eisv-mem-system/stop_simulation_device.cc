#include "stop_simulation_device.h"

#include <cstdio>
#include <fstream>

StopSimulationDevice::StopSimulationDevice(bool& stop_requested) : stop_requested(stop_requested) {}

bool StopSimulationDevice::write(uint32_t local_address, uint32_t value, uint8_t byte_enable) {
    stop_requested = true;

    return_value = value;

    return true;
}

bool StopSimulationDevice::read(uint32_t local_address, uint32_t& value_out, uint8_t byte_enable) {
    return false;
}

uint32_t StopSimulationDevice::get_return_value() const {
    return return_value;
}

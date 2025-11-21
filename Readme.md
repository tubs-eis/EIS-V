# EIS-V (5-Stage Pipeline Version)

A basic 5-stage pipelined RISC-V RV32I_Zicsr M-Mode implementation supporting synthesis for Cologne Chip GateMate and Xilinx Artix A7 FPGA (other Xilinx devices were not tested, but should also work).

For getting started quickly this repo also contains a basic system, including an UART for external communication, for which GateMate and Arty top-level VHDL files as well as a SystemC simulation model are provided. Simulation is supported using both QuestaSim and GHDL + Accellera SystemC.

## Simulation and Synthesis Environment

The EIS-V core is connected to its environment via two memory interfaces the data memory read interface used to perform load and store instructions and the instruction memory interface used to fetch instructions from memory for execution.
Devices can be mapped into the instruction address space, the data address space or both.
Usually memories (both ROM and RAM) will be visible from both address spaces and I/O devices will only be accessible from the data address space.

In the SystemC simulation environment address translation functionality is provided via the System class which maintains the address prefix and length for each device.

When synthesizing (for FPGA) the address mapping for the devices is done in the top-level module of the hardware.

To check which devices are available at what addresses refer to the simulation elaboration code (`sim/common/eisv-mem-system/main.cc`) or the hardware top-level files (`fpga/GATEMATE/rtl/gatemate_top.vhd` and `fpga/ARTY_A7-35T/rtl/arty_top.vhd`).

## Building Applications

The provided makefile supports building and linking C source files as bare metal programs to be executed on the EIS-V core.
To build a recent version of clang is required.
We tested with clang 18, which can be installed with `apt install clang` on Ubuntu 24 LTS.

To build an application place the C file containing the main function into the `app/` folder and call `make build/app/<application>.bin`, where <application> is the filename of the application without the `.c` extension.
To build an application for loading over UART via the bootloader place the file in `system/app/` instead and call `make -C system/app <application>.bootloaderimage` this will produce a hex file in the format the bootloader expects.

## Running Simulations

For development and testing purposes a SystemC model of the system is provided.
The system supports simulation using both QuestaSim and Accellera SystemC + GHDL.
At the start of the simulation the program is initialized with the contents of the file `app/imem.bin`.
To automatically build an application and setup the image file use `make sim-set-imem-image APP=<application>`, where `<application>` is the name of the application.
To simulate the usage of the bootloader use `make sim-set-imem-image APP=bootloader` and copy the generated bootloader image file to `uart_in`.

### Simulating with QuestaSim

To simulate using QuestaSim first use `make com-questa-mem-hdl` to compile the core RTL and SystemC source files. This command has to be rerun after making any changes.
Then use `make sim-questa-mem-hdl` to run the simulation.
To use the QuestaSim GUI to inspect debug and inspect signals use `make sim-questa-mem-hdl-gui`.

### Simulation with GHDL and Accellera SystemC

To simulate with GHDL a recent version of the [GHDL](https://github.com/ghdl/ghdl) llvm backend is required and should be built and installed from source.
Additionally the Accellera SystemC implementation is required to install this on Debian/Ubuntu use `apt install libsystemc-dev`.

To simulate using GHDL + Accellera SystemC use `make sim-ghdl-mem-hdl` this automatically recompiles the core and simulation requirement if any changes are made to either of them.

## Synthesis for FPGA

The repository includes top level files, scripts and constraints to synthesize for the CologneChip GateMate and Xilinx Artix A7 FPGAs.

### Synthesis for GateMate

Synthesis for GateMate requires a recent version of [GHDL](https://github.com/ghdl/ghdl), [YoSys](https://github.com/YosysHQ/yosys), the [ghdl-yosys-plugin](https://github.com/ghdl/ghdl-yosys-plugin) and the Cologne Chip Place and Route Tool. The Place and Route Tool can be obtained from the Cologne Chip Website.
For instructions on building and installing the rest of the tools refer to their respective repositories.

To run synthesis for GateMate use `make synth-gatemate APP=<application>`, where `<application>` is the application to be used for the initial program ROM.
The output files will be written to `build/fpga/gatemate`.

### Synthesis for Artix A7

Synthesis for Xilinx devices a Vivado installation and license supporting the target device.
The provided script in `fpga/ARTY_A7-35T/synth.tcl` performs synthesis and implementation for the Artix A7-35T device and the Digilent Arty A7-35t board, but can be easily adapted to target other devices/boards.

To perform synthesis for the Artix A7-35T use `make synth-arty APP=<application>`, where `<application>` is the application to be used for the initial program ROM.

## Extending the SystemC Simulation Environment

To extend the simulation environment modify the file `sim/common/eisv-mem-system/main.cc`.
During elaboration the constructor of the SystemC module `main` sets up a memory by initializing peripheral devices and adds them to the simulation system by calling `system.add_device`.
To program additional peripheral devices implement the interface defined in `sim/common.eisv-mem-system/device.h`.
Additional CPP source files need to be specified in the `Makefile` for GHDL + Accellera SystemC and `sim/questasim/eisv-mem-system/simulate.tcl` for QuestaSim based simulation.

# Contributors

XXXX

# License

This open-source project is distributed under the MIT license.

# Citation

XXXX

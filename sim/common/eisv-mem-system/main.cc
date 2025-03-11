
#define SC_INCLUDE_DYNAMIC_PROCESSES  // for sc_spawn
#include <systemc.h>

// QuestaSim compile active, create module "main"
// #include "uart_interface.hh"
// #include "spi_interface.hh"
#include "memory.h"
#include "sim_wrapper.hh"  // Interface to verilog wrapper
#include "stop_simulation_device.h"
#include "system.h"
#include "timer_device.h"
#include "uart_device.h"

constexpr size_t ROM_BYTES = 1 << 10;
constexpr size_t ROM_WORDS = ROM_BYTES >> 2;

constexpr size_t RAM_BYTES = 1 << 16;
constexpr size_t RAM_WORDS = RAM_BYTES >> 2;

struct main : public sc_module {
    sim_wrapper dut;
    sc_clock clk;

    // interface signals to verilog wrapper
    sc_signal<bool> reset;
    sc_signal<sc_bv<32>> imem_addr;
    sc_signal<bool> imem_ren;
    sc_signal<sc_bv<32>> imem_rdata;
    sc_signal<sc_bv<32>> dmem_addr;
    sc_signal<bool> dmem_ren;
    sc_signal<sc_bv<32>> dmem_rdata;
    sc_signal<bool> dmem_wen;
    sc_signal<sc_bv<32>> dmem_wdata;
    sc_signal<sc_bv<4>> dmem_byte_enable;
    sc_signal<bool> external_interrupt_pending;
    sc_signal<bool> timer_interrupt_pending;

    bool *stop_criterium;
    bool *timer_interrupt_pending_flag;

    Memory *rom;
    Memory *ram;

    UartDevice *uart_device;
    StopSimulationDevice *stop_device;

    System system;

#ifdef MTI_SYSTEMC
    main(sc_module_name name)
        : dut("dut", "sim_wrapper"),
          clk("clk", 10, SC_NS)
#else
    main(sc_module_name name, VHSocket vhsock)
        : dut("dut", vhsock),
          clk("clk", 10, SC_NS)
#endif
    {
        // connect to verilog wrapper
        dut.i_eisV_clk(clk);
        dut.i_eisV_rst_n(reset);

        dut.o_imem_addr(imem_addr);
        dut.o_imem_ren(imem_ren);
        dut.i_imem_rdata(imem_rdata);

        dut.o_dmem_addr(dmem_addr);
        dut.o_dmem_ren(dmem_ren);
        dut.i_dmem_rdata(dmem_rdata);
        dut.o_dmem_wen(dmem_wen);
        dut.o_dmem_wdata(dmem_wdata);
        dut.o_dmem_byte_enable(dmem_byte_enable);
        dut.i_external_interrupt_pending(external_interrupt_pending);
        dut.i_timer_interrupt_pending(timer_interrupt_pending);

        ram = new Memory{RAM_WORDS};
        system.add_device(ram, 16, 0x10000000);

        rom = new Memory{ROM_WORDS};
        system.add_device(rom, 22, 0x00000000);

        stop_criterium = new bool(false);
        stop_device = new StopSimulationDevice(*stop_criterium);
        system.add_device(stop_device, 30, 0x80000000);

        timer_interrupt_pending_flag = new bool(false);
        TimerDevice *timer_device = new TimerDevice(*timer_interrupt_pending_flag, 50);
        system.add_device(timer_device, 28, 0x80000010);

        uart_device = new UartDevice("uart_out");
        system.add_device(uart_device, 28, 0x90000000);

        uart_device->write_file_to_uart("uart_in");

        // ---------------------
        // Start testbench (TB)
        // ---------------------

        // Memory Initialization (IMEM)
        if (rom->init_from_file("app/imem.bin", 0)) {
            cout << "[TB] Initialized Memory with 'app/imem.bin' file" << endl;
        } else {
            cout << "[TB] Could not open Memory init file 'app/imem.bin'" << endl;
#ifndef MTI_SYSTEMC  // Questasim doesn't like exit during elaboration
            exit(1);
#endif
        }

        // Reset process
        sc_spawn([&] {
            reset.write(false);
            cout << "[TB] Reset on" << endl;

            wait(20, SC_NS);
            reset.write(true);
            cout << "[TB] Reset off" << endl;
        });

        // Spawn process to periodically read/write in memory
        sc_spawn([&] {
            while (!*stop_criterium) {
                if (imem_ren.read() == true) {
                    uint32_t imem_byte_addr = imem_addr.read().to_int();
                    uint32_t imem_read_value;
                    if (system.read(imem_byte_addr, imem_read_value, 0b1111)) {
                        printf("[TB] Reading IMEM[%08x] => %08x\n", imem_byte_addr,
                               imem_read_value);
                    } else {
                        printf("[TB] WARN IMEM read at %08x is OOB\n", imem_byte_addr);
                    }
                    imem_rdata.write(imem_read_value);
                }

                if (dmem_ren.read() == true) {
                    uint32_t dmem_byte_addr = dmem_addr.read().to_int();
                    uint32_t dmem_read_value;
                    if (system.read(dmem_byte_addr, dmem_read_value, 0b1111)) {
                        printf("[TB] Reading DMEM[%08x] => %08x\n", dmem_byte_addr,
                               dmem_read_value);
                    } else {
                        printf("[TB] WARN DMEM read at %08x is OOB\n", dmem_byte_addr);
                    }
                    dmem_rdata.write(dmem_read_value);
                }

                if (dmem_wen.read() == true) {
                    uint32_t dmem_byte_addr = dmem_addr.read().to_int();
                    uint32_t dmem_word_addr = dmem_byte_addr >> 2;
                    uint32_t dmem_write_value = dmem_wdata.read().to_uint();

                    if (system.write(dmem_byte_addr, dmem_write_value,
                                     dmem_byte_enable.read().to_uint())) {
                        printf("[TB] Writing DMEM[%08x] <= %08x, %02x\n", dmem_byte_addr,
                               dmem_write_value, dmem_byte_enable.read().to_uint());
                    } else {
                        printf("[TB] WARN DMEM write at %08x is OOB\n", dmem_byte_addr);
                    }
                }

                external_interrupt_pending.write(false);
                timer_interrupt_pending.write(*timer_interrupt_pending_flag);

                system.tick_all();

                wait(clk.posedge_event());  // Wait till end of period
            }

            // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
            // Interrupt simulaiton
            // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
            uint32_t return_value = stop_device->get_return_value();
            printf("[TB] Program finished with return value %d (%x)!\n", return_value,
                   return_value);

            printf("[TB] Dumping memory to app/dump.bin...\n");
            if (ram->write_to_file("app/dump.bin")) {
                printf("[TB] Finished dumping memory to app/dump.bin\n");
            } else {
                printf("[TB] Failed dumping memory to app/dump.bin\n");
            }

            sc_stop();
        });
    }
};

#ifdef MTI_SYSTEMC
SC_MODULE_EXPORT(main)
#else
int sc_main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Missing argument VHSOCK_NAME\n");
        return 1;
    }

    VHSocket vhsock(argv[1], 103, 67);

    std::unique_ptr<main> tb = std::make_unique<main>("main", vhsock);

    sc_start();

    return 0;
}
#endif

# Defines
SHELL := /bin/bash

ROOT_DIR:=$(realpath $(shell dirname $(firstword $(MAKEFILE_LIST))))

GHDL = ghdl
GHDLFLAGS = --std=08

RISCVCC ?= clang
RISCVCCFLAGS ?= --target=riscv32-none-eabi -march=rv32i_zicsr -nostdlib

SYSTEMCCPP ?= g++
SYSTEMCCPPFLAGS ?= -lsystemc

OBJCOPY ?= llvm-objcopy

YOSYS ?= yosys

PR ?= p_r
PRFLAGS ?= -cCP +sp +crf

VIVADO ?= vivado

APP ?= fib

BUILDDIR ?= build
RTLBUILDDIR := $(BUILDDIR)/rtl
SYTEMCBUILDDIR := $(BUILDDIR)/sim
APPBUILDDIR := $(BUILDDIR)/app
FPGABUILDDIR := $(BUILDDIR)/fpga
FPGABUILDDIR_GM := $(FPGABUILDDIR)/gatemate
FPGABUILDDIR_ARTY := $(FPGABUILDDIR)/arty_a7-35t

# SIM_FLAGS = --backtrace-severity=warning --assert-level=warning

RTLSRC = $(wildcard rtl/core/*.vhd) rtl/core/eisv_config.vhd
SIMRTLSRC = $(wildcard sim/ghdl/rtl/*.vhd)
FPGARTLSRC_GM = $(wildcard fpga/GATEMATE/rtl/*.vhd) fpga/GATEMATE/rtl/gatemate_rom.vhd
TBRTLSRC_GM = $(wildcard fpga/GATEMATE/tb/*.vhd)
FPGARTLSRC_ARTY = $(wildcard fpga/ARTY_A7-35T/rtl/*.vhd) fpga/ARTY_A7-35T/rtl/arty_rom.vhd
TBRTLSRC_ARTY = $(wildcard fpga/ARTY_A7-35T/tb/*.vhd)

MEM_SYSTEM_SRC =\
	sim/common/eisv-mem-system/device.cc \
	sim/common/eisv-mem-system/memory.cc \
	sim/common/eisv-mem-system/system.cc \
	sim/common/eisv-mem-system/timer_device.cc \
	sim/common/eisv-mem-system/stop_simulation_device.cc \
	sim/common/eisv-mem-system/uart_device.cc

GHDL_SYSTEMC_SRC = $(wildcard sim/ghdl/src/*.cc)
GHDL_SYSTEMC_INCLUDE_PATH = sim/ghdl/src
GHDL_SYSTEMC_INCLUDE_FILES = $(wildcard $(GHDL_SYSTEMC_INCLUDE_PATH)/*.hh)

INSTRUCTION ?= add
ifeq ($(INSTRUCTION),)
    INSTRUCTION_ARG :=
else
    INSTRUCTION_ARG := INSTRUCTION=$(INSTRUCTION)
endif

EISV_CONFIG ?= 0

ISA ?= $(shell EISV_CONFIG=${EISV_CONFIG} python3 scripts/isa_from_config.py)

TESTNAME ?= default

.SECONDARY:

.PHONY: always

# 00. Help
all: help

.PHONY: help
help:
	@echo "EIS-V Makefile High-Level Targets"
	@echo "Building Applications:"
	@echo "    make build/app/<application>.bin # Build binary image for bare metal <application>"
	@echo "    make system/bootloader/bootloader.bin # Build bootloader image for (re)loading applications without reprogramming the FPGA"
	@echo "    make system/app/<application>.bootloaderimage # Build hex image for loading with bootloader"
	@echo ""
	@echo "Simulation:"
	@echo "    make sim-set-imem-image APP=<application> # Setup simulation of bare metal <application>"
	@echo "    make sim-set-imem-image APP=bootloader # Setup simulation of bootloader (requires uart_in) to be a valid bootloaderimage"
	@echo "    make sim-ghdl-mem-hdl # Simulate the core together with a SystemC model of the system using GHDL"
	@echo "    make com-questa-mem-hdl # Prepare QuestaSim simulation of core together with SystemC model"
	@echo "    make sim-questa-mem-hdl # Simulate the core together with a SystemC model of the system usign Questasim"
	@echo ""
	@echo "Synthesis:"
	@echo "    make synth-arty APP=[<application>/bootloader] # Synthesize core and top-level for ARTY A7-35T FPGA"
	@echo "    make synth-gatemate APP=<application> # Synthesize core and top-level for Gatemate FPGA"
	@echo ""
	@echo "Bootloader:"
	@echo "    load-<application> # Upload <application> to bootloader via UART"

# 01. Create build directories if needed
$(RTLBUILDDIR):
	mkdir -p $(RTLBUILDDIR)

$(SYTEMCBUILDDIR):
	mkdir -p $(SYTEMCBUILDDIR)

$(APPBUILDDIR):
	mkdir -p $(APPBUILDDIR)

$(FPGABUILDDIR_GM):
	mkdir -p $(FPGABUILDDIR_GM)

$(FPGABUILDDIR_ARTY):
	mkdir -p $(FPGABUILDDIR_ARTY)

# 02. Compile RISC-V Applications
$(APPBUILDDIR)/%.o: app/%.c app/crt0.S app/link.ld | $(APPBUILDDIR)
	$(RISCVCC) $(RISCVCCFLAGS) $< app/crt0.S -T app/link.ld -o $@

$(APPBUILDDIR)/%.o: app/%.S app/link.ld | $(APPBUILDDIR)
	$(RISCVCC) $(RISCVCCFLAGS) $< -T app/link.ld -o $@

$(APPBUILDDIR)/%.bin: $(APPBUILDDIR)/%.o | $(APPBUILDDIR)
	$(OBJCOPY) -O binary $< $@

.PHONY: sim-set-imem-image
sim-set-imem-image: $(APPBUILDDIR)/$(APP).bin
	cp $(APPBUILDDIR)/$(APP).bin app/imem.bin

.PHONY: app/bootloader.bin
$(APPBUILDDIR)/bootloader.bin: | $(APPBUILDDIR)
	make -C system/bootloader bootloader.bin
	cp -u system/bootloader/bootloader.bin $(APPBUILDDIR)/bootloader.bin

# 03. Compile and send program to bootloader
load-%: always
	make -C system/app $*.flash

# 04. Generate EISV configuration
rtl/core/eisv_config.vhd: always
	EISV_CONFIG=$(EISV_CONFIG) python3 scripts/gen_config.py > $@.tmp
	@cmp -s $@ $@.tmp; \
	if [ $$? -ne 0 ]; then \
		cp $@.tmp $@;  \
	fi
	@rm -f $@.tmp

# 05 Use Questasim to simulate
com-questa-mem-hdl:
	@echo "Starting VHDL verification ..."
	@vsim -batch -do "source sim/questasim/eisv-mem-system/simulate.tcl; start -O:compile; quit -f"

sim-questa-mem-hdl:
	@echo "Starting VHDL verification ..."
	@vsim -batch -do "source sim/questasim/eisv-mem-system/simulate.tcl; start -O:simulate; run -all; quit -f"
#	@vsim -do "source sim/questasim/eisv-mem-system/simulate.tcl; start -O:simulate"

sim-questa-mem-hdl-gui:
	@echo "Starting VHDL verification ..."
#	@vsim -batch -do "source sim/questasim/eisv-mem-system/simulate.tcl; start -O:simulate; quit -f"
	@vsim -do "source sim/questasim/eisv-mem-system/simulate.tcl; start -O:simulate"

# 06. Use GHDL to simulate
$(RTLBUILDDIR)/eisv-obj08.cf: $(RTLSRC) | $(RTLBUILDDIR)
	$(GHDL) import $(GHDLFLAGS) --work=eisv --workdir=$(RTLBUILDDIR) $(RTLSRC) $(GENRTLSRC)

$(RTLBUILDDIR)/sim-obj08.cf: $(SIMRTLSRC) | $(RTLBUILDDIR)
	$(GHDL) import $(GHDLFLAGS) --work=sim --workdir=$(RTLBUILDDIR) $(SIMRTLSRC)

$(RTLBUILDDIR)/fpga-obj08.cf: $(FPGARTLSRC_GM) | $(RTLBUILDDIR)
	$(GHDL) import $(GHDLFLAGS) --work=fpga --workdir=$(RTLBUILDDIR) $(FPGARTLSRC_GM)

$(RTLBUILDDIR)/eisv_core.o: $(RTLBUILDDIR)/eisv-obj08.cf | $(RTLBUILDDIR)
	ELAB_ORDER=$$($(GHDL) elab-order $(GHDLFLAGS) --work=eisv --workdir=$(RTLBUILDDIR) eisv_core) && \
	$(GHDL) analyze $(GHDLFLAGS) --work=eisv --workdir=$(RTLBUILDDIR) $$ELAB_ORDER

$(RTLBUILDDIR)/eisv_core_wrapper.o: $(RTLBUILDDIR)/eisv-obj08.cf | $(RTLBUILDDIR)
	ELAB_ORDER=$$($(GHDL) elab-order $(GHDLFLAGS) --work=eisv --workdir=$(RTLBUILDDIR) eisv_core_wrapper) && \
	$(GHDL) analyze $(GHDLFLAGS) --work=eisv --workdir=$(RTLBUILDDIR) $$ELAB_ORDER

$(RTLBUILDDIR)/core_sim: $(RTLBUILDDIR)/sim-obj08.cf $(RTLBUILDDIR)/eisv_core_wrapper.o sim/ghdl/rtl/vhsock.c | $(RTLBUILDDIR)
	$(GHDL) compile $(GHDLFLAGS) --work=sim --workdir=$(RTLBUILDDIR) -P$(RTLBUILDDIR) -Wl,sim/ghdl/rtl/vhsock.c -o $@ $(SIMRTLSRC) -e core_sim

$(SYTEMCBUILDDIR)/eisv-mem-system: $(GHDL_SYSTEMC_SRC) $(MEM_SYSTEM_SRC) $(GHDL_SYSTEMC_INCLUDE_FILES) sim/common/eisv-mem-system/main.cc | $(SYTEMCBUILDDIR)
	$(SYSTEMCCPP) $(SYSTEMCCPPFLAGS) -I $(GHDL_SYSTEMC_INCLUDE_PATH) $^ -o $@

.PHONY: sim-ghdl-mem-hdl
sim-ghdl-mem-hdl: $(RTLBUILDDIR)/core_sim $(SYTEMCBUILDDIR)/eisv-mem-system
	VHSOCK_NAME=$$(xxd -l8 -ps /dev/urandom); \
	./$(RTLBUILDDIR)/core_sim $(SIM_FLAGS) --ieee-asserts=disable --wave=wave.ghw -gVHSOCK_NAME=$$VHSOCK_NAME & \
	./$(SYTEMCBUILDDIR)/eisv-mem-system $$VHSOCK_NAME

# 07. Synthesis for Gatemate FPGA
fpga/GATEMATE/rtl/gatemate_rom.vhd: $(APPBUILDDIR)/$(APP).bin
	python3 scripts/gen_rom.py $< gatemate_rom > $@

$(FPGABUILDDIR_GM)/%_synth.v: fpga/GATEMATE/rtl/%.vhd $(RTLBUILDDIR)/fpga-obj08.cf $(RTLBUILDDIR)/eisv-obj08.cf $(FPGARTLSRC_GM) | $(FPGABUILDDIR_GM)
	$(YOSYS) -p "plugin -i ghdl; ghdl -C $(GHDLFLAGS) --work=fpga --workdir=$(RTLBUILDDIR) -P$(RTLBUILDDIR) $(FPGARTLSRC_GM) fpga/GATEMATE/rtl/gatemate_rom.vhd -e $*; synth_gatemate -top $* -nomx8 -vlog $@"

$(FPGABUILDDIR_GM)/%: $(FPGABUILDDIR_GM)/%_synth.v | $(FPGABUILDDIR_GM)
	$(PR) $(PRFLAGS) -i $(FPGABUILDDIR_GM)/$*_synth.v -ccf fpga/GATEMATE/$*.ccf -o $(FPGABUILDDIR_GM)/$* && touch $@

.PHONY: synth-gatemate
synth-gatemate: $(FPGABUILDDIR_GM)/gatemate_top

# 08. Synthesis for Arty FPGA
fpga/ARTY_A7-35T/rtl/arty_rom.vhd: $(APPBUILDDIR)/$(APP).bin
	python3 scripts/gen_rom.py $< arty_rom > $@

$(FPGABUILDDIR_ARTY)/arty_top.bit: $(RTLSRC) $(FPGARTLSRC_ARTY) system/peripherals/register_uart.vhd fpga/ARTY_A7-35T/xdc/master.xdc fpga/ARTY_A7-35T/synth.tcl | $(FPGABUILDDIR_ARTY)
	cd $(FPGABUILDDIR_ARTY) && $(VIVADO) -mode batch -source $(ROOT_DIR)/fpga/ARTY_A7-35T/synth.tcl

.PHONY: synth-arty
synth-arty: $(FPGABUILDDIR_ARTY)/arty_top.bit

# 99. Cleanup
.PHONY: clean
clean:
	# Makefiles in subdirs
	make -C system/bootloader clean
	make -C system/app clean
	# Build directory
	rm -rf $(BUILDDIR)
	# Simulation files
	rm -f uart_out
	rm -f wave.ghw

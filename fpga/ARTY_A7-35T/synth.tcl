# Initial set up
set_part XC7A35TICSG324-1L
set_property target_language VHDL [current_project]
set_property board_part digilentinc.com:arty-a7-35:part0:1.1 [current_project]
set_property default_lib work [current_project]

# Create and configure clocking wizard ip for core clk
create_ip -vlnv xilinx.com:ip:clk_wiz:6.0 -module_name clk_wiz_core_clk
set_property -dict [list \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 25.000 \
  CONFIG.USE_LOCKED {false} \
  CONFIG.USE_RESET {false} \
] [get_ips clk_wiz_core_clk]
synth_ip [get_ips clk_wiz_core_clk]

# Read design
# Core
read_vhdl -vhdl2008 -library eisv [glob ../../../rtl/core/*.vhd]

# Peripherals
read_vhdl -vhdl2008 -library fpga ../../../system/peripherals/register_uart.vhd

# Top Level
read_vhdl -vhdl2008 -library fpga ../../../fpga/ARTY_A7-35T/rtl/arty_memory.vhd
read_vhdl -vhdl2008 -library fpga ../../../fpga/ARTY_A7-35T/rtl/arty_rom.vhd
read_vhdl -vhdl2008 -library fpga ../../../fpga/ARTY_A7-35T/rtl/arty_top.vhd

# Read constraints
read_xdc ../../../fpga/ARTY_A7-35T/xdc/master.xdc

# Perform synthesis, optimisation, placement and routing
synth_design -top arty_top
opt_design
place_design
route_design

# Write project for analysis
# save_project_as -force test.xpr

# Write output bitstream
write_bitstream -force arty_top.bit

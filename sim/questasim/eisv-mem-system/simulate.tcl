proc start {args} {
  variable operation

  set operation "compile"
  echo $args

  # parse arguments for test number
  foreach arg $args {
    if { [string compare -length 1 $arg "-"] == 0 } {
      if { [string match "-O:*" $arg] == 1 } {
        set operation $arg
        set operation [string range $operation 3 [string length $operation]]
      }
      if { [string match "-T:*" $arg] == 1 } {
        set testname $arg
        set testname [string range $testname 3 [string length $testname]]
      }
    }
  }

  ## start selected operation
  if { [string match "compile" $operation] } {
    sim_compile
  } elseif { [string match "compile-patara" $operation] } {
    sim_compile_patara
  } elseif { [string match "simulate" $operation] } {
    sim_start_sim
  } elseif { [string match "simulate-patara" $operation] } {
    sim_start_sim_patara $testname
  } elseif { [string match "clean" $operation] } {
    sim_clean
  }
}

### Compile sources (HDL)
proc sim_compile_hdl {} {

  # create & map libraries
  puts "-N- create library eisV"
  vlib eisV
  vmap eisV

  puts "-N- create library top_level"
  vlib top_level
  vmap top_level
  puts "-N- create library testbench"
  vlib testbench
  vmap testbench


  # compile source files for library eisV
  puts "-N- compile library eisV"
  eval vcom -2008 -quiet -work eisV -autoorder [glob rtl/core/*.vhd]

  # compile source files for library testbench
  puts "-N- compile library testbench"
  eval vlog -quiet -work testbench sim/questasim/eisv-mem-system/sim_wrapper.v

  # generate foreign module declaration
  scgenmod -bool -lib testbench -sc_bv sim_wrapper > sim/questasim/eisv-mem-system/sim_wrapper.hh

}

proc sim_compile {} {

  sim_compile_hdl

  eval sccom -work testbench -I sim/questasim/eisv-mem-system sim/common/eisv-mem-system/main.cc
  eval sccom -work testbench -I sim/questasim/eisv-mem-system sim/common/eisv-mem-system/device.cc
  eval sccom -work testbench -I sim/questasim/eisv-mem-system sim/common/eisv-mem-system/system.cc
  eval sccom -work testbench -I sim/questasim/eisv-mem-system sim/common/eisv-mem-system/memory.cc
  eval sccom -work testbench -I sim/questasim/eisv-mem-system sim/common/eisv-mem-system/stop_simulation_device.cc
  eval sccom -work testbench -I sim/questasim/eisv-mem-system sim/common/eisv-mem-system/timer_device.cc
  eval sccom -work testbench -I sim/questasim/eisv-mem-system sim/common/eisv-mem-system/uart_device.cc

  eval sccom -link -work testbench

}

### start simulation
proc sim_start_sim {} {

  # start simulation
  eval vsim -t ns -lib testbench -L eisV -voptargs=+acc +notimingchecks -do {"set StdArithNoWarnings 1; set NumericStdNoWarnings 1"} main

}

### clean Modelsim project
proc sim_clean {} {

  puts "-N- remove library directory eisV"
  file delete -force eisV
  puts "-N- remove library directory top_level"
  file delete -force top_level
  puts "-N- remove library directory testbench"
  file delete -force testbench

}

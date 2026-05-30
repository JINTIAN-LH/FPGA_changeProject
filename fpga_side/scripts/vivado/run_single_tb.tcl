if { $argc < 1 } {
  puts "ERROR: Missing tb name. Usage: vivado -mode batch -source run_single_tb.tcl -tclargs <tb_name>"
  exit 1
}

set tb_name [lindex $argv 0]
set proj_name "fpga_exchange_serdes_xsim_${tb_name}"
set proj_dir "./fpga_side/rtl/sim/${proj_name}"
set part_name "xc7a100tfgg484-2"

file mkdir ./fpga_side/rtl/sim
create_project ${proj_name} ${proj_dir} -force -part ${part_name}

if {[file exists "./fpga_side/rtl/src"]} {
  set src_files [glob -nocomplain ./fpga_side/rtl/src/*.v]
  if {[llength $src_files] > 0} {
    add_files -fileset sources_1 $src_files
  }
}

if {[file exists "./fpga_side/rtl/tb"]} {
  set tb_files [concat \
    [glob -nocomplain ./fpga_side/rtl/tb/*.v] \
    [glob -nocomplain ./fpga_side/rtl/tb/*.sv] \
  ]
  if {[llength $tb_files] > 0} {
    add_files -fileset sim_1 $tb_files
  }
}

set_property top ${tb_name} [get_filesets sim_1]
puts "Running single simulation top=${tb_name}"
launch_simulation -simset sim_1 -mode behavioral
close_sim
close_project
puts "single tb done: ${tb_name}"

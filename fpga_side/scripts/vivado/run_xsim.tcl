# Vivado batch simulation entry for quick VS Code integration.
# Adjust project name, part, and source lists for your board.

set proj_name "fpga_exchange_serdes_xsim"
set proj_dir "./fpga_side/rtl/sim/${proj_name}"
set part_name "xc7a100tfgg484-2"

file mkdir ./fpga_side/rtl/sim

create_project ${proj_name} ${proj_dir} -force -part ${part_name}

# Add HDL sources (update as your RTL grows).
if {[file exists "./fpga_side/rtl/src"]} {
  set src_files [glob -nocomplain ./fpga_side/rtl/src/*.v]
  if {[llength $src_files] > 0} {
    add_files -fileset sources_1 $src_files
  }
}

# Add testbench files.
if {[file exists "./fpga_side/rtl/tb"]} {
  set tb_files [concat \
    [glob -nocomplain ./fpga_side/rtl/tb/*.v] \
    [glob -nocomplain ./fpga_side/rtl/tb/*.sv] \
  ]
  if {[llength $tb_files] > 0} {
    add_files -fileset sim_1 $tb_files
  }
}

# Add XDC constraints if present.
if {[file exists "./fpga_side/rtl/constraints"]} {
  set xdc_files [glob -nocomplain ./fpga_side/rtl/constraints/*.xdc]
  if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 $xdc_files
  }
}

# If a testbench top exists, run simulation.
set tb_top "tb_top"
if {[llength [get_files -quiet -all -of_objects [get_filesets sim_1]]] > 0} {
  foreach tb_name {tb_score_calc tb_indicator_top tb_udp_result_tx tb_top tb_m1_protocol_core tb_system_mixed} {
    puts "Running simulation top=${tb_name}"
    set_property top ${tb_name} [get_filesets sim_1]
    launch_simulation -simset sim_1 -mode behavioral
    run all
    close_sim
  }
}

close_project
puts "xsim batch flow done"

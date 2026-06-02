# Vivado batch build entry for programming readiness signoff.
# Flow: create project -> add sources/constraints -> synth -> impl -> timing/drc reports -> bitstream.

set proj_name "fpga_exchange_serdes_build"
set proj_dir  "./fpga_side/rtl/build/${proj_name}"
set part_name "xc7a100tfgg484-2"
set top_name  "top_board"
set jobs      8

if {$argc >= 1} {
  set top_name [lindex $argv 0]
}
if {$argc >= 2} {
  set part_name [lindex $argv 1]
}
if {$argc >= 3} {
  set jobs [lindex $argv 2]
}

file mkdir ./fpga_side/rtl/build
file mkdir ./fpga_side/logs

if {[file exists ${proj_dir}]} {
  file delete -force ${proj_dir}
}

puts "BUILD CONFIG: top=${top_name}, part=${part_name}, jobs=${jobs}"

create_project ${proj_name} ${proj_dir} -force -part ${part_name}

if {[file exists "./fpga_side/rtl/src"]} {
  set src_files [glob -nocomplain ./fpga_side/rtl/src/*.v]
  if {[llength $src_files] > 0} {
    add_files -fileset sources_1 $src_files
  } else {
    puts "ERROR: no RTL sources found under fpga_side/rtl/src"
    exit 2
  }
} else {
  puts "ERROR: source directory fpga_side/rtl/src not found"
  exit 2
}

if {[file exists "./fpga_side/rtl/constraints"]} {
  set xdc_files [glob -nocomplain ./fpga_side/rtl/constraints/*.xdc]
  if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 $xdc_files
  } else {
    puts "WARNING: no XDC files found under fpga_side/rtl/constraints"
  }
} else {
  puts "WARNING: constraints directory fpga_side/rtl/constraints not found"
}

set_property top ${top_name} [get_filesets sources_1]

update_compile_order -fileset sources_1

launch_runs synth_1 -jobs ${jobs}
wait_on_run synth_1

if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
  puts "ERROR: synthesis failed"
  exit 3
}

launch_runs impl_1 -to_step write_bitstream -jobs ${jobs}
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
if {[string first "write_bitstream Complete" ${impl_status}] < 0} {
  puts "ERROR: implementation/bitstream failed: ${impl_status}"
  exit 4
}

open_run impl_1

report_timing_summary -file ./fpga_side/logs/impl_timing_summary.rpt -delay_type max -max_paths 30
report_drc -file ./fpga_side/logs/impl_drc.rpt
report_clock_interaction -file ./fpga_side/logs/impl_clock_interaction.rpt
report_utilization -file ./fpga_side/logs/impl_utilization.rpt
report_cdc -file ./fpga_side/logs/impl_cdc.rpt

set bit_file [get_property BITSTREAM.FILE [current_design]]
puts "BUILD DONE"
puts "TOP: ${top_name}"
puts "PART: ${part_name}"
puts "BIT: ${bit_file}"
puts "REPORTS: ./fpga_side/logs/impl_timing_summary.rpt, impl_drc.rpt, impl_clock_interaction.rpt, impl_utilization.rpt, impl_cdc.rpt"

close_project

# AMD Vivado Non-Project Batch Flow Synthesis & Implementation Script
# Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
# Run with: vivado -mode batch -source scripts/vivado/run_vivado.tcl

set PROJECT_NAME "rv32i_cisco_soc"
set PART_NUMBER  "xc7a35tcpg236-1"
set OUTPUT_DIR   "build/vivado_output"

puts "======================================================================"
puts " Starting Vivado Synthesis & Implementation Flow for ${PROJECT_NAME}   "
puts " Target Part: ${PART_NUMBER}                                          "
puts "======================================================================"

file mkdir ${OUTPUT_DIR}

# 1. Read SystemVerilog RTL Sources
puts "--> [Step 1] Reading SystemVerilog RTL files..."
read_verilog -sv [glob ../../rtl/core/*.sv]
read_verilog -sv [glob ../../rtl/bus/*.sv]
read_verilog -sv [glob ../../rtl/peripherals/*.sv]
read_verilog -sv [glob ../../rtl/soc/*.sv]
read_verilog -sv ../../fpga/seven_segment_driver.sv
read_verilog -sv ../../fpga/rv32i_fpga_top.sv

# 2. Read Timing & Physical Constraints
puts "--> [Step 2] Reading XDC constraints..."
read_xdc ../../fpga/constraints.xdc

# 3. Synthesize Design
puts "--> [Step 3] Running synth_design (Target Clock: 100 MHz)..."
synth_design -top rv32i_fpga_top -part ${PART_NUMBER} -flatten_hierarchy rebuilt
write_checkpoint -force ${OUTPUT_DIR}/post_synth.dcp
report_utilization -file ${OUTPUT_DIR}/post_synth_utilization.rpt
report_timing_summary -file ${OUTPUT_DIR}/post_synth_timing.rpt

# 4. Logic Optimization
puts "--> [Step 4] Running opt_design..."
opt_design
write_checkpoint -force ${OUTPUT_DIR}/post_opt.dcp

# 5. Placement
puts "--> [Step 5] Running place_design..."
place_design
write_checkpoint -force ${OUTPUT_DIR}/post_place.dcp

# 6. Physical Optimization
puts "--> [Step 6] Running phys_opt_design for timing closure..."
phys_opt_design
write_checkpoint -force ${OUTPUT_DIR}/post_phys_opt.dcp

# 7. Routing
puts "--> [Step 7] Running route_design..."
route_design
write_checkpoint -force ${OUTPUT_DIR}/post_route.dcp

# 8. Timing & Resource Reporting
puts "--> [Step 8] Generating final timing, utilization, and power reports..."
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -file ${OUTPUT_DIR}/timing_summary.rpt
report_utilization -hierarchical -file ${OUTPUT_DIR}/utilization_hierarchical.rpt
report_power -file ${OUTPUT_DIR}/power_summary.rpt
report_drc -file ${OUTPUT_DIR}/drc_report.rpt

# 9. Bitstream Generation
puts "--> [Step 9] Generating bitstream image for FPGA validation..."
write_bitstream -force ${OUTPUT_DIR}/rv32i_soc.bit

puts "======================================================================"
puts " Vivado Flow Complete! Artifacts saved in ${OUTPUT_DIR}                "
puts "======================================================================"

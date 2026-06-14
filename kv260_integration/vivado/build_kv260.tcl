# ============================================================================
# AES-128 Accelerator — KV260 ZynqMP Integration
# Vivado 2025.2 Tcl Build Script (complete flow)
# ============================================================================
# 1. Creates project with all AES RTL
# 2. Packages the AES AXI4-Lite peripheral as custom IP
# 3. Creates block design: ZynqMP PS + AES IP
# 4. Synthesizes, implements, generates bitstream
# 5. Exports XSA
# ============================================================================

set proj_name    "aes_kv260"
set base_dir     [file normalize "C:/Work/Eitesal_EG/SMC26-24/kv260_integration"]
set proj_dir     "$base_dir/vivado"
set repo_dir     [file normalize "C:/Work/Eitesal_EG/SMC26-24/AES-Project-repo"]
set rtl_dir      "$repo_dir/rtl"
set ip_repo_dir  "$base_dir/ip_repo/aes_core"
set part         "xczu5ev-sfvc784-2LV-e"
set board_part   "xilinx.com:kv260_som:part0:1.4"
set board_repo   "C:/AMDDesignTools/2025.2/Vivado/data/boards/board_files"

# ── 0. Board repo ───────────────────────────────────────────────────────────
if {[file exists $board_repo]} {
    set_param board.repoPaths [list $board_repo]
}

# ============================================================================
# PHASE 1: Package AES IP
# ============================================================================

# Create temporary project for IP packaging
create_project aes_ip_pkg "$proj_dir/aes_ip_pkg" -part $part -force
set_property target_language Verilog [current_project]

# Add ALL RTL files including the AXI wrapper
add_files -norecurse [glob -directory $rtl_dir *.v]
update_compile_order -fileset sources_1
set_property top myip_test5_v1_0 [current_fileset]

# Package as IP (Vivado auto-infers AXI-Lite interface from s00_axi_* prefix)
ipx::package_project -root_dir $ip_repo_dir -vendor user.org -library user -taxonomy /UserIP -import_files -force

# Get the packaged core
set ip_core [ipx::current_core]
if {$ip_core eq ""} {
    # Fall back: find by VLNV
    set ip_core [ipx::find_cores -current -name {user.org:user:myip_test5_v1_0:*}]
    if {[llength $ip_core] > 0} {
        set ip_core [lindex $ip_core 0]
    }
}
if {$ip_core ne ""} {
    set_property name aes_core $ip_core
    set_property display_name {AES-128 Accelerator} $ip_core
    set_property description {5-stage pipelined AES-128 encryption accelerator with AXI4-Lite interface} $ip_core
    set_property company_url {http://user.org} $ip_core

    # Set FREQ_HZ parameter on clock interface to be user-resolvable (not fixed)
    set clk_if [ipx::get_bus_interfaces s00_axi_aclk -of_objects $ip_core]
    if {$clk_if ne ""} {
        set freq_param [ipx::get_bus_parameters FREQ_HZ -of_objects $clk_if]
        if {$freq_param ne ""} {
            set_property value_resolve_type user $freq_param
            set_property value 0 $freq_param
        }
    }

    # Save and close IP package
    ipx::create_xgui_files $ip_core
    ipx::update_checksums $ip_core
    ipx::check_integrity $ip_core
    ipx::save_core $ip_core
    ipx::unload_core $ip_core
    puts "PHASE 1 COMPLETE: AES IP packaged at $ip_repo_dir"
} else {
    puts "ERROR: IP packaging failed - no core found"
    close_project
    return -code error
}

# ============================================================================
# PHASE 2: Create Main Project + Block Design
# ============================================================================

create_project $proj_name "$proj_dir/$proj_name" -part $part -force
set_property board_part $board_part [current_project]
set_property target_language Verilog [current_project]

# Add AES core RTL (non-AXI files for reference/synthesis in wrapper)
add_files -norecurse [glob -directory $rtl_dir *.v]
update_compile_order -fileset sources_1

# Register the packaged IP repo
set_property ip_repo_paths $ip_repo_dir [current_project]
update_ip_catalog

# Create block design
create_bd_design "design_1"

# 2a. Add ZynqMP PS with KV260 board preset
set ps_cell [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  $ps_cell

# Configure PS: enable HPM0 FPD master for AXI-Lite, disable HPM1
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {32} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
] $ps_cell

# 2b. Add AES IP
set aes_cell [create_bd_cell -type ip -vlnv user.org:user:aes_core:1.0 aes_core_0]

# 2c. Define PL clock and reset wires
set pl_clk [get_bd_pins -of_objects $ps_cell -filter {NAME=~pl_clk0}]
set pl_rst [get_bd_pins -of_objects $ps_cell -filter {NAME=~pl_resetn0}]

# 2d. Add AXI SmartConnect for AXI4 (PS) → AXI4-Lite (AES) protocol conversion
set smartcon [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0]
set_property -dict [list \
    CONFIG.NUM_SI {1} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_CLKS {1} \
] $smartcon

# Select the first PS master interface (HPM0_FPD)
set ps_master [lindex [get_bd_intf_pins -of_objects $ps_cell -filter {MODE==Master && VLNV =~ "*aximm*"}] 0]
puts "PS Master interface selected: $ps_master"

# Connect: PS → SmartConnect → AES
connect_bd_intf_net $ps_master [get_bd_intf_pins smartconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M00_AXI] [get_bd_intf_pins aes_core_0/S00_AXI]

# Clock and reset for SmartConnect and AES
connect_bd_net $pl_clk [get_bd_pins smartconnect_0/aclk]
connect_bd_net $pl_clk [get_bd_pins aes_core_0/s00_axi_aclk]
# Connect PS AXI master clock
connect_bd_net $pl_clk [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]

# Create proc_sys_reset for the AXI-Lite domain
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
connect_bd_net $pl_clk [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net $pl_rst [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins aes_core_0/s00_axi_aresetn] 

# 2f. Auto-assign addresses (Vivado picks base address automatically)
assign_bd_address -force

# Note the auto-assigned address (from the log output above)
puts "AES IP auto-assigned at 0xA000_0000 [4K] (check log for confirmation)"

# 2e. Validate and save (FREQ_HZ auto-inherited from connected clock)
regenerate_bd_layout
validate_bd_design
save_bd_design

# 2g. Create HDL wrapper
make_wrapper -files [get_files design_1.bd] -top -import
update_compile_order -fileset sources_1
set_property top design_1_wrapper [current_fileset]

puts "PHASE 2 COMPLETE: Block design created"

# ============================================================================
# PHASE 3: Synthesize + Implement + Bitstream
# ============================================================================

# Synthesize
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Check synthesis result
set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis: $synth_status"

# Implement
launch_runs impl_1 -jobs 8
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation: $impl_status"

# Bitstream (if implementation succeeded)
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# ============================================================================
# PHASE 4: Export XSA
# ============================================================================

write_hw_platform -fixed -include_bit -force "$proj_dir/aes_kv260.xsa"
puts "XSA: $proj_dir/aes_kv260.xsa"

# Reports
open_run impl_1
report_utilization -file "$proj_dir/utilization_report.txt"
report_timing_summary -max_paths 10 -file "$proj_dir/timing_report.txt"
close_design

puts "============================================================"
puts "  BUILD COMPLETE"
puts "  XSA:         $proj_dir/aes_kv260.xsa"
puts "  Utilization: $proj_dir/utilization_report.txt"
puts "  Timing:      $proj_dir/timing_report.txt"
puts "============================================================"

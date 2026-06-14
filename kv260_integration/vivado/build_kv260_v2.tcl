# ============================================================================
# AES-128 Accelerator -- KV260 ZynqMP Integration (v2)
# ============================================================================
# Changes from v1:
#   1. axi_interconnect replaces SmartConnect (matches team TEST4 design)
#   2. system_ila with 2 AXI monitor slots for debugging AXI hang
#   3. PS config matches TEST4 exactly (explicit UART1, clocks, etc.)
#   4. AES IP address range = 64K (matches TEST4)
#
# Vivado 2025.2 Tcl Build Script (complete flow)
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

# -- 0. Board repo --
if {[file exists $board_repo]} {
    set_param board.repoPaths [list $board_repo]
}

# ============================================================================
# PHASE 1: Package AES IP (same as v1)
# ============================================================================

create_project aes_ip_pkg "$proj_dir/aes_ip_pkg" -part $part -force
set_property target_language Verilog [current_project]

add_files -norecurse [glob -directory $rtl_dir *.v]
update_compile_order -fileset sources_1
set_property top myip_test5_v1_0 [current_fileset]

ipx::package_project -root_dir $ip_repo_dir -vendor user.org -library user -taxonomy /UserIP -import_files -force

set ip_core [ipx::current_core]
if {$ip_core eq ""} {
    set ip_core [ipx::find_cores -current -name {user.org:user:myip_test5_v1_0:*}]
    if {[llength $ip_core] > 0} { set ip_core [lindex $ip_core 0] }
}
if {$ip_core ne ""} {
    set_property name aes_core $ip_core
    set_property display_name {AES-128 Accelerator} $ip_core
    set_property description {5-stage pipelined AES-128 encryption accelerator with AXI4-Lite interface} $ip_core
    set_property company_url {http://user.org} $ip_core

    set clk_if [ipx::get_bus_interfaces s00_axi_aclk -of_objects $ip_core]
    if {$clk_if ne ""} {
        set freq_param [ipx::get_bus_parameters FREQ_HZ -of_objects $clk_if]
        if {$freq_param ne ""} {
            set_property value_resolve_type user $freq_param
            set_property value 0 $freq_param
        }
    }

    ipx::create_xgui_files $ip_core
    ipx::update_checksums $ip_core
    ipx::check_integrity $ip_core
    ipx::save_core $ip_core
    ipx::unload_core $ip_core
    puts "PHASE 1 COMPLETE: AES IP packaged"
} else {
    puts "ERROR: IP packaging failed"
    close_project
    return -code error
}

# ============================================================================
# PHASE 2: Block Design with axi_interconnect + system_ila
# ============================================================================

create_project $proj_name "$proj_dir/$proj_name" -part $part -force
set_property board_part $board_part [current_project]
set_property target_language Verilog [current_project]

add_files -norecurse [glob -directory $rtl_dir *.v]
update_compile_order -fileset sources_1

set_property ip_repo_paths $ip_repo_dir [current_project]
update_ip_catalog

create_bd_design "design_1"

# ---- 2a. ZynqMP PS (TEST4-matching configuration) ----
puts ">>> Creating ZynqMP PS..."
set ps_cell [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1" }  $ps_cell

# Configure PS to match TEST4 exactly
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {32} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__UART1__BAUD_RATE {115200} \
    CONFIG.PSU__UART1__MODEM__ENABLE {0} \
    CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__UART1__PERIPHERAL__IO {MIO 36 .. 37} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__FPGA_PL1_ENABLE {1} \
    CONFIG.PSU__PL_CLK0_BUF {TRUE} \
    CONFIG.PSU__PL_CLK1_BUF {TRUE} \
] $ps_cell
puts "  PS configured (UART1 on MIO 36-37, HPM0_FPD 32-bit, pl_clk0+1)"

# ---- 2b. AES IP ----
puts ">>> Creating AES IP..."
create_bd_cell -type ip -vlnv user.org:user:aes_core:1.0 aes_core_0

# ---- 2c. AXI Interconnect (replaces SmartConnect) ----
puts ">>> Creating axi_interconnect..."
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph
set_property -dict [list \
    CONFIG.NUM_SI {1} \
    CONFIG.NUM_MI {1} \
] [get_bd_cells ps8_0_axi_periph]
puts "  axi_interconnect: 1 SI, 1 MI (auto protocol converter AXI4->AXI4-Lite)"

# ---- 2d. Processor System Reset ----
puts ">>> Creating proc_sys_reset..."
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps8_0_99M

# ---- 2e. System ILA (2 AXI monitor slots) ----
puts ">>> Creating system_ila..."
create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_0
set_property -dict [list \
    CONFIG.C_MON_TYPE {INTERFACE} \
    CONFIG.C_NUM_MONITOR_SLOTS {2} \
    CONFIG.C_DATA_DEPTH {1024} \
] [get_bd_cells system_ila_0]
puts "  system_ila: 2 slots, 1024 depth"
puts "    SLOT_0 = AES-side  (interconnect M00 -> AES S00_AXI)"
puts "    SLOT_1 = PS-side   (PS M_AXI_HPM0_FPD -> interconnect S00)"

# ---- 2f. AXI interface connections ----
puts ">>> Connecting AXI interfaces..."

# PS master -> interconnect S00
connect_bd_intf_net \
    [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
    [get_bd_intf_pins ps8_0_axi_periph/S00_AXI]

# interconnect M00 -> AES slave
connect_bd_intf_net \
    [get_bd_intf_pins ps8_0_axi_periph/M00_AXI] \
    [get_bd_intf_pins aes_core_0/S00_AXI]

# ---- 2g. System ILA monitor taps ----
puts ">>> Connecting ILA monitor slots..."

# SLOT_1 monitors PS-side bus (PS -> interconnect S00)
# Connect ILA slot to PS master pin (already on the PS-interconnect net)
connect_bd_intf_net \
    [get_bd_intf_pins system_ila_0/SLOT_1_AXI] \
    [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]

# SLOT_0 monitors AES-side bus (interconnect M00 -> AES S00_AXI)
# Connect ILA slot to AES slave pin (already on the interconnect-AES net)
connect_bd_intf_net \
    [get_bd_intf_pins system_ila_0/SLOT_0_AXI] \
    [get_bd_intf_pins aes_core_0/S00_AXI]

# Mark debug attributes on both monitored nets
set_property HDL_ATTRIBUTE.DEBUG true \
    [get_bd_intf_nets -of_objects [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]]
set_property HDL_ATTRIBUTE.DEBUG true \
    [get_bd_intf_nets -of_objects [get_bd_intf_pins aes_core_0/S00_AXI]]

# ---- 2h. Clock distribution (pl_clk0 -> all) ----
puts ">>> Connecting clocks..."
set pl_clk [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]
connect_bd_net $pl_clk [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]
connect_bd_net $pl_clk [get_bd_pins ps8_0_axi_periph/ACLK]
connect_bd_net $pl_clk [get_bd_pins ps8_0_axi_periph/S00_ACLK]
connect_bd_net $pl_clk [get_bd_pins ps8_0_axi_periph/M00_ACLK]
connect_bd_net $pl_clk [get_bd_pins aes_core_0/s00_axi_aclk]
connect_bd_net $pl_clk [get_bd_pins system_ila_0/clk]
connect_bd_net $pl_clk [get_bd_pins rst_ps8_0_99M/slowest_sync_clk]

# ---- 2i. Reset distribution ----
puts ">>> Connecting resets..."
connect_bd_net \
    [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
    [get_bd_pins rst_ps8_0_99M/ext_reset_in]

set periph_rst [get_bd_pins rst_ps8_0_99M/peripheral_aresetn]
connect_bd_net $periph_rst [get_bd_pins ps8_0_axi_periph/ARESETN]
connect_bd_net $periph_rst [get_bd_pins ps8_0_axi_periph/S00_ARESETN]
connect_bd_net $periph_rst [get_bd_pins ps8_0_axi_periph/M00_ARESETN]
connect_bd_net $periph_rst [get_bd_pins aes_core_0/s00_axi_aresetn]
connect_bd_net $periph_rst [get_bd_pins system_ila_0/resetn]

# ---- 2j. Address map (64K range, matching TEST4) ----
puts ">>> Assigning address map..."
assign_bd_address -force

# Set AES IP to 0xA0000000 with 64K range (matching TEST4)
catch {
    set_property offset 0xA0000000 \
        [get_bd_addr_segs aes_core_0/s00_axi/reg0]
    set_property range 64K \
        [get_bd_addr_segs aes_core_0/s00_axi/reg0]
    puts "  AES IP at 0xA0000000, range 64K"
} err_msg
if {$err_msg ne ""} {
    puts "  Note: address segment auto-assigned (offset/range adjustment skipped: $err_msg)"
}

# ---- 2k. Validate and save ----
puts ">>> Validating block design..."
regenerate_bd_layout
validate_bd_design
save_bd_design

# ---- 2l. Create HDL wrapper ----
make_wrapper -files [get_files design_1.bd] -top -import
update_compile_order -fileset sources_1
set_property top design_1_wrapper [current_fileset]

puts "PHASE 2 COMPLETE: Block design with axi_interconnect + system_ila"

# ============================================================================
# PHASE 3: Synthesize + Implement + Bitstream
# ============================================================================

puts ">>> Starting synthesis..."
launch_runs synth_1 -jobs 8
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis: $synth_status"

puts ">>> Starting implementation..."
launch_runs impl_1 -jobs 8
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation: $impl_status"

puts ">>> Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# ============================================================================
# PHASE 4: Export XSA + Reports
# ============================================================================

write_hw_platform -fixed -include_bit -force "$proj_dir/aes_kv260.xsa"
puts "XSA: $proj_dir/aes_kv260.xsa"

open_run impl_1
report_utilization -file "$proj_dir/utilization_report.txt"
report_timing_summary -max_paths 10 -file "$proj_dir/timing_report.txt"
close_design

# Locate the .ltx debug probes file (needed for Hardware Manager ILA)
set ltx_file [get_files -of_objects [get_runs impl_1] *.ltx]
if {$ltx_file eq ""} {
    set impl_dir [file dirname [get_files -of_objects [get_runs impl_1] design_1_wrapper.bit]]
    set ltx_file "$impl_dir/design_1_wrapper.ltx"
}
puts "Debug probes (.ltx): $ltx_file"

puts "============================================================"
puts "  BUILD v2 COMPLETE"
puts "  XSA:          $proj_dir/aes_kv260.xsa"
puts "  Bitstream:    $proj_dir/$proj_name/${proj_name}.runs/impl_1/design_1_wrapper.bit"
puts "  Debug probes: $ltx_file"
puts "  Utilization:  $proj_dir/utilization_report.txt"
puts "  Timing:       $proj_dir/timing_report.txt"
puts "============================================================"

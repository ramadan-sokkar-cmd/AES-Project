# ============================================================================
# jtag_boot_phase1_fpga.tcl
# ============================================================================
# Full Phase 1 boot INCLUDING fpga command, so PL is freshly configured.
# After this, PS is initialized and PL has our bitstream + debug cores.
# ============================================================================

set bitfile "C:/Work/Eitesal_EG/SMC26-24/kv260_integration/vivado/aes_kv260/aes_kv260.runs/impl_1/design_1_wrapper.bit"
set pmufw   "C:/Work/Eitesal_EG/SMC26-24/kv260_integration/sw_baremetal/workspace/aes_platform/zynqmp_pmufw/pmufw.elf"
set fsbl    "C:/Work/Eitesal_EG/SMC26-24/kv260_integration/sw_baremetal/workspace/aes_platform/zynqmp_fsbl/fsbl_a53.elf"

# Step 1: System reset + JTAG boot mode
puts "Step 1: System reset"
connect
targets -set -filter {name =~ "PSU"}
mwr 0xffca0010 0x0
mwr 0xff5e0200 0x0100
rst -system
after 2000

# Step 2: Load bitstream via PCAP
puts "Step 2: Load bitstream"
targets -set -filter {name =~ "PSU"}
fpga $bitfile
mwr 0xffca0038 0x1FF
after 1000

# Step 3: PMUFW
puts "Step 3: PMUFW"
targets -set -filter {name =~ "MicroBlaze PMU"}
after 500
dow $pmufw
con
after 2000

# Step 4: FSBL
puts "Step 4: FSBL"
targets -set -filter {name =~ "Cortex-A53 #0"}
rst -processor -clear-registers
dow $fsbl
con
puts "  Waiting 10s for FSBL..."
after 10000
stop

# Step 4b: UART1 fix
puts "Step 4b: UART1 fix"
targets -set -filter {name =~ "PSU"}
mwr 0xFF5E0078 0x01010A00
after 100
mwr 0xFF180090 0x000000C0
after 50
mwr 0xFF180094 0x000000C0
after 100
mwr 0xFF5E0238 0x00000000
after 100

# Verify pl_clk0 is running
set pl0_clk [mrd 0xFF5E00C0]
puts "PL0_REF_CTRL = $pl0_clk"

puts ""
puts "========================================="
puts "  Phase 1 complete with fpga load."
puts "  PL is freshly configured. PS is init."
puts "  pl_clk0 should be running."
puts "========================================="

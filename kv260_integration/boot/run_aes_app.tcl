# ============================================================================
# run_aes_app.tcl - JTAG Boot Phase 2 (Step 5: download and run AES app)
# ============================================================================
# Assumes Phase 1 (jtag_boot_pre_aes.tcl) has already:
#   - System reset + JTAG boot mode
#   - PL AXI enabled
#   - PMUFW running
#   - FSBL initialized PS (DDR, clocks)
#   - UART1 configured
#   - A53 #0 halted
#
# This script downloads the AES application to A53 #0 and runs it.
# The ILA should be armed in HW Manager BEFORE running this script.
# ============================================================================

set aes_app "C:/Work/Eitesal_EG/SMC26-24/kv260_integration/sw_baremetal/aes_ila_loop.elf"

# ============================================================================
# Step 5: Download and run AES application
# ============================================================================
puts "========================================================="
puts "Step 5: Download and run AES-128 baremetal application"
puts "========================================================="

connect

targets -set -filter {name =~ "Cortex-A53 #0"}

# Download AES app to DDR (initialized by FSBL in Phase 1)
dow $aes_app

# Run the application
con

puts "Step 5 complete: AES application running."
puts "  UART output should appear on COM6 (115200 baud)."
puts "  Waiting 30 seconds for AES tests to complete..."
puts ""

# Wait for AES tests to complete
after 30000

# ============================================================================
# Done
# ============================================================================
puts "========================================================="
puts "  AES test should be complete."
puts "  Check ILA capture in Hardware Manager."
puts "  Check UART output on COM6 for test results."
puts "========================================================="

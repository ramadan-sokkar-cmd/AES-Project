# ============================================================================
# jtag_boot.tcl - Proper JTAG Baremetal Boot for KV260 AES Accelerator
# ============================================================================
# Follows the official AMD Kria SOM baremetal JTAG boot flow:
#   1. Switch to JTAG boot mode (mwr + rst -system)
#   2. Load bitstream via fpga + CSU register write
#   3. Download and run PMUFW (handles PL power management)
#   4. Download and run FSBL (initializes DDR, clocks, PS peripherals)
#   5. Download and run AES application
#
# This is the flow we SHOULD have used from the start. Our previous attempts
# skipped steps 1, 2b, 3, and 4 — which is why PL AXI always hung.
#
# Reference: https://xilinx.github.io/kria-apps-docs/creating_applications/
#            2022.1/build/html/docs/baremetal.html (Option 1: JTAG)
# ============================================================================

# ---- File paths ----
set bitfile "C:/Work/Eitesal_EG/SMC26-24/kv260_integration/vivado/aes_kv260/aes_kv260.runs/impl_1/design_1_wrapper.bit"
set pmufw   "C:/Work/Eitesal_EG/SMC26-24/kv260_integration/sw_baremetal/workspace/aes_platform/zynqmp_pmufw/pmufw.elf"
set fsbl    "C:/Work/Eitesal_EG/SMC26-24/kv260_integration/sw_baremetal/workspace/aes_platform/zynqmp_fsbl/fsbl_a53.elf"
set aes_app "C:/Work/Eitesal_EG/SMC26-24/kv260_integration/sw_baremetal/aes_fsbl.elf"

# ---- Helper: find target by pattern ----
proc safe_target {pattern} {
    set t [targets -set -filter {name =~ $pattern}]
    return $t
}

# ============================================================================
# Step 1: Connect and switch to JTAG boot mode
# ============================================================================
puts "========================================================="
puts "Step 1: Connect and switch to JTAG boot mode"
puts "========================================================="

connect

# Select PS TAP (has access to full register space)
targets -set -filter {name =~ "PSU"}

# Clear multiboot offset (Boot ROM image selector)
mwr 0xffca0010 0x0

# Switch boot mode to JTAG (CRL_APB.BOOT_MODE pins)
# This tells the Boot ROM we're in JTAG mode so FSBL
# will skip boot-media reading and just initialize PS
mwr 0xff5e0200 0x0100

# System reset — resets all CPUs, peripherals, and PL
rst -system

# Wait for reset to complete and JTAG chain to stabilize
after 2000
puts "Step 1 complete: System reset done, JTAG boot mode active."
puts ""

# ============================================================================
# Step 2: Load bitstream into PL
# ============================================================================
puts "========================================================="
puts "Step 2: Load AES bitstream into PL"
puts "========================================================="

targets -set -filter {name =~ "PSU"}

# Program FPGA via JTAG (uses ICAP path, works without DDR)
fpga $bitfile

# CSU register write — enables PL AXI access from PS
# This is from the official AMD Kria baremetal flow
mwr 0xffca0038 0x1FF

# Verify PL is configured (use catch to handle mrd output format)
puts "PCAP_STATUS:"
catch {mrd 0xffca3010}
puts "Step 2 complete: Bitstream loaded into PL."
puts ""

# ============================================================================
# Step 3: Download and run PMUFW
# ============================================================================
puts "========================================================="
puts "Step 3: Download and run PMUFW 2025.2"
puts "========================================================="

# Select PMU MicroBlaze target
targets -set -filter {name =~ "MicroBlaze PMU"}
after 500

# Download PMUFW to PMU local memory
dow $pmufw

# Start PMUFW — it will manage PL power domains and isolation
con
after 2000

puts "Step 3 complete: PMUFW running (managing PL power)."
puts ""

# ============================================================================
# Step 4: Download and run FSBL
# ============================================================================
puts "========================================================="
puts "Step 4: Download and run FSBL 2025.2"
puts "========================================================="

# Select A53 Core 0
targets -set -filter {name =~ "Cortex-A53 #0"}

# Reset A53 core (clears registers, sets PC to reset vector)
rst -processor -clear-registers

# Download FSBL to OCM (doesn't need DDR)
dow $fsbl

# Run FSBL — it initializes DDR, clocks, and PS peripherals
# FSBL detects JTAG boot mode and skips boot-media reading
con

# Wait for FSBL to complete initialization
puts "  Waiting 10 seconds for FSBL to initialize PS..."
after 10000

# Stop A53 after FSBL has finished
stop
puts "Step 4 complete: FSBL initialized PS (DDR, clocks, peripherals)."
puts ""

# ============================================================================
# Step 4b: Manually configure UART1 (missing from FSBL's psu_init.c)
# ============================================================================
puts "========================================================="
puts "Step 4b: Configure UART1 clock + reset + MIO pins (psu_init fix)"
puts "========================================================="

# Switch to PSU for JTAG register access
targets -set -filter {name =~ "PSU"}

# --- Fix 1: Enable UART1 reference clock ---
# UART1_REF_CTRL @ 0xFF5E0078: CLKACT=1, DIVISOR1=1, DIVISOR0=0xA, SRCSEL=IOPLL
mwr 0xFF5E0078 0x01010A00
after 100

# --- Fix 2: Configure MIO pins 36-37 for UART1 ---
# Vivado psu_init.tcl: MASK=0x000000FE, VALUE=0x000000C0
# The FSBL psu_init.c has VALUE=0x00000000 (wrong!)
mwr 0xFF180090 0x000000C0
after 50
mwr 0xFF180094 0x000000C0
after 100

# --- Fix 3: Clear UART1 block-level reset ---
# RST_LPD_IOU2 @ 0xFF5E0238: clear bit 2 (UART1_RESET)
# Write 0 to release all LPD IO peripheral resets
mwr 0xFF5E0238 0x00000000
after 100

# Verify UART1 is accessible now
puts "UART1 verification:"
catch {puts "  UART1_CR (0xFF010000): [mrd 0xFF010000]"}
catch {puts "  UART1_SR (0xFF010008): [mrd 0xFF010008]"}
catch {puts "  MIO_PIN_36 (0xFF180090): [mrd 0xFF180090]"}
catch {puts "  MIO_PIN_37 (0xFF180094): [mrd 0xFF180094]"}
puts "Step 4b complete: UART1 clock + MIO + reset configured."
puts ""

# ============================================================================
# Step 5: Download and run AES application
# ============================================================================
puts "========================================================="
puts "Step 5: Download and run AES-128 baremetal application"
puts "========================================================="

# Switch back to A53 Core 0 (was on PSU for UART1 register writes)
targets -set -filter {name =~ "Cortex-A53 #0"}

# Download AES app to DDR (now initialized by FSBL)
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
# Done — check application state
# ============================================================================
puts "========================================================="
puts "Boot sequence complete. Checking A53 state..."
puts "========================================================="

targets -set -filter {name =~ "Cortex-A53 #0"}
set state [targets -index 0]
puts "A53 state: $state"

# Keep JTAG connected for potential ILA debugging
puts ""
puts "JTAG session remains connected for debugging."
puts "Use Hardware Manager for ILA inspection if needed."
puts "========================================================="

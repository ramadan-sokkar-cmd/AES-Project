# ============================================================================
# AES-128 Baremetal Build Script for ZynqMP (KV260)
# ============================================================================
# Creates a Vitis standalone platform from the Vivado XSA, builds the
# standalone BSP, creates a baremetal application, and compiles it.
#
# Usage:
#   xsct build_baremetal.tcl
# ============================================================================

set PROJECT_ROOT    [file normalize "C:/Work/Eitesal_EG/SMC26-24/kv260_integration"]
set XSA_PATH        [file normalize "$PROJECT_ROOT/vivado/aes_kv260.xsa"]
set WORKSPACE       [file normalize "$PROJECT_ROOT/sw_baremetal/workspace"]
set APP_NAME        "aes_baremetal"
set PLATFORM_NAME   "aes_platform"
set PROC            "psu_cortexa53_0"
set OS              "standalone"

puts "=============================================="
puts "  AES-128 Baremetal Build (Vitis 2025.2)"
puts "=============================================="
puts "  XSA:      $XSA_PATH"
puts "  Workspace: $WORKSPACE"
puts "  Processor: $PROC"
puts "==============================================\n"

# ---- Set workspace ----
setws $WORKSPACE

# ---- Create platform from XSA ----
puts ">>> Creating platform '$PLATFORM_NAME'..."
if {[catch {platform create -name $PLATFORM_NAME \
    -hw $XSA_PATH \
    -os $OS \
    -proc $PROC} result]} {
    puts "Platform create result: $result"
    # If it already exists, continue
    if {![info exists result] || [string match "*already*" $result]} {
        puts "Platform already exists, continuing..."
    }
}

# ---- Build platform (generates BSP) ----
puts "\n>>> Generating platform (building BSP, this takes a few minutes)..."
platform generate

# ---- Application is compiled separately via Makefile ----
puts "\n>>> Platform build complete."
puts ">>> To compile the application, run:"
puts "    cd sw_baremetal && make"
puts "\n>>> To package the boot image, run:"
puts "    cd boot && bootgen -image aes_baremetal.bif -arch zynqmp -o BOOT.BIN -w on"

# ---- Report ----
puts "\n=============================================="
puts "  PLATFORM BUILD COMPLETE"
puts "=============================================="
puts "  Platform: $WORKSPACE/$PLATFORM_NAME"
puts "  FSBL:     $WORKSPACE/$PLATFORM_NAME/zynqmp_fsbl/fsbl_a53.elf"
puts "  PMUFW:    $WORKSPACE/$PLATFORM_NAME/zynqmp_pmufw/pmufw.elf"
puts "  BSP lib:  $WORKSPACE/$PLATFORM_NAME/psu_cortexa53_0/standalone_domain/bsp/psu_cortexa53_0/lib/libxil.a"
puts "=============================================="

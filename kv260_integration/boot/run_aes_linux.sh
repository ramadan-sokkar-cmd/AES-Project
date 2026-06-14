#!/bin/bash
# ============================================================================
# AES-128 Hardware Accelerator — PetaLinux Runtime Script
# ============================================================================
# Run this script on the KV260 board running PetaLinux.
#
# This script:
#   1. Loads the AES bitstream into the PL fabric using fpgautil
#   2. Runs the AES Linux application
#
# Prerequisites:
#   - KV260 booted with pre-built PetaLinux image
#   - design_1_wrapper.bit and aes_linux copied to the board
#   - Run as root: sudo ./run_aes_linux.sh
# ============================================================================

set -e

echo "=============================================="
echo "  AES-128 Hardware Accelerator (Linux)"
echo "=============================================="

# ---- Check files exist ----
if [ ! -f design_1_wrapper.bit ]; then
    echo "ERROR: design_1_wrapper.bit not found in current directory"
    echo "Copy it from: kv260_integration/vivado/aes_kv260/aes_kv260.runs/impl_1/"
    exit 1
fi

if [ ! -f aes_linux ]; then
    echo "ERROR: aes_linux binary not found"
    echo "Copy it from: kv260_integration/sw_linux/"
    exit 1
fi

# ---- Make binary executable ----
chmod +x aes_linux

# ---- Load bitstream into PL ----
echo ">>> Loading bitstream into PL..."
if fpgautil -b design_1_wrapper.bit 2>/dev/null; then
    echo "    Bitstream loaded successfully."
elif fpgautil -b design_1_wrapper.bit -o design_1_wrapper.dtbo 2>/dev/null; then
    echo "    Bitstream + DTBO loaded successfully."
else
    echo "    fpgautil failed, trying direct firmware load..."
    mkdir -p /lib/firmware 2>/dev/null || true
    echo 0 > /sys/class/fpga_manager/fpga0/flags 2>/dev/null || true
    cp design_1_wrapper.bit /lib/firmware/aes.bit 2>/dev/null || true
    echo aes.bit > /sys/class/fpga_manager/fpga0/firmware 2>/dev/null || {
        echo "    ERROR: Could not load bitstream. Check permissions and drivers."
        exit 1
    }
fi

echo ""

# ---- Run AES application ----
echo ">>> Running AES application..."
echo ""
./aes_linux

echo ""
echo "=============================================="
echo "  Done."
echo "=============================================="

#!/usr/bin/env python3
"""
Orchestrator for proper JTAG baremetal boot of KV260 AES accelerator.
Follows official AMD Kria SOM baremetal JTAG flow.

Starts UART capture (background thread), runs xsct TCL script, then
checks UART output for AES test results.
"""
import subprocess
import threading
import serial
import time
import sys
import os
import re

# ---- Configuration ----
XSCT_BIN = r"C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat"
TCL_SCRIPT = os.path.join(os.path.dirname(__file__), "jtag_boot.tcl")
UART_PORT = "COM6"
UART_BAUD = 115200
UART_OUTPUT = os.path.join(os.path.dirname(__file__), "uart_jtag_boot.txt")
XSCT_TIMEOUT = 120  # seconds for xsct to complete

# ---- UART Capture Thread ----
uart_data = bytearray()
uart_lock = threading.Lock()
uart_stop = threading.Event()

def capture_uart():
    """Background thread that captures UART data."""
    global uart_data
    try:
        ser = serial.Serial(UART_PORT, UART_BAUD, timeout=0.5,
                           bytesize=serial.EIGHTBITS,
                           parity=serial.PARITY_NONE,
                           stopbits=serial.STOPBITS_ONE)
    except Exception as e:
        print(f"[UART] Cannot open {UART_PORT}: {e}")
        return

    print(f"[UART] Capture started on {UART_PORT}")
    while not uart_stop.is_set():
        data = ser.read(4096)
        if data:
            with uart_lock:
                uart_data.extend(data)
            # Print in real-time
            text = data.decode("ascii", errors="replace")
            safe = text.encode("ascii", errors="replace").decode("ascii")
            sys.stdout.write(safe)
            sys.stdout.flush()

    ser.close()
    print("[UART] Capture stopped.")

    # Save to file
    with open(UART_OUTPUT, "wb") as f:
        with uart_lock:
            f.write(uart_data)
    print(f"[UART] Saved to {UART_OUTPUT}")


# ---- Main ----
def main():
    print("=" * 60)
    print("KV260 AES JTAG Baremetal Boot (Official AMD Flow)")
    print("=" * 60)
    print()

    # Verify files exist
    files_to_check = [
        XSCT_BIN,
        TCL_SCRIPT,
        r"C:\Work\Eitesal_EG\SMC26-24\kv260_integration\sw_baremetal\workspace\aes_platform\zynqmp_pmufw\pmufw.elf",
        r"C:\Work\Eitesal_EG\SMC26-24\kv260_integration\sw_baremetal\workspace\aes_platform\zynqmp_fsbl\fsbl_a53.elf",
        r"C:\Work\Eitesal_EG\SMC26-24\kv260_integration\vivado\aes_kv260\aes_kv260.runs\impl_1\design_1_wrapper.bit",
        r"C:\Work\Eitesal_EG\SMC26-24\kv260_integration\sw_baremetal\aes_fsbl.elf",
    ]
    for f in files_to_check:
        if not os.path.exists(f):
            print(f"[ERROR] File not found: {f}")
            sys.exit(1)
    print("[OK] All required files present.")
    print()

    # Start UART capture thread
    print("[1/3] Starting UART capture...")
    uart_thread = threading.Thread(target=capture_uart, daemon=True)
    uart_thread.start()
    time.sleep(1)

    # Run xsct TCL script
    print("[2/3] Running xsct JTAG boot script...")
    print(f"  TCL: {TCL_SCRIPT}")
    print(f"  xsct: {XSCT_BIN}")
    print()

    cmd = [XSCT_BIN, TCL_SCRIPT]
    try:
        result = subprocess.run(
            cmd,
            timeout=XSCT_TIMEOUT,
            capture_output=False,
            text=True
        )
        print()
        print(f"[xsct] Exit code: {result.returncode}")
    except subprocess.TimeoutExpired:
        print()
        print(f"[ERROR] xsct timed out after {XSCT_TIMEOUT}s!")
    except Exception as e:
        print()
        print(f"[ERROR] xsct failed: {e}")

    # Wait a bit more for any final UART output
    print()
    print("[3/3] Waiting 5s for final UART output...")
    time.sleep(5)

    # Stop UART capture
    uart_stop.set()
    uart_thread.join(timeout=10)

    # Analyze results
    print()
    print("=" * 60)
    print("ANALYSIS")
    print("=" * 60)

    with uart_lock:
        text = uart_data.decode("ascii", errors="replace")

    # Check for key indicators
    checks = [
        ("FSBL output",         r"First Stage Boot Loader", "FSBL ran"),
        ("PMUFW output",        r"PMU Firmware",            "PMUFW ran"),
        ("AES banner",          r"AES.128",                  "AES app started"),
        ("PL AXI access",       r"AFTER read",               "PL AXI accessible"),
        ("Test PASS",           r"\[PASS\]|PASS",            "AES test passed"),
        ("Test FAIL",           r"\[FAIL\]|FAIL",            "AES test failed"),
        ("AXI hang",            r"BEFORE read",              "AXI hang (no AFTER)"),
        ("Key expansion",       r"Key expansion|key_ready",  "Key loaded OK"),
        ("Throughput",          r"Throughput|throughput|MB/s|Gbps", "Throughput measured"),
    ]

    for name, pattern, desc in checks:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            print(f"  [FOUND] {desc}")
        else:
            print(f"  [----]  {desc}")

    # Print last 50 lines of UART output
    print()
    print("--- Last UART output ---")
    lines = text.split('\n')
    for line in lines[-50:]:
        if line.strip():
            print(f"  {line.rstrip()}")


if __name__ == "__main__":
    main()

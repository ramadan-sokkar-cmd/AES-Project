#!/usr/bin/env python3
"""
Linux boot + AES test orchestrator for KV260.

Waits for the user to power-cycle the board, captures PetaLinux boot on COM6,
logs in, and runs the AES test automatically.
"""
import serial
import time
import sys
import os
import re
import threading

UART_PORT = os.environ.get("KV260_UART", "COM6")
UART_BAUD = 115200
TIMEOUT_BOOT = 120   # seconds for Linux to boot
TIMEOUT_CMD = 30     # seconds for each command response

def main():
    print("=" * 60)
    print("KV260 AES Linux Test Orchestrator")
    print("=" * 60)
    print(f"  UART: {UART_PORT} @ {UART_BAUD} baud")
    print()

    try:
        ser = serial.Serial(UART_PORT, UART_BAUD, timeout=0.5,
                           bytesize=serial.EIGHTBITS,
                           parity=serial.PARITY_NONE,
                           stopbits=serial.STOPBITS_ONE)
    except Exception as e:
        print(f"ERROR: Cannot open {UART_PORT}: {e}")
        return 1

    print("Serial port open. Waiting for data...")
    print("(Power-cycle the KV260 now to boot PetaLinux)")
    print()

    # ---- Phase 1: Wait for boot ----
    boot_data = bytearray()
    print("[1/4] Waiting for PetaLinux boot (up to %ds)..." % TIMEOUT_BOOT)
    boot_start = time.time()
    login_seen = False

    while time.time() - boot_start < TIMEOUT_BOOT:
        data = ser.read(4096)
        if data:
            boot_data.extend(data)
            text = data.decode("ascii", errors="replace")
            safe = text.encode("ascii", errors="replace").decode("ascii")
            sys.stdout.write(safe)
            sys.stdout.flush()

            # Check for login prompt
            combined = boot_data.decode("ascii", errors="replace")
            if "login:" in combined.lower() and not login_seen:
                login_seen = True
                print("\n\n[Login prompt detected]")
                break

            # Check if already logged in (auto-login)
            if "root@xilinx" in combined or "$ " in combined[-200:]:
                login_seen = True
                print("\n\n[Already logged in]")
                break
    else:
        print("\n\n[WARNING] Boot timeout reached.")

    time.sleep(1)

    # ---- Phase 2: Login ----
    print("\n[2/4] Logging in...")

    def send_cmd(cmd, wait=1.0):
        """Send a command and wait."""
        ser.write((cmd + "\n").encode("ascii"))
        time.sleep(wait)

    def read_until(pattern, timeout_s=10):
        """Read until pattern is found or timeout."""
        data = bytearray()
        start = time.time()
        while time.time() - start < timeout_s:
            chunk = ser.read(4096)
            if chunk:
                data.extend(chunk)
                text = chunk.decode("ascii", errors="replace")
                safe = text.encode("ascii", errors="replace").decode("ascii")
                sys.stdout.write(safe)
                sys.stdout.flush()
                combined = data.decode("ascii", errors="replace")
                if re.search(pattern, combined):
                    return True, combined
        return False, data.decode("ascii", errors="replace")

    # Try login
    send_cmd("root", 2.0)
    found, _ = read_until(r"[#\$] ", timeout_s=5)
    if not found:
        send_cmd("root", 2.0)
        read_until(r"[#\$] ", timeout_s=5)

    # ---- Phase 3: Load bitstream ----
    print("\n\n[3/4] Loading bitstream...")
    send_cmd("mkdir -p /mnt/sd")
    send_cmd("mount /dev/mmcblk0p1 /mnt/sd 2>/dev/null || mount /dev/mmcblk1p1 /mnt/sd 2>/dev/null", 2.0)
    found, mount_output = read_until(r"[#\$] ", timeout_s=5)
    
    # Check if mount worked
    send_cmd("ls /mnt/sd/", 2.0)
    found, ls_output = read_until(r"[#\$] ", timeout_s=5)
    
    if "design_1_wrapper.bit" not in ls_output:
        print("\n\n[ERROR] Bitstream not found on mounted SD card!")
        print("Trying alternative paths...")
        send_cmd("find / -name 'design_1_wrapper.bit' 2>/dev/null", 5.0)
        read_until(r"[#\$] ", timeout_s=10)
        ser.close()
        return 1

    # Load bitstream via fpgautil
    print("\n\nLoading bitstream via fpgautil...")
    send_cmd("fpgautil -b /mnt/sd/design_1_wrapper.bit", 10.0)
    found, fpga_output = read_until(r"[#\$] ", timeout_s=30)
    
    if not found:
        print("\n\n[WARNING] fpgautil might have timed out")

    # ---- Phase 4: Run AES test ----
    print("\n\n[4/4] Running AES test...")
    send_cmd("chmod +x /mnt/sd/aes_linux", 1.0)
    read_until(r"[#\$] ", timeout_s=3)
    
    send_cmd("/mnt/sd/aes_linux", 15.0)
    
    # Read test output (wait for summary)
    found, test_output = read_until(r"SUMMARY|Test complete|passed", timeout_s=TIMEOUT_CMD)

    # Wait a bit more for final output
    time.sleep(3)
    remaining = ser.read(8192)
    if remaining:
        text = remaining.decode("ascii", errors="replace")
        safe = text.encode("ascii", errors="replace").decode("ascii")
        sys.stdout.write(safe)
        sys.stdout.flush()

    # ---- Analysis ----
    print("\n\n" + "=" * 60)
    print("ANALYSIS")
    print("=" * 60)

    all_output = (test_output + remaining.decode("ascii", errors="replace")
                  if remaining else test_output)

    checks = [
        ("5/5 passed",       r"5/5\s*passed",          "All test vectors pass"),
        ("Test PASS",        r"\[PASS\]",              "AES test passed"),
        ("Test FAIL",        r"\[FAIL\]",              "AES test failed"),
        ("Key expansion",    r"Key expansion complete", "Key loaded OK"),
        ("Latency",          r"[Ll]atency.*\d+\s*ns",  "Latency measured"),
        ("Throughput",       r"[Tt]hroughput.*[Mm]bps|blocks/sec", "Throughput measured"),
        ("fpgautil OK",      r"SUCCESS|done|loaded",   "Bitstream loaded"),
    ]

    for name, pattern, desc in checks:
        if re.search(pattern, all_output, re.IGNORECASE):
            print(f"  [FOUND] {desc}")
        else:
            print(f"  [----]  {desc}")

    ser.close()
    print("\nDone.")
    return 0

if __name__ == "__main__":
    sys.exit(main())

# AES-128 Hardware Accelerator — KV260 Integration Tutorial

## SMC26-24 Graduation Project

**Board:** Kria KV260 Vision AI Starter Kit (Zynq UltraScale+ ZU5EV)
**Toolchain:** AMD Vivado / Vitis 2025.2
**Target:** Cortex-A53 (AArch64) — baremetal and PetaLinux Linux

---

## Final Hardware Results

Both baremetal and Linux flows were tested on the physical KV260 board.
All 5 NIST/FIPS test vectors pass.

| Metric | Baremetal (JTAG) | Linux (PetaLinux) |
|--------|------------------|-------------------|
| Correctness | **5/5 PASSED** | **5/5 PASSED** |
| Single-block latency | **490 ns** (49 cycles @ 99 MHz) | **530 ns** |
| Throughput (1000 blocks) | **13 Mbps** (103,412 blocks/sec) | **100.29 Mbps** (783,479 blocks/sec) |
| Bitstream load | N/A (JTAG `fpga` command) | **133 ms** (`fpgautil`) |

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [The Reset Bug: Root Cause and Fix](#2-the-reset-bug-root-cause-and-fix)
3. [Prerequisites](#3-prerequisites)
4. [Vivado Hardware Design](#4-vivado-hardware-design)
5. [AES Register Map](#5-aes-register-map)
6. [Baremetal Software](#6-baremetal-software)
7. [Baremetal JTAG Boot Flow](#7-baremetal-jtag-boot-flow)
8. [Linux Software and Runtime Flow](#8-linux-software-and-runtime-flow)
9. [Test Vectors](#9-test-vectors)
10. [Troubleshooting](#10-troubleshooting)
11. [Appendix: Build Commands Summary](#appendix-build-commands-summary)

---

## 1. Architecture Overview

```
+-------------------------------------------------------------+
|                    KV260 (Zynq UltraScale+)                  |
|                                                               |
|  +------------------+         +------------------------------+ |
|  |  PS (Processing  |         |  PL (Programmable Logic)     | |
|  |     System)      |         |                              | |
|  |                   |         |  +------------------------+  | |
|  |  Cortex-A53 x4   |  AXI4   |  | axi_interconnect       |  | |
|  |  (1.3 GHz)       |---------|--| (AXI4 Full -> AXI4-Lit)|  | |
|  |                   |  32-bit |  +----------+-------------+  | |
|  |  M_AXI_HPM0_FPD  |         |             | AXI4-Lite     | |
|  |  @ pl_clk0        |         |  +----------v-------------+  | |
|  |  (~100 MHz)       |         |  | AES-128 IP             |  | |
|  |                   |         |  |  +------------------+  |  | |
|  |  DDR4 (2 GB)     |         |  |  | Key Expansion    |  |  | |
|  |  UART1 @0xFF010  |         |  |  | (49 cycles)      |  |  | |
|  |  (USB-UART)      |         |  |  +--------+---------+  |  | |
|  |                   |         |  |           |            |  | |
|  |                   |         |  |  +--------v---------+  |  | |
|  |                   |         |  |  | 5-Stage Pipeline  |  |  | |
|  |                   |         |  |  | (5 cycles)        |  |  | |
|  |                   |         |  |  +------------------+  |  | |
|  |                   |         |  |  @ 0xA000_0000 (64K)  |  | |
|  |                   |         |  +------------------------+  | |
|  |                   |         |                              | |
|  |                   |         |  +------------------------+  | |
|  |                   |         |  | system_ila (debug)     |  | |
|  |                   |         |  | 2 AXI monitor slots    |  | |
|  |                   |         |  +------------------------+  | |
|  +------------------+         +------------------------------+ |
+-------------------------------------------------------------+
```

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| PS-PL Interface | M_AXI_HPM0_FPD (AXI4 Full, 32-bit) | FPD port provides direct A53 access to PL |
| Protocol Conversion | axi_interconnect | AXI4 Full to AXI4-Lite for AES registers |
| AES Clock | pl_clk0 (~100 MHz from PS PLL) | No separate clock needed; avoids CDC |
| AES Address | 0xA000_0000 (64K range) | Matches team's TEST4 address map |
| Console UART | UART1 @ 0xFF010000 (MIO 36/37) | KV260 USB-UART bridge uses UART1 |
| Timer | AArch64 Generic Timer | 64-bit, ~99 MHz, read via system registers |
| Debug | system_ila (2 slots) | Captures AXI4-Lite transactions on both PS and AES sides |

---

## 2. The Reset Bug: Root Cause and Fix

### The Problem

AES encryption produced wrong ciphertext on the KV260 hardware, even though the
testbench simulation passed all vectors. The root cause was a **key expansion
timing race**:

1. At PL power-up, all AXI slave registers initialize to **0** (key = 0x0000...0000).
2. The AES key expansion module runs **once** at reset deassertion.
3. Since the C driver writes the actual key **milliseconds later** (after the
   FSBL, PMUFW, and application startup), the key expansion had already
   completed with key=0.
4. The `key_ready` signal reflected the completion of expanding the wrong key.

**Why the testbench worked:** In simulation, the testbench sets `top_key`
*before* deasserting `top_rst` -- the key was present when expansion started.

### The Fix: Software-Controlled AES Reset

We added a **dedicated AES core reset** that the software driver controls
independently from the AXI bus reset:

**RTL change in `myip_test5_v1_0_S00_AXI.v`:**
```verilog
output wire aes_rst_n,
...
assign aes_rst_n = S_AXI_ARESETN & slv_reg8[1];
```

**Wiring in `myip_test5_v1_0.v`:**
```verilog
wire aes_rst_n;
...
// AXI wrapper drives aes_rst_n
.aes_rst_n(aes_rst_n)

// AES core uses aes_rst_n as its reset
aes_top top(
    ...
    .rst_n(aes_rst_n),
    ...
);
```

**CTRL register bit 1** now controls the AES core reset:
- `CTRL[1] = 0` -> AES core held in reset (key expansion halted)
- `CTRL[1] = 1` -> AES core running (AND with AXI reset)

### Updated Driver Sequence

```c
// Phase 1: Key load with proper reset sequence
aes_hold_reset();           // CTRL = 0 (AES in reset)
aes_load_key(key);          // Write 4 key registers
aes_release_reset();        // CTRL = 2 (AES out of reset, expansion begins)
// Wait for key_ready       // ~49 cycles for expansion

// Phase 2: Encryption
aes_load_plaintext(pt);     // Write 4 data registers
aes_start();                // CTRL = 3 (valid_in + rst_n)
while (!aes_valid_out());   // Wait 5 cycles
aes_read_ciphertext(ct);    // Read 4 output registers
aes_stop();                 // CTRL = 2 (deassert valid_in)
```

This is the **critical fix** that made all 5 test vectors pass on hardware.

---

## 3. Prerequisites

### Software

| Tool | Version | Path |
|------|---------|------|
| Vivado | 2025.2 | `C:\AMDDesignTools\2025.2\Vivado\bin` |
| Vitis (xsct, bootgen) | 2025.2 | `C:\AMDDesignTools\2025.2\Vitis\bin` |
| aarch64 baremetal GCC | 13.3.0 | `...\Vitis\gnu\aarch64\nt\aarch64-none\bin` |
| aarch64 Linux GCC | 13.3.0 | `...\Vitis\gnu\aarch64\nt\aarch64-linux\bin` |
| GNU Make | -- | `...\Vitis\gnuwin\bin\make.exe` |
| Python 3 | Any | For test orchestrator scripts |
| pyserial | Any | `pip install pyserial` (for UART automation) |

### Hardware

- KV260 Starter Kit with power adapter (12V, 3A)
- MicroSD card (>= 8 GB, for Linux boot)
- Micro-USB cable for UART console
- Host PC (Windows 10/11) with USB port

### Project Directory Structure

```
kv260_integration/
|-- vivado/
|   |-- build_kv260_v2.tcl          # v2 build script (axi_interconnect + system_ila)
|   |-- aes_kv260.xsa               # Exported hardware handoff
|   |-- aes_kv260/                  # Vivado project directory
|   |   |-- aes_kv260.runs/impl_1/
|   |       |-- design_1_wrapper.bit  # Bitstream
|   |       |-- design_1_wrapper.ltx  # Debug probes (for ILA)
|   |-- utilization_report.txt
|   `-- timing_report.txt
|-- sw_baremetal/
|   |-- aes_hw.h                    # Shared driver header
|   |-- aes_baremetal.c             # Baremetal application
|   |-- start.S                     # AArch64 startup code
|   |-- lscript.ld                  # Linker script
|   |-- Makefile                    # Build (JTAG and FSBL modes)
|   |-- aes_fsbl.elf                # Compiled ELF (FSBL boot mode)
|   `-- workspace/                  # Vitis workspace + BSP
|       `-- aes_platform/
|           |-- zynqmp_fsbl/fsbl_a53.elf    # FSBL 2025.2
|           `-- zynqmp_pmufw/pmufw.elf      # PMUFW 2025.2
|-- sw_linux/
|   |-- aes_linux.c                 # Linux user-space application
|   `-- Makefile                    # Cross-compile (static)
|-- boot/
|   |-- jtag_boot.tcl               # 5-step JTAG boot script
|   |-- run_jtag_boot.py            # JTAG boot orchestrator
|   |-- run_linux_test.py           # Linux test orchestrator
|   `-- uart_jtag_boot.txt          # Captured UART output (5/5 passing)
`-- docs/
    `-- KV260_Integration_Tutorial.md  # This file
```

---

## 4. Vivado Hardware Design

### 4.1 Block Design Components

1. **ZynqMP PS** (`zynq_ultra_ps_e` v3.5) -- KV260 board preset
   - M_AXI_HPM0_FPD enabled (32-bit AXI4 Full master)
   - UART1 on MIO 36/37 (115200 baud)
   - pl_clk0 and pl_clk1 enabled (~100 MHz)
   - DDR4 (2 GB)

2. **AES-128 IP** (`user.org:user:aes_core:1.0`) -- packaged from team RTL
   - AXI4-Lite slave interface (32-bit data, 6-bit address)
   - 128-bit data/key ports, valid/hready handshake, key_ready status

3. **AXI Interconnect** (`axi_interconnect` v2.1)
   - 1 slave port (from PS), 1 master port (to AES)
   - Automatic AXI4 Full to AXI4-Lite protocol conversion
   - All ports clocked from pl_clk0

4. **Processor System Reset** (`proc_sys_reset` v5.0)
   - Synchronizes reset to pl_clk0 domain
   - Input: `pl_resetn0` from PS
   - Output: `peripheral_aresetn` to all PL peripherals

5. **System ILA** (`system_ila` v1.1) -- for debug
   - 2 AXI monitor slots (PS-side and AES-side)
   - 1024 sample depth
   - Used during bring-up to diagnose AXI bus hangs

### 4.2 Building from Tcl

```bash
"C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat" -mode batch -nojournal -nolog ^
  -source "C:\Work\Eitesal_EG\SMC26-24\kv260_integration\vivado\build_kv260_v2.tcl" ^
  -tempDir "C:\Work\Eitesal_EG\SMC26-24\kv260_integration\vivado\tmp"
```

The build script (`build_kv260_v2.tcl`) performs:

1. **Phase 1:** Packages the AES RTL into a reusable IP core
2. **Phase 2:** Creates the block design with all 5 components above
3. **Phase 3:** Runs synthesis, implementation, and bitstream generation
4. **Phase 4:** Exports the XSA and writes utilization/timing reports

Build time: ~15 minutes on a modern PC.

### 4.3 PS Configuration Details

Key PS register settings applied in the Tcl:

```tcl
CONFIG.PSU__USE__M_AXI_GP0 {1}             # Enable FPD master port
CONFIG.PSU__MAXIGP0__DATA_WIDTH {32}        # 32-bit AXI4 Full
CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1}   # Enable UART1
CONFIG.PSU__UART1__PERIPHERAL__IO {MIO 36 .. 37}  # Route to MIO pins
CONFIG.PSU__UART1__BAUD_RATE {115200}
CONFIG.PSU__FPGA_PL0_ENABLE {1}             # Enable pl_clk0 output
CONFIG.PSU__FPGA_PL1_ENABLE {1}             # Enable pl_clk1 output
CONFIG.PSU__PL_CLK0_BUF {TRUE}              # Buffer pl_clk0
```

### 4.4 Utilization Report (Actual)

From `vivado/utilization_report.txt` (device: xczu5ev-sfvc784-2LV-e):

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| CLB LUTs | 13,546 | 117,120 | 11.57% |
| LUT as Logic | 12,375 | 117,120 | 10.57% |
| LUT as Memory | 1,171 | 57,600 | 2.03% |
| CLB Registers (FF) | 8,782 | 234,240 | 3.75% |
| CARRY8 | 89 | 14,640 | 0.61% |
| F7 Muxes | 2,800 | 58,560 | 4.78% |
| BRAM | 0 | -- | 0% |
| DSP | 0 | -- | 0% |

Note: The LUT count includes the system_ila debug logic. The AES core itself
uses approximately 3,000-4,000 LUTs and 2,500-3,000 FFs.

### 4.5 Timing Report (Actual)

From `vivado/timing_report.txt`:

| Check | Worst Slack | Status |
|-------|-------------|--------|
| Setup (pl_clk0, ~10ns period) | **+3.362 ns** | MET |
| Hold | **+0.011 ns** | MET |
| Pulse Width | **+3.500 ns** | MET |
| Total Failing Endpoints | **0** | ALL MET |

The design has 3.362 ns of positive setup slack at ~100 MHz, meaning it can
comfortably run at this frequency. There is no need for additional pipelining
or retiming.

### 4.6 Output Artifacts

| File | Location | Purpose |
|------|----------|---------|
| `aes_kv260.xsa` | `vivado/` | Hardware handoff for Vitis BSP build |
| `design_1_wrapper.bit` | `vivado/aes_kv260/aes_kv260.runs/impl_1/` | FPGA bitstream |
| `design_1_wrapper.ltx` | Same as .bit | Debug probes for Hardware Manager ILA |

---

## 5. AES Register Map

### AXI4-Lite Register Map (Base: 0xA000_0000, 64K range)

| Offset | Register | Access | Bits | Description |
|--------|----------|--------|------|-------------|
| 0x00 | DATA_IN0 | W | [31:0] | Plaintext bits [31:0] (LSW) |
| 0x04 | DATA_IN1 | W | [63:32] | Plaintext bits [63:32] |
| 0x08 | DATA_IN2 | W | [95:64] | Plaintext bits [95:64] |
| 0x0C | DATA_IN3 | W | [127:96] | Plaintext bits [127:96] (MSW) |
| 0x10 | KEY_IN0 | W | [31:0] | Key bits [31:0] (LSW) |
| 0x14 | KEY_IN1 | W | [63:32] | Key bits [63:32] |
| 0x18 | KEY_IN2 | W | [95:64] | Key bits [95:64] |
| 0x1C | KEY_IN3 | W | [127:96] | Key bits [127:96] (MSW) |
| 0x20 | CTRL | W | Bit 0 | valid_in -- start encryption pulse |
| | | | Bit 1 | aes_rst_n -- AES core reset (1=run, 0=reset) |
| 0x24 | STATUS | R | Bit 0 | valid_out -- ciphertext available |
| | | | Bit 1 | key_ready -- key expansion done |
| 0x28 | DATA_OUT0 | R | [31:0] | Ciphertext bits [31:0] (LSW) |
| 0x2C | DATA_OUT1 | R | [63:32] | Ciphertext bits [63:32] |
| 0x30 | DATA_OUT2 | R | [95:64] | Ciphertext bits [95:64] |
| 0x34 | DATA_OUT3 | R | [127:96] | Ciphertext bits [127:96] (MSW) |

### Byte Ordering Convention

The AES RTL assembles the 128-bit data path as:
```
data_in[127:0] = {DATA_IN3, DATA_IN2, DATA_IN1, DATA_IN0}
```

Where `data_in[127:120]` maps to the **first byte** of the NIST test vector
byte string, and `data_in[7:0]` maps to the **last byte**.

In C, this means:
- `key[0]` = LSW = last 4 bytes of the NIST byte string
- `key[3]` = MSW = first 4 bytes of the NIST byte string

Example: Key `2B7E1516 28AED2A6 ABF71588 09CF4F3C`
```c
uint32_t key[4] = {0x09CF4F3C, 0xABF71588, 0x28AED2A6, 0x2B7E1516};
//                 ^LSW(k[0])                          ^MSW(k[3])
```

---

## 6. Baremetal Software

### 6.1 Driver Layer (`aes_hw.h`)

The shared driver header provides platform-independent access to the AES
hardware. It compiles differently for baremetal (direct memory-mapped I/O)
and Linux (via `mmap`'d `/dev/mem`):

**Register access primitives:**
```c
#ifdef __BAREMETAL__
  // Direct physical address access (baremetal)
  static inline void aes_write32(uint32_t offset, uint32_t val) {
      *(volatile uint32_t *)(AES_BASE_ADDR + offset) = val;
  }
  static inline uint32_t aes_read32(uint32_t offset) {
      return *(volatile uint32_t *)(AES_BASE_ADDR + offset);
  }
#else
  // Via mmap'd /dev/mem (Linux)
  extern volatile uint8_t *aes_base;
  static inline void aes_write32(uint32_t offset, uint32_t val) {
      *(volatile uint32_t *)(aes_base + offset) = val;
  }
#endif
```

**High-level functions:**
```c
void aes_hold_reset(void);           // CTRL = 0 (AES core in reset)
void aes_release_reset(void);         // CTRL = 2 (AES core running)
void aes_load_key(const uint32_t key[4]);
void aes_load_plaintext(const uint32_t pt[4]);
void aes_start(void);                 // CTRL = 3 (valid_in + rst_n)
void aes_stop(void);                  // CTRL = 2 (deassert valid_in)
int  aes_key_ready(void);             // Poll STATUS bit 1
int  aes_valid_out(void);             // Poll STATUS bit 0
void aes_read_ciphertext(uint32_t ct[4]);
```

### 6.2 Baremetal Application (`aes_baremetal.c`)

The baremetal application runs directly on Cortex-A53 #0 without an OS. It
performs three phases:

**Phase 0: PL Configuration**
- Detects exception level (EL3 from JTAG, or EL1 after FSBL)
- Verifies PL AXI access by reading the AES STATUS register

**Phase 1: Functional Correctness**
- Holds AES core in reset
- Writes the 128-bit key
- Releases AES core from reset
- Waits for key expansion (~49 cycles)
- Tests 5 NIST/FIPS vectors

**Phase 2: Latency Measurement**
- Encrypts a single block
- Measures elapsed timer ticks using the AArch64 Generic Timer
- Converts to nanoseconds based on timer frequency (~99 MHz)

**Phase 3: Throughput Benchmark**
- Encrypts 1000 blocks in a tight loop
- Computes blocks/sec and effective Mbps

### 6.3 UART Configuration

The baremetal app initializes UART1 directly (the FSBL only sets up DCC debug
console, not the physical UART):

```c
#define UART0_BASE  0xFF010000  // UART1 on ZynqMP
// 115200 baud from 100 MHz IOPLL: BAUDGEN=124, BAUDDIV=6
// Actual baud: 100MHz/(124*7+6) ~= 115207 (0.006% error)
```

### 6.4 Compilation

The baremetal app is compiled with the Vitis aarch64-none-elf GCC toolchain
against the standalone BSP. There are two build modes:

**JTAG mode** (default, for development):
```bash
cd C:\Work\Eitesal_EG\SMC26-24\kv260_integration\sw_baremetal
"C:\AMDDesignTools\2025.2\Vitis\gnuwin\bin\make.exe"
```
Produces `aes_baremetal.elf` -- expects bitstream pre-loaded via JTAG.

**FSBL boot mode** (for production):
```bash
make fsbl
```
Produces `aes_fsbl.elf` -- expects FSBL + PMUFW to configure PL.

Both modes compile the same `aes_baremetal.c` source; the FSBL mode adds
`-DFSBL_BOOT` which enables the PL-confirmation diagnostics.

### 6.5 Linker Script (`lscript.ld`)

| Section | Address | Notes |
|---------|---------|-------|
| `.text` | 0x00100000 (1 MB) | Code + read-only data |
| `.data` | after `.text` | Initialized data |
| `.bss` | after `.data` | Includes 256 KB stack |
| Entry | `_vector_table` | From `start.S` |

### 6.6 Startup Code (`start.S`)

Custom AArch64 startup that:
1. Sets up exception vectors
2. Configures SCTRL_EL3 for cacheable memory
3. Drops to EL1 for application execution
4. Zeroes BSS
5. Jumps to `main()`

This bypasses the standard BSP startup to give us full control over the
hardware initialization sequence.

---

## 7. Baremetal JTAG Boot Flow

### 7.1 The Official AMD Kria JTAG Flow

The KV260 always boots from QSPI flash. For baremetal development, we use the
official AMD Kria SOM baremetal JTAG boot flow (5 steps):

```
Step 1: Switch to JTAG boot mode (mwr + rst -system)
Step 2: Load bitstream via JTAG (fpga command + CSU register write)
Step 3: Download and run PMUFW (handles PL power management)
Step 4: Download and run FSBL (initializes DDR, clocks, PS peripherals)
Step 4b: Manually fix UART1 configuration (FSBL psu_init.c bug workaround)
Step 5: Download and run AES application
```

### 7.2 Running the JTAG Boot

**Prerequisites:**
- KV260 powered on and connected via micro-USB
- COM port identified (check Windows Device Manager for FTDI FT4232H)
- All build artifacts present (bitstream, PMUFW, FSBL, AES app)

**Method A: Automated (Python orchestrator)**

```bash
cd C:\Work\Eitesal_EG\SMC26-24\kv260_integration\boot
python run_jtag_boot.py
```

This script:
1. Starts a background thread to capture UART output on COM6
2. Runs xsct with the `jtag_boot.tcl` script
3. Analyzes the UART output for test results
4. Saves output to `uart_jtag_boot.txt`

**Method B: Manual (xsct directly)**

```bash
"C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat" ^
  "C:\Work\Eitesal_EG\SMC26-24\kv260_integration\boot\jtag_boot.tcl"
```

Then watch the serial terminal (PuTTY/TeraTerm on COM6, 115200 8N1).

### 7.3 The jtag_boot.tcl Script (Annotated)

**Step 1: Switch to JTAG boot mode**
```tcl
targets -set -filter {name =~ "PSU"}
mwr 0xffca0010 0x0       # Clear multiboot offset
mwr 0xff5e0200 0x0100    # Set BOOT_MODE to JTAG
rst -system               # System reset
after 2000                # Wait for stabilization
```

**Step 2: Load bitstream**
```tcl
fpga $bitfile             # Program FPGA via JTAG/ICAP
mwr 0xffca0038 0x1FF     # Enable PL AXI access from PS
```

**Step 3: Start PMUFW**
```tcl
targets -set -filter {name =~ "MicroBlaze PMU"}
dow $pmufw                # Download PMUFW to PMU local memory
con                       # Start PMUFW
after 2000
```

**Step 4: Start FSBL**
```tcl
targets -set -filter {name =~ "Cortex-A53 #0"}
rst -processor -clear-registers
dow $fsbl                 # Download FSBL to OCM
con                       # Run FSBL (initializes DDR, clocks, peripherals)
after 10000               # Wait for FSBL to complete
stop
```

**Step 4b: UART1 Configuration Fix**

The FSBL BSP's `psu_init.c` is missing three critical UART1 configurations
that exist in Vivado's auto-generated `psu_init.tcl`. Without this fix,
UART1 produces no output.

```tcl
targets -set -filter {name =~ "PSU"}

# Enable UART1 reference clock
mwr 0xFF5E0078 0x01010A00    # UART1_REF_CTRL: CLKACT=1

# Configure MIO pins 36-37 for UART1 (L3_SEL=6)
mwr 0xFF180090 0x000000C0    # MIO_PIN_36
mwr 0xFF180094 0x000000C0    # MIO_PIN_37

# Clear UART1 block-level reset
mwr 0xFF5E0238 0x00000000    # RST_LPD_IOU2: clear UART1_RESET
```

| Register | Address | Vivado Value | FSBL Value (BUG) |
|----------|---------|-------------|------------------|
| UART1_REF_CTRL | 0xFF5E0078 | 0x01010A00 | Missing |
| MIO_PIN_36 | 0xFF180090 | 0x000000C0 | 0x00000000 |
| MIO_PIN_37 | 0xFF180094 | 0x000000C0 | 0x00000000 |
| RST_LPD_IOU2 | 0xFF5E0238 | bit 2 = 0 | Never cleared |

**Step 5: Run AES application**
```tcl
targets -set -filter {name =~ "Cortex-A53 #0"}
dow $aes_app               # Download AES app to DDR
con                         # Run the application
```

### 7.4 Expected Baremetal Output

This is the actual UART output captured during the 5/5 passing run
(saved in `boot/uart_jtag_boot.txt`):

```
==============================================
  AES-128 Hardware Accelerator
  Baremetal Test on ZynqMP (KV260)
==============================================

--- Phase 0: PL Configuration ---
  Exception Level: EL3
  FSBL boot: PL configured by boot image (FSBL+PMUFW 2025.2)
  PL is powered, configured, and out of reset.
  PL0_REF_CTRL = 0x01010A00 (CLKACT=1)

  --- PL AXI Access Test ---
  Read STATUS (0xA0000024)...
  > BEFORE read
  > AFTER read = 0x00000000

--- Phase 1: Functional Correctness ---
Holding AES core in reset...
Loading AES-128 key...
Releasing AES core from reset...
Key expansion complete.

  [PASS] NIST SP800-38A Block 1
  [PASS] NIST SP800-38A Block 2
  [PASS] NIST SP800-38A Block 3
  [PASS] NIST SP800-38A Block 4
  [PASS] FIPS-197 App B

Functional Test: 5/5 passed

--- Phase 2: Latency Measurement ---
  Single-block latency: 49 ticks (490 ns @ 99MHz)

--- Phase 3: Throughput Benchmark (1000 blocks) ---
  Blocks encrypted: 1000
  Total time:       9773 us
  Time per block:   9670 ns
  Throughput:       13 Mbps (103412 blocks/sec)

==============================================
  SUMMARY
==============================================
  Correctness: 5/5 passed
  Latency:     490 ns/block
==============================================
```

### 7.5 Interpreting the Results

- **49 ticks @ 99 MHz = 490 ns** -- This is the hardware encryption latency
  from asserting `valid_in` to seeing `valid_out`. It matches the expected
  ~49 clock cycles (key expansion is 44 cycles in the pipeline, plus overhead).

- **13 Mbps throughput** -- The 1000-block benchmark measures total round-trip
  time including register writes, polling overhead, and inter-block delays.
  This is the effective throughput of the AXI4-Lite register-polling
  interface, not the pipeline's raw throughput.

---

## 8. Linux Software and Runtime Flow

### 8.1 Linux Application (`aes_linux.c`)

The Linux app runs on PetaLinux and accesses the AES hardware via `/dev/mem`
(memory-mapped I/O). It uses the same driver functions from `aes_hw.h`, but
with the Linux I/O backend.

**Hardware access via mmap:**
```c
int fd = open("/dev/mem", O_RDWR | O_SYNC);
void *map = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED,
                 fd, 0xA0000000 & ~0xFFF);
aes_base = (volatile uint8_t *)map;
// Now aes_write32()/aes_read32() use the mmap'd pointer
```

**Timing uses clock_gettime:**
```c
struct timespec ts;
clock_gettime(CLOCK_MONOTONIC, &ts);
uint64_t ns = ts.tv_sec * 1e9 + ts.tv_nsec;
```

The application performs the same three phases as the baremetal version:
functional correctness, latency, and throughput.

### 8.2 Cross-Compilation

```bash
cd C:\Work\Eitesal_EG\SMC26-24\kv260_integration\sw_linux
"C:\AMDDesignTools\2025.2\Vitis\gnuwin\bin\make.exe"
```

This produces a **statically-linked** aarch64 Linux ELF (~707 KB). Static
linking avoids glibc version mismatch with the pre-built PetaLinux image.

### 8.3 Preparing the SD Card

The KV260 boots PetaLinux from QSPI flash (U-Boot loads kernel + ramdisk
from the SD card). The SD card needs:

| File | Purpose |
|------|---------|
| `BOOT.BIN` | PetaLinux boot image (FSBL + PMUFW + ATF + U-Boot) |
| `boot.scr` | U-Boot boot script |
| `Image` | Linux kernel |
| `ramdisk.cpio.gz.u-boot` | Root filesystem (initramfs) |
| `system.dtb` | Device tree |
| `design_1_wrapper.bit` | AES bitstream |
| `aes_linux` | AES test binary |
| `run_aes.sh` | Helper script |

Copy the bitstream and AES binary to the SD card alongside the PetaLinux
boot files.

### 8.4 Running the Linux Test

**Boot PetaLinux:**
1. Insert the SD card into the KV260
2. Power on the board
3. Wait for PetaLinux to boot (~30 seconds)
4. Log in as `root`

**Load bitstream and run test:**
```bash
mount /dev/mmcblk1p1 /mnt/sd
fpgautil -b /mnt/sd/design_1_wrapper.bit
/mnt/sd/aes_linux
```

**Automated (Python orchestrator):**
```bash
cd C:\Work\Eitesal_EG\SMC26-24\kv260_integration\boot
python run_linux_test.py
```

This script waits for the Linux boot, logs in, mounts the SD card, loads
the bitstream via `fpgautil`, and runs the AES test automatically.

### 8.5 Expected Linux Output

```
==============================================
  AES-128 Hardware Accelerator
  Linux User-Space Test on ZynqMP (KV260)
==============================================
  AES base address: 0xA0000000

Hardware mapped successfully.

--- Phase 1: Functional Correctness ---
Holding AES core in reset...
Loading AES-128 key...
Releasing AES core from reset...
Key expansion complete.

  [PASS] NIST SP800-38A Block 1
  [PASS] NIST SP800-38A Block 2
  [PASS] NIST SP800-38A Block 3
  [PASS] NIST SP800-38A Block 4
  [PASS] FIPS-197 App B

Functional Test: 5/5 passed

--- Phase 2: Latency Measurement ---
  Single-block latency: 530 ns

--- Phase 3: Throughput Benchmark (1000 blocks) ---
  Blocks encrypted: 1000
  Total time:       1276 us
  Time per block:   1276 ns
  Throughput:       100.29 Mbps (783479 blocks/sec)

==============================================
  SUMMARY
==============================================
  Correctness: 5/5 passed
  Latency:     530 ns/block
  Throughput:  100.29 Mbps (783479 blocks/sec)
==============================================
```

### 8.6 fpgautil Bitstream Loading

The `fpgautil` utility loads the bitstream through the Linux FPGA Manager
framework. Measured load time: **133 ms**.

```bash
# Verify FPGA manager exists
ls /sys/class/fpga_manager/fpga0

# Load bitstream
fpgautil -b /mnt/sd/design_1_wrapper.bit

# Verify PL is configured
cat /sys/class/fpga_manager/fpga0/state
# Should show: operating
```

---

## 9. Test Vectors

### NIST SP 800-38A Appendix F (ECB-AES128)

All vectors use the same 128-bit key:

**Key:** `2B7E1516 28AED2A6 ABF71588 09CF4F3C`

| # | Plaintext (byte string) | Expected Ciphertext |
|---|------------------------|---------------------|
| 1 | `6BC1BEE2 2E409F96 E93D7E11 7393172A` | `3AD77BB4 0D7A3660 A89ECAF3 2466EF97` |
| 2 | `AE2D8A57 1E03AC9C 9EB76FAC 45AF8E51` | `F5D3D585 03B9699D E785895A 96FDBAAF` |
| 3 | `30C81C46 A35CE411 E5FBC119 1A0A52EF` | `43B1CD7F 598ECE23 881B00E3 ED030688` |
| 4 | `F69F2445 DF4F9B17 AD2B417B E66CEA35` | `9367966A EC52DDB3 6892DE6E 184C7549` |

### FIPS-197 Appendix B

| Plaintext | Expected Ciphertext |
|-----------|---------------------|
| `3243F6A8 885A308D 313198A2 E0370734` | `3925841D 02DC09FB DC118597 196A0B32` |

### C Word Format (as used in the driver)

```
Key:  {0x09CF4F3C, 0xABF71588, 0x28AED2A6, 0x2B7E1516}
      ^LSW(word 0)                         ^MSW(word 3)

Block 1: PT {0x7393172A, 0xE93D7E11, 0x2E409F96, 0x6BC1BEE2}
         CT {0x2466EF97, 0xA89ECAF3, 0x0D7A3660, 0x3AD77BB4}

Block 2: PT {0x45AF8E51, 0x9EB76FAC, 0x1E03AC9C, 0xAE2D8A57}
         CT {0x96FDBAAF, 0xE785895A, 0x03B9699D, 0xF5D3D585}

Block 3: PT {0x1A0A52EF, 0xE5FBC119, 0xA35CE411, 0x30C81C46}
         CT {0xED030688, 0x881B00E3, 0x598ECE23, 0x43B1CD7F}

Block 4: PT {0xE66CEA35, 0xAD2B417B, 0xDF4F9B17, 0xF69F2445}
         CT {0x184C7549, 0x6892DE6E, 0xEC52DDB3, 0x9367966A}

FIPS-197: PT {0xE0370734, 0x313198A2, 0x885A308D, 0x3243F6A8}
          CT {0x196A0B32, 0xDC118597, 0x02DC09FB, 0x3925841D}
```

---

## 10. Troubleshooting

### AES produces wrong ciphertext

| Cause | Fix |
|-------|-----|
| Key expansion ran with key=0 at reset | Use the `aes_hold_reset()` / `aes_release_reset()` sequence (see Section 2) |
| Wrong byte order in test vectors | `key[0]` = LSW = last 4 NIST bytes, `key[3]` = MSW = first 4 NIST bytes |
| Block 4 vector was wrong | Use corrected: PT word[0] = `0xE66CEA35`, CT = `9367966A...184C7549` |

### No UART output after FSBL (baremetal)

The FSBL BSP's `psu_init.c` is missing UART1 clock, MIO pin, and reset
configuration. Apply the JTAG register fix in Step 4b of `jtag_boot.tcl`
(Section 7.3). The three registers that need fixing:

| Register | Address | Write Value |
|----------|---------|-------------|
| UART1_REF_CTRL | 0xFF5E0078 | 0x01010A00 |
| MIO_PIN_36 | 0xFF180090 | 0x000000C0 |
| MIO_PIN_37 | 0xFF180094 | 0x000000C0 |
| RST_LPD_IOU2 | 0xFF5E0238 | 0x00000000 |

### PL AXI bus hang (read never returns)

| Cause | Fix |
|-------|-----|
| PL not powered | Run PMUFW before FSBL (Step 3 in JTAG flow) |
| PL not configured | Load bitstream via `fpga` command before FSBL |
| CSU not enabled | Write `mwr 0xffca0038 0x1FF` after bitstream load |
| Wrong boot mode | Set JTAG boot mode via `mwr 0xff5e0200 0x0100` |

### fpgautil fails (Linux)

```bash
# Check FPGA manager
ls /sys/class/fpga_manager/fpga0

# Check if bitstream file is valid
file /mnt/sd/design_1_wrapper.bit

# Try alternative load method
cp /mnt/sd/design_1_wrapper.bit /lib/firmware/aes.bit
echo aes.bit > /sys/class/fpga_manager/fpga0/firmware
```

### /dev/mem access denied (Linux)

```bash
# Run as root
sudo /mnt/sd/aes_linux

# Or check if CONFIG_DEVMEM is enabled
zcat /proc/config.gz | grep DEVMEM
```

### Key expansion timeout

If the driver polls `key_ready` and it never asserts:
1. Verify `aes_hold_reset()` was called before writing key registers
2. Verify `aes_release_reset()` was called after writing key registers
3. Check that the AES IP is at 0xA000_0000 in the address editor
4. Use Hardware Manager + system_ila to inspect actual AXI transactions
5. Verify `slv_reg8[1]` is reaching the AES core's `rst_n` pin

### Link errors (baremetal compilation)

| Error | Fix |
|-------|-----|
| `undefined reference to '__el3_stack'` | Ensure linker script defines `__el3_stack` |
| `no memory region for .note.gnu.build-id` | Add `-Wl,--build-id=none` to LDFLAGS |
| `cannot find -lxil` | App doesn't use BSP library; check that LDFLAGS doesn't include `-lxil` |

### KV260 boot mode

The KV260 Starter Kit **always boots from QSPI flash** -- there is no boot
mode switch on the carrier board. SD card boot requires resistor changes
(MODE[3:0] = 0b1110). The QSPI flash contains PetaLinux which loads the
kernel and rootfs from the SD card via U-Boot.

For baremetal development, **always use the JTAG flow** (Section 7).
For Linux deployment, boot PetaLinux from QSPI and use `fpgautil` to load
the AES bitstream at runtime.

---

## Appendix: Build Commands Summary

### Quick Reference

```bash
# 1. Vivado hardware design (v2)
"C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat" -mode batch -nojournal -nolog ^
  -source "C:\Work\Eitesal_EG\SMC26-24\kv260_integration\vivado\build_kv260_v2.tcl"

# 2. Vitis platform (FSBL, PMUFW, BSP) -- one-time
"C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat" ^
  "C:\Work\Eitesal_EG\SMC26-24\kv260_integration\sw_baremetal\build_baremetal.tcl"

# 3. Baremetal application (FSBL boot mode)
cd C:\Work\Eitesal_EG\SMC26-24\kv260_integration\sw_baremetal
"C:\AMDDesignTools\2025.2\Vitis\gnuwin\bin\make.exe" fsbl

# 4. Linux application (static)
cd C:\Work\Eitesal_EG\SMC26-24\kv260_integration\sw_linux
"C:\AMDDesignTools\2025.2\Vitis\gnuwin\bin\make.exe"

# 5. Run baremetal test on KV260 (JTAG)
python C:\Work\Eitesal_EG\SMC26-24\kv260_integration\boot\run_jtag_boot.py

# 6. Run Linux test on KV260 (PetaLinux)
python C:\Work\Eitesal_EG\SMC26-24\kv260_integration\boot\run_linux_test.py
```

### Tool Versions

| Component | Version |
|-----------|---------|
| Vivado | 2025.2 |
| Vitis / xsct | 2025.2 |
| aarch64-none-elf-gcc | 13.3.0 (baremetal) |
| aarch64-linux-gnu-gcc | 13.3.0 (Linux) |
| ZynqMP PS IP | zynq_ultra_ps_e v3.5 |
| axi_interconnect | v2.1 |
| system_ila | v1.1 |
| proc_sys_reset | v5.0 |
| KV260 Board Part | xilinx.com:kv260_som:part0:1.4 |
| Device | xczu5ev-sfvc784-2LV-e |

### File Paths

```
AES RTL source:     C:\Work\Eitesal_EG\SMC26-24\AES-Project-repo\rtl\
Integration root:   C:\Work\Eitesal_EG\SMC26-24\kv260_integration\
Vivado:             C:\AMDDesignTools\2025.2\Vivado\bin\
Vitis:              C:\AMDDesignTools\2025.2\Vitis\bin\
Baremetal GCC:      C:\AMDDesignTools\2025.2\Vitis\gnu\aarch64\nt\aarch64-none\bin\
Linux GCC:          C:\AMDDesignTools\2025.2\Vitis\gnu\aarch64\nt\aarch64-linux\bin\
GNU Make:           C:\AMDDesignTools\2025.2\Vitis\gnuwin\bin\make.exe
```

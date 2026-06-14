# Reproducibility Guide: AES-128 Hardware Accelerator on KV260

> **Audience:** Students on team SMC26-24 and anyone reproducing this project.
>
> **Goal:** By the end of this guide you will have simulated the AES core,
> synthesized it into a ZynqMP block design, loaded it onto the KV260 board,
> and verified 5/5 NIST test vectors using both baremetal and Linux software.
>
> **Estimated time:** 2-3 hours (assuming tools are installed).

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Phase 1: RTL Simulation](#2-phase-1-rtl-simulation)
3. [Phase 2: Vivado Block Design](#3-phase-2-vivado-block-design)
4. [Phase 3: The Reset Fix (RTL Modification)](#4-phase-3-the-reset-fix-rtl-modification)
5. [Phase 4: Vitis Platform and BSP Build](#5-phase-4-vitis-platform-and-bsp-build)
6. [Phase 5: Baremetal Application](#6-phase-5-baremetal-application)
7. [Phase 6: JTAG Boot Flow (Baremetal on Hardware)](#7-phase-6-jtag-boot-flow-baremetal-on-hardware)
8. [Phase 7: Linux Application](#8-phase-7-linux-application)
9. [Phase 8: Linux Runtime Flow (PetaLinux on Hardware)](#9-phase-8-linux-runtime-flow-petalinux-on-hardware)
10. [Phase 9: ILA Debugging (Optional)](#10-phase-9-ila-debugging-optional)
11. [Appendix A: The UART1 Bug](#appendix-a-the-uart1-bug)
12. [Appendix B: KV260 Boot Architecture](#appendix-b-kv260-boot-architecture)
13. [Appendix C: Common Pitfalls](#appendix-c-common-pitfalls)

---

## 1. Prerequisites

### What you need

| Item | Details |
|------|---------|
| Vivado 2025.2 | `C:\AMDDesignTools\2025.2\Vivado\bin` |
| Vitis 2025.2 (xsct, bootgen) | `C:\AMDDesignTools\2025.2\Vitis\bin` |
| aarch64 baremetal GCC | `...\Vitis\gnu\aarch64\nt\aarch64-none\bin` |
| aarch64 Linux GCC | `...\Vitis\gnu\aarch64\nt\aarch64-linux\bin` |
| GNU Make | `...\Vitis\gnuwin\bin\make.exe` |
| Python 3 + pyserial | For automated test scripts (`pip install pyserial`) |
| Icarus Verilog (optional) | For RTL simulation if not using Vivado Simulator |
| KV260 Starter Kit | Powered, connected via micro-USB (UART) |
| MicroSD card (>=8 GB) | For Linux boot flow |
| Serial terminal | PuTTY or TeraTerm (115200 baud, 8N1) |

### Why these versions matter

The KV260's QSPI flash ships with PetaLinux 2023.2. Our FSBL and PMUFW must
be 2025.2 to match the Vivado-generated bitstream format. The PMUFW version
must match the PS configuration or PL power-up will silently fail. This is
why we load our own FSBL + PMUFW via JTAG rather than relying on the QSPI
versions.

---

## 2. Phase 1: RTL Simulation

### What

Verify that the AES RTL produces correct ciphertext for all NIST test vectors
before attempting hardware deployment.

### Why

Catching logic bugs in simulation is 100x faster than debugging on hardware.
The comprehensive testbench covers 15 test sections including individual
operations (SubBytes, ShiftRows, MixColumns, AddRoundKey), full pipeline,
and NIST SP 800-38A test vectors.

### When

Before any synthesis. This is the first step after writing or modifying RTL.

### Where

From the repository root, using any Verilog simulator.

### How

**Option A: Icarus Verilog (fastest)**

```bash
cd AES-Project-repo

# Compile all RTL + comprehensive testbench
iverilog -o sim_results/aes_top.vvp -g2012 \
    rtl/*.v \
    tb_comprehensive/aes_comprehensive_tb.v

# Run simulation
vvp sim_results/aes_top.vvp
```

Expected output: All 15 sections PASS, including 5 NIST/FIPS vectors.

**Option B: Vivado Simulator**

```bash
vivado.bat -mode batch -source scripts/run_sim.tcl
```

### What to check

- All 5 NIST SP 800-38A / FIPS-197 vectors pass
- No X (unknown) values in the ciphertext output
- Key expansion completes in the expected number of cycles
- Pipeline produces output 5 cycles after valid_in (pipeline depth = 5 stages)

---

## 3. Phase 2: Vivado Block Design

### What

Create a Vivado block design that connects the AES hardware accelerator to the
ZynqMP Processing System (PS) on the KV260, then synthesize and generate a
bitstream.

### Why

The AES RTL is a pure hardware module. To communicate with it from software
(Cortex-A53), we need:
1. A PS (Processing System) providing the CPU, DDR memory, and clocks
2. An AXI interconnect bridging the PS's AXI4 Full master to the AES IP's
   AXI4-Lite slave
3. Clock and reset infrastructure

### When

After RTL simulation passes. This produces the bitstream (.bit) and hardware
handoff (.xsa) needed for software development.

### Where

Run from the host PC. The entire flow is automated in a Tcl script.

### How

```bash
"C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat" -mode batch -nojournal -nolog ^
    -source kv260_integration/vivado/build_kv260_v2.tcl ^
    -tempDir kv260_integration/vivado/tmp
```

This script performs 4 phases automatically:

**Phase 1: IP Packaging**
- Takes all `.v` files from `rtl/`
- Packages them into a reusable IP core (`user.org:user:aes_core:1.0`)
- Creates `ip_repo/aes_core/` directory

**Phase 2: Block Design Creation**
- Creates ZynqMP PS with KV260 board preset
- Configures M_AXI_HPM0_FPD (32-bit AXI4 Full master to PL)
- Configures UART1 on MIO pins 36/37 (KV260 USB-UART)
- Instantiates AES IP, axi_interconnect, proc_sys_reset, system_ila
- Wires clock (pl_clk0) and reset to all PL components
- Assigns AES IP address 0xA000_0000 (64K range)

**Phase 3: Synthesis + Implementation + Bitstream**
- Runs Vivado synth_1, impl_1, write_bitstream
- Takes ~15 minutes on a modern PC

**Phase 4: Export**
- Writes `aes_kv260.xsa` (hardware handoff for Vitis)
- Writes utilization and timing reports

### Key configuration explained

| Setting | Value | Why |
|---------|-------|-----|
| M_AXI_HPM0_FPD | 32-bit | FPD port gives direct A53 access to PL |
| pl_clk0 | ~100 MHz | AES clock; no separate PLL needed |
| UART1 on MIO 36/37 | 115200 | KV260 USB-UART bridge is wired to UART1, NOT UART0 |
| system_ila 2 slots | 1024 depth | Debug: monitors AXI on both PS and AES sides |
| AES at 0xA000_0000 | 64K | Matches the team's TEST4 address map |

### What to check after build

```
vivado/utilization_report.txt  ->  ~13,500 LUTs (11.57%), 0 BRAM, 0 DSP
vivado/timing_report.txt       ->  WNS +3.362 ns (all timing MET)
```

The design fits comfortably in the ZU5EV with 3.362 ns of positive slack at
~100 MHz.

### Output artifacts

| File | Location |
|------|----------|
| `aes_kv260.xsa` | `kv260_integration/vivado/` |
| `design_1_wrapper.bit` | `.../aes_kv260.runs/impl_1/` |
| `design_1_wrapper.ltx` | Same directory (debug probes for ILA) |

---

## 4. Phase 3: The Reset Fix (RTL Modification)

### What

Adding a software-controlled AES core reset signal (`aes_rst_n`) that allows
the C driver to hold the AES core in reset while writing key registers, then
release it to trigger key expansion with the correct key.

### Why (this is the most important fix in the project)

Without this fix, **AES produces wrong ciphertext on hardware despite passing
simulation.** Here is the root cause:

```
PL Power-Up Timeline (WITHOUT fix):

Time 0:   PL powers up -> all AXI slave registers = 0 (key = 0x0000...)
Time 0+:  aes_rst_n deasserts (tied to AXI reset)
Time 0+:  Key expansion starts with key=0x0000...
Time 49:  Key expansion completes -> key_ready = 1 (but expanded WRONG key!)
...
Time 5ms: FSBL finishes, PMUFW finishes
Time 5ms: C driver runs, writes actual key to registers
          BUT key expansion already finished with key=0!
          The new key registers are ignored.
Time 5ms: Driver encrypts -> WRONG ciphertext (using expanded key from key=0)
```

The testbench worked because in simulation, the testbench set `top_key`
**before** deasserting `top_rst` -- the key was present when expansion started.

### When

This is a **mandatory RTL modification** before any hardware testing. Apply it
once, then rebuild the Vivado project (Phase 2).

### Where

Three files are modified:

1. `rtl/myip_test5_v1_0_S00_AXI.v` -- Add output port + assign statement
2. `rtl/myip_test5_v1_0.v` -- Wire the new port through to `aes_top`
3. (No change to `aes_top.v` -- it already has a `rst_n` input)

### How

**Step 1: Modify `myip_test5_v1_0_S00_AXI.v`**

Add `aes_rst_n` to the port list:
```verilog
output wire aes_rst_n,
```

Add the assign statement (CTRL register bit 1 gates the AES reset):
```verilog
// slv_reg8 = CTRL register at offset 0x20
// Bit 0 = valid_in, Bit 1 = aes_rst_n
assign aes_rst_n = S_AXI_ARESETN & slv_reg8[1];
```

This AND's the AXI bus reset with the software-controlled bit. The AES core
only comes out of reset when BOTH:
- The AXI bus is out of reset (`S_AXI_ARESETN = 1`)
- Software has written bit 1 of CTRL (`slv_reg8[1] = 1`)

**Step 2: Modify `myip_test5_v1_0.v`**

Add `aes_rst_n` wire and wire it through:
```verilog
wire aes_rst_n;

// In AXI wrapper instantiation:
.aes_rst_n(aes_rst_n)

// In aes_top instantiation (CRITICAL - use aes_rst_n, not the AXI reset):
.rst_n(aes_rst_n),
```

**Step 3: Update the register map documentation**

CTRL register (0x20) now has 2 bits:
- Bit 0: `valid_in` -- start encryption
- Bit 1: `aes_rst_n` -- AES core reset (1=run, 0=reset)

### The correct driver sequence (after fix)

```c
// 1. Hold AES in reset BEFORE writing key
aes_hold_reset();           // CTRL = 0  (aes_rst_n = 0)

// 2. Write the actual key
aes_load_key(key);          // KEY_IN0-3 = actual key values

// 3. Release AES from reset -> key expansion starts with correct key
aes_release_reset();        // CTRL = 2  (aes_rst_n = 1)

// 4. Wait for key expansion to finish (~49 clock cycles)
while (!aes_key_ready());   // Poll STATUS bit 1

// 5. Now encrypt normally
aes_load_plaintext(pt);
aes_start();                // CTRL = 3  (valid_in + aes_rst_n)
while (!aes_valid_out());   // Poll STATUS bit 0
aes_read_ciphertext(ct);
aes_stop();                 // CTRL = 2  (deassert valid_in)
```

### Why this works

By holding the AES core in reset while we write key registers, we freeze the
key expansion module. It cannot start until we explicitly release it. When we
release it, the key registers already contain the correct values, so expansion
produces the correct round keys. The `key_ready` signal now genuinely indicates
"expansion complete with YOUR key."

---

## 5. Phase 4: Vitis Platform and BSP Build

### What

Generate the Vitis standalone platform, which produces:
- FSBL (First Stage Boot Loader) for Cortex-A53
- PMUFW (Platform Management Unit Firmware) for the MicroBlaze PMU
- Standalone BSP (Board Support Package) with PS initialization code

### Why

The KV260 needs these firmware components to initialize the PS (DDR, clocks,
peripherals) before the AES application can run. We use Vitis 2025.2 versions
to match the Vivado bitstream format.

### When

After the Vivado XSA is generated (Phase 2). This is a one-time build (~10 min).

### Where

From the `sw_baremetal/` directory.

### How

```bash
"C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat" ^
    kv260_integration/sw_baremetal/build_baremetal.tcl
```

This creates a Vitis workspace at `sw_baremetal/workspace/` containing:
- `zynqmp_fsbl/fsbl_a53.elf` -- FSBL 2025.2
- `zynqmp_pmufw/pmufw.elf` -- PMUFW 2025.2
- `psu_cortexa53_0/` -- Standalone BSP with psu_init code

### What to check

Verify the ELF files exist:
```bash
ls sw_baremetal/workspace/aes_platform/zynqmp_fsbl/fsbl_a53.elf
ls sw_baremetal/workspace/aes_platform/zynqmp_pmufw/pmufw.elf
```

> **Note:** The FSBL's `psu_init.c` has a known bug -- it does not configure
> UART1's clock, MIO pins, or reset. We work around this manually in the JTAG
> boot script. See [Appendix A](#appendix-a-the-uart1-bug) for details.

---

## 6. Phase 5: Baremetal Application

### What

Compile the AES baremetal test application for Cortex-A53 (AArch64).

### Why

The baremetal app runs directly on the CPU without an OS, giving us
cycle-accurate performance measurements and direct hardware access.

### When

After the Vitis platform is built (Phase 4).

### Where

From the `sw_baremetal/` directory.

### How

```bash
cd kv260_integration/sw_baremetal

# Build for FSBL boot mode (PL configured by FSBL):
"C:\AMDDesignTools\2025.2\Vitis\gnuwin\bin\make.exe" fsbl

# Or build for ILA debugging (infinite encryption loop):
"C:\AMDDesignTools\2025.2\Vitis\gnuwin\bin\make.exe" ila
```

### What the application does

The application (`aes_baremetal.c`) runs three test phases:

**Phase 0: PL Configuration Check**
- Verifies PL AXI is accessible by reading the AES STATUS register

**Phase 1: Functional Correctness** (5 NIST/FIPS test vectors)
- Hold AES in reset -> write key -> release reset -> wait key_ready
- For each vector: write plaintext -> start -> wait valid_out -> read ciphertext -> verify

**Phase 2: Latency Measurement**
- Single-block encryption timed with the AArch64 Generic Timer
- Result: 49 ticks = 490 ns at 99 MHz

**Phase 3: Throughput Benchmark**
- 1000 blocks in a tight loop
- Result: 103,412 blocks/sec = 13 Mbps effective throughput

### How latency is measured

The AArch64 Generic Timer is a 64-bit counter running at ~99 MHz (CPU clock / 2):

```c
uint64_t t_start = read_generic_timer();  // MRS CNTPCT_EL0
aes_start();
while (!aes_valid_out());
uint64_t t_end = read_generic_timer();
// latency = (t_end - t_start) * 1e9 / timer_freq
```

### Output: `aes_fsbl.elf` (~4.5 KB text, 256 KB BSS for stack)

---

## 7. Phase 6: JTAG Boot Flow (Baremetal on Hardware)

### What

Boot the KV260 via JTAG and run the AES baremetal application on the physical
hardware. This follows the official AMD Kria SOM baremetal JTAG boot flow.

### Why

The KV260 always boots from QSPI flash (containing PetaLinux). For baremetal
development, we use JTAG to:
1. Override the boot mode
2. Load our own bitstream
3. Run our own FSBL + PMUFW (matching 2025.2)
4. Run the AES application

This avoids needing to flash QSPI and allows rapid iteration.

### When

After compiling the baremetal application (Phase 5). You need physical access
to the KV260 board.

### Where

Host PC connected to KV260 via:
- Micro-USB cable (UART console -- check Device Manager for COM port, typically COM6)
- JTAG via the same USB cable (FTDI FT4232H provides both JTAG + UART)

### How

**Step 1: Open serial terminal**

Open PuTTY or TeraTerm on COM6, 115200 baud, 8N1.

**Step 2: Run the JTAG boot script**

```bash
cd kv260_integration/boot

# Option A: Automated (captures UART output to file)
python run_jtag_boot.py

# Option B: Manual (xsct directly, watch terminal for output)
"C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat" jtag_boot.tcl
```

### The 5-step JTAG boot sequence explained

The `jtag_boot.tcl` script performs these steps in order:

**Step 1: Switch to JTAG boot mode**
- **What:** Write to CRL_APB.BOOT_MODE register to force JTAG boot
- **Why:** This tells the Boot ROM we are in debug mode, so FSBL will skip
  boot-media reading
- **Commands:** `mwr 0xffca0010 0x0` + `mwr 0xff5e0200 0x0100` + `rst -system`

**Step 2: Load bitstream into PL**
- **What:** Program the FPGA via JTAG's ICAP path
- **Why:** The AES hardware must be in the PL before software can access it
- **Commands:** `fpga design_1_wrapper.bit` + `mwr 0xffca0038 0x1FF`

**Step 3: Download and run PMUFW**
- **What:** Load Platform Management Unit firmware onto the MicroBlaze PMU
- **Why:** PMUFW manages PL power domains. Without it, the PL might not be
  powered or out of isolation
- **Commands:** Target "MicroBlaze PMU" -> `dow pmufw.elf` -> `con`

**Step 4: Download and run FSBL**
- **What:** Load First Stage Boot Loader onto Cortex-A53 #0
- **Why:** FSBL initializes DDR memory, PLLs, clocks, and PS peripherals.
  Without it, DDR is not usable and the AES app cannot be loaded
- **Commands:** Target "Cortex-A53 #0" -> `dow fsbl_a53.elf` -> `con` -> wait 10s -> `stop`

**Step 4b: UART1 configuration fix**
- **What:** Manually configure UART1 clock, MIO pins, and reset
- **Why:** The FSBL's `psu_init.c` is missing UART1 configuration. Without
  this fix, no UART output appears. See [Appendix A](#appendix-a-the-uart1-bug).
- **Commands:** Write to UART1_REF_CTRL, MIO_PIN_36/37, RST_LPD_IOU2

**Step 5: Download and run AES application**
- **What:** Load the AES test app onto Cortex-A53 #0 and run it
- **Why:** This is the actual test that verifies AES on hardware
- **Commands:** `dow aes_fsbl.elf` -> `con`

### Expected output (on serial terminal)

```
==============================================
  AES-128 Hardware Accelerator
  Baremetal Test on ZynqMP (KV260)
==============================================

--- Phase 0: PL Configuration ---
  Exception Level: EL3
  FSBL boot: PL configured by boot image (FSBL+PMUFW 2025.2)
  PL0_REF_CTRL = 0x01010A00 (CLKACT=1)
  PL AXI Access Test: OK

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
  Throughput:       13 Mbps (103412 blocks/sec)

==============================================
  SUMMARY: 5/5 passed, 490 ns/block
==============================================
```

If you see this output, congratulations -- AES works on hardware!

---

## 8. Phase 7: Linux Application

### What

Compile the AES Linux user-space application that accesses the hardware via
`/dev/mem` memory-mapped I/O.

### Why

For production deployment, the AES accelerator must be accessible from Linux
applications. The Linux driver demonstrates real-world performance (higher
throughput due to CPU caches and out-of-order execution).

### When

After the Vivado bitstream is ready. Does NOT require the Vitis BSP.

### Where

From the `sw_linux/` directory.

### How

```bash
cd kv260_integration/sw_linux
"C:\AMDDesignTools\2025.2\Vitis\gnuwin\bin\make.exe"
```

This produces a **statically-linked** aarch64 ELF (~707 KB). Static linking
avoids glibc version mismatch with the pre-built PetaLinux image.

### How Linux accesses hardware

The Linux app maps the AES register space into user-space memory:

```c
int fd = open("/dev/mem", O_RDWR | O_SYNC);
void *map = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED,
                 fd, 0xA0000000 & ~0xFFF);
aes_base = (volatile uint8_t *)map;

// Now register access works identically to baremetal:
aes_write32(AES_REG_KEY_IN0, key[0]);  // writes to 0xA0000010
```

The `/dev/mem` path requires root privileges. The `O_SYNC` flag bypasses
CPU caches so every register write immediately reaches the hardware.

### Copying to the KV260

Copy the binary to the SD card alongside the bitstream:
```bash
cp aes_linux /path/to/sd_card/
cp ../vivado/aes_kv260/aes_kv260.runs/impl_1/design_1_wrapper.bit /path/to/sd_card/
```

---

## 9. Phase 8: Linux Runtime Flow (PetaLinux on Hardware)

### What

Boot PetaLinux on the KV260, load the AES bitstream at runtime using
`fpgautil`, and run the AES test.

### Why

This is the production deployment model: Linux manages the system, loads the
hardware accelerator on demand, and applications access it via `/dev/mem`.

### When

After the Linux application is compiled and the SD card is prepared.

### Where

On the KV260 board via serial terminal.

### How

**Step 1: Prepare the SD card**

Copy these files to the SD card root (FAT32 partition):
- `BOOT.BIN` (existing PetaLinux boot image)
- `Image`, `ramdisk.cpio.gz.u-boot`, `system.dtb` (existing PetaLinux files)
- `design_1_wrapper.bit` (our AES bitstream)
- `aes_linux` (our test binary)

**Step 2: Boot PetaLinux**

1. Insert SD card into the KV260
2. Power on
3. Wait ~30 seconds for boot to complete
4. Log in as `root`

**Step 3: Load bitstream**

```bash
mount /dev/mmcblk1p1 /mnt/sd
fpgautil -b /mnt/sd/design_1_wrapper.bit
```

`fpgautil` loads the bitstream through the Linux FPGA Manager framework.
Expected load time: ~133 ms.

**Step 4: Run the test**

```bash
chmod +x /mnt/sd/aes_linux
/mnt/sd/aes_linux
```

**Automated alternative:**
```bash
python run_linux_test.py
```

This Python script waits for boot, logs in, mounts SD, loads bitstream, and
runs the test automatically.

### Expected output

```
==============================================
  AES-128 Hardware Accelerator
  Linux User-Space Test on ZynqMP (KV260)
==============================================
Hardware mapped successfully.

--- Phase 1: Functional Correctness ---
  [PASS] NIST SP800-38A Block 1
  [PASS] NIST SP800-38A Block 2
  [PASS] NIST SP800-38A Block 3
  [PASS] NIST SP800-38A Block 4
  [PASS] FIPS-197 App B

Functional Test: 5/5 passed

--- Phase 3: Throughput ---
  Throughput: 100.29 Mbps (783479 blocks/sec)
```

### Why Linux throughput (100 Mbps) is higher than baremetal (13 Mbps)

The baremetal benchmark includes polling overhead in the C loop, while Linux
benefits from CPU caches, out-of-order execution, and branch prediction
warming up over 1000 iterations. The AES hardware latency is identical in both
cases (~490-530 ns per block).

---

## 10. Phase 9: ILA Debugging (Optional)

### What

Use the system_ila core (integrated in the block design) to capture AXI4-Lite
transactions between the PS and AES hardware.

### Why

Visual confirmation of the register-write sequence, protocol correctness, and
timing. Useful for debugging AXI hangs or protocol violations.

### When

After the JTAG boot flow is working, when you want to see actual bus
transactions.

### How

The ILA capture requires a special boot sequence because the debug hub needs
`pl_clk0` to be running:

**Step 1: Phase 1 boot WITH fpga command**

```bash
"C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat" jtag_boot_phase1_fpga.tcl
```

This loads the bitstream, runs FSBL (which enables pl_clk0), and halts the CPU.

**Step 2: Refresh HW Manager**

In Vivado Hardware Manager:
1. Close the hw_target
2. Reopen the hw_target
3. Refresh the xck26_0 device

The ILA debug core (`hw_ila_1`) should now appear because `pl_clk0` is running.

> **Key insight:** The `dbg_hub` is clocked by `pl_clk0`, which only runs after
> FSBL configures the PS PLLs. You must boot FSBL first, then refresh the
> device for HW Manager to detect the debug cores.

**Step 3: Arm the ILA**

Set trigger to "Trigger Immediately" (captures next 1024 clock cycles) and
click Run Trigger.

**Step 4: Run AES loop app**

```bash
"C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat" run_aes_app.tcl
```

This downloads `aes_ila_loop.elf` which encrypts blocks in an infinite loop,
generating continuous AXI transactions for the ILA to capture.

**Step 5: Examine the waveform**

In the ILA waveform you should see:
- SLOT_0 (AES-side): AXI4-Lite writes to KEY_IN0-3, CTRL, DATA_IN0-3
- SLOT_1 (PS-side): Same transactions from the PS master port
- The reset sequence: CTRL=0 (hold), CTRL=2 (release), then CTRL=3 (start)

---

## Appendix A: The UART1 Bug

### What

The FSBL BSP's `psu_init.c` (auto-generated by Vitis) is missing three
critical UART1 configurations that exist in Vivado's auto-generated
`psu_init.tcl`.

### The three missing configurations

| Register | Address | Correct Value | FSBL Value |
|----------|---------|--------------|------------|
| UART1_REF_CTRL | 0xFF5E0078 | 0x01010A00 (CLKACT=1) | Missing |
| MIO_PIN_36 | 0xFF180090 | 0x000000C0 (L3_SEL=6) | 0x00000000 |
| MIO_PIN_37 | 0xFF180094 | 0x000000C0 (L3_SEL=6) | 0x00000000 |
| RST_LPD_IOU2 | 0xFF5E0238 | bit 2 = 0 (UART1_RESET clear) | Never cleared |

### Workaround

In the JTAG boot script (`jtag_boot.tcl`), Step 4b manually writes these
registers via JTAG after FSBL runs:

```tcl
targets -set -filter {name =~ "PSU"}
mwr 0xFF5E0078 0x01010A00    ;# Enable UART1 clock
mwr 0xFF180090 0x000000C0    ;# Configure MIO 36 for UART1 TX
mwr 0xFF180094 0x000000C0    ;# Configure MIO 37 for UART1 RX
mwr 0xFF5E0238 0x00000000    ;# Clear UART1 reset
```

### Proper fix (for production)

Regenerate the FSBL BSP using the corrected `psu_init.c` derived from the
Vivado XSA. This would require patching the BSP generation or using a newer
Vitis version. The JTAG workaround works fine for development.

---

## Appendix B: KV260 Boot Architecture

### How the KV260 boots

```
Power On
    |
    v
Boot ROM (on-chip, read-only)
    |
    | Reads from QSPI flash
    v
FSBL (from QSPI, PetaLinux 2023.2)
    |
    | Initializes DDR, clocks, basic PS peripherals
    | Loads PMUFW, ATF (ARM Trusted Firmware), U-Boot
    v
U-Boot
    |
    | Loads Linux kernel + ramdisk + device tree from SD card
    v
Linux (PetaLinux)
    |
    | User logs in
    | User loads bitstream via fpgautil
    | User runs aes_linux
```

### Key points

- The KV260 **always boots from QSPI flash**. There is no boot mode switch on
  the Starter Kit carrier board.
- SD card boot requires resistor changes (MODE[3:0] = 0b1110) -- not available
  on the Starter Kit.
- For baremetal development: **always use JTAG** (Section 7).
- For Linux: QSPI boots PetaLinux, which loads kernel from SD card via U-Boot.

---

## Appendix C: Common Pitfalls

### 1. AES produces wrong ciphertext on hardware

**Symptom:** Simulation passes, but hardware fails all or most vectors.

**Cause:** Key expansion ran with key=0 before software wrote the actual key.

**Fix:** Apply the reset fix (Section 4). The driver must hold AES in reset
while writing key registers.

### 2. No UART output after FSBL

**Symptom:** xsct shows FSBL completed, but no text appears on the serial
terminal.

**Cause:** FSBL's `psu_init.c` does not configure UART1.

**Fix:** Apply the UART1 fix (Appendix A) in Step 4b of the JTAG boot script.

### 3. PL AXI bus hangs (read never returns)

**Symptom:** Application hangs on the first AES register read/write.

**Causes and fixes:**
- PL not powered: Run PMUFW before FSBL (Step 3 in JTAG boot)
- PL not configured: Load bitstream via `fpga` command before FSBL
- CSU not enabled: `mwr 0xffca0038 0x1FF` after bitstream load
- Wrong boot mode: Set JTAG boot mode via `mwr 0xff5e0200 0x0100`

### 4. ILA not detected in Hardware Manager

**Symptom:** "The debug hub core was not detected" error.

**Cause:** `dbg_hub` is clocked by `pl_clk0`, which only runs after FSBL.

**Fix:**
1. Run Phase 1 boot WITH `fpga` command (`jtag_boot_phase1_fpga.tcl`)
2. Close and reopen hw_target in HW Manager
3. If still not detected: `set_property BSCAN_SWITCH_USER_MASK 2 [get_hw_devices xck26_0]`

### 5. Key expansion timeout

**Symptom:** `key_ready` never asserts.

**Causes:**
- `aes_hold_reset()` not called before writing key
- `aes_release_reset()` not called after writing key
- `slv_reg8[1]` not wired through to `aes_top.rst_n`

**Fix:** Verify the reset fix wiring (Section 4) and the driver sequence.

### 6. `/dev/mem` access denied (Linux)

**Fix:** Run as root (`sudo`) or enable `CONFIG_DEVMEM` in kernel config.

### 7. fpgautil fails (Linux)

**Troubleshooting:**
```bash
ls /sys/class/fpga_manager/fpga0           # Check FPGA manager exists
cat /sys/class/fpga_manager/fpga0/state    # Should show "operating" after load
file design_1_wrapper.bit                  # Verify bitstream is valid
```

### 8. Link errors (baremetal compilation)

| Error | Fix |
|-------|-----|
| `undefined reference to '__el3_stack'` | Ensure linker script defines `__el3_stack` |
| `no memory region for .note.gnu.build-id` | Add `-Wl,--build-id=none` to LDFLAGS |

---

## Quick Reference: Build Commands

```bash
# 1. RTL Simulation (Icarus Verilog)
iverilog -o sim_results/aes_top.vvp -g2012 rtl/*.v tb_comprehensive/aes_comprehensive_tb.v
vvp sim_results/aes_top.vvp

# 2. Vivado block design + bitstream
vivado.bat -mode batch -source kv260_integration/vivado/build_kv260_v2.tcl

# 3. Vitis platform (FSBL + PMUFW + BSP) -- one-time
xsct.bat kv260_integration/sw_baremetal/build_baremetal.tcl

# 4. Baremetal application
cd kv260_integration/sw_baremetal && make.exe fsbl

# 5. Linux application
cd kv260_integration/sw_linux && make.exe

# 6. Baremetal test on KV260 (JTAG)
python kv260_integration/boot/run_jtag_boot.py

# 7. Linux test on KV260 (PetaLinux)
python kv260_integration/boot/run_linux_test.py

# 8. ILA debugging on KV260
xsct.bat kv260_integration/boot/jtag_boot_phase1_fpga.tcl
# ... refresh HW Manager, arm ILA ...
xsct.bat kv260_integration/boot/run_aes_app.tcl
```

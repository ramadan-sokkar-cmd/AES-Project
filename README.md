# Cypher-X: Pipelined AES-128 Hardware Accelerator for IIoT

<div align="center">

![Hardware/Software Co-Design](https://img.shields.io/badge/Architecture-Hardware%2FSoftware%20Co--Design-blue)
![Language](https://img.shields.io/badge/Language-Verilog-blue)
![Platform](https://img.shields.io/badge/Platform-Zynq%20SoC%20%2F%20FPGA-blue)
![Status](https://img.shields.io/badge/Status-Hardware%20Verified-brightgreen)
![Test](https://img.shields.io/badge/NIST%20Vectors-5%2F5%20Passed-success)

</div>

---

## Project Overview

**Cypher-X** (Team SMC26-24) is a high-throughput, 5-stage spatial pipelined
AES-128 hardware accelerator designed for Industrial IoT (IIoT) edge gateways
and smart factory control loops.

Unlike traditional iterative AES cores that suffer from high latency and deplete
FPGA memory, Cypher-X processes two encryption rounds per clock cycle. It
introduces a **Zero-BRAM** architecture by implementing the SubBytes step using
Composite Field Galois Field GF((2^4)^2) arithmetic, ensuring real-time
multi-gigabit security without creating system bottlenecks.

The accelerator is wrapped in an AXI4-Lite slave interface and deployed on the
**AMD Kria KV260** (Zynq UltraScale+ ZU5EV), where it is accessible from the
quad-core Cortex-A53 processor via memory-mapped registers. Both **baremetal**
and **PetaLinux Linux** software drivers have been tested and verified on the
physical hardware.

### Verified Hardware Results (KV260)

| Metric | Baremetal (JTAG) | Linux (PetaLinux) |
|--------|------------------|-------------------|
| Correctness (NIST/FIPS) | **5/5 PASSED** | **5/5 PASSED** |
| Single-block latency | **490 ns** (49 cycles @ 99 MHz) | **530 ns** |
| Throughput (1000 blocks) | **13 Mbps** (103,412 blocks/sec) | **100.29 Mbps** (783,479 blocks/sec) |
| Bitstream load time | N/A (JTAG) | **133 ms** (fpgautil) |

---

## Key Features

- **Standard Compliant:** Implements AES-128 encryption (FIPS-197).
- **High Throughput:** 5-stage unrolled spatial pipeline achieving up to
  **30 Gbps** continuous throughput at 250 MHz (standalone synthesis).
- **Zero-BRAM S-Box:** SubBytes implemented with GF((2^4)^2) composite field
  arithmetic instead of memory-heavy lookup tables.
- **Design Space Exploration (DSE):** Both GF-based (area-optimized) and
  LUT-based (speed-optimized) S-Box implementations.
- **AXI4-Lite Integration:** Wrapped in AXI4-Lite slave interface for PS
  communication via memory-mapped registers.
- **Software-Controlled Reset:** Dedicated AES core reset bit (CTRL[1]) enables
  proper key-expansion sequencing from software (see
  [The Reset Fix](#the-reset-fix) below).
- **Dual Software Stack:** Both baremetal C (JTAG boot) and PetaLinux Linux
  user-space drivers, sharing the same `aes_hw.h` driver header.

---

## Repository Structure

```
AES-Project-repo/
|
|-- rtl/                               # Verilog RTL source files
|   |-- aes_top.v                      #   Top-level AES pipeline (clk, rst_n, key_ready)
|   |-- myip_test5_v1_0.v              #   AXI4-Lite wrapper (instantiates AES core + AXI slave)
|   |-- myip_test5_v1_0_S00_AXI.v      #   AXI4-Lite slave interface (registers + aes_rst_n output)
|   |-- aes_stage.v                    #   Pipeline stage (groups 2 AES rounds)
|   |-- aes_round.v                    #   Single AES round logic
|   |-- aes_finalstage.v               #   Final pipeline stage (1 round)
|   |-- aes_finalround.v               #   Final round (no MixColumns)
|   |-- sub_bytes.v                    #   SubBytes wrapper
|   |-- Sbox_GF.v                      #   GF-based S-Box (Zero-BRAM)
|   |-- Sbox_assign.v                  #   LUT-based S-Box (for DSE comparison)
|   |-- shift_rows.v                   #   ShiftRows wire permutations
|   |-- Mix_Col_1.v                    #   MixColumns XOR-tree
|   |-- addRoundKey.v                  #   AddRoundKey XOR
|   |-- u_key_expansion_seq2.v         #   Sequential key expansion (44 rounds)
|   `-- G_function.v                   #   GF(2^8) multiplication for key expansion
|
|-- tb/                                # Module-level testbenches (one per RTL module)
|
|-- tb_comprehensive/                  # Comprehensive system-level testbench
|   `-- aes_comprehensive_tb.v         #   15-section test: correctness, edge cases, NIST vectors
|
|-- sim_results/                       # Pre-compiled simulation results (.vvp files)
|
|-- scripts/                           # Synthesis and evaluation environments
|   |-- standalone_benchmark/          #   Standalone (no PS) max-throughput synthesis
|   |   |-- aes_result.xpr             #     Vivado project
|   |   |-- lut_based/                 #     Reports: LUT S-Box variant
|   |   `-- gf_based/                  #     Reports: GF S-Box variant
|   `-- soc_integration/               #   Early PS-PL integration (legacy XSA)
|
|-- kv260_integration/                 # *** KV260 PS-PL Integration (Phase 2) ***
|   |-- vivado/                        #   Vivado block design build scripts + reports
|   |   |-- build_kv260_v2.tcl         #     v2 build (axi_interconnect + system_ila + reset fix)
|   |   |-- build_kv260.tcl            #     v1 build (SmartConnect, legacy)
|   |   |-- utilization_report.txt     #     Actual KV260 utilization (13,546 LUTs, 11.57%)
|   |   `-- timing_report.txt          #     Actual KV260 timing (WNS +3.362 ns, all MET)
|   |
|   |-- sw_baremetal/                  #   Baremetal C application (Cortex-A53, no OS)
|   |   |-- aes_hw.h                   #     Shared driver header (register map + I/O functions)
|   |   |-- aes_baremetal.c            #     Main app: correctness + latency + throughput
|   |   |-- aes_ila_loop.c             #     ILA debug app: infinite encryption loop
|   |   |-- start.S                    #     AArch64 custom startup (EL3 -> EL1 transition)
|   |   |-- lscript.ld                 #     Linker script (code @ 0x100000, 256 KB stack)
|   |   |-- Makefile                   #     Build: `make` (JTAG), `make fsbl`, `make ila`
|   |   |-- build_baremetal.tcl        #     Vitis platform creation (FSBL + PMUFW + BSP)
|   |   `-- build_app.tcl              #     Vitis application build (alternative to Makefile)
|   |
|   |-- sw_linux/                      #   Linux user-space C application (PetaLinux)
|   |   |-- aes_linux.c                #     Main app: mmap /dev/mem, same 3-phase test
|   |   `-- Makefile                   #     Cross-compile: static aarch64-linux-gnu
|   |
|   |-- boot/                          #   Boot and test orchestration scripts
|   |   |-- jtag_boot.tcl              #     5-step JTAG baremetal boot (official AMD flow)
|   |   |-- jtag_boot_phase1_fpga.tcl  #     Phase 1 only (boot PS + load bitstream, for ILA)
|   |   |-- run_aes_app.tcl            #     Phase 2 only (download + run AES app)
|   |   |-- run_jtag_boot.py           #     Python orchestrator (UART capture + xsct)
|   |   |-- run_linux_test.py          #     Python Linux test (boot detect + fpgautil + test)
|   |   |-- aes_baremetal.bif          #     Boot image format (for BOOT.BIN generation)
|   |   |-- run_aes_linux.sh           #     Linux runtime helper script
|   |   `-- uart_jtag_boot.txt         #     Captured UART output (5/5 passing baremetal run)
|   |
|   `-- docs/                          #   Integration-specific documentation
|       `-- KV260_Integration_Tutorial.md  # Comprehensive technical tutorial
|
|-- docs/                              # Project documents (PDFs, presentations)
|   |-- AES hardware core design_391.pdf
|   |-- AES Presentation.pptx
|   `-- Cypher-X Architecture.pdf
|
|-- REPRODUCIBILITY_GUIDE.md           # Step-by-step reproducibility tutorial (start here!)
|-- .gitignore
`-- README.md                          # This file
```

---

## Architecture Details

The data enters via the AXI4-Lite interface from the Zynq processor into
`aes_top.v`. It passes through the initial AddRoundKey and cascades
continuously through 5 pipeline stages (`aes_stage.v`). Each stage processes
2 AES rounds in a single clock cycle. A parallel valid-pipe synchronizes the
5-cycle latency, outputting valid ciphertext continuously without stalling.

```
                    AXI4-Lite Slave
                    +------------------+
  PS Cortex-A53 ----> myip_test5_v1_0  |
  (M_AXI_HPM0_FPD)  |  +------------+ |   +-----------+   +-----------+
  @ 0xA000_0000     |  | Register   | |   | Key Expand|   | 5-Stage   |
                    |  | File       |--->| (49 cycles)|-->| Pipeline  |
                    |  | (slv_reg0-9)| |   +-----------+   | (5 cycles)|
                    |  +------------+ |                  +->|----------> CT
                    +------------------+                  |  +--------> valid_out
                                                          |
                    aes_top.v                             |
                    +------------------------------------+
                    | data_in[127:0], key_in[127:0]      |
                    | valid_in, clk, rst_n ----------+   |
                    |                                  |  |
                    |  +--+ +--+ +--+ +--+ +--+      |  |
                    |  |S1| |S2| |S3| |S4| |SF| <----+  |
                    |  +--+ +--+ +--+ +--+ +--+         |
                    |  Each stage = 2 AES rounds        |
                    +-----------------------------------+
```

The full block diagram is available in `docs/Cypher-X Architecture.pdf`.

---

## The Reset Fix

### The Problem

When deployed on the KV260, AES encryption produced wrong ciphertext despite
passing all testbench simulations. The root cause was a **key expansion timing
race**:

1. At PL power-up, all AXI slave registers initialize to 0 (key = 0x0000...).
2. The key expansion module runs **once** at reset deassertion.
3. The C driver writes the actual key **milliseconds later** (after FSBL,
   PMUFW, and application startup).
4. `key_ready` reflected expansion of key=0, not the intended key.

### The Fix

Added a **software-controlled AES core reset** (CTRL register bit 1):

```verilog
// In myip_test5_v1_0_S00_AXI.v:
assign aes_rst_n = S_AXI_ARESETN & slv_reg8[1];
```

The driver sequence became:
1. `aes_hold_reset()` -- hold AES in reset (CTRL = 0)
2. `aes_load_key()` -- write 4 key registers
3. `aes_release_reset()` -- release AES reset (CTRL = 2)
4. Wait for `key_ready` (~49 cycles)
5. Encrypt blocks normally

This ensures key expansion sees the correct key. See the
[Reproducibility Guide](REPRODUCIBILITY_GUIDE.md) Section 5 for full details.

---

## AES Register Map

Base address: **0xA000_0000** (64K range, auto-assigned by Vivado)

| Offset | Register | Access | Description |
|--------|----------|--------|-------------|
| 0x00-0x0C | DATA_IN0-3 | W | Plaintext [31:0] to [127:96] |
| 0x10-0x1C | KEY_IN0-3 | W | Key [31:0] to [127:96] |
| 0x20 | CTRL | W | Bit 0: valid_in (start), Bit 1: aes_rst_n (reset control) |
| 0x24 | STATUS | R | Bit 0: valid_out (ciphertext ready), Bit 1: key_ready |
| 0x28-0x34 | DATA_OUT0-3 | R | Ciphertext [31:0] to [127:96] |

**Byte ordering:** word[0] = LSW = last 4 NIST bytes. word[3] = MSW = first 4 NIST bytes.

---

## Getting Started

### For Simulation (Phase 1)

```bash
# Using Icarus Verilog:
iverilog -o aes_top.vvp -g2012 rtl/*.v tb_comprehensive/aes_comprehensive_tb.v
vvp aes_top.vvp

# Using Vivado Simulator:
vivado.bat -mode batch -source scripts/run_sim.tcl
```

### For KV260 Hardware (Phase 2)

See the **[Reproducibility Guide](REPRODUCIBILITY_GUIDE.md)** for detailed
step-by-step instructions covering:

1. RTL simulation and verification
2. Vivado block design creation
3. Baremetal JTAG boot flow
4. PetaLinux Linux runtime flow
5. ILA debugging with Hardware Manager

### Prerequisites

| Tool | Version |
|------|---------|
| Vivado | 2025.2 |
| Vitis (xsct, bootgen) | 2025.2 |
| Icarus Verilog or QuestaSim | Any recent |
| PetaLinux (pre-built SD image) | 2023.2 or later |
| KV260 Starter Kit | Any revision |

---

## Key Files Quick Reference

| What | Where |
|------|-------|
| AES RTL source | `rtl/*.v` |
| Comprehensive testbench | `tb_comprehensive/aes_comprehensive_tb.v` |
| Module testbenches | `tb/*.v` |
| Vivado block design build | `kv260_integration/vivado/build_kv260_v2.tcl` |
| Shared C driver header | `kv260_integration/sw_baremetal/aes_hw.h` |
| Baremetal application | `kv260_integration/sw_baremetal/aes_baremetal.c` |
| Linux application | `kv260_integration/sw_linux/aes_linux.c` |
| JTAG boot script | `kv260_integration/boot/jtag_boot.tcl` |
| Detailed integration tutorial | `kv260_integration/docs/KV260_Integration_Tutorial.md` |
| Step-by-step reproducibility guide | `REPRODUCIBILITY_GUIDE.md` |

---

## Team

- **Abdelrahman Mohamed Hamad** -- Lead Digital Design & RTL Engineer
- **Ramadan Mohammed Sokkar** -- RTL Design Engineer & FPGA Integration
- **Abanoub Sabry** -- RTL Design

---

## Acknowledgments

KV260 integration, the software-controlled reset fix, the JTAG boot flow, and
both baremetal and Linux drivers were developed with mentorship guidance as
part of the graduation project Phase 2 integration effort.

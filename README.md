# AES-Project
Hardware/software co-design of pipelined AES-128 using Zynq SoC for IIoT gateways
# Cypher-X: Pipelined AES-128 Hardware Accelerator for IIoT

![Hardware/Software Co-Design](https://img.shields.io/badge/Architecture-Hardware%2FSoftware%20Co--Design-blue)
![Language](https://img.shields.io/badge/Language-Verilog-orange)
![Platform](https://img.shields.io/badge/Platform-Zynq%20SoC%20%2F%20FPGA-lightgrey)

## 📌 Project Overview
**Cypher-X** (Team SMC26-24) is a high-throughput, 5-stage spatial pipelined AES-128 hardware accelerator specifically engineered for Industrial IoT (IIoT) edge gateways and smart factory control loops. 

Unlike traditional iterative AES cores that suffer from high latency and deplete FPGA memory, Cypher-X processes two encryption rounds per clock cycle. It introduces a **Zero-BRAM** architecture by implementing the SubBytes step using Composite Field Galois Field $GF((2^4)^2)$ arithmetic, ensuring real-time multi-gigabit security without creating system bottlenecks.

## ✨ Key Features
* **Standard Compliant:** Implements AES-128 encryption algorithm (FIPS-197).
* **High Throughput:** 5-stage unrolled spatial pipeline achieving up to **30 Gbps** continuous throughput (at 250 MHz).
* **Zero-BRAM S-Box:** Employs an area-optimized S-Box using mathematical GF logic instead of memory-heavy Look-Up Tables.
* **Design Space Exploration (DSE):** Provides both `GF-based` (Area optimized) and `LUT-based` (Speed optimized) S-Boxes.
* **AXI4-Lite Integration:** Wrapped in an AXI4-Lite slave interface (`myip_test5_v1_0`) for seamless Hardware/Software co-design with Zynq UltraScale+ Processing System (PS).
* **Zero-Delay Key Expansion:** Sequential Key Expansion unit pre-calculates and registers subkeys locally to avoid distribution delays.

## 📂 Repository Structure
```text
Cypher-X-AES128-Accelerator/
├── docs/                      # Architecture diagrams, presentations, and documentation
├── rtl/                       # Verilog source files for the AES core
│   ├── aes_top.v              # Top-level AES pipeline wrapper
│   ├── myip_test5_v1_0.v      # AXI4-Lite interface wrapper
│   ├── aes_stage.v            # Structural pipeline stage (groups 2 rounds)
│   ├── aes_round.v            # Standard encryption round logic
│   ├── sub_bytes.v            # SubBytes wrapper
│   ├── Sbox_GF.v              # GF-based S-Box (Zero BRAM)
│   ├── Sbox_assign.v          # LUT-based S-Box (For DSE)
│   ├── shift_rows.v           # Hardware wire-routing for permutations
│   ├── Mix_Col_1.v            # Optimized XOR-tree for linear diffusion
│   ├── addRoundKey.v          # Key mixing logic
│   └── u_key_expansion_seq2.v # Key expansion unit
├── tb/                        # Testbenches for module and top-level verification
└── README.md                  # Project overview and instructions
# Hardware/Software Co-Design of Pipelined AES-128 using Zynq SoC for IIoT Gateways

![Version](https://img.shields.io/badge/Version-1.0-brightgreen)
![Platform](https://img.shields.io/badge/Platform-Zynq%20SoC%20%2F%20FPGA-blue)
![Language](https://img.shields.io/badge/Language-Verilog%20HDL-orange)
![Application](https://img.shields.io/badge/Application-IIoT%20Security-red)

## 📌 Project Overview
This repository contains the RTL implementation and verification environment for **Cypher-X**, a high-performance AES-128 hardware accelerator. Developed by Team **SMC26-24**, this project is specifically engineered to secure Industrial IoT (IIoT) edge gateways. 

By leveraging a **Hardware/Software Co-Design** approach on the Xilinx Zynq SoC, the system offloads intensive cryptographic operations from the Processing System (PS) to a custom 5-stage spatial pipelined accelerator in the Programmable Logic (PL) via an AXI4-Lite interface.

## ✨ Key Architectural Features
* **5-Stage Spatial Pipeline:** Processes 2 AES rounds per clock cycle, achieving multi-gigabit throughput to prevent bottlenecks in real-time industrial control loops.
* **Zero-BRAM S-Box (GF Arithmetic):** Implements the SubBytes step using Composite Field Galois Field $GF((2^4)^2)$ logic, saving critical FPGA memory resources.
* **Design Space Exploration (DSE):** The repository includes two S-Box implementations:
  * `Sbox_GF.v`: Area-optimized (Zero BRAM).
  * `Sbox_assign.v`: Speed-optimized (LUT-based).
* **Hardware/Software Partitioning:** * **PS (ARM Cortex):** Handles network traffic, key management, and overall system control.
  * **PL (FPGA):** Executes the pipelined AES-128 datapath.
* **AXI4-Lite Integration:** Custom AXI4-Lite slave IP wrapper for seamless memory-mapped communication between the PS and PL.
* **Sequential Key Expansion:** Pre-calculates and registers subkeys locally at each pipeline stage to eliminate distribution delays.

## 📂 Repository Structure
```text
AES-Project/
├── docs/                      # Architecture diagrams, presentations, and design docs
├── rtl/                       # All Verilog source files for the AES core
│   ├── aes_top.v              # Top-level AES pipeline wrapper
│   ├── myi_axi4_lite_ip... .v # AXI4-Lite slave interface wrapper
│   ├── aes_stage.v            # Structural pipeline stage (groups 2 rounds)
│   ├── aes_round.v            # Standard encryption round logic
│   ├── sub_bytes.v            # SubBytes wrapper
│   ├── Sbox_GF.v              # Area-optimized S-Box (GF)
│   ├── Sbox_assign.v          # Speed-optimized S-Box (LUT)
│   ├── shift_rows.v           # Hardware wire-routing logic
│   ├── Mix_Col_1.v            # Optimized XOR-tree for linear diffusion
│   ├── addRoundKey.v          # Key mixing logic
│   └── u_key_expansion_seq2.v # Sequential key expansion unit
├── tb/                        # Testbench files and simulation scripts
│   ├── aes_top_tbb.v          # Top-level testbench
│   └── ...                    # Unit-level testbenches (Round, Stage, S-Box)
└── README.md                  # Project overview and build instructions

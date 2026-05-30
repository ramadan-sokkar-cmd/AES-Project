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
```
## ⚙️ Architecture details
The data enters via the AXI4-Lite interface from the Zynq processor into aes_top.v. It passes through the initial addRoundKey and cascades continuously through 5 pipeline stages (aes_stage.v). Each stage processes 2 AES rounds in a single clock cycle. A parallel Valid-Pipe synchronizes the 5-cycle latency, outputting valid ciphertext continuously without stalling the industrial control loop.

(Note: You can view the full block diagram in the docs/ Cypher-X Architecture).

## 🚀 Getting Started & Simulation
Prerequisites
* Simulator: Siemens QuestaSim / ModelSim OR Xilinx Vivado Simulator.
* Synthesis Tool: Xilinx Vivado (Targeting AMD Kria KV260 ).

## 👥 Team List:
* Abdelrahman Mohamed Hamad - Lead Digital Design & RTL Engineer
* Ramadan Mohammed Sokkar - RTL Design Engineer & FPGA Integration
* Abanoub Sabry - RTL Design 
<br>


![Visitors](https://api.visitorbadge.io/api/visitors?path=ramadan-sokkar-cmd/AES-Project&label=VISITORS&labelColor=%23000000&countColor=%230d76a8&style=flat)

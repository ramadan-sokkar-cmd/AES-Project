# AES-Project
Hardware/software co-design of pipelined AES-128 using Zynq SoC for IIoT gateways
# Cypher-X: Hardware/Software Co-Design of Pipelined AES-128 using Zynq SoC for IIoT Gateways

![Status](https://img.shields.io/badge/Status-Active-success)
![Platform](https://img.shields.io/badge/Platform-Zynq%20SoC%20%2F%20FPGA-blue)
![Language](https://img.shields.io/badge/Language-Verilog%20HDL-orange)
![Target](https://img.shields.io/badge/Target-IIoT%20Security-red)

## 📌 Project Overview
**Cypher-X** (Team SMC26-24) is a high-performance AES-128 hardware accelerator designed specifically to secure Industrial IoT (IIoT) edge gateways and smart factory environments. 

Developed as part of the **Egypt Semiconductor Challenge (2025-2026)**, this project utilizes a Hardware/Software Co-Design approach. By offloading intensive cryptographic workloads from the Processing System (PS) to a custom-designed Programmable Logic (PL) accelerator via an AXI4-Lite interface, we eliminate system bottlenecks. The core features a **5-stage spatial pipelined architecture** capable of multi-gigabit throughput and utilizes a **Zero-BRAM S-Box** (based on Composite Field GF arithmetic) to optimize FPGA area.

## 📂 Repository Structure & Deliverables
This repository is strictly structured according to the standard IC design flow and the competition requirements:

* **`/docs`** — Contains the system block diagrams (PDF/PNG), detailed architectural design documents (S-Box and Key Expansion), and the project presentation slides.
* **`/rtl`** — Contains all Verilog source files (`.v`) for the AES-128 datapath, including the pipelined stages, round logic, Zero-BRAM S-Box, and the AXI4-Lite slave wrapper.
* **`/tb`** — Contains all testbench files and simulation environments used to verify the functional correctness of the core and individual sub-modules against FIPS-197 test vectors.
* **`/scripts`** — *(Work in Progress)* Will contain the Vivado synthesis scripts, physical design constraint files (`.xdc` for Kria KV260), and final timing/utilization reports.

## 🛠️ Build & Simulation Instructions

### 1. Toolchain Requirements
* **RTL Simulation:** Siemens QuestaSim, ModelSim, or Xilinx Vivado Simulator.
* **Synthesis & Implementation:** Xilinx Vivado (Targeting AMD Kria KV260 / Nexys A7).

### 2. Running Functional Simulation
1. Clone this repository:
   ```bash
   git clone [https://github.com/ramadan-sokkar-cmd/AES-Project.git](https://github.com/ramadan-sokkar-cmd/AES-Project.git)

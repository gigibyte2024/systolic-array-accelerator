# Systolic Array Matrix Multiplication Accelerator

## Project Overview

This project focuses on designing and implementing a hardware accelerator for matrix multiplication using a Systolic Array architecture in Verilog.

A systolic array consists of interconnected Processing Elements (PEs) that perform multiply-and-accumulate operations while passing data between neighbouring elements. This parallel architecture can accelerate matrix computations commonly used in Artificial Intelligence and Machine Learning applications.

## Objectives

- Design a modular Processing Element (PE).
- Implement Multiply-Accumulate (MAC) operations.
- Connect multiple PEs to form a systolic array.
- Perform matrix multiplication using parallel processing.
- Verify functional correctness through simulation.
- Analyse latency, throughput and hardware resource utilisation.

## Technology Stack

- **HDL:** Verilog
- **Simulation:** Icarus Verilog
- **Waveform Viewer:** GTKWave
- **Reference Model:** Python
- **Version Control:** Git and GitHub

## Project Structure

```text
systolic-array-accelerator/
├── rtl/
├── testbench/
├── reference/
├── diagrams/
├── simulation/
├── synthesis/
├── report/
├── demo/
└── README.md
```

## Team Contributions

| Member | Responsibility | Status |
|---|---|---|
| Member 1 | Processing Element and MAC Unit | Completed |
| Member 2 | Systolic Array Architecture | Completed |
| Member 3 | Input Buffers and Matrix Interface | Pending |
| Member 4 | Systolic Array Controller | Completed |
| Member 5 | Verification and Performance Analysis | In Progress |

## Project Status

Currently in the initial development and architecture design phase.

## License

To be decided.


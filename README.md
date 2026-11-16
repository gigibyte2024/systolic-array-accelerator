# Systolic Array Matrix Multiplication Accelerator

**Group Kamlesh** · Verilog RTL · verified in Icarus Verilog simulation

A parameterized hardware accelerator for signed matrix multiplication
(`C = A × B`) built on an output-stationary systolic array, written in Verilog
and verified by simulation for 2×2, 3×3 and 4×4 matrices.

## Submission links

| Item | Link |
|---|---|
| Project report (IEEE format) | [report/IEEE_Report.pdf](report/IEEE_Report.pdf) |
| Prototype / demo video | [video link](https://youtu.be/PYQDciO5-Eo) |

## Team

| Member | Name | Responsibility | Main files | Report |
|---|---|---|---|---|
| 1 | Gargi | MAC unit & Processing Element | `rtl/mac_unit.v`, `rtl/processing_element.v` | [report/member1](report/member1/VERIFICATION_SUMMARY.md) |
| 2 | Agrima | Parameterized systolic array | `rtl/systolic_array.v` | [report/member2](report/member2/VERIFICATION_SUMMARY.md) |
| 3 | Bhawana | Input buffer & matrix interface | `rtl/input_buffer.v`, `rtl/matrix_interface.v` | [report/member3](report/member3/README.md) |
| 4 | Deepak | Controller (FSM) | `rtl/systolic_controller.v` | [report/member4](report/member4/VERIFICATION_SUMMARY.md) |
| 5 | Dev | System verification & performance analysis | `testbench/tb_member5_verification.v` | [report/member5](report/member5/VERIFICATION_AND_PERFORMANCE.md) |

All five parts are complete, integrated, and verified.

## Project idea

Matrix multiplication is the core operation in machine-learning workloads.
A systolic array speeds it up with a grid of small processing elements (PEs).
Each PE multiplies, accumulates, and passes its inputs to its neighbours.
Every PE works in parallel and only communicates with adjacent PEs, so the
design scales regularly with array size.

## Architecture

```
               load_a / load_b / load_en
                         |
                         v
                +-----------------+   buffer_ready   +----------------------+
                |  input_buffer   |----------------->|  systolic_controller |
                | stores A and B  |                  |  IDLE > INIT >       |
                +-----------------+                  |  COMPUTE > DONE      |
                         |                           +----------------------+
              matrix_a_flat / matrix_b_flat             |          |
                         v                  buffer_rd_en|          |array_rst
                +-----------------+   cycle_cnt         |          |array_en
                |matrix_interface |<--------------------+          |
                | skews A and B   |                                |
                +-----------------+                                |
                    a_in |  b_in                                   |
                         v                                         v
                +--------------------------------------------------+
                |       systolic_array  (N x N processing_element) |
                |       A moves right, B moves down, acc stays     |
                +--------------------------------------------------+
                                         |
                                         v
                                 acc_out  (C = A x B)
```

- **Processing element:** a registered `a`/`b` forwarding path plus a MAC
  unit (`acc <= acc + a * b`). Operands are signed 8-bit and accumulators are
  signed 32-bit by default. Overflow wraps around in two's complement.
- **Systolic array:** a generate-based N × N grid. Row inputs feed A from the
  left and column inputs feed B from the top.
- **Input buffer and matrix interface:** they store both matrices, then stream
  them skewed. Row `i` of A is delayed by `i` cycles and column `j` of B by `j`
  cycles, so that `A[i][k]` and `B[k][j]` meet at `PE[i][j]` in the same cycle.
- **Controller:** after `start` and `buffer_ready`, it resets the array for 1
  cycle. It then streams operands for `2N − 1` cycles, flushes for `N` cycles,
  and asserts `done`.

Detailed design notes:
[PE interface](rtl/PE_INTERFACE.md) ·
[systolic array](rtl/SYSTOLIC_ARRAY_ARCHITECTURE.md) ·
[controller](rtl/CONTROLLER_ARCHITECTURE.md)

## Results

Full-system simulation (buffer + interface + controller + array). Every output
matched the reference product for each size:

| Array | Outputs checked | Compute cycles (`3N − 1`) | MAC operations (`N³`) | Average MAC/cycle |
|---:|---:|---:|---:|---:|
| 2×2 | 4 | 5 | 8 | 1.600 |
| 3×3 | 9 | 8 | 27 | 3.375 |
| 4×4 | 16 | 11 | 64 | 5.818 |

A sequential single-MAC design needs `N³` cycles: 64 cycles for 4×4,
compared with 11 compute cycles here. These are schedule-level figures from
simulation. No synthesis was performed, so area, maximum clock frequency and
power are not estimated.

## Repository structure

```text
systolic-array-accelerator/
├── rtl/          Verilog modules and architecture notes
├── testbench/    16 testbenches (unit, integration, full system)
├── simulation/   VCD waveforms written by the testbenches
├── report/       Per-member verification reports and waveform evidence
└── README.md
```

## Running the simulations

Requires [Icarus Verilog](https://steveicarus.github.io/iverilog/).
GTKWave or any VCD viewer can be used to open waveforms.

Run every testbench from the repository root:

```sh
for tb in testbench/tb_*.v; do
  name=$(basename "$tb" .v)
  iverilog -g2005 -o "/tmp/$name" rtl/*.v "$tb" && vvp "/tmp/$name"
done
```

Run the full-system test for one array size (N = 2, 3 or 4):

```sh
iverilog -g2012 -s tb_member5_verification -Ptb_member5_verification.N=4 \
  -o /tmp/member5_N4.vvp rtl/*.v testbench/tb_member5_verification.v
vvp /tmp/member5_N4.vvp
```

## Verification status

All 16 testbenches pass: MAC unit, processing element (functional, stress,
parameterization, overflow, back-to-back), 2×2 integration, 4×4 systolic
array, input buffer, matrix interface, controller, controller–array
integration, Member 3 integration, and full-system verification for N = 2, 3
and 4.

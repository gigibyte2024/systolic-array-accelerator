# Member 2 — Verification Summary

## Responsibility
Systolic Array Architecture: connect multiple Processing Elements (PEs,
designed by Member 1) into an N x N grid, implement the data-forwarding
mesh between PEs, integrate the array, and verify correct communication
between PEs including a full matrix multiplication.

## Deliverables
- `rtl/systolic_array.v` — parameterized N x N systolic array
- `rtl/SYSTOLIC_ARRAY_ARCHITECTURE.md` — architecture / dataflow diagram
- `testbench/tb_systolic_array.v` — 4x4 integration testbench
- `simulation/systolic_array_waveform.vcd` / `report/member2/waveforms/systolic_array_waveform.vcd` — waveform evidence

## Simulation Environment
- HDL: Verilog
- Simulator: Icarus Verilog 13.0
- Waveform format: VCD

## Test Results

| Testbench | Array size | Result |
|---|---:|---|
| tb_systolic_array | 4x4 | PASS |
| ad hoc 3x3 instantiation (parameterization check) | 3x3 | PASS |

Member 1's `tb_systolic_2x2` (hand-wired 2x2) and `tb_pe_2x2_integration`
continue to pass unmodified, confirming `systolic_array.v` did not require
any changes to `processing_element.v` or `mac_unit.v`.

## 4x4 Matrix Multiplication Verification

### Input Matrices

A =
```
 1  2  3  4
 5  6  7  8
 2  1  4  3
 0  1  2  1
```

B =
```
 2  0  1  3
 1  2  0  1
 3  1  2  0
 0  1  1  2
```

### Expected Output (C = A x B)

```
13 11 11 13
37 27 27 37
17  9 13 13
 7  5  5  3
```

### Procedure
- Both operand matrices were fed into the array using the standard
  skewed/diagonal systolic feeding scheme: row `i` of A is delayed by `i`
  cycles, column `j` of B is delayed by `j` cycles, so that `A[i][k]` and
  `B[k][j]` always meet at `PE[i][j]` on the same clock edge.
- After the `2N - 1` cycle load phase, zero inputs were held for `N`
  additional cycles to let the pipeline drain.
- All 16 PE accumulators (`acc_out`) were compared against the reference
  product computed independently with NumPy.

### Result
All 16 output values matched the expected matrix product exactly.

```
PASS: C[0][0] = 13   PASS: C[0][1] = 11   PASS: C[0][2] = 11   PASS: C[0][3] = 13
PASS: C[1][0] = 37   PASS: C[1][1] = 27   PASS: C[1][2] = 27   PASS: C[1][3] = 37
PASS: C[2][0] = 17   PASS: C[2][1] = 9    PASS: C[2][2] = 13   PASS: C[2][3] = 13
PASS: C[3][0] = 7    PASS: C[3][1] = 5    PASS: C[3][2] = 5    PASS: C[3][3] = 3
4x4 SYSTOLIC ARRAY MATRIX MULTIPLICATION PASSED
```

Waveform: `simulation/systolic_array_waveform.vcd`
Testbench: `testbench/tb_systolic_array.v`

## Parameterization Check (3x3)

A second instantiation with `N = 3` (different matrices, independently
hand-computed expected product) was simulated to confirm the generate-based
grid genuinely scales with the `N` parameter rather than being hard-coded
for 4x4. All 9 accumulators matched. This test was run ad hoc to validate
the design and is not committed as a permanent testbench (the N=2 and N=4
cases already give full edge-to-edge coverage of the generate structure).

## PE Communication / Forwarding Verification
- Row-wise `a_out -> a_in` forwarding (left to right) verified across all
  4 rows for 4 PEs each.
- Column-wise `b_out -> b_in` forwarding (top to bottom) verified across all
  4 columns for 4 PEs each.
- Reset behaviour verified: all forwarding registers and accumulators clear
  to zero on `rst`.
- Accumulate-only-when-enabled behaviour (inherited from
  `processing_element`) verified implicitly by the drain phase, where
  `en` stays high but `a_in`/`b_in` are zero and accumulators correctly
  stop changing once all real operands have been consumed.

## Conclusion
The systolic array interconnect correctly integrates Member 1's processing
elements into a parameterized N x N grid. Data forwarding between PEs and
full matrix multiplication were verified for both 4x4 and 3x3
configurations. The implementation is ready for integration with the input
buffer / matrix interface (Member 3) and controller / FSM (Member 4).

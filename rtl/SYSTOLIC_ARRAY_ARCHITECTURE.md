# Systolic Array Architecture (Member 2)

## Module
`systolic_array` (`rtl/systolic_array.v`)

## Overview
`systolic_array` is a parameterized `N x N` output-stationary grid built from
`N*N` instances of the `processing_element` module designed by Member 1
(`rtl/processing_element.v`). Each PE keeps its own accumulator in place for
the whole computation while the A and B operands are pumped through the
array and forwarded, cycle by cycle, to the PE's neighbours.

- A operands enter from the **left edge** and move **rightward**, one PE per
  cycle (row-wise forwarding).
- B operands enter from the **top edge** and move **downward**, one PE per
  cycle (column-wise forwarding).
- PE[i][j] computes `acc[i][j] += a * b` every cycle `en` is high, where `a`
  and `b` are whatever values are currently present at that PE's inputs.

```
            b_in[0]   b_in[1]   b_in[2]   b_in[3]
               |         |         |         |
               v         v         v         v
a_in[0] -->  PE00  -->  PE01  -->  PE02  -->  PE03
               |         |         |         |
               v         v         v         v
a_in[1] -->  PE10  -->  PE11  -->  PE12  -->  PE13
               |         |         |         |
               v         v         v         v
a_in[2] -->  PE20  -->  PE21  -->  PE22  -->  PE23
               |         |         |         |
               v         v         v         v
a_in[3] -->  PE30  -->  PE31  -->  PE32  -->  PE33
```

Horizontal arrows are the registered `a_out -> a_in` forwarding path between
PEs in the same row; vertical arrows are the registered `b_out -> b_in`
forwarding path between PEs in the same column.

## Parameters

| Parameter | Default | Description |
|---|---:|---|
| N | 4 | Array size (N x N processing elements) |
| DATA_WIDTH | 8 | Width of signed A/B operands, forwarded to each PE |
| ACC_WIDTH | 32 | Width of each PE's signed accumulator |

The module was verified for both `N = 3` and `N = 4` to confirm the
generate-based grid is genuinely size-parameterized, not hand-wired per size
(Member 1's `tb_systolic_2x2` covers the `N = 2` case).

## Ports

| Signal | Width | Description |
|---|---:|---|
| clk | 1 | Clock |
| rst | 1 | Synchronous active-high reset (clears forwarding registers and all accumulators) |
| en | 1 | Global MAC enable, passed through to every PE |
| a_in | N*DATA_WIDTH | Flattened row inputs. Row `i` occupies bits `[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH]` |
| b_in | N*DATA_WIDTH | Flattened column inputs. Column `j` occupies bits `[(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH]` |
| acc_out | N*N*ACC_WIDTH | Flattened accumulator outputs. PE[i][j]'s accumulator occupies bits `[((i*N+j)+1)*ACC_WIDTH-1 : (i*N+j)*ACC_WIDTH]` |

Ports are flattened (1-D vectors) rather than multi-dimensional, since plain
Verilog-2001 does not support unpacked array ports. Internally, the module
uses unpacked `wire` arrays (`a_grid`, `b_grid`) to hold the forwarding mesh
between PEs, which is clearer and easier to index than manually wiring each
PE-to-PE connection as Member 1's 2x2 proof-of-concept testbench did.

## Feeding the array: skewed (diagonal) input

Because every row and column shares the same clock and the forwarding paths
are registered (one cycle of latency per hop), operands must be fed in
**skewed** order so that `A[i][k]` and `B[k][j]` arrive at `PE[i][j]`
simultaneously, `k` cycles after the computation starts:

- Row `i`'s operand stream `A[i][0], A[i][1], ..., A[i][N-1]` is delayed by
  `i` cycles before it is driven onto `a_in` row `i`.
- Column `j`'s operand stream `B[0][j], B[1][j], ..., B[N-1][j]` is delayed
  by `j` cycles before it is driven onto `b_in` column `j`.

After `2N - 1` cycles of skewed input, all operand pairs have entered the
array; an additional `N` cycles (with inputs held at zero) let the last
partial sums propagate and settle before the accumulators are checked.

## Verification

`testbench/tb_systolic_array.v` instantiates a 4x4 `systolic_array`, drives
two 4x4 integer matrices through it using the skewed-feed scheme above, and
checks all 16 resulting accumulators against the reference matrix product
`C = A x B`. All 16 checks passed. See
`report/member2/VERIFICATION_SUMMARY.md` for full results and a second
(3x3) instantiation used to confirm the size parameter works correctly.

## Integration Note
This module depends only on Member 1's `processing_element` interface
(`clk`, `rst`, `en`, `a_in`, `b_in`, `a_out`, `b_out`, `acc`), unchanged. No
modifications to `rtl/processing_element.v` or `rtl/mac_unit.v` were needed.

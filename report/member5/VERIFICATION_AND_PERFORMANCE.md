# Member 5 — Verification and Performance Results

## Scope

The Member 5 testbench exercises the existing input buffer, matrix interface,
controller, systolic array, processing elements, and MAC units together. It
does not change RTL owned by Members 1–4. A deterministic signed matrix pair
is generated for each configuration, and every output is checked against an
independently accumulated reference matrix product.

## Verification setup

- Simulator: Icarus Verilog 13.0 (`iverilog` / `vvp`)
- Clock period: 10 ns
- Matrix sizes: 2×2, 3×3, and 4×4
- Checks: buffer ready handshake, controller cycle counter, feed and flush
  windows, completion, and all output accumulators
- Waveforms: `report/member5/waveforms/member5_N2.vcd`, `member5_N3.vcd`,
  and `member5_N4.vcd`

Run from the repository root:

```sh
for n in 2 3 4; do
  iverilog -g2012 -s tb_member5_verification \
    -Ptb_member5_verification.N=$n -o /tmp/member5_N${n}.vvp \
    rtl/mac_unit.v rtl/processing_element.v rtl/systolic_array.v \
    rtl/input_buffer.v rtl/matrix_interface.v rtl/systolic_controller.v \
    testbench/tb_member5_verification.v
  vvp /tmp/member5_N${n}.vvp
done
```

## Results

| Array | Outputs checked | Compute cycles | Init + compute cycles | MAC operations | Average MAC/cycle |
|---:|---:|---:|---:|---:|---:|
| 2×2 | 4 | 5 | 6 | 8 | 1.600 |
| 3×3 | 9 | 8 | 9 | 27 | 3.375 |
| 4×4 | 16 | 11 | 12 | 64 | 5.818 |

All three simulations passed. Every output matched the reference product.
For each size, compute duration matched `3N - 1` cycles: `2N - 1` feed
cycles followed by `N` flush cycles. Including the one-cycle array init state,
the controller uses `3N` cycles from accepting `start` until asserting
`done`. At the testbench's 10 ns clock period, that is 60 ns, 90 ns, and
120 ns for N=2, N=3, and N=4, respectively.

Average MAC/cycle is the `N^3` scalar multiply-accumulate operations required
for one matrix product divided by the controller's `3N - 1` compute cycles.
It is a schedule-level throughput measure, not a post-synthesis timing or
physical throughput result. Peak parallel capacity is `N^2` MACs per cycle
when all PEs are active; this simulation does not estimate area, maximum
clock frequency, or power.

## Artifacts

- Testbench: `testbench/tb_member5_verification.v`
- Waveforms: `report/member5/waveforms/`
- Results: this report

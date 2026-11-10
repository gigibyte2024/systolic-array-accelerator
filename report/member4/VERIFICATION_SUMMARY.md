# Member 4 — Verification Summary

## Responsibility
Systolic Array Controller: Design the top-level FSM controller to orchestrate matrix multiplication execution across the systolic array, manage timing sequences for skewed input streams and flush cycles, and interface with input buffers and processing elements.

## Deliverables
- `rtl/systolic_controller.v` — Parameterised controller FSM
- `rtl/CONTROLLER_ARCHITECTURE.md` — Controller architecture and interface specification
- `testbench/tb_systolic_controller.v` — Unit testbench with mock buffers and handshake verification
- `testbench/tb_controller_array_integration.v` — Integration testbench connecting Controller to Member 2's Systolic Array

## FSM & Timing Verification

For an $N \times N$ matrix multiplication on an output-stationary systolic array:
- **Array Init:** 1 cycle (`array_rst` asserted)
- **Feed Window:** $2N - 1$ cycles (`array_en = 1`, `buffer_rd_en = 1`)
- **Flush Window:** $N$ cycles (`array_en = 1`, `buffer_rd_en = 0`)
- **Total Compute Duration:** $3N - 1$ cycles (11 cycles for $N=4$)
- **Completion:** `done = 1` asserted at cycle $3N - 1$

## Test Results

| Testbench | Description | Result |
|---|---|---|
| `tb_systolic_controller` | Reset check, handshake (`buffer_ready`), feed/flush timing, and `done` flag assertion | PASS |
| `tb_controller_array_integration` | End-to-end integration: Controller + Member 2 Systolic Array ($4 \times 4$ signed matrix multiplication $C = A \times B$) | PASS |

## Integration Handshake Summary for Member 3

When Member 3 implements the input buffers, the interface contract is:
1. Member 3 asserts `buffer_ready = 1` once matrix data is populated in FIFOs/SRAM.
2. Member 4 samples `start` and `buffer_ready`, transitions to `S_INIT`, then asserts `buffer_rd_en = 1` for $2N - 1$ consecutive cycles.
3. Member 3 pops/streams one skewed row/column vector per cycle while `buffer_rd_en == 1`.

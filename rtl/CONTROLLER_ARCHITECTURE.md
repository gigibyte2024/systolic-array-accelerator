# Member 4 — Controller Architecture and Interface Specification

## Module
`systolic_controller` (`rtl/systolic_controller.v`)

## Overview
The `systolic_controller` is a parameterised Finite State Machine (FSM) that orchestrates the entire matrix multiplication pipeline of the $N \times N$ Systolic Array Accelerator. It coordinates with Member 3's input buffers (read streaming handshake) and commands Member 2's systolic array (array reset and array computation enable).

## FSM State Machine

```
              +-------------------------+
              |         S_IDLE          |<--------------------------+
              +-------------------------+                           |
                           |                                        |
                           | (start && buffer_ready)                |
                           v                                        |
              +-------------------------+                           |
              |         S_INIT          |                           |
              | (pulse array_rst = 1)   |                           |
              +-------------------------+                           |
                           |                                        |
                           v                                        |
              +-------------------------+                           |
              |        S_COMPUTE        |                           |
              | (array_en = 1)          |                           |
              | (step cycle_cnt)        |                           |
              +-------------------------+                           |
                           |                                        |
                           | (cycle_cnt == 3N - 2)                  |
                           v                                        |
              +-------------------------+                           |
              |         S_DONE          |                           |
              | (assert done = 1)       |---------------------------+
              +-------------------------+
```

### States Description

1. **`S_IDLE` (3'b000):**
   - Accelerator is inactive (`busy = 0`, `done = 0`, `array_en = 0`).
   - Waits for `start` pulse AND `buffer_ready == 1` from Member 3.

2. **`S_INIT` (3'b001):**
   - Controller asserts `array_rst = 1` for 1 clock cycle to synchronously reset all PEs, clearing internal registers and accumulators before starting.

3. **`S_COMPUTE` (3'b010):**
   - Controller asserts `array_en = 1` to enable MAC computations in all PEs.
   - **Feed Stage ($0 \le \text{cycle\_cnt} < 2N - 1$):** `buffer_rd_en = 1`, streaming skewed matrix operands from Member 3's input buffers.
   - **Flush/Drain Stage ($2N - 1 \le \text{cycle\_cnt} < 3N - 1$):** `buffer_rd_en = 0`, zero-padding inputs while remaining partial sums propagate to all accumulators.
   - Active duration is exactly $3N - 1$ clock cycles.

4. **`S_DONE` (3'b011):**
   - Asserts `done = 1` and deasserts `busy = 0`.
   - Results in `acc_out` are valid and ready to be read.
   - Returns to `S_IDLE` on the following cycle.

## Interface Ports

| Port | Direction | Width | Description |
|---|---|---:|---|
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low asynchronous reset |
| `start` | Input | 1 | Start computation strobe |
| `buffer_ready` | Input | 1 | Input buffer ready flag from Member 3 |
| `array_rst` | Output | 1 | Synchronous reset pulse to systolic array PEs |
| `array_en` | Output | 1 | Compute enable to systolic array PEs |
| `buffer_rd_en` | Output | 1 | Read enable strobe to Member 3 buffers |
| `done` | Output | 1 | Computation complete flag |
| `busy` | Output | 1 | Controller active status flag |
| `cycle_cnt` | Output | CNT_WIDTH | Step counter ($0$ to $3N-2$) |

## Integration with Other Members
- **Member 2 (Systolic Array):** Directly drives `u_array.rst` and `u_array.en`.
- **Member 3 (Input Buffers):** Awaits `buffer_ready` before initiating, and asserts `buffer_rd_en` across the $2N - 1$ feed cycles.

# Processing Element (PE) Interface Specification

## Module
`processing_element`

## Data Configuration
- Input A: signed 8-bit
- Input B: signed 8-bit
- Accumulator: signed 32-bit

## Input Signals

| Signal | Width | Description |
|---|---:|---|
| clk | 1 | Clock |
| rst | 1 | Synchronous active-high reset |
| en | 1 | MAC accumulation enable |
| a_in | 8 | Signed input A |
| b_in | 8 | Signed input B |

## Output Signals

| Signal | Width | Description |
|---|---:|---|
| a_out | 8 | Registered forwarding output A |
| b_out | 8 | Registered forwarding output B |
| acc | 32 | Accumulated multiplication result |

## Behaviour

1. The PE receives signed input values A and B.
2. The MAC unit calculates `ACC = ACC + (A × B)` when `en` is high.
3. A and B are forwarded through registered outputs on every clock cycle.
4. When `rst` is high, the accumulator and forwarding registers are reset to zero.
5. The accumulator retains its previous value when `en` is low.

## Verification
- MAC arithmetic testbench passed.
- PE functional testbench passed.
- PE stress testbench passed.
- Waveform files generated for simulation evidence.

## Integration Note
This is the proposed PE interface. Confirm signal names, forwarding timing and control behaviour with the systolic array designer before final integration.
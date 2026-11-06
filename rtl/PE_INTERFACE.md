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


## Parameterisation and Verification

### Configurable Parameters

The Processing Element supports configurable data and accumulator widths.

| Parameter | Default | Description |
|---|---:|---|
| DATA_WIDTH | 8 | Width of signed input and forwarded data |
| ACC_WIDTH | 32 | Width of signed accumulator |

The PE passes these parameters to its internal MAC unit.

### Verification Results

The following tests were performed:

1. MAC unit functional test — PASS
2. Processing Element functional test — PASS
3. PE stress test — PASS
4. 16-bit PE parameterisation test — PASS
5. Signed multiplication and accumulation — PASS
6. Data forwarding test — PASS
7. 32-bit accumulator overflow test — PASS

### Overflow Behaviour

The accumulator uses fixed-width signed arithmetic.

When the mathematical result exceeds the signed 32-bit range, the result wraps around according to two's complement arithmetic. Saturation and overflow protection are not implemented.

### Back-to-Back MAC Verification

A dedicated testbench was created to verify consecutive MAC operations.

Test sequence:
- 3 × 4 = 12
- 2 × 5 + 12 = 22
- (-2) × 3 + 22 = 16
- Disable MAC and verify accumulator holds at 16
- Verify data forwarding while MAC is disabled
- Re-enable MAC and calculate 1 × 10 + 16 = 26

Result: All six checks passed.
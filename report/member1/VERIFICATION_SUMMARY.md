
# Member 1 — Verification Summary

## Simulation Environment
- HDL: Verilog
- Simulator: Icarus Verilog 13.0
- Waveform format: VCD

## Test Results

| Testbench | Result |
|---|---|
| tb_mac_unit | PASS |
| tb_processing_element | PASS |
| tb_pe_stress | PASS |
| tb_mac_parameter | PASS |
| tb_pe_parameter | PASS |
| tb_pe_overflow | PASS |
| tb_pe_back_to_back | PASS |
| tb_pe_2x2_integration | PASS |
| tb_systolic_2x2 | PASS |

## Integration Results

### 2×2 PE Integration

| Processing Element | Result |
|---|---:|
| PE00 | 10 |
| PE01 | 14 |
| PE10 | 15 |
| PE11 | 21 |

### 2×2 Matrix Multiplication

Input:

A = [[1, 2], [3, 4]]

B = [[5, 7], [6, 8]]

Expected output:

C = [[17, 23], [39, 53]]

All four output values matched the expected results.

## Waveform Evidence

All simulation waveforms are stored in:

`report/member1/waveforms/`

## Conclusion

The MAC unit and Processing Element passed all listed standalone and 2×2 integration simulations. The implementation is ready for integration testing with the complete team architecture.

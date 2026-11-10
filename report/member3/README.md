# Member 3: Input Buffer and Matrix Interface

## 1. Overview

Member 3 is responsible for storing input matrices and providing correctly
timed matrix operands to the systolic array.

The implementation consists of:
- Input Buffer
- Matrix Interface
- Verification Testbenches
- Integration Verification

## 2. Input Buffer

File: `rtl/input_buffer.v`

The input buffer stores two N x N matrices:
- Matrix A
- Matrix B

Parameters:
- N: Matrix dimension (default 4)
- DATA_WIDTH: Operand width (default 8 bits)

The buffer accepts matrix elements sequentially through `load_a` and
`load_b`, controlled by `load_en`.

After all N x N pairs are loaded, `buffer_ready` is asserted.

The matrices are provided as flattened output vectors.

## 3. Matrix Interface

File: `rtl/matrix_interface.v`

The matrix interface reads the flattened matrices and generates
the row and column inputs required by the systolic array.

It uses:
- `buffer_rd_en` to enable streaming
- `cycle_cnt` to select matrix elements
- `matrix_a_flat` and `matrix_b_flat` as stored matrix inputs
- `a_in` and `b_in` as packed systolic-array inputs

Matrix A is skewed row by row.
Matrix B is skewed column by column.

Zero values are supplied for invalid positions and when streaming
is disabled.

## 4. System Integration

Member 3 modules were connected with:
- Member 1: MAC unit and Processing Element
- Member 2: Systolic Array
- Member 4: Systolic Controller

The controller provides `buffer_ready`, `buffer_rd_en`, and
`cycle_cnt` signals to coordinate matrix streaming.

The matrix interface supplies `a_in` and `b_in` to the systolic array.

## 5. Verification Results

### Input Buffer Test

Testbench: `testbench/tb_input_buffer.v`

Result: PASSED

Verified:
- Sequential loading of 16 matrix element pairs
- Correct storage of Matrix A and Matrix B
- Correct assertion of `buffer_ready`

### Matrix Interface Test

Testbench: `testbench/tb_matrix_interface.v`

Result: PASSED

Verified:
- Seven skewed feed cycles for N = 4
- Correct row-wise A input selection
- Correct column-wise B input selection
- Zero padding for invalid positions
- Zero outputs when streaming is disabled

### Full Integration Test

Testbench: `testbench/tb_member3_integration.v`

Result: PASSED

Verified:
- Matrix loading
- Controller operation
- Matrix streaming
- Systolic array computation
- All 16 output elements against the reference matrix product

## 6. Waveform Evidence

Generated waveforms are stored in `report/member3/waveforms/`.

1. `input_buffer_waveform.vcd`
2. `matrix_interface_waveform.vcd`
3. `member3_integration.vcd`

These files can be opened using GTKWave or another VCD waveform viewer.

## 7. Conclusion

The Member 3 input buffer and matrix interface were implemented and
verified independently and as part of the integrated systolic-array
system.

All three verification testbenches passed successfully.

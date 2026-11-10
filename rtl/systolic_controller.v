`timescale 1ns / 1ps

module systolic_controller #(
    parameter N = 4,                       // Matrix dimension (N x N)
    parameter CNT_WIDTH = 8                // Cycle counter bit-width
)(
    input  wire                   clk,
    input  wire                   rst_n,          // Active-low asynchronous/synchronous reset
    input  wire                   start,          // Pulse to start computation
    input  wire                   buffer_ready,   // High when Member 3 buffers are loaded

    output reg                    array_rst,      // Active-high synchronous reset to systolic array PEs
    output reg                    array_en,       // Enable computation across systolic array PEs
    output reg                    buffer_rd_en,   // Read-enable / stream-enable to Member 3 input buffers
    output reg                    done,           // Computation complete pulse/flag
    output reg                    busy,           // Controller is actively processing
    output reg  [CNT_WIDTH-1:0]   cycle_cnt       // Current execution cycle count
);

    // Timing parameters:
    // FEED_CYCLES: Number of cycles matrix inputs are streamed from buffers = 2*N - 1
    // TOTAL_CYCLES: Feed cycles + N cycles for pipeline flush/accumulation propagation = 3*N - 1
    localparam [CNT_WIDTH-1:0] FEED_CYCLES  = 2 * N - 1;
    localparam [CNT_WIDTH-1:0] TOTAL_CYCLES = 3 * N - 1;

    // FSM State Encoding
    localparam [2:0]
        S_IDLE    = 3'b000,
        S_INIT    = 3'b001,
        S_COMPUTE = 3'b010,
        S_DONE    = 3'b011;

    reg [2:0] state, next_state;

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            cycle_cnt <= {CNT_WIDTH{1'b0}};
        end
        else begin
            state <= next_state;
            if (state == S_COMPUTE) begin
                cycle_cnt <= cycle_cnt + 1'b1;
            end
            else begin
                cycle_cnt <= {CNT_WIDTH{1'b0}};
            end
        end
    end

    // Next-State Logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start && buffer_ready)
                    next_state = S_INIT;
            end

            S_INIT: begin
                // One-cycle reset pulse to clear PE accumulators and forwarding registers
                next_state = S_COMPUTE;
            end

            S_COMPUTE: begin
                // Run until all skewed inputs are fed and flushed through the grid
                if (cycle_cnt == TOTAL_CYCLES - 1'b1)
                    next_state = S_DONE;
            end

            S_DONE: begin
                // Return to IDLE on next cycle
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Output Logic (Registered or Combinational based on current state)
    always @(*) begin
        // Defaults
        array_rst    = 1'b0;
        array_en     = 1'b0;
        buffer_rd_en = 1'b0;
        done         = 1'b0;
        busy         = 1'b0;

        case (state)
            S_IDLE: begin
                busy = 1'b0;
            end

            S_INIT: begin
                busy      = 1'b1;
                array_rst = 1'b1; // Clear all PEs before starting
            end

            S_COMPUTE: begin
                busy     = 1'b1;
                array_en = 1'b1;

                // Stream operands from buffers during the skewed feed window (0 to 2N-2)
                if (cycle_cnt < FEED_CYCLES) begin
                    buffer_rd_en = 1'b1;
                end
                else begin
                    buffer_rd_en = 1'b0; // Drain/flush stage, pad inputs with zero
                end
            end

            S_DONE: begin
                busy = 1'b0;
                done = 1'b1;
            end

            default: begin
                array_rst    = 1'b0;
                array_en     = 1'b0;
                buffer_rd_en = 1'b0;
                done         = 1'b0;
                busy         = 1'b0;
            end
        endcase
    end

endmodule

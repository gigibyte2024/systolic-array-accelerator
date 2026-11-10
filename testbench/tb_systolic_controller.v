`timescale 1ns / 1ps

module tb_systolic_controller;

    parameter N = 4;
    parameter CNT_WIDTH = 8;
    parameter DATA_WIDTH = 8;

    // Clock and reset signals
    reg clk;
    reg rst_n;
    reg start;
    reg buffer_ready;

    // Controller outputs
    wire array_rst;
    wire array_en;
    wire buffer_rd_en;
    wire done;
    wire busy;
    wire [CNT_WIDTH-1:0] cycle_cnt;

    // Mocked input buffer data streams (N rows for A, N columns for B)
    reg signed [(N*DATA_WIDTH)-1:0] mock_a_stream;
    reg signed [(N*DATA_WIDTH)-1:0] mock_b_stream;

    integer errors;
    integer step;

    // Instantiate Controller DUT
    systolic_controller #(
        .N(N),
        .CNT_WIDTH(CNT_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .buffer_ready(buffer_ready),
        .array_rst(array_rst),
        .array_en(array_en),
        .buffer_rd_en(buffer_rd_en),
        .done(done),
        .busy(busy),
        .cycle_cnt(cycle_cnt)
    );

    // Clock generator (100MHz, 10ns period)
    always #5 clk = ~clk;

    // Stub/Mock Buffer Logic:
    // When buffer_rd_en is asserted by the controller, feed mock skewed data.
    // Otherwise, drive zeroes (pipeline drain / idle).
    always @(posedge clk) begin
        if (buffer_rd_en) begin
            // Simulating skewed feed: row r gets mock value (cycle_cnt + r + 1)
            mock_a_stream <= {8'sd4 + cycle_cnt, 8'sd3 + cycle_cnt, 8'sd2 + cycle_cnt, 8'sd1 + cycle_cnt};
            mock_b_stream <= {8'sd40 + cycle_cnt, 8'sd30 + cycle_cnt, 8'sd20 + cycle_cnt, 8'sd10 + cycle_cnt};
        end
        else begin
            mock_a_stream <= {(N*DATA_WIDTH){1'b0}};
            mock_b_stream <= {(N*DATA_WIDTH){1'b0}};
        end
    end

    initial begin
        $dumpfile("simulation/systolic_controller_waveform.vcd");
        $dumpvars(0, tb_systolic_controller);

        errors = 0;
        clk = 0;
        rst_n = 0;
        start = 0;
        buffer_ready = 0;
        mock_a_stream = 0;
        mock_b_stream = 0;

        $display("==================================================");
        $display("   TESTBENCH: Systolic Array Controller (Member 4)");
        $display("==================================================");

        // 1. Reset check
        #15;
        rst_n = 1;
        #10;

        if (busy !== 1'b0 || done !== 1'b0 || array_en !== 1'b0) begin
            $display("[FAIL] Controller not idle after reset");
            errors = errors + 1;
        end else begin
            $display("[PASS] Reset state verified (IDLE)");
        end

        // 2. Check that start without buffer_ready does not trigger computation
        @(posedge clk);
        start = 1;
        buffer_ready = 0;
        @(posedge clk);
        start = 0;

        if (busy !== 1'b0) begin
            $display("[FAIL] Controller started without buffer_ready");
            errors = errors + 1;
        end else begin
            $display("[PASS] Start ignored when buffer_ready = 0");
        end

        // 3. Trigger valid computation with buffer_ready = 1
        @(posedge clk);
        buffer_ready = 1;
        start = 1;
        @(posedge clk);
        start = 0;

        // Next cycle should be S_INIT (array_rst asserted, busy asserted)
        #1;
        if (array_rst !== 1'b1 || busy !== 1'b1) begin
            $display("[FAIL] S_INIT state expected (array_rst=1, busy=1)");
            errors = errors + 1;
        end else begin
            $display("[PASS] S_INIT state verified (array_rst pulsed)");
        end

        // 4. Verify COMPUTE Phase (Total cycles = 3*N - 1 = 11 for N=4)
        // Feed cycles = 2*N - 1 = 7 (cycles 0 to 6)
        // Flush cycles = N = 4 (cycles 7 to 10)
        @(posedge clk); // Moves into S_COMPUTE

        for (step = 0; step < (3 * N - 1); step = step + 1) begin
            #1;
            if (busy !== 1'b1 || array_en !== 1'b1) begin
                $display("[FAIL] Cycle %0d: Expected busy=1, array_en=1", step);
                errors = errors + 1;
            end

            // Check feed window vs flush window
            if (step < (2 * N - 1)) begin
                if (buffer_rd_en !== 1'b1) begin
                    $display("[FAIL] Cycle %0d: Expected buffer_rd_en=1 during feed window", step);
                    errors = errors + 1;
                end
            end else begin
                if (buffer_rd_en !== 1'b0) begin
                    $display("[FAIL] Cycle %0d: Expected buffer_rd_en=0 during flush window", step);
                    errors = errors + 1;
                end
            end

            @(posedge clk);
        end

        // 5. Verify DONE Phase
        #1;
        if (done !== 1'b1 || busy !== 1'b0) begin
            $display("[FAIL] Expected done=1, busy=0 in S_DONE state");
            errors = errors + 1;
        end else begin
            $display("[PASS] S_DONE state reached with done=1");
        end

        // Return to IDLE
        @(posedge clk);
        #1;
        if (done !== 1'b0 || busy !== 1'b0) begin
            $display("[FAIL] Expected return to IDLE (done=0, busy=0)");
            errors = errors + 1;
        end else begin
            $display("[PASS] Controller smoothly returned to IDLE");
        end

        #20;
        $display("==================================================");
        if (errors == 0) begin
            $display("   TEST PASSED: Controller verified successfully! ");
        end else begin
            $display("   TEST FAILED: %0d error(s) encountered.", errors);
        end
        $display("==================================================");

        $finish;
    end

endmodule

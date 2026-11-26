`timescale 1ns/1ps

// Protocol stress test for systolic_controller.
//
// Case 1 - start without buffer_ready:  must stay in IDLE.
// Case 2 - buffer_ready without start:  must stay in IDLE.
// Case 3 - normal run: exactly 1 INIT, 3N-1 COMPUTE, 1 DONE cycle,
//          cycle_cnt = 0,1,...,3N-2 and buffer_rd_en high only while
//          cycle_cnt < 2N-1.
// Case 4 - extra start pulses during INIT, COMPUTE and DONE: ignored,
//          the run length is unchanged and no second run starts.
// Case 5 - start held high: runs repeat back to back, each one exact,
//          with one IDLE cycle between them.
// Case 6 - buffer_ready dropped during COMPUTE: the run still completes
//          (buffer_ready is only checked in IDLE).
// Case 7 - rst_n asserted between clock edges in INIT, early/middle/last
//          COMPUTE and DONE: the reset is asynchronous, so the controller
//          must return to IDLE at once, with all outputs low and
//          cycle_cnt = 0, and the next run must be exact.
//
// Invariants checked on every cycle (outside reset):
//   array_rst and array_en are never high together
//   buffer_rd_en implies array_en,  array_en implies busy
//   done implies not busy,          cycle_cnt is 0 in IDLE and INIT
//   cycle_cnt in DONE equals the total compute cycles (3N-1)
//
// Run one size (example N = 8):
//   iverilog -g2012 -s tb_controller_stress -Ptb_controller_stress.N=8 \
//     -o ctl.vvp rtl/systolic_controller.v testbench/tb_controller_stress.v
module tb_controller_stress;

    parameter N         = 4;
    parameter CNT_WIDTH = $clog2(3*N) + 1;

    localparam S_IDLE    = 0;
    localparam S_INIT    = 1;
    localparam S_COMPUTE = 2;
    localparam S_DONE    = 3;

    reg clk, rst_n, start, buffer_ready;
    wire array_rst, array_en, buffer_rd_en, done, busy;
    wire [CNT_WIDTH-1:0] cycle_cnt;

    integer errors, i, run_i, inject, init_cycles, compute_cycles, done_cycles;
    integer expected_cnt, target, guard;

    systolic_controller #(.N(N), .CNT_WIDTH(CNT_WIDTH)) u (
        .clk(clk), .rst_n(rst_n), .start(start), .buffer_ready(buffer_ready),
        .array_rst(array_rst), .array_en(array_en), .buffer_rd_en(buffer_rd_en),
        .done(done), .busy(busy), .cycle_cnt(cycle_cnt)
    );

    always #5 clk = ~clk;

    // ---------------- invariants, every cycle ----------------
    always @(negedge clk) begin
        if (rst_n) begin
            if (array_rst && array_en)    begin $display("FAIL invariant: array_rst and array_en both high"); errors = errors + 1; end
            if (buffer_rd_en && !array_en) begin $display("FAIL invariant: buffer_rd_en without array_en");   errors = errors + 1; end
            if (array_en && !busy)         begin $display("FAIL invariant: array_en without busy");           errors = errors + 1; end
            if (done && busy)              begin $display("FAIL invariant: done and busy both high");         errors = errors + 1; end
            // The counter increments on the edge that leaves COMPUTE, so in
            // DONE it shows the total compute cycles (3N-1); otherwise 0.
            if (u.state == S_DONE && cycle_cnt != 3*N - 1) begin
                $display("FAIL invariant: cycle_cnt = %0d in DONE, expected %0d", cycle_cnt, 3*N - 1);
                errors = errors + 1;
            end
            if ((u.state == S_IDLE || u.state == S_INIT) && cycle_cnt != 0) begin
                $display("FAIL invariant: cycle_cnt = %0d in IDLE/INIT", cycle_cnt);
                errors = errors + 1;
            end
        end
    end

    task fail(input [8*60-1:0] msg);
        begin
            $display("FAIL: %0s", msg);
            errors = errors + 1;
        end
    endtask

    task expect_idle_for(input integer cycles, input [8*40-1:0] label);
        integer n, bad;
        begin
            bad = 0;
            for (n = 0; n < cycles; n = n + 1) begin
                @(negedge clk);
                if (u.state != S_IDLE || busy || array_en || array_rst || done)
                    bad = bad + 1;
            end
            if (bad == 0) $display("PASS %0s", label);
            else begin $display("FAIL %0s: left IDLE on %0d cycles", label, bad); errors = errors + bad; end
        end
    endtask

    // Pulse start, then follow one run until it returns to IDLE.
    // inject: 0 none, 1 extra start in INIT, 2 extra starts in COMPUTE,
    //         3 extra start in DONE, 4 drop buffer_ready during COMPUTE.
    task measure_run(input integer inj);
        begin
            init_cycles = 0; compute_cycles = 0; done_cycles = 0;
            expected_cnt = 0; guard = 0;

            @(negedge clk); start = 1;
            @(negedge clk); start = 0;           // first rising edge -> INIT

            while (u.state != S_IDLE && guard < 3*N + 10) begin
                start = 0;
                case (u.state)
                    S_INIT: begin
                        init_cycles = init_cycles + 1;
                        if (!array_rst || !busy) fail("INIT outputs wrong");
                        if (inj == 1) start = 1;
                    end
                    S_COMPUTE: begin
                        compute_cycles = compute_cycles + 1;
                        if (cycle_cnt != expected_cnt) begin
                            $display("FAIL: cycle_cnt = %0d, expected %0d", cycle_cnt, expected_cnt);
                            errors = errors + 1;
                        end
                        if (buffer_rd_en !== (expected_cnt < 2*N - 1)) begin
                            $display("FAIL: buffer_rd_en = %0b at cycle_cnt %0d", buffer_rd_en, expected_cnt);
                            errors = errors + 1;
                        end
                        expected_cnt = expected_cnt + 1;
                        if (inj == 2 && (expected_cnt % 3 == 1)) start = 1;
                        if (inj == 4 && expected_cnt == N) buffer_ready = 0;
                    end
                    S_DONE: begin
                        done_cycles = done_cycles + 1;
                        if (!done) fail("done low in DONE");
                        if (inj == 3) start = 1;
                    end
                endcase
                @(negedge clk);
                guard = guard + 1;
            end
            start = 0;
            buffer_ready = 1;
        end
    endtask

    task check_run(input [8*40-1:0] label);
        begin
            if (init_cycles == 1 && compute_cycles == 3*N - 1 && done_cycles == 1)
                $display("PASS %0s (INIT 1, COMPUTE %0d, DONE 1)", label, compute_cycles);
            else begin
                $display("FAIL %0s: INIT %0d, COMPUTE %0d (expected %0d), DONE %0d",
                         label, init_cycles, compute_cycles, 3*N - 1, done_cycles);
                errors = errors + 1;
            end
        end
    endtask

    // Asynchronous reset between clock edges, then check at once.
    task reset_now(input [8*40-1:0] label);
        begin
            #2 rst_n = 0;      // 2 ns after a falling edge: no clock edge here
            #1;
            if (u.state == S_IDLE && cycle_cnt == 0 &&
                !busy && !array_en && !array_rst && !buffer_rd_en && !done)
                $display("PASS %0s: back to IDLE immediately", label);
            else begin
                $display("FAIL %0s: state %0d, cycle_cnt %0d after async reset",
                         label, u.state, cycle_cnt);
                errors = errors + 1;
            end
            @(negedge clk); @(negedge clk);
            rst_n = 1;
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; start = 0; buffer_ready = 0; errors = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Case 1: start without buffer_ready.
        start = 1;
        expect_idle_for(20, "case1 start without buffer_ready");
        start = 0;

        // Case 2: buffer_ready without start.
        buffer_ready = 1;
        expect_idle_for(20, "case2 buffer_ready without start");

        // Case 3: normal run.
        measure_run(0); check_run("case3 normal run");
        expect_idle_for(5, "case3 stays IDLE afterwards");

        // Case 4: extra start pulses inside a run.
        measure_run(1); check_run("case4 start during INIT");
        expect_idle_for(5, "case4 no extra run after INIT start");
        measure_run(2); check_run("case4 starts during COMPUTE");
        expect_idle_for(5, "case4 no extra run after COMPUTE starts");
        measure_run(3); check_run("case4 start during DONE");
        expect_idle_for(5, "case4 no extra run after DONE start");

        // Case 5: start held high, three back-to-back runs.
        @(negedge clk); start = 1;
        for (run_i = 0; run_i < 3; run_i = run_i + 1) begin
            while (u.state != S_INIT) @(negedge clk);
            init_cycles = 0; compute_cycles = 0; done_cycles = 0;
            while (u.state == S_INIT)    begin init_cycles    = init_cycles + 1;    @(negedge clk); end
            while (u.state == S_COMPUTE) begin compute_cycles = compute_cycles + 1; @(negedge clk); end
            while (u.state == S_DONE)    begin done_cycles    = done_cycles + 1;    @(negedge clk); end
            if (u.state != S_IDLE) fail("held start: no IDLE cycle after DONE");
            @(negedge clk);
            if (u.state != S_INIT) fail("held start: did not restart after one IDLE cycle");
            check_run("case5 held start, back-to-back run");
        end
        start = 0;
        while (u.state != S_IDLE) @(negedge clk);

        // Case 6: buffer_ready dropped during COMPUTE.
        measure_run(4); check_run("case6 buffer_ready dropped mid-run");

        // Case 7: asynchronous reset in every state.
        for (target = 0; target < 5; target = target + 1) begin
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;           // now in INIT
            case (target)
                0: ;                                                    // INIT
                1: while (!(u.state == S_COMPUTE && cycle_cnt == 0))      @(negedge clk);
                2: while (!(u.state == S_COMPUTE && cycle_cnt == 2*N - 1)) @(negedge clk);
                3: while (!(u.state == S_COMPUTE && cycle_cnt == 3*N - 2)) @(negedge clk);
                4: while (u.state != S_DONE)                               @(negedge clk);
            endcase
            case (target)
                0: reset_now("case7 reset in INIT");
                1: reset_now("case7 reset in first COMPUTE cycle");
                2: reset_now("case7 reset at start of flush");
                3: reset_now("case7 reset in last COMPUTE cycle");
                4: reset_now("case7 reset in DONE");
            endcase
            buffer_ready = 1;
            measure_run(0); check_run("case7 run after reset");
        end

        $display("------------------------------");
        if (errors == 0)
            $display("N=%0d CONTROLLER STRESS TEST PASSED", N);
        else
            $fatal(1, "N=%0d: %0d errors in controller stress test", N, errors);
        $display("------------------------------");
        $finish;
    end

endmodule

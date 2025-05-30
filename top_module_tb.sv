`timescale 1ns / 1ps

module tb_all_phases_with_top;

    reg clk, reset, start;
    reg code_in;
    reg [3:0] switch_in;
    reg [2:0] dir_in;
    reg [7:0] plate_in;
    wire [1:0] time_lock_out;
    wire alarm;

    // Instantiate the full top module
    top_module uut (
        .clk(clk), .reset(reset), .start(start),
        .code_in(code_in), .switch_in(switch_in),
        .dir_in(dir_in), .plate_in(plate_in),
        .time_lock_out(time_lock_out), .alarm(alarm)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("all_phases_with_top_tb.vcd");
        $dumpvars(0, tb_all_phases_with_top);

        clk = 0; reset = 1; start = 0;
        code_in = 0; switch_in = 0;
        dir_in = 0; plate_in = 0;

        #10 reset = 0;
        #10 start = 1; #10 start = 0;

        // === PHASE 1 ===
        #10 code_in = 1; #10;
        code_in = 0; #10;
        code_in = 1; #10;
        code_in = 1; #10;

        // === PHASE 2 ===
        #20 switch_in = 4'b1101; #10;

        // === PHASE 3 ===
        dir_in = 3'b000; #10; // UP
        dir_in = 3'b011; #10; // RIGHT
        dir_in = 3'b001; #10; // DOWN
        dir_in = 3'b010; #10; // LEFT
        dir_in = 3'b000; #10; // UP

        // === PHASE 4 ===
        plate_in = 8'hAA; #10;
        plate_in = 8'hCC; #10;
        plate_in = 8'hF0; #10;

        // === PHASE 5 ===
        repeat (3) begin
            #10 $display("Time Lock Out: %b", time_lock_out);
        end

        if (alarm)
            $display("FAIL ❌: Alarm triggered during execution.");
        else
            $display("PASS ✅: All phases completed successfully, vault unlocked.");

        #20 $finish;
    end
endmodule

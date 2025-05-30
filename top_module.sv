`timescale 1ns / 1ps

// =====================
// === PHASE 1 MODULE ===
// =====================
module phase1 (
    input wire clk, reset, code_in, start,
    output reg phase1_done, phase1_fail, alarm
);
    parameter IDLE=3'd0, S1=3'd1, S2=3'd2, S3=3'd3, S4=3'd4, CHECK=3'd5;
    reg [2:0] state, next_state;
    reg [3:0] code_shift;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE; code_shift <= 0;
            phase1_done <= 0; phase1_fail <= 0; alarm <= 0;
        end else begin
            state <= next_state;
            if (state == S1 || state == S2 || state == S3 || state == S4)
                code_shift <= {code_shift[2:0], code_in};
            if (state == CHECK) begin
                if (code_shift == 4'b1011) phase1_done <= 1;
                else begin phase1_fail <= 1; alarm <= 1; end
            end
        end
    end

    always @(*) begin
        case (state)
            IDLE: next_state = start ? S1 : IDLE;
            S1:   next_state = S2;
            S2:   next_state = S3;
            S3:   next_state = S4;
            S4:   next_state = CHECK;
            CHECK:next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
endmodule

// =====================
// === PHASE 2 MODULE ===
// =====================
module phase2 (
    input clk, rst,
    input [3:0] switch_in,
    input enable,
    output reg phase2_done, phase2_fail
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            phase2_done <= 0;
            phase2_fail <= 0;
        end else if (enable) begin
            if (switch_in == 4'b1101)
                phase2_done <= 1;
            else
                phase2_fail <= 1;
        end
    end
endmodule

// =====================
// === PHASE 3 MODULE ===
// =====================
module phase3 (
    input clk, rst,
    input valid,
    input [2:0] dir_in,
    output reg phase3_done, phase3_fail
);
    reg [2:0] expected[0:4];
    reg [2:0] buffer[0:4];
    integer i;
    integer count;

    initial begin
        expected[0]=3'b000; expected[1]=3'b011;
        expected[2]=3'b001; expected[3]=3'b010;
        expected[4]=3'b000;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count = 0;
            phase3_done = 0;
            phase3_fail = 0;
        end else if (valid && count < 5) begin
            buffer[count] <= dir_in;
            count <= count + 1;
            if (count == 4) begin
                phase3_fail = 0;
                for (i = 0; i < 5; i = i + 1) begin
                    if (buffer[i] !== expected[i])
                        phase3_fail = 1;
                end
                if (!phase3_fail)
                    phase3_done = 1;
            end
        end
    end
endmodule

// =====================
// === PHASE 4 MODULE ===
// =====================
module phase4 (
    input clk, rst,
    input valid,
    input [7:0] plate_in,
    output reg phase4_done, phase4_fail
);
    reg [7:0] buffer[0:2];
    reg [7:0] expected[0:2];
    integer count;

    initial begin
        expected[0]=8'hAA; expected[1]=8'hCC; expected[2]=8'hF0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count = 0;
            phase4_done = 0;
            phase4_fail = 0;
        end else if (valid && count < 3) begin
            buffer[count] <= plate_in;
            count <= count + 1;
            if (count == 2) begin
                if (buffer[0]==expected[0] && buffer[1]==expected[1] && buffer[2]==expected[2])
                    phase4_done <= 1;
                else
                    phase4_fail <= 1;
            end
        end
    end
endmodule

// =====================
// === PHASE 5 MODULE ===
// =====================
module phase5 (
    input clk, rst,
    input start,
    output reg [1:0] time_lock_out,
    output reg phase5_done, phase5_fail
);
    reg [1:0] seq[0:2];
    integer idx;

    initial begin
        seq[0] = 2'b01;
        seq[1] = 2'b10;
        seq[2] = 2'b11;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idx <= 0;
            time_lock_out <= 2'b00;
            phase5_done <= 0;
            phase5_fail <= 0;
        end else if (start && !phase5_done) begin
            time_lock_out <= seq[idx];
            idx <= idx + 1;
            if (idx == 2)
                phase5_done <= 1;
        end
    end
endmodule

// =====================
// === TOP MODULE ===
// =====================
module top_module (
    input clk, reset, start,
    input code_in,
    input [3:0] switch_in,
    input [2:0] dir_in,
    input [7:0] plate_in,
    output [1:0] time_lock_out,
    output reg alarm
);
    typedef enum logic [2:0] {
        IDLE, PH1, PH2, PH3, PH4, PH5, DONE, FAIL
    } fsm_state_t;

    fsm_state_t state, next_state;

    reg p1_start, p2_en, p3_val, p4_val, p5_start;
    wire d1, f1, d2, f2, d3, f3, d4, f4, d5, f5;
    wire alarm_p1;

    phase1 m1(clk, reset, code_in, p1_start, d1, f1, alarm_p1);
    phase2 m2(clk, reset, switch_in, p2_en, d2, f2);
    phase3 m3(clk, reset, p3_val, dir_in, d3, f3);
    phase4 m4(clk, reset, p4_val, plate_in, d4, f4);
    phase5 m5(clk, reset, p5_start, time_lock_out, d5, f5);

    always @(posedge clk or posedge reset)
        if (reset) state <= IDLE;
        else       state <= next_state;

    always @(*) begin
        p1_start = 0; p2_en = 0; p3_val = 0; p4_val = 0; p5_start = 0;
        alarm = 0;
        next_state = state;

        case (state)
            IDLE: if (start) next_state = PH1;

            PH1: begin
                p1_start = 1;
                if (d1) next_state = PH2;
                else if (f1 || alarm_p1) begin alarm = 1; next_state = FAIL; end
            end

            PH2: begin
                p2_en = 1;
                if (d2) next_state = PH3;
                else if (f2) begin alarm = 1; next_state = FAIL; end
            end

            PH3: begin
                p3_val = 1;
                if (d3) next_state = PH4;
                else if (f3) begin alarm = 1; next_state = FAIL; end
            end

            PH4: begin
                p4_val = 1;
                if (d4) next_state = PH5;
                else if (f4) begin alarm = 1; next_state = FAIL; end
            end

            PH5: begin
                p5_start = 1;
                if (d5) next_state = DONE;
                else if (f5) begin alarm = 1; next_state = FAIL; end
            end

            FAIL: begin
                alarm = 1;
                next_state = IDLE;
            end

            DONE: next_state = DONE;
        endcase
    end
endmodule

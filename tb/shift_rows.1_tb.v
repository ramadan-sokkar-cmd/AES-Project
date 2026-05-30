`timescale 1ns/1ps
module tb_shift_rows;
    reg  [127:0] state_in;
    wire [127:0] state_out;
    shift_rows dut (
        .state_in(state_in),
        .state_out(state_out)
    );
    initial begin
        // Apply test vector
        state_in = 128'h00112233445566778899AABBCCDDEEFF;
        #10;
        // Expected result after ShiftRows
        if (state_out == 128'h0055AAFF4499EE3388DD2277CC1166BB)
            $display("ShiftRows PASS");
        else begin
            $display("ShiftRows FAIL");
            $display("Expected: 0055AAFF4499EE3388DD2277CC1166BB");
            $display("Got     : %h", state_out);
        end
        $finish;
    end
endmodule

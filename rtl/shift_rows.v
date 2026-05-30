module shift_rows (
    input  wire [127:0] state_in,   // Input state from SubBytes (S-Box output)
    output wire [127:0] state_out    // Output state to MixColumns
);

    // ShiftRows operation in AES: Each row of the 4x4 state matrix is cyclically shifted left by a different number of bytes.
    // Row 0: no shift (0 bytes)
    // Row 1: shift left by 1 byte
    // Row 2: shift left by 2 bytes
    // Row 3: shift left by 3 bytes
    // This implementation uses direct byte assignments for highest speed, eliminating intermediate wires and reducing logic depth.
    // No combinational loops or extra logic; each output byte is directly mapped from input bytes.

    // Row 0: no shift - bytes remain in their positions
    assign state_out[127:120] = state_in[127:120]; // S 0,0
    assign state_out[95:88] = state_in[95:88];     // S 0,1
    assign state_out[63:56] = state_in[63:56];     // S 0,2
    assign state_out[31:24] = state_in[31:24];     // S 0,3

    // Row 1: shift left by 1 - cycle bytes within the row
    assign state_out[119:112] = state_in[87:80];   // S 1,0 <- S 1,1
    assign state_out[87:80] = state_in[55:48];     // S 1,1 <- S 1,2
    assign state_out[55:48] = state_in[23:16];     // S 1,2 <- S 1,3
    assign state_out[23:16] = state_in[119:112];   // S 1,3 <- S 1,0

    // Row 2: shift left by 2 - cycle bytes within the row
    assign state_out[111:104] = state_in[47:40];   // S 2,0 <- S 2,2
    assign state_out[79:72] = state_in[15:8];      // S 2,1 <- S 2,3
    assign state_out[47:40] = state_in[111:104];   // S 2,2 <- S 2,0
    assign state_out[15:8] = state_in[79:72];      // S 2,3 <- S 2,1

    // Row 3: shift left by 3 - cycle bytes within the row (equivalent to shift right by 1)
    assign state_out[103:96] = state_in[7:0];      // S 3,0 <- S 3,3
    assign state_out[71:64] = state_in[103:96];    // S 3,1 <- S 3,0
    assign state_out[39:32] = state_in[71:64];     // S 3,2 <- S 3,1
    assign state_out[7:0] = state_in[39:32];       // S 3,3 <- S 3,2

endmodule

// g_function module: performs AES RotWord + SubWord
// Parameter use_gf selects which S-Box implementation to use:
//   use_gf = 1 → GF arithmetic S-Box
//   use_gf = 0 → Assign/lookup S-Box

module g_function #(parameter use_gf = 0) (
    input  wire   [31:0]word_in,   // 4 bytes input word (32-bit total)
    output wire   [31:0]word_out        // 32-bit output word after g_function
);



    // Step 1: RotWord
    // Rotate the input word left by one byte:
    // {b1, b2, b3, b0}
    wire [31:0] shiftword_out;
    assign shiftword_out = {word_in[23:16], word_in[15:8], word_in[7:0], word_in[31:24]};

    // Step 2: SubWord
    // Apply S-Box substitution to each byte of shiftword_out
    wire [31:0] sword_out;

    generate
        if (use_gf == 1) begin
            // GF arithmetic S-Box implementation
            genvar i;
            for (i = 0; i < 4; i = i + 1) begin : sbox_loop
                sbox_gf sbox_ins (
                    .data_i(shiftword_out[8*i +: 8]),   // input byte
                    .data_o(sword_out[8*i +: 8])        // output byte
                );
            end
        end else begin
            // Lookup/assign S-Box implementation
            sbox_assign sbox_ins (
                .sboxw(shiftword_out),   // 32-bit input word
                .new_sboxw(sword_out)    // 32-bit output word
            );
        end
    endgenerate

    // Step 3: Output assignment
    // Final result of g_function is sword_out
    assign word_out = sword_out;

endmodule
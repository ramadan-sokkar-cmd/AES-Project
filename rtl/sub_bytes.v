//==============================================================
// SubBytes Module
// Performs AES SubBytes transformation on 128-bit state
// Supports two S-box implementations:
// 1) GF arithmetic S-box
// 2) LUT/assign S-box
//==============================================================

module sub_bytes(data_in, data_out);

parameter USE_gf = 1;

// 128-bit AES state input
input  [127:0] data_in;

// 128-bit AES state output after SubBytes
output wire [127:0] data_out;

// Generate variable for loop instantiation
genvar i;

generate

//==============================================================
// Case 1: GF arithmetic S-box implementation
// 16 parallel byte substitutions
//==============================================================
if (USE_gf == 1)
begin : GF_IMPLEMENTATION

    for (i = 15; i >= 0; i = i - 1)
    begin : sbox_loop

        // Instantiate one S-box per byte
        sbox_gf sbox_gf (
            .data_i(data_in[8*i +: 8]),    // input byte
            .data_o(data_out[8*i +: 8])    // substituted byte
        );

    end

end

//==============================================================
// Case 2: LUT S-box implementation
// 4 parallel 32-bit substitutions
//==============================================================
else
begin : LUT_IMPLEMENTATION

    for (i = 3; i >= 0; i = i - 1)
    begin : sbox_loop

        // Instantiate 32-bit S-box (4 bytes at once)
        sbox_assign sbox_assign (
            .sboxw(data_in[32*i +: 32]),       // input word
            .new_sboxw(data_out[32*i +: 32])   // substituted word
        );

    end

end

endgenerate

endmodule

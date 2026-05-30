// ============================================================
// AES Key Expansion (Standard – 128 / 192 / 256)
// - Uses standard AES equations
// - Supports pipeline (2 round keys per output)
// - Compatible with GF-based g_function
// ============================================================

module keyExpansion_comb #
(
    parameter Nk = 4,   // 4 = AES-128, 6 = AES-192, 8 = AES-256
    parameter Nb = 4,
    parameter Nr = (Nk==4) ? 10 :
                   (Nk==6) ? 12 : 14
)
(
    input  wire [Nk*32-1:0] KEY_in,        // مفتاح أصلي كـ bus
    // output reg  [256*(Nr/2+1)-1:0] KEY_out // كل entry = اتنين round keys
       output reg  [256*(Nr/2)-1:0] KEY_out  
    );

    // --------------------------------------------------------
    // Rcon table
    // --------------------------------------------------------
    localparam [31:0] Rcon [0:15] = '{
        32'h01000000, 32'h02000000, 32'h04000000, 32'h08000000,
        32'h10000000, 32'h20000000, 32'h40000000, 32'h80000000,
        32'h1B000000, 32'h36000000,
        32'h6C000000, 32'hD8000000,
        32'hab000000, 32'h4D000000,
        32'h9A000000, 32'h2F000000
    };

    // --------------------------------------------------------
    // Total expanded words
    // --------------------------------------------------------
    localparam TOTAL_W = Nb * (Nr + 1);
    reg [31:0] W [0:TOTAL_W-1];

    // --------------------------------------------------------
    // g_function (RotWord + SubWord + optional Rcon)
    // --------------------------------------------------------
    // reg  [31:0] g_in;
    // wire [31:0] g_out;
    wire [31:0] g_out [Nk:TOTAL_W-1];


    // g_function #(1) gfun (
    //     .word_in (g_in),
    //     .word_out(g_out)
    // );
genvar j;
generate
    for (j = Nk; j < TOTAL_W; j = j + 1) begin : gfun_loop
        g_function #(1) gfun_inst (
            .word_in(W[j-1]),
            .word_out(g_out[j])
        );
    end
endgenerate




    // --------------------------------------------------------
    // Key Expansion Logic (STANDARD AES)
    // --------------------------------------------------------

    integer i;
    reg [31:0] temp;

    always @(*) begin
        // Unpack KEY_in bus إلى كلمات
        for (i = 0; i < Nk; i = i + 1)
            W[i] = KEY_in[32*(Nk-1-i) +: 32];
            //    W[i] = KEY_in[32*i +: 32];

        // Expand key words
        for (i = Nk; i < TOTAL_W; i = i + 1) begin
            temp = W[i-1];

            if (i % Nk == 0) begin
                // g_in = W[i-1];
                // temp = g_out[i] ^ Rcon[i/Nk];
                temp  = g_out[i] ^ Rcon[i>>2];
  
            end
            else if (Nk == 8 && (i % Nk) == 4) begin
                // g_in = W[i-1];
                temp = g_out[i];
            end

            W[i] = W[i-Nk] ^ temp;
        end
    

        // Pack 2 round keys per output (pipeline friendly)
        for (i = 1; i < Nr; i = i + 2) begin
        KEY_out[256*((i-1)/2) +: 256] = {
             W[4*i+3],     W[4*i+2],     W[4*i+1],     W[4*i],
    W[4*(i+1)+3], W[4*(i+1)+2], W[4*(i+1)+1], W[4*(i+1)]
            // W[4*(i+1)+3], W[4*(i+1)+2], W[4*(i+1)+1], W[4*(i+1)],
            // W[4*i+3],     W[4*i+2],     W[4*i+1],     W[4*i]
        };
    end
end
        // for (i = 0; i < Nr; i = i + 2) begin
            // KEY_out[256*(i/2) +: 256] = {
                // W[4*i],     W[4*i + 1],     W[4*i + 2],     W[4*i + 3],
                // W[4*(i+1)], W[4*(i+1) + 1], W[4*(i+1) + 2], W[4*(i+1) + 3]
            // W[4*i + 3],     W[4*i + 2],     W[4*i + 1],     W[4*i],
            // W[4*(i+1) + 3], W[4*(i+1) + 2], W[4*(i+1) + 1], W[4*(i+1)]

            // };
    
    // end
    



endmodule
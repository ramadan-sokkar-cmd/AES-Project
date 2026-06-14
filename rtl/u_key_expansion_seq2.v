///////////////////////////////////////////////////////////////
// Module: keyExpansion_seq2
// Description:
// Sequential AES Key Expansion supporting AES-128/192/256
//
// - Generates expanded round keys
// - Uses iterative word generation
// - Outputs keys packed in 256-bit pairs
//
// Author: <ABDELRAHMAN_hamad>
// Version: v1.0
///////////////////////////////////////////////////////////////

module u_keyExpansion_seq2 #
(
    parameter Nk = 4,                 // Number of key words (4,6,8)
    parameter Nb = 4,                 // AES block words (fixed = 4)
    parameter Nr = (Nk==4) ? 10 :     // Number of rounds
                   (Nk==6) ? 12 : 14
)
(
    input  wire clk,                             // Clock input
     input  wire rst_n,                         
    input  wire [Nk*32-1:0] KEY_in,          // Original AES key
    output reg  [256*(Nr/2)-1:0] KEY_out,    // Packed expanded keys
    output reg key_ready
);

///////////////////////////////////////////////////////////////
// Derived parameters
///////////////////////////////////////////////////////////////

localparam TOTAL_W = Nb*(Nr+1);   // Total expanded words required

///////////////////////////////////////////////////////////////
// Internal storage
///////////////////////////////////////////////////////////////

reg [31:0] W [0:TOTAL_W-1];   // Expanded key word array
reg [5:0]  i ;             // Word generation index
reg [31:0] temp;              // Temporary word
reg done ;                 // Output generation flag
reg [2:0]  phase ;         // Phase state machine (FIX #3: Added phase)

integer r;                    // Round index for packing

///////////////////////////////////////////////////////////////
// g_function instance
// Applies RotWord + SubWord + Rcon when needed
///////////////////////////////////////////////////////////////

wire [127:0] sub_out;
wire [31:0] sub_in;
assign sub_in = (i > 0) ? W[i-1] : 32'h0;
sub_bytes #(.USE_gf(0)) sub(.data_in({sub_in,96'b0}),.data_out(sub_out));

wire [31:0] g_out;


g_function #(.use_gf(0)) gfun (
        // .word_in(W[i-1]),عشان اول مره هتبقي -1

    .word_in( (i>0) ? W[i-1] : 32'h0 ),
    .word_out(g_out)
);

///////////////////////////////////////////////////////////////
// Rcon lookup table
// Round constants used in AES key schedule
///////////////////////////////////////////////////////////////

function [31:0] Rcon;
    input [3:0] i;
    begin
        case(i)
            4'd1:  Rcon = 32'h01000000;
            4'd2:  Rcon = 32'h02000000;
            4'd3:  Rcon = 32'h04000000;
            4'd4:  Rcon = 32'h08000000;
            4'd5:  Rcon = 32'h10000000;
            4'd6:  Rcon = 32'h20000000;
            4'd7:  Rcon = 32'h40000000;
            4'd8:  Rcon = 32'h80000000;
            4'd9:  Rcon = 32'h1B000000;
            4'd10: Rcon = 32'h36000000;
            default: Rcon = 32'h00000000;
        endcase
    end
endfunction
///////////////////////////////////////////////////////////////
// Sequential key expansion process
///////////////////////////////////////////////////////////////

always @(posedge clk) begin

    if(!rst_n) begin
        i=0;
        temp=0;
        done=0;
         phase=2'b00;
         KEY_out=0;
         key_ready=0;

      
    end

//     ///////////////////////////////////////////////////////////
//     // Phase 1: Load original key words
//     ///////////////////////////////////////////////////////////
//     if (i < Nk) begin
//         W[i] <= KEY_in[32*(Nk-1-i) +: 32];
//         i <= i + 1;
//     end

//     ///////////////////////////////////////////////////////////
//     // Phase 2: Generate expanded key words
//     ///////////////////////////////////////////////////////////
//     else if (i < TOTAL_W) begin

//         temp = W[i-1];

//         // Apply g_function every Nk words
//         if (i % Nk == 0)
//             temp = g_out ^ Rcon(i/Nk);

//         // AES-256 special SubWord step
//         else if (Nk == 8 && (i % Nk) == 4)
//             temp = g_out;

//         // XOR with previous Nk word
//         W[i] <= W[i-Nk] ^ temp;

//         i <= i + 1;
//     end

//     /////////////////////////////////////////////////////////
//     // Phase 3: Pack round keys into KEY_out
//     /////////////////////////////////////////////////////////
//     else if (!done) begin
//             for (r = 1; r < Nr; r = r + 2) begin
//         KEY_out[256*((Nr-r)/2) +: 256] <= {
//             W[4*r], W[4*r+1], W[4*r+2], W[4*r+3],
//             W[4*(r+1)], W[4*(r+1)+1], W[4*(r+1)+2], W[4*(r+1)+3]
            
//         };
//     end
//     done <= 1;
//     key_ready <=1;
// end




    // الكود الجديد
case (phase)
    // Phase 0: Load key words
    0: begin
        if (i < Nk) begin
            W[i] <= KEY_in[32*(Nk-1-i) +: 32];
            i <= i + 1;
        end else begin
            phase <= 1;
            i <= Nk;
        end
    end

    // Phase 1: Generate expanded words
    1: begin
        if (i < TOTAL_W) begin
            temp = W[i-1];
            if (i % Nk == 0)
                temp = g_out ^ Rcon(i/Nk);
            else if (Nk == 8 && (i % Nk) == 4)
              temp = sub_out[127:96];
            W[i] <= W[i-Nk] ^ temp;
            i <= i + 1;
        end else begin
            phase <= 2;
            i <= 1;
        end
    end

    // Phase 2: Pack pairs iteratively (ONE pair per cycle!)
    2: begin
        if (i < Nr) begin
         
                KEY_out[256*((Nr-i-1)/2) +: 256] <= {
                    W[4*i],   W[4*i+1],   W[4*i+2],   W[4*i+3],
                    W[4*(i+1)], W[4*(i+1)+1], W[4*(i+1)+2], W[4*(i+1)+3]
                };
        
            i <= i + 2;  // Process pairs one at a time
        end else begin
            phase <= 3;
            done <= 1;
            key_ready <= 1;
        end
    end

    // Phase 3: Done
    3: begin
        key_ready <= 1;
    end
endcase

end

endmodule

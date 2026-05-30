///////////////////////////////////////////////////////////////
// Module: u_keyExpansion_seq2 (FIXED VERSION)
// Description:
// Sequential AES Key Expansion supporting AES-128/192/256
//
// - Generates expanded round keys
// - Uses iterative word generation
// - Outputs keys packed in 256-bit pairs
// - NOW SUPPORTS ALL KEY SIZES!
//
// Author: ABDELRAHMAN_hamad
// Version: v2.0 (FIXED)
///////////////////////////////////////////////////////////////

module u_keyExpansion_seq2 #
(
    parameter Nk = 4,                 // Number of key words (4,6,8)
    parameter Nb = 4,                 // AES block words (fixed = 4)
    parameter Nr = (Nk==4) ? 10 :     // Number of rounds
                   (Nk==6) ? 12 : 14
)
(
    input  wire clk,                         // Clock input
    input  wire rst_n,                       // Reset (active low) - FIX #1: Added reset
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
reg [5:0]  i = 0;             // Word generation index
reg [31:0] temp;              // Temporary word
reg [2:0]  phase = 0;         // Phase state machine (FIX #3: Added phase)
reg        done = 0;           // Output generation flag

integer r;                    // Round index for packing

///////////////////////////////////////////////////////////////
// g_function instance
// Applies RotWord + SubWord + Rcon when needed
///////////////////////////////////////////////////////////////

wire [31:0] g_out;

g_function #(.use_gf(0)) gfun (    // FIX #2: Added .use_gf parameter
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
// Sequential key expansion process with proper phase control
///////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    
    if (!rst_n) begin
        // Reset all state
        i <= 0;
        done <= 0;
        phase <= 0;
        key_ready <= 0;
        KEY_out <= {(256*(Nr/2)){1'b0}};
    end
    else begin
        
        case (phase)
            ///////////////////////////////////////////////////////////
            // PHASE 0: Load original key words
            ///////////////////////////////////////////////////////////
            0: begin
                if (i < Nk) begin
                    W[i] <= KEY_in[32*(Nk-1-i) +: 32];
                    i <= i + 1;
                end
                else begin
                    // Phase 0 complete, move to Phase 1
                    phase <= 1;
                    i <= Nk;
                end
            end

            ///////////////////////////////////////////////////////////
            // PHASE 1: Generate expanded key words iteratively
            ///////////////////////////////////////////////////////////
            1: begin
                if (i < TOTAL_W) begin
                    temp = W[i-1];

                    // Apply g_function every Nk words
                    if (i % Nk == 0)
                        temp = g_out ^ Rcon(i/Nk);
                    
                    // AES-256 special SubWord step
                    else if (Nk == 8 && (i % Nk) == 4)
                        temp = g_out;

                    // XOR with previous Nk word
                    W[i] <= W[i-Nk] ^ temp;
                    
                    i <= i + 1;
                end
                else begin
                    // Phase 1 complete, move to Phase 2 (packing)
                    phase <= 2;
                    i <= 1;  // Start from round 1 for packing
                end
            end

            ///////////////////////////////////////////////////////////
            // PHASE 2: Pack round keys into KEY_out
            // Do it one round pair at a time to avoid race conditions!
            ///////////////////////////////////////////////////////////
            2: begin
                // Pack rounds in pairs: (K1,K2), (K3,K4), (K5,K6), ...
                if (i < Nr) begin
                    // Pack two consecutive rounds into one 256-bit slot
                    if (i + 1 < Nr) begin
                        KEY_out[256*((Nr-i-1)/2) +: 256] <= {
                            W[4*i],   W[4*i+1],   W[4*i+2],   W[4*i+3],
                            W[4*(i+1)], W[4*(i+1)+1], W[4*(i+1)+2], W[4*(i+1)+3]
                        };
                    end
                    i <= i + 2;  // Process pairs
                end
                else begin
                    // Phase 2 complete
                    phase <= 3;
                    done <= 1;
                    key_ready <= 1;
                end
            end

            ///////////////////////////////////////////////////////////
            // PHASE 3: Done - hold state
            ///////////////////////////////////////////////////////////
            3: begin
                // Maintain state, wait for next key input
                key_ready <= 1;
            end

        endcase
    end
end

endmodule

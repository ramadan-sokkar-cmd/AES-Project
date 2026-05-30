module aes_finalstagee (data_in,data_out,key_in,clk,rst_n);

input  wire [127:0]data_in;
input  wire [255:0]key_in;
input  wire clk,rst_n;

output reg  [127:0]data_out;

parameter USE_gf=1;

wire [127:0] r1_out,r2_out;

aes_round #(.USE_gf(USE_gf)) round1(.data_in(data_in),.data_out(r1_out),.round_key(key_in[255:128]));
aes_finalround #(.USE_gf(USE_gf)) round2(.data_in(r1_out),.data_out(r2_out),.round_key(key_in[127:0]));
    

always @(posedge clk or negedge rst_n) begin
if (!rst_n) data_out<=0;
else data_out<=r2_out;
    
end

endmodule
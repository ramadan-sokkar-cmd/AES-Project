module aes_round (data_in,data_out,round_key);
input [127:0] data_in,round_key ;
output wire [127:0] data_out;

parameter USE_gf=1;

wire [127:0] sub_out,shift_out,mix_out,add_out;

     sub_bytes #(.USE_gf(USE_gf)) sub(.data_in(data_in), .data_out(sub_out));
     shift_rows     shift(.state_in(sub_out),.state_out(shift_out));
     MixColumns     mix(.stateIn(shift_out), .stateOut(mix_out));
     addRoundKey    add(.data(mix_out), .out(add_out), .key(round_key));

     assign data_out=add_out;


endmodule
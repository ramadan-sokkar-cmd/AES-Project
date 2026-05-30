module aes_top(data_in,data_out,key_in,valid_in,valid_out,clk,rst_n);
input [127:0] data_in,key_in;
input clk,rst_n,valid_in;
// output reg [127:0] data_out;
output wire [127:0] data_out;//new
output wire valid_out;
// output wire key_ready;//new


wire [127:0] add_out,module1_out,module2_out,module3_out,module4_out,module5_out;
wire [1279:0] key_expanded;
wire [255:0] K1_K2 ;
wire [255:0] K3_K4 ;
wire [255:0] K5_K6 ;
wire [255:0] K7_K8 ;
wire [255:0] K9_K10;
assign K1_K2  = key_expanded[1279:1024];
assign K3_K4  = key_expanded[1023:768];
assign K5_K6  = key_expanded[767:512];
assign K7_K8  = key_expanded[511:256];
assign K9_K10 = key_expanded[255:0];
reg [4:0]   valid_pipe;
wire key_ready;
// reg valid_out_reg;//new




addRoundKey add(.data(data_in), .out(add_out), .key(key_in));

aes_stage #(.USE_gf(0)) module_1(.data_in(add_out),.data_out(module1_out),.key_in(K1_K2),.clk(clk),.rst_n(rst_n));
aes_stage #(.USE_gf(0)) module_2(.data_in(module1_out),.data_out(module2_out),.key_in(K3_K4),.clk(clk),.rst_n(rst_n));
aes_stage #(.USE_gf(0)) module_3(.data_in(module2_out),.data_out(module3_out),.key_in(K5_K6),.clk(clk),.rst_n(rst_n));
aes_stage #(.USE_gf(0)) module_4(.data_in(module3_out),.data_out(module4_out),.key_in(K7_K8),.clk(clk),.rst_n(rst_n));

aes_finalstagee #(.USE_gf(0)) module5 (.data_in(module4_out),.data_out(module5_out),.key_in(K9_K10),.clk(clk),.rst_n(rst_n));

u_keyExpansion_seq2 #(
    .Nk(4),   // AES-128 → 4 words key
    .Nb(4)
) key_exp (
    .clk(clk),
    .KEY_in(key_in),
    .KEY_out(key_expanded),
    .rst_n(rst_n),
    .key_ready(key_ready)
);


// always @(posedge clk or negedge rst_n) begin
//   if (!rst_n)begin
//       valid_out_reg<=0;//new
 
//   end else if (valid_in) 
//     valid_out_reg<=0;
//      else if (valid_pipe[4])
//         valid_out_reg <= 1;
//   end

  always @(posedge clk or negedge rst_n) begin
  if (!rst_n)begin
    //   data_out<=0;
      valid_pipe<=0;
  end

   else begin
    // data_out<=module5_out;

valid_pipe <= {valid_pipe[3:0], (valid_in & key_ready)};

end
  end
    
    

    
assign valid_out = valid_pipe[4];
// assign valid_out = valid_out_reg;//new
assign data_out  = module5_out;//new
endmodule
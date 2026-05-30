module aes_round_tb();
reg [127:0] data_in,round_key;
wire [127:0] data_out;
reg [127:0] expected;



    aes_round tb (.data_in(data_in),.data_out(data_out),.round_key(round_key));

initial begin   

        data_in=128'h193de3bea0f4e22ba9cb8d2ae9f84808;
      round_key=128'ha0fafe1788542cb123a339392a6c7605;
        expected=128'ha49c7ff2689f352b6b5bea43026a5049;

            if (data_out!=expected) begin
                $display("errorrrrrr____data_o=%h,expected=%h",data_out,expected);
                $display("SubBytes   = %h", tb.sub_out);
$display("ShiftRows  = %h", tb.shift_out);
$display("MixColumns = %h", tb.mix_out);
$display("AddRoundKey= %h", tb.add_out);
                $stop;
            end  else begin
        $display("TEST PASSED");
    end




end


endmodule
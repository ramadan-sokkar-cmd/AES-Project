module aes_finalround_tb();
reg [127:0] data_in,round_key;
wire [127:0] data_out;
reg [127:0] expected;



    aes_finalround tb (.data_in(data_in),.data_out(data_out),.round_key(round_key));

initial begin   

        data_in=128'heb40f21e592e38848ba113e71bc342d2;
      round_key=128'hd014f9a8c9ee2589e13f0cc8b6630ca6;
        expected=128'h3925842d02dc09fbdc118597196a0b32;

            if (data_out!=expected) begin
                $display("errorrrrrr____data_o=%h,expected=%h",data_out,expected);
                $display("SubBytes   = %h", tb.sub_out);
                $display("ShiftRows  = %h", tb.shift_out);
                $display("AddRoundKey= %h", tb.add_out);
                $stop;
            end  else begin
                $display("TEST PASSED");
            end




end


endmodule
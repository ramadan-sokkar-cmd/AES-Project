module aes_stage_tb();
reg [127:0] data_in;
reg [255:0] key_in;
wire [127:0] data_out;
reg clk,rst_n;
reg [127:0] expected;



initial begin
    clk = 0;
forever #1 clk=~clk;
end
    aes_stage tb (.data_in(data_in),.data_out(data_out),.clk(clk),.rst_n(rst_n),.key_in(key_in));

initial begin   
    data_in=128'h1234567890;
    key_in=256'h123456789;
    rst_n=0;
    repeat(10) @(negedge clk);

    if (data_out!=0) begin
        $display("errorrr____");
        $stop;
    end
    else $display("rst done");


        rst_n=1;
        data_in=128'h40BFABF406EE4D3042CA6B997A5C5816;
        key_in = 256'hA0FAFE1788542CB123A339392A6C7605F2C295F27A96B9435935807A7359F67F;
        expected=128'hFDF37CDB4B0C8C1BF7FCD8E94AA9BBF8;

            repeat(10) @(negedge clk);
            if (data_out!=expected) begin
                $display("errorrrrrr____data_o=%h,expected=%h",data_out,expected);
                $display("r1_out   = %h", tb.r1_out);
                $display("r2_out  = %h", tb.r2_out);
                $stop;
            end  else begin
        $display("TEST PASSED");
    end




end


endmodule
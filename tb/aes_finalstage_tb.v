module aes_afinalstagee_tb();
reg [127:0] data_in;
reg [255:0] key_in;
wire [127:0] data_out;
reg clk,rst_n;
reg [127:0] expected;

 aes_finalstagee dut(.data_in(data_in),.data_out(data_out),.clk(clk),.rst_n(rst_n),.key_in(key_in));


initial
 begin
    clk = 0;
forever #1 clk=~clk;
end


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
        data_in=128'h41D7C6537D669140DD2F179D02ACC51B;
       key_in = 256'hAC7766F319FADC2128D12941575C006ED014F9A8C9EE2589E13F0CC8B6630CA6;
       expected=128'h3AD77BB40D7A3660A89ECAF32466EF97;

            repeat(10) @(negedge clk);
            if (data_out!=expected) begin
                $display("errorrrrrr____data_o=%h,expected=%h",data_out,expected);
                $display("r1_out   = %h", dut.r1_out);
                $display("r2_out  = %h", dut.r2_out);
                $stop;
            end  else begin
        $display("TEST PASSED");
    end




end


endmodule
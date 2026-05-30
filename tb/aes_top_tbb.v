module aes_topp_tb();
reg [127:0] data_in,key_in;
reg clk,rst_n,valid_in;
wire  [127:0] data_out;
wire valid_out;
reg [127:0] expected;
initial begin
    clk = 0;
forever #1 clk=~clk;
end

aes_top dut(.data_in(data_in),.data_out(data_out),.key_in(key_in),.valid_in(valid_in),.valid_out(valid_out),.clk(clk),.rst_n(rst_n));
initial begin
    rst_n=0;
    valid_in = 0;

    data_in=128'h6BC1BEE22E409F96E93D7E117393172A;
    key_in=128'h2B7E151628AED2A6ABF7158809CF4F3C;
    expected=128'h3AD77BB40D7A3660A89ECAF32466EF97;

    repeat(5) @(negedge clk);

    if (data_out!=0) begin
        $display("errorrr____");
        $stop;
    end
    else $display("rst done");
    rst_n=1;
    valid_in=1;

    data_in=128'h6BC1BEE22E409F96E93D7E117393172A;
    key_in=128'h2B7E151628AED2A6ABF7158809CF4F3C;
    expected=128'h3AD77BB40D7A3660A89ECAF32466EF97;
    
        wait(dut.key_ready);
     repeat (2) @(negedge clk);

// valid_in=1;
valid_in=0;//new

           

    @(posedge valid_out);//new
if (data_out !== expected) begin

    $display("\n================ AES TEST FAILED ================");

    $display("Input        = %h", data_in);
    $display("Key          = %h", key_in);

    $display("-----------------------------------------------");

    $display("Expected Out = %h", expected);
    $display("Actual Out   = %h", data_out);

    $display("-----------------------------------------------");

    $display("AddRoundKey  = %h", dut.add_out);

    $display("Stage1_out   = %h", dut.module1_out);
    $display("Stage2_out   = %h", dut.module2_out);
    $display("Stage3_out   = %h", dut.module3_out);
    $display("Stage4_out   = %h", dut.module4_out);

    $display("FinalStage   = %h", dut.module5_out);

    $display("-----------------------------------------------");

    $display("Key Ready    = %b", dut.key_ready);
    $display("Valid Pipe   = %b", dut.valid_pipe);

    $display("================================================\n");

    $stop;

end else begin
    $display("\n================ TEST PASSED ===================");
    $display("Ciphertext = %h,expected= %h", data_out,expected);
    $display("================================================\n");

end
            repeat(6) @(negedge clk);


    data_in=128'hAE2D8A571E03AC9C9EB76FAC45AF8E51;
    key_in=256'h2b7E151628AED2A6ABF7158809CF4F3C;
    expected=128'hF5D3D58503B9699DE785895A96FDBAAF;
        // wait(dut.key_ready);

    valid_in=1;
     repeat (2) @(negedge clk);
valid_in=0;//new

            repeat(6) @(negedge clk);

if (data_out !== expected) begin

    $display("\n================ AES TEST_2 FAILED ================");

    $display("Input        = %h", data_in);
    $display("Key          = %h", key_in);

    $display("-----------------------------------------------");

    $display("Expected Out = %h", expected);
    $display("Actual Out   = %h", data_out);

    $display("-----------------------------------------------");

    $display("AddRoundKey  = %h", dut.add_out);

    $display("Stage1_out   = %h", dut.module1_out);
    $display("Stage2_out   = %h", dut.module2_out);
    $display("Stage3_out   = %h", dut.module3_out);
    $display("Stage4_out   = %h", dut.module4_out);

    $display("FinalStage   = %h", dut.module5_out);

    $display("-----------------------------------------------");

    $display("Key Ready    = %b", dut.key_ready);
    $display("Valid Pipe   = %b", dut.valid_pipe);

    $display("================================================\n");

    $stop;

end else begin
    $display("\n================ TES_2 PASSED ===================");
    $display("Ciphertext = %h", data_out);
    $display("================================================\n");

end
            repeat(6) @(negedge clk);
         
    rst_n = 0;
    valid_in = 0;
    
    
    key_in   = 128'h000102030405060708090a0b0c0d0e0f; 
    data_in  = 128'h00112233445566778899aabbccddeeff;
    expected = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
    
   
    repeat(5) @(negedge clk);
    
    
    rst_n = 1;
    
   
    wait(dut.key_ready);
    repeat(2) @(negedge clk); 
    
   
    valid_in = 1;
        repeat(2) @(negedge clk); 
            valid_in = 0;
    @(posedge valid_out);//new

    if (data_out !== expected) begin

    $display("\n================ AES TEST_3 FAILED ================");

    $display("Input        = %h", data_in);
    $display("Key          = %h", key_in);

    $display("-----------------------------------------------");

    $display("Expected Out = %h", expected);
    $display("Actual Out   = %h", data_out);

    $display("-----------------------------------------------");

    $display("AddRoundKey  = %h", dut.add_out);

    $display("Stage1_out   = %h", dut.module1_out);
    $display("Stage2_out   = %h", dut.module2_out);
    $display("Stage3_out   = %h", dut.module3_out);
    $display("Stage4_out   = %h", dut.module4_out);

    $display("FinalStage   = %h", dut.module5_out);

    $display("-----------------------------------------------");

    $display("Key Ready    = %b", dut.key_ready);
    $display("Valid Pipe   = %b", dut.valid_pipe);

    $display("================================================\n");

    $stop;

end else begin
    $display("\n================ TES_3 PASSED ===================");
    $display("Ciphertext = %h", data_out);
    $display("================================================\n");

end

    
            
    $stop;




end
endmodule
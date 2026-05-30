module u_tb_keyexpansion_seq();
reg clk;
initial begin
 clk = 0;
forever #1 clk=~clk;
   
end

//////////////////////////////////////////////////
// AES-128
//////////////////////////////////////////////////
reg  [127:0] key128;
wire [1280-1:0] out128;
reg  [1280-1:0] golden128;
reg rst_n;
wire key_ready_128;
wire key_ready_192;
wire key_ready_256key_ready_256;
u_keyExpansion_seq2 #(.Nk(4)) dut128 (
    .clk(clk),
    .KEY_in(key128),
    .KEY_out(out128),
    .rst_n(rst_n),
    .key_ready(key_ready_128)

);

//////////////////////////////////////////////////
// AES-192
//////////////////////////////////////////////////
reg  [191:0] key192;
wire [1536-1:0] out192;
reg  [1536-1:0] golden192;

u_keyExpansion_seq2 #(.Nk(6)) dut192 (
    .clk(clk),
    .KEY_in(key192),
    .KEY_out(out192),
        .rst_n(rst_n),
            .key_ready( key_ready_192)


);

//////////////////////////////////////////////////
// AES-256
//////////////////////////////////////////////////
reg  [255:0] key256;
wire [1792-1:0] out256;
reg  [1792-1:0] golden256;

u_keyExpansion_seq2 #(.Nk(8)) dut256 (
    .clk(clk),
    .KEY_in(key256),
    .KEY_out(out256),
        .rst_n(rst_n),
            .key_ready(key_ready_256)


);

//////////////////////////////////////////////////
// TEST
//////////////////////////////////////////////////
initial begin
    key128 = 128'h2b7e151628aed2a6abf7158809cf4f3c;
golden128=1280'ha0fafe1788542cb123a339392a6c7605f2c295f27a96b9435935807a7359f67f3d80477d4716fe3e1e237e446d7a883bef44a541a8525b7fb671253bdb0bad00d4d1c6f87c839d87caf2b8bc11f915bc6d88a37a110b3efddbf98641ca0093fd4e54f70e5f5fc9f384a64fb24ea6dc4fead27321b58dbad2312bf5607f8d292fac7766f319fadc2128d12941575c006ed014f9a8c9ee2589e13f0cc8b6630ca6;

// golden128=1280'hac7766f319fadc2128d12941575c006ed014f9a8c9ee2589e13f0cc8b6630ca64e54f70e5f5fc9f384a64fb24ea6dc4fead27321b58dbad2312bf5607f8d292fd4d1c6f87c839d87caf2b8bc11f915bc6d88a37a110b3efddbf98641ca0093fd3d80477d4716fe3e1e237e446d7a883bef44a541a8525b7fb671253bdb0bad00a0fafe1788542cb123a339392a6c7605f2c295f27a96b9435935807a7359f67f;


key192 = 192'h8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b;
// golden192=1536'hfe0c91f72402f5a5ec12068e6c827f6b0e7a95b95c56fec24db7b4bd69b5411885a74796e92538fde75fad44bb095386485af05721efb14fa448f6d94d6dce24aa326360113b30e6a25e7ed583b1cf9a27f939436a94f767c0a69407d19da4e1ec1786eb6fa64971485f703222cb8755e26d135233f0b7b340beeb282f18a2596747d26b458c553ea7e1466c9411f1df821f750aad07d753ca4005388fcc5006282d166abc3ce7b5e016baf4aebf7ad25499b3b1a4a3e2a05e390f7df7a69296;
golden192=1536'h62f8ead2522c6b7bfe0c91f72402f5a5ec12068e6c827f6b0e7a95b95c56fec24db7b4bd69b5411885a74796e92538fde75fad44bb095386485af05721efb14fa448f6d94d6dce24aa326360113b30e6a25e7ed583b1cf9a27f939436a94f767c0a69407d19da4e1ec1786eb6fa64971485f703222cb8755e26d135233f0b7b340beeb282f18a2596747d26b458c553ea7e1466c9411f1df821f750aad07d753ca4005388fcc5006282d166abc3ce7b5e98ba06f448c773c8ecc720401002202;
// golden192 =1536'h016baf4aebf7ad25499b3b1a4a3e2a05e390f7df7a69296ca4005388fcc5006282d166abc3ce7b5e40beeb282f18a2596747d26b458c553ea7e1466c9411f1df821f750aad07d753c0a69407d19da4e1ec1786eb6fa64971485f703222cb8755e26d135233f0b7b3a448f6d94d6dce24aa326360113b30e6a25e7ed583b1cf9a27f939436a94f7674db7b4bd69b5411885a74796e92538fde75fad44bb095386485af05721efb14ffe0c91f72402f5a5ec12068e6c827f6b0e7a95b95c56fec2;


key256 = 256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
golden256 = 1792'hfe4890d1e6188d0b046df344706c631eb5a9328a2678a647983122292f6c79b3812c81addadf48ba24360af2fab8b46498c5bfc9bebd19ef268c3bc609e0427568007bacb2df331696e939e46c518d80c814e20476a9fbe8d025a9a0bba1d2f7749c47ab18501ddae2757e4f7401905acafaaae3e4d59b349adf6acebd10190d6de1f1486fa54f9275f8eb5373b8518dc656827fc9a799176f294cec6cd5598b3de23a75524775e727bf9eb45407cf390bdc905fc27b0948ad5245a4c1871c2f45f5a66017b2d387300d4d33640a820a7ccff71cbeb4fe5413e6bbf0d261a6df;
@(negedge  clk);


    rst_n=0;
    @(negedge  clk);
    if (out128 === 0)
    $display("AES-128 rest PASS");
else begin
    

    $display("AES-128 rest ERROR,out128=%h,golden=%h",out128,golden128);
    $stop;
end

if (out192 === 0)
    $display("AES-192 rest PASS");
else begin
    
    $display("AES-192crest ERROR,out192=%h,golden=%h",out192,golden192);
        $stop;
end

if (out256 === 0)
    $display("AES-256 rest PASS");
else begin
    

    $display("AES-256 rest ERROR,out256=%h,golden=%h",out256,golden256);
        $stop;
end

rst_n=1;
 @(negedge  clk);




//////////////////////////////////////////////////
// Test vectors (standard NIST)
//////////////////////////////////////////////////

key128 = 128'h2b7e151628aed2a6abf7158809cf4f3c;
golden128=1280'ha0fafe1788542cb123a339392a6c7605f2c295f27a96b9435935807a7359f67f3d80477d4716fe3e1e237e446d7a883bef44a541a8525b7fb671253bdb0bad00d4d1c6f87c839d87caf2b8bc11f915bc6d88a37a110b3efddbf98641ca0093fd4e54f70e5f5fc9f384a64fb24ea6dc4fead27321b58dbad2312bf5607f8d292fac7766f319fadc2128d12941575c006ed014f9a8c9ee2589e13f0cc8b6630ca6;
// golden128=1280'hac7766f319fadc2128d12941575c006ed014f9a8c9ee2589e13f0cc8b6630ca64e54f70e5f5fc9f384a64fb24ea6dc4fead27321b58dbad2312bf5607f8d292fd4d1c6f87c839d87caf2b8bc11f915bc6d88a37a110b3efddbf98641ca0093fd3d80477d4716fe3e1e237e446d7a883bef44a541a8525b7fb671253bdb0bad00a0fafe1788542cb123a339392a6c7605f2c295f27a96b9435935807a7359f67f;


key192 = 192'h8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b;
golden192=1536'hfe0c91f72402f5a5ec12068e6c827f6b0e7a95b95c56fec24db7b4bd69b5411885a74796e92538fde75fad44bb095386485af05721efb14fa448f6d94d6dce24aa326360113b30e6a25e7ed583b1cf9a27f939436a94f767c0a69407d19da4e1ec1786eb6fa64971485f703222cb8755e26d135233f0b7b340beeb282f18a2596747d26b458c553ea7e1466c9411f1df821f750aad07d753ca4005388fcc5006282d166abc3ce7b5e016baf4aebf7ad25499b3b1a4a3e2a05e390f7df7a69296;
golden192=1536'h62f8ead2522c6b7bfe0c91f72402f5a5ec12068e6c827f6b0e7a95b95c56fec24db7b4bd69b5411885a74796e92538fde75fad44bb095386485af05721efb14fa448f6d94d6dce24aa326360113b30e6a25e7ed583b1cf9a27f939436a94f767c0a69407d19da4e1ec1786eb6fa64971485f703222cb8755e26d135233f0b7b340beeb282f18a2596747d26b458c553ea7e1466c9411f1df821f750aad07d753ca4005388fcc5006282d166abc3ce7b5e98ba06f448c773c8ecc720401002202;

// golden192 =1536'h016baf4aebf7ad25499b3b1a4a3e2a05e390f7df7a69296ca4005388fcc5006282d166abc3ce7b5e40beeb282f18a2596747d26b458c553ea7e1466c9411f1df821f750aad07d753c0a69407d19da4e1ec1786eb6fa64971485f703222cb8755e26d135233f0b7b3a448f6d94d6dce24aa326360113b30e6a25e7ed583b1cf9a27f939436a94f7674db7b4bd69b5411885a74796e92538fde75fad44bb095386485af05721efb14ffe0c91f72402f5a5ec12068e6c827f6b0e7a95b95c56fec2;


key256 = 256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
golden256 = 1792'hfe4890d1e6188d0b046df344706c631eb5a9328a2678a647983122292f6c79b3812c81addadf48ba24360af2fab8b46498c5bfc9bebd19ef268c3bc609e0427568007bacb2df331696e939e46c518d80c814e20476a9fbe8d025a9a0bba1d2f7749c47ab18501ddae2757e4f7401905acafaaae3e4d59b349adf6acebd10190d6de1f1486fa54f9275f8eb5373b8518dc656827fc9a799176f294cec6cd5598b3de23a75524775e727bf9eb45407cf390bdc905fc27b0948ad5245a4c1871c2f45f5a66017b2d387300d4d33640a820a7ccff71cbeb4fe5413e6bbf0d261a6df;

wait(key_ready_128 && key_ready_192 && key_ready_256);
@(negedge clk);
if (out128 === golden128)
    $display("AES-128 PASS");
else begin
    

    $display("AES-128 ERROR,out128=%h,golden=%h",out128,golden128);
    $stop;
end

if (out192 === golden192)
    $display("AES-192 PASS");
else begin
    
    $display("AES-192 ERROR,out192=%h,golden=%h",out192,golden192);
        $stop;
end

if (out256 === golden256)
    $display("AES-256 PASS");
else begin
    

    $display("AES-256 ERROR,out256=%h,golden=%h",out256,golden256);
        $stop;
end

        $stop;

end

endmodule

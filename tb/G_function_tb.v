module tb_g_function();

  // DUT inputs/outputs
  reg  [31:0] word_in;   // 4 bytes input word
  wire [31:0] word_out;       // output word

  // Instantiate DUT (choose GF or assign S-Box)
  g_function #(1) uut (       // use_gf=1 → GF arithmetic S-Box // use_assign=0 → 256 Byte ROM
    .word_in(word_in),
    .word_out(word_out)
  );

  // Expected output
  reg [31:0] expected;

  integer i;

  initial begin
    $display("Starting g_function test...");

    // Test vector 1
word_in[31:24] = 8'ha0;
    word_in[23:16] = 8'hfa;
    word_in[15:8] = 8'hfe;
    word_in[7:0] = 8'h17;
    expected   = 32'h2dbbf0e0; // SubWord(RotWord(w[3]))
    #5;
    if (word_out !== expected) begin
      $display("ERROR: input=%h %h %h %h, expected=%h, got=%h",
               word_in[31:24], word_in[23:16], word_in[15:8], word_in[7:0], expected, word_out);
    end else begin
      $display("PASS: input=%h %h %h %h, expected=%h, output=%h, ",
               word_in[31:24], word_in[23:16], word_in[15:8], word_in[7:0],expected, word_out);
    end

    // Test vector 2
    word_in[31:24] = 8'h00;
    word_in[23:16] = 8'h11;
    word_in[15:8] = 8'h22;
    word_in[7:0] = 8'h33;
    expected   = 32'h8293c363;
    #5;
    if (word_out !== expected) begin
      $display("ERROR: input=%h %h %h %h, expected=%h, got=%h",
               word_in[31:24], word_in[23:16], word_in[15:8], word_in[7:0], expected, word_out);
    end else begin
      
      $display("PASS: input=%h %h %h %h, expected=%h, output=%h",
               word_in[31:24], word_in[23:16], word_in[15:8], word_in[7:0],expected, word_out);
    end
    // Test vector 3
    word_in[31:24] = 8'hde;
    word_in[23:16] = 8'had;
    word_in[15:8] = 8'hbe;
    word_in[7:0] = 8'hef;
    expected   = 32'h95aedf1d;
    #5;
    if (word_out !== expected)begin
      $display("ERROR: input=%h %h %h %h, expected=%h, got=%h",
               word_in[31:24], word_in[23:16], word_in[15:8], word_in[7:0], expected, word_out);
               $stop;
    end else begin
      
      $display("PASS: input=%h %h %h %h, expected=%h, output=%h",
               word_in[31:24], word_in[23:16], word_in[15:8], word_in[7:0],expected, word_out);

    $display("g_function test finished.");
    $stop;
    end 
end

endmodule
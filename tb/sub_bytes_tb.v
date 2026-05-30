module tb_sub_bytes();

reg  [127:0] data_in;
wire [127:0] data_out;

// instantiate DUT
sub_bytes #(.USE_gf(1)) dut (
    .data_in(data_in),
    .data_out(data_out)
);

// expected output
reg [127:0] expected;

initial begin

    // test vector
    data_in  = 128'hcf4f3c096c76052a59f67f737a883b6d;
    expected = 128'h8a84eb0150386be5cb42d28fdac4e23c;

    #10;

    if (data_out === expected)
        $display("PASS");
    else begin
        $display("ERROR");
        $display("input    = %h", data_in);
        $display("output   = %h", data_out);
        $display("expected = %h", expected);
        $stop;
    end

    #10;
end

endmodule

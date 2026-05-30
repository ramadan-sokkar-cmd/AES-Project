module MixColumns_DUT();
	reg [127:0] stateIn;
	wire [127:0] stateOut;

	MixColumns mc(stateIn, stateOut);

	initial begin
		stateIn = 128'h6353e08c0960e104cd70b751bacad0e7;
		#10
		stateIn = 128'h84e1dd691a41d76f792d389783fbac70;
		#10
		stateIn = 128'h1fb5430ef0accf64aa370cde3d77792c;
	end

	initial begin
		$display("MixColumns_DUT");
        $display("==================================");
		$monitor("Expected: 5f72641557f5bc92f7be3b291db9f91a, Actual: %h\n",stateOut);
		#10
		$monitor("Expected: 9f487f794f955f662afc86abd7f1ab29, Actual: %h\n",stateOut);
		#10
		$monitor("Expected: b7a53ecbbf9d75a0c40efc79b674cc11, Actual: %h\n",stateOut);
	end
endmodule
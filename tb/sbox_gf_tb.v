module tb_sbox_gf();

  // DUT inputs/outputs
  reg [7:0] data_i;       // input byte
  wire [7:0] data_o;       // output byte
//   wire [7:0] data_i_fix = {
//   data_i[0], data_i[1], data_i[2], data_i[3],
//   data_i[4], data_i[5], data_i[6], data_i[7]
// };
// wire [7:0] data_o_fix = {
//   data_o[0],
//   data_o[1],
//   data_o[2],
//   data_o[3],
//   data_o[4],
//   data_o[5],
//   data_o[6],
//   data_o[7]
// };




  // Expected output (for checking)
  reg [7:0] expected;

  // Instantiate DUT (choose which one to test)

   sbox_gf uut (.data_i(data_i), .data_o(data_o));

  // Test procedure
      integer i;

  initial begin
    $display("Starting S-Box test...");

    // Loop through all possible input values (0x00 to 0xFF)
    for (i = 0; i < 256; i = i + 1) begin
      data_i = i[7:0];   // apply input

      #5;

      // Expected value (lookup table for AES S-Box)
      case (data_i)
       8'h00: expected=8'h63;
	   8'h01: expected=8'h7c;
	   8'h02: expected=8'h77;
	   8'h03: expected=8'h7b;
	   8'h04: expected=8'hf2;
	   8'h05: expected=8'h6b;
	   8'h06: expected=8'h6f;
	   8'h07: expected=8'hc5;
	   8'h08: expected=8'h30;
	   8'h09: expected=8'h01;
	   8'h0a: expected=8'h67;
	   8'h0b: expected=8'h2b;
	   8'h0c: expected=8'hfe;
	   8'h0d: expected=8'hd7;
	   8'h0e: expected=8'hab;
	   8'h0f: expected=8'h76;
	   8'h10: expected=8'hca;
	   8'h11: expected=8'h82;
	   8'h12: expected=8'hc9;
	   8'h13: expected=8'h7d;
	   8'h14: expected=8'hfa;
	   8'h15: expected=8'h59;
	   8'h16: expected=8'h47;
	   8'h17: expected=8'hf0;
	   8'h18: expected=8'had;
	   8'h19: expected=8'hd4;
	   8'h1a: expected=8'ha2;
	   8'h1b: expected=8'haf;
	   8'h1c: expected=8'h9c;
	   8'h1d: expected=8'ha4;
	   8'h1e: expected=8'h72;
	   8'h1f: expected=8'hc0;
	   8'h20: expected=8'hb7;
	   8'h21: expected=8'hfd;
	   8'h22: expected=8'h93;
	   8'h23: expected=8'h26;
	   8'h24: expected=8'h36;
	   8'h25: expected=8'h3f;
	   8'h26: expected=8'hf7;
	   8'h27: expected=8'hcc;
	   8'h28: expected=8'h34;
	   8'h29: expected=8'ha5;
	   8'h2a: expected=8'he5;
	   8'h2b: expected=8'hf1;
	   8'h2c: expected=8'h71;
	   8'h2d: expected=8'hd8;
	   8'h2e: expected=8'h31;
	   8'h2f: expected=8'h15;
	   8'h30: expected=8'h04;
	   8'h31: expected=8'hc7;
	   8'h32: expected=8'h23;
	   8'h33: expected=8'hc3;
	   8'h34: expected=8'h18;
	   8'h35: expected=8'h96;
	   8'h36: expected=8'h05;
	   8'h37: expected=8'h9a;
	   8'h38: expected=8'h07;
	   8'h39: expected=8'h12;
	   8'h3a: expected=8'h80;
	   8'h3b: expected=8'he2;
	   8'h3c: expected=8'heb;
	   8'h3d: expected=8'h27;
	   8'h3e: expected=8'hb2;
	   8'h3f: expected=8'h75;
	   8'h40: expected=8'h09;
	   8'h41: expected=8'h83;
	   8'h42: expected=8'h2c;
	   8'h43: expected=8'h1a;
	   8'h44: expected=8'h1b;
	   8'h45: expected=8'h6e;
	   8'h46: expected=8'h5a;
	   8'h47: expected=8'ha0;
	   8'h48: expected=8'h52;
	   8'h49: expected=8'h3b;
	   8'h4a: expected=8'hd6;
	   8'h4b: expected=8'hb3;
	   8'h4c: expected=8'h29;
	   8'h4d: expected=8'he3;
	   8'h4e: expected=8'h2f;
	   8'h4f: expected=8'h84;
	   8'h50: expected=8'h53;
	   8'h51: expected=8'hd1;
	   8'h52: expected=8'h00;
	   8'h53: expected=8'hed;
	   8'h54: expected=8'h20;
	   8'h55: expected=8'hfc;
	   8'h56: expected=8'hb1;
	   8'h57: expected=8'h5b;
	   8'h58: expected=8'h6a;
	   8'h59: expected=8'hcb;
	   8'h5a: expected=8'hbe;
	   8'h5b: expected=8'h39;
	   8'h5c: expected=8'h4a;
	   8'h5d: expected=8'h4c;
	   8'h5e: expected=8'h58;
	   8'h5f: expected=8'hcf;
	   8'h60: expected=8'hd0;
	   8'h61: expected=8'hef;
	   8'h62: expected=8'haa;
	   8'h63: expected=8'hfb;
	   8'h64: expected=8'h43;
	   8'h65: expected=8'h4d;
	   8'h66: expected=8'h33;
	   8'h67: expected=8'h85;
	   8'h68: expected=8'h45;
	   8'h69: expected=8'hf9;
	   8'h6a: expected=8'h02;
	   8'h6b: expected=8'h7f;
	   8'h6c: expected=8'h50;
	   8'h6d: expected=8'h3c;
	   8'h6e: expected=8'h9f;
	   8'h6f: expected=8'ha8;
	   8'h70: expected=8'h51;
	   8'h71: expected=8'ha3;
	   8'h72: expected=8'h40;
	   8'h73: expected=8'h8f;
	   8'h74: expected=8'h92;
	   8'h75: expected=8'h9d;
	   8'h76: expected=8'h38;
	   8'h77: expected=8'hf5;
	   8'h78: expected=8'hbc;
	   8'h79: expected=8'hb6;
	   8'h7a: expected=8'hda;
	   8'h7b: expected=8'h21;
	   8'h7c: expected=8'h10;
	   8'h7d: expected=8'hff;
	   8'h7e: expected=8'hf3;
	   8'h7f: expected=8'hd2;
	   8'h80: expected=8'hcd;
	   8'h81: expected=8'h0c;
	   8'h82: expected=8'h13;
	   8'h83: expected=8'hec;
	   8'h84: expected=8'h5f;
	   8'h85: expected=8'h97;
	   8'h86: expected=8'h44;
	   8'h87: expected=8'h17;
	   8'h88: expected=8'hc4;
	   8'h89: expected=8'ha7;
	   8'h8a: expected=8'h7e;
	   8'h8b: expected=8'h3d;
	   8'h8c: expected=8'h64;
	   8'h8d: expected=8'h5d;
	   8'h8e: expected=8'h19;
	   8'h8f: expected=8'h73;
	   8'h90: expected=8'h60;
	   8'h91: expected=8'h81;
	   8'h92: expected=8'h4f;
	   8'h93: expected=8'hdc;
	   8'h94: expected=8'h22;
	   8'h95: expected=8'h2a;
	   8'h96: expected=8'h90;
	   8'h97: expected=8'h88;
	   8'h98: expected=8'h46;
	   8'h99: expected=8'hee;
	   8'h9a: expected=8'hb8;
	   8'h9b: expected=8'h14;
	   8'h9c: expected=8'hde;
	   8'h9d: expected=8'h5e;
	   8'h9e: expected=8'h0b;
	   8'h9f: expected=8'hdb;
	   8'ha0: expected=8'he0;
	   8'ha1: expected=8'h32;
	   8'ha2: expected=8'h3a;
	   8'ha3: expected=8'h0a;
	   8'ha4: expected=8'h49;
	   8'ha5: expected=8'h06;
	   8'ha6: expected=8'h24;
	   8'ha7: expected=8'h5c;
	   8'ha8: expected=8'hc2;
	   8'ha9: expected=8'hd3;
	   8'haa: expected=8'hac;
	   8'hab: expected=8'h62;
	   8'hac: expected=8'h91;
	   8'had: expected=8'h95;
	   8'hae: expected=8'he4;
	   8'haf: expected=8'h79;
	   8'hb0: expected=8'he7;
	   8'hb1: expected=8'hc8;
	   8'hb2: expected=8'h37;
	   8'hb3: expected=8'h6d;
	   8'hb4: expected=8'h8d;
	   8'hb5: expected=8'hd5;
	   8'hb6: expected=8'h4e;
	   8'hb7: expected=8'ha9;
	   8'hb8: expected=8'h6c;
	   8'hb9: expected=8'h56;
	   8'hba: expected=8'hf4;
	   8'hbb: expected=8'hea;
	   8'hbc: expected=8'h65;
	   8'hbd: expected=8'h7a;
	   8'hbe: expected=8'hae;
	   8'hbf: expected=8'h08;
	   8'hc0: expected=8'hba;
	   8'hc1: expected=8'h78;
	   8'hc2: expected=8'h25;
	   8'hc3: expected=8'h2e;
	   8'hc4: expected=8'h1c;
	   8'hc5: expected=8'ha6;
	   8'hc6: expected=8'hb4;
	   8'hc7: expected=8'hc6;
	   8'hc8: expected=8'he8;
	   8'hc9: expected=8'hdd;
	   8'hca: expected=8'h74;
	   8'hcb: expected=8'h1f;
	   8'hcc: expected=8'h4b;
	   8'hcd: expected=8'hbd;
	   8'hce: expected=8'h8b;
	   8'hcf: expected=8'h8a;
	   8'hd0: expected=8'h70;
	   8'hd1: expected=8'h3e;
	   8'hd2: expected=8'hb5;
	   8'hd3: expected=8'h66;
	   8'hd4: expected=8'h48;
	   8'hd5: expected=8'h03;
	   8'hd6: expected=8'hf6;
	   8'hd7: expected=8'h0e;
	   8'hd8: expected=8'h61;
	   8'hd9: expected=8'h35;
	   8'hda: expected=8'h57;
	   8'hdb: expected=8'hb9;
	   8'hdc: expected=8'h86;
	   8'hdd: expected=8'hc1;
	   8'hde: expected=8'h1d;
	   8'hdf: expected=8'h9e;
	   8'he0: expected=8'he1;
	   8'he1: expected=8'hf8;
	   8'he2: expected=8'h98;
	   8'he3: expected=8'h11;
	   8'he4: expected=8'h69;
	   8'he5: expected=8'hd9;
	   8'he6: expected=8'h8e;
	   8'he7: expected=8'h94;
	   8'he8: expected=8'h9b;
	   8'he9: expected=8'h1e;
	   8'hea: expected=8'h87;
	   8'heb: expected=8'he9;
	   8'hec: expected=8'hce;
	   8'hed: expected=8'h55;
	   8'hee: expected=8'h28;
	   8'hef: expected=8'hdf;
	   8'hf0: expected=8'h8c;
	   8'hf1: expected=8'ha1;
	   8'hf2: expected=8'h89;
	   8'hf3: expected=8'h0d;
	   8'hf4: expected=8'hbf;
	   8'hf5: expected=8'he6;
	   8'hf6: expected=8'h42;
	   8'hf7: expected=8'h68;
	   8'hf8: expected=8'h41;
	   8'hf9: expected=8'h99;
	   8'hfa: expected=8'h2d;
	   8'hfb: expected=8'h0f;
	   8'hfc: expected=8'hb0;
	   8'hfd: expected=8'h54;
	   8'hfe: expected=8'hbb;    
       8'hff: expected=8'h16;
       default: expected = 8'hxx;
      endcase

      // Compare DUT output with expected
      if (data_o !== expected) begin
        $display("ERROR: input=%h, expected=%h, got=%h", data_i, expected, data_o);
        $stop;
      end else begin
        $display("PASS: input=%h, output=%h,expected=%h", data_i, data_o,expected);
      end
    end

    $display("S-Box test finished.");
    $stop;
    // $finish;
  end

endmodule
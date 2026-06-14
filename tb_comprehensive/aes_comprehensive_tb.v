`timescale 1ns/1ps
module aes_comprehensive_tb;

reg clk;
initial begin clk = 0; forever #1 clk = ~clk; end

integer total_tests;
integer pass_count;
integer fail_count;
integer errors_in_section;

reg [7:0] sbox_ref [0:255];
initial begin
    sbox_ref[8'h00]=8'h63; sbox_ref[8'h01]=8'h7c; sbox_ref[8'h02]=8'h77; sbox_ref[8'h03]=8'h7b;
    sbox_ref[8'h04]=8'hf2; sbox_ref[8'h05]=8'h6b; sbox_ref[8'h06]=8'h6f; sbox_ref[8'h07]=8'hc5;
    sbox_ref[8'h08]=8'h30; sbox_ref[8'h09]=8'h01; sbox_ref[8'h0a]=8'h67; sbox_ref[8'h0b]=8'h2b;
    sbox_ref[8'h0c]=8'hfe; sbox_ref[8'h0d]=8'hd7; sbox_ref[8'h0e]=8'hab; sbox_ref[8'h0f]=8'h76;
    sbox_ref[8'h10]=8'hca; sbox_ref[8'h11]=8'h82; sbox_ref[8'h12]=8'hc9; sbox_ref[8'h13]=8'h7d;
    sbox_ref[8'h14]=8'hfa; sbox_ref[8'h15]=8'h59; sbox_ref[8'h16]=8'h47; sbox_ref[8'h17]=8'hf0;
    sbox_ref[8'h18]=8'had; sbox_ref[8'h19]=8'hd4; sbox_ref[8'h1a]=8'ha2; sbox_ref[8'h1b]=8'haf;
    sbox_ref[8'h1c]=8'h9c; sbox_ref[8'h1d]=8'ha4; sbox_ref[8'h1e]=8'h72; sbox_ref[8'h1f]=8'hc0;
    sbox_ref[8'h20]=8'hb7; sbox_ref[8'h21]=8'hfd; sbox_ref[8'h22]=8'h93; sbox_ref[8'h23]=8'h26;
    sbox_ref[8'h24]=8'h36; sbox_ref[8'h25]=8'h3f; sbox_ref[8'h26]=8'hf7; sbox_ref[8'h27]=8'hcc;
    sbox_ref[8'h28]=8'h34; sbox_ref[8'h29]=8'ha5; sbox_ref[8'h2a]=8'he5; sbox_ref[8'h2b]=8'hf1;
    sbox_ref[8'h2c]=8'h71; sbox_ref[8'h2d]=8'hd8; sbox_ref[8'h2e]=8'h31; sbox_ref[8'h2f]=8'h15;
    sbox_ref[8'h30]=8'h04; sbox_ref[8'h31]=8'hc7; sbox_ref[8'h32]=8'h23; sbox_ref[8'h33]=8'hc3;
    sbox_ref[8'h34]=8'h18; sbox_ref[8'h35]=8'h96; sbox_ref[8'h36]=8'h05; sbox_ref[8'h37]=8'h9a;
    sbox_ref[8'h38]=8'h07; sbox_ref[8'h39]=8'h12; sbox_ref[8'h3a]=8'h80; sbox_ref[8'h3b]=8'he2;
    sbox_ref[8'h3c]=8'heb; sbox_ref[8'h3d]=8'h27; sbox_ref[8'h3e]=8'hb2; sbox_ref[8'h3f]=8'h75;
    sbox_ref[8'h40]=8'h09; sbox_ref[8'h41]=8'h83; sbox_ref[8'h42]=8'h2c; sbox_ref[8'h43]=8'h1a;
    sbox_ref[8'h44]=8'h1b; sbox_ref[8'h45]=8'h6e; sbox_ref[8'h46]=8'h5a; sbox_ref[8'h47]=8'ha0;
    sbox_ref[8'h48]=8'h52; sbox_ref[8'h49]=8'h3b; sbox_ref[8'h4a]=8'hd6; sbox_ref[8'h4b]=8'hb3;
    sbox_ref[8'h4c]=8'h29; sbox_ref[8'h4d]=8'he3; sbox_ref[8'h4e]=8'h2f; sbox_ref[8'h4f]=8'h84;
    sbox_ref[8'h50]=8'h53; sbox_ref[8'h51]=8'hd1; sbox_ref[8'h52]=8'h00; sbox_ref[8'h53]=8'hed;
    sbox_ref[8'h54]=8'h20; sbox_ref[8'h55]=8'hfc; sbox_ref[8'h56]=8'hb1; sbox_ref[8'h57]=8'h5b;
    sbox_ref[8'h58]=8'h6a; sbox_ref[8'h59]=8'hcb; sbox_ref[8'h5a]=8'hbe; sbox_ref[8'h5b]=8'h39;
    sbox_ref[8'h5c]=8'h4a; sbox_ref[8'h5d]=8'h4c; sbox_ref[8'h5e]=8'h58; sbox_ref[8'h5f]=8'hcf;
    sbox_ref[8'h60]=8'hd0; sbox_ref[8'h61]=8'hef; sbox_ref[8'h62]=8'haa; sbox_ref[8'h63]=8'hfb;
    sbox_ref[8'h64]=8'h43; sbox_ref[8'h65]=8'h4d; sbox_ref[8'h66]=8'h33; sbox_ref[8'h67]=8'h85;
    sbox_ref[8'h68]=8'h45; sbox_ref[8'h69]=8'hf9; sbox_ref[8'h6a]=8'h02; sbox_ref[8'h6b]=8'h7f;
    sbox_ref[8'h6c]=8'h50; sbox_ref[8'h6d]=8'h3c; sbox_ref[8'h6e]=8'h9f; sbox_ref[8'h6f]=8'ha8;
    sbox_ref[8'h70]=8'h51; sbox_ref[8'h71]=8'ha3; sbox_ref[8'h72]=8'h40; sbox_ref[8'h73]=8'h8f;
    sbox_ref[8'h74]=8'h92; sbox_ref[8'h75]=8'h9d; sbox_ref[8'h76]=8'h38; sbox_ref[8'h77]=8'hf5;
    sbox_ref[8'h78]=8'hbc; sbox_ref[8'h79]=8'hb6; sbox_ref[8'h7a]=8'hda; sbox_ref[8'h7b]=8'h21;
    sbox_ref[8'h7c]=8'h10; sbox_ref[8'h7d]=8'hff; sbox_ref[8'h7e]=8'hf3; sbox_ref[8'h7f]=8'hd2;
    sbox_ref[8'h80]=8'hcd; sbox_ref[8'h81]=8'h0c; sbox_ref[8'h82]=8'h13; sbox_ref[8'h83]=8'hec;
    sbox_ref[8'h84]=8'h5f; sbox_ref[8'h85]=8'h97; sbox_ref[8'h86]=8'h44; sbox_ref[8'h87]=8'h17;
    sbox_ref[8'h88]=8'hc4; sbox_ref[8'h89]=8'ha7; sbox_ref[8'h8a]=8'h7e; sbox_ref[8'h8b]=8'h3d;
    sbox_ref[8'h8c]=8'h64; sbox_ref[8'h8d]=8'h5d; sbox_ref[8'h8e]=8'h19; sbox_ref[8'h8f]=8'h73;
    sbox_ref[8'h90]=8'h60; sbox_ref[8'h91]=8'h81; sbox_ref[8'h92]=8'h4f; sbox_ref[8'h93]=8'hdc;
    sbox_ref[8'h94]=8'h22; sbox_ref[8'h95]=8'h2a; sbox_ref[8'h96]=8'h90; sbox_ref[8'h97]=8'h88;
    sbox_ref[8'h98]=8'h46; sbox_ref[8'h99]=8'hee; sbox_ref[8'h9a]=8'hb8; sbox_ref[8'h9b]=8'h14;
    sbox_ref[8'h9c]=8'hde; sbox_ref[8'h9d]=8'h5e; sbox_ref[8'h9e]=8'h0b; sbox_ref[8'h9f]=8'hdb;
    sbox_ref[8'ha0]=8'he0; sbox_ref[8'ha1]=8'h32; sbox_ref[8'ha2]=8'h3a; sbox_ref[8'ha3]=8'h0a;
    sbox_ref[8'ha4]=8'h49; sbox_ref[8'ha5]=8'h06; sbox_ref[8'ha6]=8'h24; sbox_ref[8'ha7]=8'h5c;
    sbox_ref[8'ha8]=8'hc2; sbox_ref[8'ha9]=8'hd3; sbox_ref[8'haa]=8'hac; sbox_ref[8'hab]=8'h62;
    sbox_ref[8'hac]=8'h91; sbox_ref[8'had]=8'h95; sbox_ref[8'hae]=8'he4; sbox_ref[8'haf]=8'h79;
    sbox_ref[8'hb0]=8'he7; sbox_ref[8'hb1]=8'hc8; sbox_ref[8'hb2]=8'h37; sbox_ref[8'hb3]=8'h6d;
    sbox_ref[8'hb4]=8'h8d; sbox_ref[8'hb5]=8'hd5; sbox_ref[8'hb6]=8'h4e; sbox_ref[8'hb7]=8'ha9;
    sbox_ref[8'hb8]=8'h6c; sbox_ref[8'hb9]=8'h56; sbox_ref[8'hba]=8'hf4; sbox_ref[8'hbb]=8'hea;
    sbox_ref[8'hbc]=8'h65; sbox_ref[8'hbd]=8'h7a; sbox_ref[8'hbe]=8'hae; sbox_ref[8'hbf]=8'h08;
    sbox_ref[8'hc0]=8'hba; sbox_ref[8'hc1]=8'h78; sbox_ref[8'hc2]=8'h25; sbox_ref[8'hc3]=8'h2e;
    sbox_ref[8'hc4]=8'h1c; sbox_ref[8'hc5]=8'ha6; sbox_ref[8'hc6]=8'hb4; sbox_ref[8'hc7]=8'hc6;
    sbox_ref[8'hc8]=8'he8; sbox_ref[8'hc9]=8'hdd; sbox_ref[8'hca]=8'h74; sbox_ref[8'hcb]=8'h1f;
    sbox_ref[8'hcc]=8'h4b; sbox_ref[8'hcd]=8'hbd; sbox_ref[8'hce]=8'h8b; sbox_ref[8'hcf]=8'h8a;
    sbox_ref[8'hd0]=8'h70; sbox_ref[8'hd1]=8'h3e; sbox_ref[8'hd2]=8'hb5; sbox_ref[8'hd3]=8'h66;
    sbox_ref[8'hd4]=8'h48; sbox_ref[8'hd5]=8'h03; sbox_ref[8'hd6]=8'hf6; sbox_ref[8'hd7]=8'h0e;
    sbox_ref[8'hd8]=8'h61; sbox_ref[8'hd9]=8'h35; sbox_ref[8'hda]=8'h57; sbox_ref[8'hdb]=8'hb9;
    sbox_ref[8'hdc]=8'h86; sbox_ref[8'hdd]=8'hc1; sbox_ref[8'hde]=8'h1d; sbox_ref[8'hdf]=8'h9e;
    sbox_ref[8'he0]=8'he1; sbox_ref[8'he1]=8'hf8; sbox_ref[8'he2]=8'h98; sbox_ref[8'he3]=8'h11;
    sbox_ref[8'he4]=8'h69; sbox_ref[8'he5]=8'hd9; sbox_ref[8'he6]=8'h8e; sbox_ref[8'he7]=8'h94;
    sbox_ref[8'he8]=8'h9b; sbox_ref[8'he9]=8'h1e; sbox_ref[8'hea]=8'h87; sbox_ref[8'heb]=8'he9;
    sbox_ref[8'hec]=8'hce; sbox_ref[8'hed]=8'h55; sbox_ref[8'hee]=8'h28; sbox_ref[8'hef]=8'hdf;
    sbox_ref[8'hf0]=8'h8c; sbox_ref[8'hf1]=8'ha1; sbox_ref[8'hf2]=8'h89; sbox_ref[8'hf3]=8'h0d;
    sbox_ref[8'hf4]=8'hbf; sbox_ref[8'hf5]=8'he6; sbox_ref[8'hf6]=8'h42; sbox_ref[8'hf7]=8'h68;
    sbox_ref[8'hf8]=8'h41; sbox_ref[8'hf9]=8'h99; sbox_ref[8'hfa]=8'h2d; sbox_ref[8'hfb]=8'h0f;
    sbox_ref[8'hfc]=8'hb0; sbox_ref[8'hfd]=8'h54; sbox_ref[8'hfe]=8'hbb; sbox_ref[8'hff]=8'h16;
end

task check8;
    input [7:0] actual;
    input [7:0] expected;
    input [256*8-1:0] name;
begin
    total_tests = total_tests + 1;
    if (actual === expected) begin
        pass_count = pass_count + 1;
    end else begin
        fail_count = fail_count + 1;
        errors_in_section = errors_in_section + 1;
        $display("  [FAIL] %s: got %h, expected %h", name, actual, expected);
    end
end
endtask

task check32;
    input [31:0] actual;
    input [31:0] expected;
    input [256*8-1:0] name;
begin
    total_tests = total_tests + 1;
    if (actual === expected) begin
        pass_count = pass_count + 1;
    end else begin
        fail_count = fail_count + 1;
        errors_in_section = errors_in_section + 1;
        $display("  [FAIL] %s: got %h, expected %h", name, actual, expected);
    end
end
endtask

task check128;
    input [127:0] actual;
    input [127:0] expected;
    input [256*8-1:0] name;
begin
    total_tests = total_tests + 1;
    if (actual === expected) begin
        pass_count = pass_count + 1;
    end else begin
        fail_count = fail_count + 1;
        errors_in_section = errors_in_section + 1;
        $display("  [FAIL] %s", name);
        $display("    Got:      %h", actual);
        $display("    Expected: %h", expected);
    end
end
endtask

task section_header;
    input [256*8-1:0] title;
begin
    errors_in_section = 0;
    $display("");
    $display("================================================================");
    $display("  %s", title);
    $display("================================================================");
end
endtask

task section_result;
    input [256*8-1:0] title;
begin
    if (errors_in_section == 0)
        $display("  >> %s: ALL PASSED", title);
    else
        $display("  >> %s: %0d FAILURES", title, errors_in_section);
end
endtask

reg [7:0] sb_in;
wire [7:0] sb_gf_out;
sbox_gf u_sbox_gf(.data_i(sb_in), .data_o(sb_gf_out));

reg [31:0] sa_in;
wire [31:0] sa_out;
wire [127:0] sa_out128;
sbox_assign u_sbox_assign(.sboxw(sa_in), .new_sboxw(sa_out));

reg [127:0] sub_in;
wire [127:0] sub_gf_out, sub_lut_out;
sub_bytes #(.USE_gf(1)) u_sub_gf(.data_in(sub_in), .data_out(sub_gf_out));
sub_bytes #(.USE_gf(0)) u_sub_lut(.data_in(sub_in), .data_out(sub_lut_out));

reg [31:0] gf_in;
wire [31:0] gf_gf_out, gf_lut_out;
g_function #(.use_gf(1)) u_gfunc_gf(.word_in(gf_in), .word_out(gf_gf_out));
g_function #(.use_gf(0)) u_gfunc_lut(.word_in(gf_in), .word_out(gf_lut_out));

reg [127:0] sr_in;
wire [127:0] sr_out;
shift_rows u_shift_rows(.state_in(sr_in), .state_out(sr_out));

reg [127:0] mc_in;
wire [127:0] mc_out;
MixColumns u_mixcols(mc_in, mc_out);

reg [127:0] rnd_in, rnd_key;
wire [127:0] rnd_out;
aes_round u_aes_round(.data_in(rnd_in), .data_out(rnd_out), .round_key(rnd_key));

reg [127:0] frnd_in, frnd_key;
wire [127:0] frnd_out;
aes_finalround u_aes_finalround(.data_in(frnd_in), .data_out(frnd_out), .round_key(frnd_key));

reg [127:0] ke128_key;
wire [1280-1:0] ke128_out;
wire ke128_rdy;
reg ke128_rst;

reg [191:0] ke192_key;
wire [1536-1:0] ke192_out;
wire ke192_rdy;

reg [255:0] ke256_key;
wire [1792-1:0] ke256_out;
wire ke256_rdy;

u_keyExpansion_seq2 #(.Nk(4)) u_ke128(.clk(clk),.rst_n(ke128_rst),.KEY_in(ke128_key),.KEY_out(ke128_out),.key_ready(ke128_rdy));
u_keyExpansion_seq2 #(.Nk(6)) u_ke192(.clk(clk),.rst_n(ke128_rst),.KEY_in(ke192_key),.KEY_out(ke192_out),.key_ready(ke192_rdy));
u_keyExpansion_seq2 #(.Nk(8)) u_ke256(.clk(clk),.rst_n(ke128_rst),.KEY_in(ke256_key),.KEY_out(ke256_out),.key_ready(ke256_rdy));

reg [127:0] stg_in, stg_expected;
reg [255:0] stg_key;
wire [127:0] stg_out;
reg stg_rst;
aes_stage u_aes_stage(.data_in(stg_in),.data_out(stg_out),.clk(clk),.rst_n(stg_rst),.key_in(stg_key));

reg [127:0] fstg_in, fstg_expected;
reg [255:0] fstg_key;
wire [127:0] fstg_out;
reg fstg_rst;
aes_finalstagee u_aes_fstage(.data_in(fstg_in),.data_out(fstg_out),.clk(clk),.rst_n(fstg_rst),.key_in(fstg_key));

reg [127:0] top_in, top_key;
reg top_rst, top_valid;
wire [127:0] top_out;
wire top_valid_out;
aes_top u_aes_top(.data_in(top_in),.data_out(top_out),.key_in(top_key),.valid_in(top_valid),.valid_out(top_valid_out),.clk(clk),.rst_n(top_rst));

integer i;

initial begin
    total_tests = 0; pass_count = 0; fail_count = 0;
    top_rst = 0; top_valid = 0; top_in = 0; top_key = 0;
    stg_rst = 0; stg_in = 0; stg_key = 0;
    fstg_rst = 0; fstg_in = 0; fstg_key = 0;
    ke128_rst = 0;
    @(negedge clk);
    $display("============================================================");
    $display("  AES Comprehensive Testbench");
    $display("  Generated: 2026-06-13");
    $display("  Test vectors: FIPS-197, NIST SP 800-38A");
    $display("============================================================");

    // ============================================================
    // SECTION 1: S-Box GF exhaustive
    // ============================================================
    section_header("S1: S-Box GF (256-entry exhaustive)");
    for (i = 0; i < 256; i = i + 1) begin
        sb_in = i[7:0];
        #1;
        check8(sb_gf_out, sbox_ref[i], "S-Box GF entry");
    end
    section_result("S1: S-Box GF");

    // ============================================================
    // SECTION 2: S-Box Assign exhaustive (all 4 byte lanes)
    // ============================================================
    section_header("S2: S-Box Assign (256-entry, all 4 byte lanes)");
    for (i = 0; i < 256; i = i + 1) begin
        sa_in = {i[7:0], i[7:0], i[7:0], i[7:0]};
        #1;
        check8(sa_out[31:24], sbox_ref[i], "S-Box Assign byte3");
        check8(sa_out[23:16], sbox_ref[i], "S-Box Assign byte2");
        check8(sa_out[15:8],  sbox_ref[i], "S-Box Assign byte1");
        check8(sa_out[7:0],   sbox_ref[i], "S-Box Assign byte0");
    end
    section_result("S2: S-Box Assign");

    // ============================================================
    // SECTION 3: S-Box cross-validation GF vs Assign
    // ============================================================
    section_header("S3: S-Box cross-validation GF vs Assign");
    for (i = 0; i < 256; i = i + 1) begin
        sb_in = i[7:0];
        sa_in = {i[7:0], 24'h0};
        #1;
        check8(sb_gf_out, sa_out[31:24], "GF vs Assign");
    end
    section_result("S3: S-Box cross-validation");

    // ============================================================
    // SECTION 4: SubBytes 128-bit (both paths)
    // ============================================================
    section_header("S4: SubBytes 128-bit (GF + LUT paths)");
    sub_in = 128'h193de3bea0f4e22b9ac68d2ae9f84808;
    #1;
    check128(sub_gf_out, 128'hd42711aee0bf98f1b8b45de51e415230, "SubBytes GF round 1");
    check128(sub_lut_out, 128'hd42711aee0bf98f1b8b45de51e415230, "SubBytes LUT round 1");
    check128(sub_gf_out, sub_lut_out, "SubBytes GF==LUT round 1");

    sub_in = 128'ha49c7ff2689f352b6b5bea43026a5049;
    #1;
    check128(sub_gf_out, 128'h49ded28945db96f17f39871a7702533b, "SubBytes GF round 2");
    check128(sub_lut_out, 128'h49ded28945db96f17f39871a7702533b, "SubBytes LUT round 2");
    check128(sub_gf_out, sub_lut_out, "SubBytes GF==LUT round 2");

    sub_in = 128'haa8f5f0361dde3ef82d24ad26832469a;
    #1;
    check128(sub_gf_out, 128'hac73cf7befc111df13b5d6b545235ab8, "SubBytes GF round 3");
    check128(sub_lut_out, 128'hac73cf7befc111df13b5d6b545235ab8, "SubBytes LUT round 3");
    check128(sub_gf_out, sub_lut_out, "SubBytes GF==LUT round 3");
    section_result("S4: SubBytes 128-bit");

    // ============================================================
    // SECTION 5: ShiftRows
    // ============================================================
    section_header("S5: ShiftRows (4 vectors + edge)");
    sr_in = 128'h00112233445566778899AABBCCDDEEFF;
    #1; check128(sr_out, 128'h0055AAFF4499EE3388DD2277CC1166BB, "ShiftRows sequential");

    sr_in = 128'hd42711aee0bf98f1b8b45de51e415230;
    #1; check128(sr_out, 128'hd4bf5d30e0b452aeb84111f11e2798e5, "ShiftRows FIPS round 1");

    sr_in = 128'h49ded28945db96f17f39871a7702533b;
    #1; check128(sr_out, 128'h49db873b453953897f02d2f177de961a, "ShiftRows FIPS round 2");

    sr_in = 128'hac73cf7befc111df13b5d6b545235ab8;
    #1; check128(sr_out, 128'hacc1d6b8efb55a7b1323cfdf457311b5, "ShiftRows FIPS round 3");

    sr_in = 128'h00000000000000000000000000000000;
    #1; check128(sr_out, 128'h00000000000000000000000000000000, "ShiftRows all-zero");
    section_result("S5: ShiftRows");

    // ============================================================
    // SECTION 6: MixColumns (automated self-checking)
    // ============================================================
    section_header("S6: MixColumns (6 vectors, automated)");
    mc_in = 128'h6353e08c0960e104cd70b751bacad0e7;
    #1; check128(mc_out, 128'h5f72641557f5bc92f7be3b291db9f91a, "MixColumns original 1");

    mc_in = 128'h84e1dd691a41d76f792d389783fbac70;
    #1; check128(mc_out, 128'h9f487f794f955f662afc86abd7f1ab29, "MixColumns original 2");

    mc_in = 128'h1fb5430ef0accf64aa370cde3d77792c;
    #1; check128(mc_out, 128'hb7a53ecbbf9d75a0c40efc79b674cc11, "MixColumns original 3");

    mc_in = 128'hd4bf5d30e0b452aeb84111f11e2798e5;
    #1; check128(mc_out, 128'h046681e5e0cb199a48f8d37a2806264c, "MixColumns FIPS round 1");

    mc_in = 128'h49db873b453953897f02d2f177de961a;
    #1; check128(mc_out, 128'h584dcaf11b4b5aacdbe7caa81b6bb0e5, "MixColumns FIPS round 2");

    mc_in = 128'hacc1d6b8efb55a7b1323cfdf457311b5;
    #1; check128(mc_out, 128'h75ec0993200b633353c0cf7cbb25d0dc, "MixColumns FIPS round 3");
    section_result("S6: MixColumns");

    // ============================================================
    // SECTION 7: G-function (both paths, 7 vectors)
    // ============================================================
    section_header("S7: G-function (GF+LUT, 7 vectors)");
    gf_in = 32'ha0fafe17; #1;
    check32(gf_gf_out, 32'h2dbbf0e0, "G-func GF vec1");
    check32(gf_lut_out, 32'h2dbbf0e0, "G-func LUT vec1");

    gf_in = 32'h00112233; #1;
    check32(gf_gf_out, 32'h8293c363, "G-func GF vec2");
    check32(gf_lut_out, 32'h8293c363, "G-func LUT vec2");

    gf_in = 32'hdeadbeef; #1;
    check32(gf_gf_out, 32'h95aedf1d, "G-func GF vec3");
    check32(gf_lut_out, 32'h95aedf1d, "G-func LUT vec3");

    gf_in = 32'h09cf4f3c; #1;
    check32(gf_gf_out, 32'h8a84eb01, "G-func GF key word");
    check32(gf_lut_out, 32'h8a84eb01, "G-func LUT key word");

    gf_in = 32'h00000000; #1;
    check32(gf_gf_out, 32'h63636363, "G-func GF zero");
    check32(gf_lut_out, 32'h63636363, "G-func LUT zero");

    gf_in = 32'hffffffff; #1;
    check32(gf_gf_out, 32'h16161616, "G-func GF ones");
    check32(gf_lut_out, 32'h16161616, "G-func LUT ones");

    gf_in = 32'h2a6c7605; #1;
    check32(gf_gf_out, gf_lut_out, "G-func GF==LUT extra");
    section_result("S7: G-function");

    // ============================================================
    // SECTION 8: AES Round (9 rounds from FIPS-197 trace)
    // ============================================================
    section_header("S8: AES Round (9 FIPS-197 intermediate rounds)");
    rnd_in=128'h193de3bea0f4e22b9ac68d2ae9f84808; rnd_key=128'ha0fafe1788542cb123a339392a6c7605;
    #1; check128(rnd_out, 128'ha49c7ff2689f352b6b5bea43026a5049, "Round 1");

    rnd_in=128'ha49c7ff2689f352b6b5bea43026a5049; rnd_key=128'hf2c295f27a96b9435935807a7359f67f;
    #1; check128(rnd_out, 128'haa8f5f0361dde3ef82d24ad26832469a, "Round 2");

    rnd_in=128'haa8f5f0361dde3ef82d24ad26832469a; rnd_key=128'h3d80477d4716fe3e1e237e446d7a883b;
    #1; check128(rnd_out, 128'h486c4eee671d9d0d4de3b138d65f58e7, "Round 3");

    rnd_in=128'h486c4eee671d9d0d4de3b138d65f58e7; rnd_key=128'hef44a541a8525b7fb671253bdb0bad00;
    #1; check128(rnd_out, 128'he0927fe8c86363c0d9b1355085b8be01, "Round 4");

    rnd_in=128'he0927fe8c86363c0d9b1355085b8be01; rnd_key=128'hd4d1c6f87c839d87caf2b8bc11f915bc;
    #1; check128(rnd_out, 128'hf1006f55c1924cef7cc88b325db5d50c, "Round 5");

    rnd_in=128'hf1006f55c1924cef7cc88b325db5d50c; rnd_key=128'h6d88a37a110b3efddbf98641ca0093fd;
    #1; check128(rnd_out, 128'h260e2e173d41b77de86472a9fdd28b25, "Round 6");

    rnd_in=128'h260e2e173d41b77de86472a9fdd28b25; rnd_key=128'h4e54f70e5f5fc9f384a64fb24ea6dc4f;
    #1; check128(rnd_out, 128'h5a4142b11949dc1fa3e019657a8c040c, "Round 7");

    rnd_in=128'h5a4142b11949dc1fa3e019657a8c040c; rnd_key=128'head27321b58dbad2312bf5607f8d292f;
    #1; check128(rnd_out, 128'hea835cf00445332d655d98ad8596b0c5, "Round 8");

    rnd_in=128'hea835cf00445332d655d98ad8596b0c5; rnd_key=128'hac7766f319fadc2128d12941575c006e;
    #1; check128(rnd_out, 128'heb40f21e592e38848ba113e71bc342d2, "Round 9");
    section_result("S8: AES Round");

    // ============================================================
    // SECTION 9: AES Final Round
    // ============================================================
    section_header("S9: AES Final Round (FIPS-197)");
    frnd_in=128'heb40f21e592e38848ba113e71bc342d2; frnd_key=128'hd014f9a8c9ee2589e13f0cc8b6630ca6;
    #1; check128(frnd_out, 128'h3925841d02dc09fbdc118597196a0b32, "Final round FIPS-197");

    frnd_in=128'h193de3bea0f4e22ba9cb8d2ae9f84808; frnd_key=128'ha0fafe1788542cb123a339392a6c7605;
    #1; check128(frnd_out, 128'h7445a327684b7e1ff0e228c8344beee0, "Final round different key");
    section_result("S9: AES Final Round");

    // ============================================================
    // SECTION 10: Key Expansion AES-128/192/256
    // ============================================================
    section_header("S10: Key Expansion AES-128/192/256");
    ke128_rst = 0;
    ke128_key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    ke192_key = 192'h8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b;
    ke256_key = 256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
    @(negedge clk);
    ke128_rst = 0; @(negedge clk);
    check128(ke128_out[127:0], 128'h0, "KE128 reset check");
    @(negedge clk);
    ke128_rst = 1;
    wait(ke128_rdy && ke192_rdy && ke256_rdy);
    @(negedge clk);

    check128(ke128_out, 1280'ha0fafe1788542cb123a339392a6c7605f2c295f27a96b9435935807a7359f67f3d80477d4716fe3e1e237e446d7a883bef44a541a8525b7fb671253bdb0bad00d4d1c6f87c839d87caf2b8bc11f915bc6d88a37a110b3efddbf98641ca0093fd4e54f70e5f5fc9f384a64fb24ea6dc4fead27321b58dbad2312bf5607f8d292fac7766f319fadc2128d12941575c006ed014f9a8c9ee2589e13f0cc8b6630ca6, "KE-128");

    check128(ke192_out[127:0], 1536'h62f8ead2522c6b7bfe0c91f72402f5a5ec12068e6c827f6b0e7a95b95c56fec24db7b4bd69b5411885a74796e92538fde75fad44bb095386485af05721efb14fa448f6d94d6dce24aa326360113b30e6a25e7ed583b1cf9a27f939436a94f767c0a69407d19da4e1ec1786eb6fa64971485f703222cb8755e26d135233f0b7b340beeb282f18a2596747d26b458c553ea7e1466c9411f1df821f750aad07d753ca4005388fcc5006282d166abc3ce7b5e98ba06f448c773c8ecc720401002202, "KE-192");

    check128(ke256_out[127:0], 1792'h1f352c073b6108d72d9810a30914dff49ba354118e6925afa51a8b5f2067fcdea8b09c1a93d194cdbe49846eb75d5b9ad59aecb85bf3c917fee94248de8ebe96b5a9328a2678a647983122292f6c79b3812c81addadf48ba24360af2fab8b46498c5bfc9bebd198e268c3ba709e0421468007bacb2df331696e939e46c518d80c814e20476a9fb8a5025c02d59c58239de1369676ccc5a71fa2563959674ee155886ca5d2e2f31d77e0af1fa27cf73c3749c47ab18501ddae2757e4f7401905acafaaae3e4d59b349adf6acebd10190dfe4890d1e6188d0b046df344706c631e, "KE-256");
    section_result("S10: Key Expansion");

    // ============================================================
    // SECTION 11: AES Stage (2-round pairs)
    // ============================================================
    section_header("S11: AES Stage (reset + 3 FIPS vectors)");
    stg_rst = 0; stg_in = 0; stg_key = 0;
    repeat(3) @(negedge clk);
    check128(stg_out, 128'h0, "Stage reset");
    stg_rst = 1;

    stg_in=128'h193de3bea0f4e22b9ac68d2ae9f84808; stg_key=256'ha0fafe1788542cb123a339392a6c7605f2c295f27a96b9435935807a7359f67f;
    repeat(3) @(negedge clk);
    check128(stg_out, 128'haa8f5f0361dde3ef82d24ad26832469a, "Stage rounds 1-2");

    stg_in=128'haa8f5f0361dde3ef82d24ad26832469a; stg_key=256'h3d80477d4716fe3e1e237e446d7a883bef44a541a8525b7fb671253bdb0bad00;
    repeat(3) @(negedge clk);
    check128(stg_out, 128'he0927fe8c86363c0d9b1355085b8be01, "Stage rounds 3-4");

    stg_in=128'he0927fe8c86363c0d9b1355085b8be01; stg_key=256'hd4d1c6f87c839d87caf2b8bc11f915bc6d88a37a110b3efddbf98641ca0093fd;
    repeat(3) @(negedge clk);
    check128(stg_out, 128'h260e2e173d41b77de86472a9fdd28b25, "Stage rounds 5-6");
    section_result("S11: AES Stage");

    // ============================================================
    // SECTION 12: AES Final Stage
    // ============================================================
    section_header("S12: AES Final Stage (reset + FIPS vector)");
    fstg_rst = 0; fstg_in = 0; fstg_key = 0;
    repeat(3) @(negedge clk);
    check128(fstg_out, 128'h0, "Final stage reset");
    fstg_rst = 1;

    fstg_in=128'hea835cf00445332d655d98ad8596b0c5; fstg_key=256'hac7766f319fadc2128d12941575c006ed014f9a8c9ee2589e13f0cc8b6630ca6;
    repeat(3) @(negedge clk);
    check128(fstg_out, 128'h3925841d02dc09fbdc118597196a0b32, "Final stage rounds 9-10");
    section_result("S12: AES Final Stage");

    // ============================================================
    // SECTION 13: Full Pipeline FIPS-197
    // ============================================================
    section_header("S13: Full Pipeline (7 FIPS-197/NIST vectors)");
    top_rst = 0; top_valid = 0; top_in = 0;
    top_key = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
    repeat(5) @(negedge clk);
    check128(top_out, 128'h0, "Pipeline reset");

    top_key = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
    top_in  = 128'h6BC1BEE22E409F96E93D7E117393172A;
    top_rst = 1; top_valid = 1;
    wait(u_aes_top.key_ready);
    repeat(2) @(negedge clk);
    top_valid = 0;
    @(posedge top_valid_out);
    check128(top_out, 128'h3AD77BB40D7A3660A89ECAF32466EF97, "NIST SP800-38A block 1");
    repeat(6) @(negedge clk);

    top_in = 128'hAE2D8A571E03AC9C9EB76FAC45AF8E51;
    top_valid = 1;
    repeat(2) @(negedge clk);
    top_valid = 0;
    repeat(6) @(negedge clk);
    check128(top_out, 128'hF5D3D58503B9699DE785895A96FDBAAF, "NIST SP800-38A block 2");

    top_in = 128'h00000000000000000000000000000000;
    top_valid = 1;
    repeat(2) @(negedge clk);
    top_valid = 0;
    repeat(6) @(negedge clk);
    check128(top_out, 128'h7df76b0c1ab899b33e42f047b91b546f, "All-zero plaintext");

    top_in = 128'hffffffffffffffffffffffffffffffff;
    top_valid = 1;
    repeat(2) @(negedge clk);
    top_valid = 0;
    repeat(6) @(negedge clk);
    check128(top_out, 128'h8af2860142f786f409307c1a3f7eaaac, "All-ones plaintext");

    top_in = 128'h30C81C46A35CE411E5FBC1191A0A52EF;
    top_valid = 1;
    repeat(2) @(negedge clk);
    top_valid = 0;
    repeat(6) @(negedge clk);
    check128(top_out, 128'h43b1cd7f598ece23881b00e3ed030688, "NIST SP800-38A block 3");

    top_rst = 0; top_valid = 0;
    top_key = 128'h000102030405060708090A0B0C0D0E0F;
    top_in  = 128'h00112233445566778899AABBCCDDEEFF;
    repeat(5) @(negedge clk);
    top_rst = 1; top_valid = 1;
    wait(u_aes_top.key_ready);
    repeat(2) @(negedge clk);
    top_valid = 0;
    @(posedge top_valid_out);
    check128(top_out, 128'h69C4E0D86A7B0430D8CDB78070B4C55A, "FIPS-197 key2 vector");

    top_rst = 0; top_valid = 0;
    top_key = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
    top_in  = 128'h3243F6A8885A308D313198A2E0370734;
    repeat(5) @(negedge clk);
    top_rst = 1; top_valid = 1;
    wait(u_aes_top.key_ready);
    repeat(2) @(negedge clk);
    top_valid = 0;
    @(posedge top_valid_out);
    check128(top_out, 128'h3925841d02dc09fbdc118597196a0b32, "FIPS-197 Appendix B full");
    section_result("S13: Full Pipeline");

    // ============================================================
    // SECTION 14: Back-to-back pipeline (continuous streaming)
    // ============================================================
    section_header("S14: Back-to-back streaming (II=1 throughput)");
    top_rst = 0; top_valid = 0;
    top_key = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
    repeat(5) @(negedge clk);
    top_key = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
    top_in  = 128'h6BC1BEE22E409F96E93D7E117393172A;
    top_rst = 1; top_valid = 1;
    wait(u_aes_top.key_ready);
    @(negedge clk);
    @(negedge clk);
    top_in = 128'hAE2D8A571E03AC9C9EB76FAC45AF8E51;
    @(negedge clk);
    top_in = 128'h00000000000000000000000000000000;
    @(negedge clk);
    top_valid = 0;

    @(posedge top_valid_out);
    check128(top_out, 128'h3AD77BB40D7A3660A89ECAF32466EF97, "Stream block 1");
    @(posedge clk); @(negedge clk);
    check128(top_out, 128'hF5D3D58503B9699DE785895A96FDBAAF, "Stream block 2");
    @(posedge clk); @(negedge clk);
    check128(top_out, 128'h7df76b0c1ab899b33e42f047b91b546f, "Stream block 3");
    section_result("S14: Back-to-back streaming");

    // ============================================================
    // SECTION 15: Key change (requires reset)
    // ============================================================
    section_header("S15: Key change (reset + new key)");
    top_rst = 0; top_valid = 0;
    top_key = 128'h000102030405060708090A0B0C0D0E0F;
    top_in  = 128'h00112233445566778899AABBCCDDEEFF;
    repeat(5) @(negedge clk);
    top_rst = 1; top_valid = 1;
    wait(u_aes_top.key_ready);
    repeat(2) @(negedge clk);
    top_valid = 0;
    @(posedge top_valid_out);
    check128(top_out, 128'h69C4E0D86A7B0430D8CDB78070B4C55A, "Key change: first key");

    top_rst = 0; top_valid = 0;
    top_key = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
    top_in  = 128'h6BC1BEE22E409F96E93D7E117393172A;
    repeat(5) @(negedge clk);
    top_rst = 1; top_valid = 1;
    wait(u_aes_top.key_ready);
    repeat(2) @(negedge clk);
    top_valid = 0;
    @(posedge top_valid_out);
    check128(top_out, 128'h3AD77BB40D7A3660A89ECAF32466EF97, "Key change: second key");
    section_result("S15: Key change");

    // ============================================================
    // FINAL SUMMARY
    // ============================================================
    $display("");
    $display("============================================================");
    $display("  FINAL SUMMARY");
    $display("============================================================");
    $display("  Total checks : %0d", total_tests);
    $display("  Passed       : %0d", pass_count);
    $display("  Failed       : %0d", fail_count);
    if (fail_count == 0)
        $display("  RESULT       : *** ALL TESTS PASSED ***");
    else
        $display("  RESULT       : *** %0d TESTS FAILED ***", fail_count);
    $display("============================================================");

    if (fail_count > 0) $stop;
    else $finish;
end

endmodule

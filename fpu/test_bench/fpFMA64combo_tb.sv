`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpFMA64combo_tb.v
//		- floating point multiplier - adder test bench
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//                                                                          
// ============================================================================

import fp64Pkg::*;

module fpFMA64combo_tb();
reg rst;
reg clk;
reg [15:0] adr;
reg [131:0] mem [0:24000];
reg [131:0] memo [0:24000];
reg [259:0] memd [0:24000];
reg [255:0] memdo [0:24000];
reg [31:0] a,b,c;
reg [3:0] rm, rmx;
wire [3:0] rms;
wire [31:0] a5,b5,c5;
wire [31:0] o;
wire [31:0] as,bs,cs;
reg [63:0] ad,bd,cd;
wire [63:0] ad5,bd5,cd5,adx,bdx,cdx;
wire [63:0] od;
reg [7:0] cnt;
real delta = 1.0e-5;

integer outfile;

initial begin
	rst = 1'b0;
	clk = 1'b0;
	$readmemh("d:/cores2022/float/fpu/test_bench/data/fpFMA64_tv.txt", memd);
	#20 rst = 1;
	#50 rst = 0;
end

always #5
	clk = ~clk;

wire [4:0] dd = 5'd27;
delay5 #(32) u2 (clk, 1'b1, a, a5);
delay5 #(32) u3 (clk, 1'b1, b, b5);
delay5 #(32) u4 (clk, 1'b1, c, c5);
delay5 #(64) u5 (clk, 1'b1, ad, ad5);
delay5 #(64) u6 (clk, 1'b1, bd, bd5);
delay5 #(64) u7 (clk, 1'b1, cd, cd5);
vtdl #(64,32) u8 (clk, 1'b1, dd, ad, adx);
vtdl #(64,32) u9 (clk, 1'b1, dd, bd, bdx);
vtdl #(64,32) u10 (clk, 1'b1, dd, cd, cdx);
vtdl #(4,32) u11 (clk, 1'b1, dd, rm, rms);
vtdl #(32,32) u12 (clk, 1'b1, dd, a, as);
vtdl #(32,32) u13 (clk, 1'b1, dd, b, bs);
vtdl #(32,32) u14 (clk, 1'b1, dd, c, cs);

reg [63:0] sim_result;
real sim_result1,sim_result2,sim3,sim4;
always_comb
	sim3 = $bitstoreal(ad);
always_comb
	sim4 = $bitstoreal(bd);
always_comb
	sim_result1 = sim3 * sim4;
always_comb
	sim_result2 = sim_result1 + $bitstoreal(cd);
always_comb
	sim_result = $realtobits(sim_result2);

always_ff @(posedge clk)
if (rst) begin
	adr <= 0;
	cnt <= 0;
end else
begin
  if (adr==0) begin
    outfile = $fopen("d:/cores2022/float/fpu/test_bench/data/fpFMA64_tvo.txt", "wb");
    $fwrite(outfile, "rm ------ A ------  ------- B ------    ------- C ------- DUT result -  - SIM result -\n");
  end
	cnt <= cnt + 1;
	if (cnt==54)
		cnt <= 0;
	if (cnt==4) 
	begin
//		a <= mem[adr][31: 0];
//		b <= mem[adr][63:32];
//		c <= mem[adr][95:64];
		rm <= 3'd0;//mem[adr][131:128];
		ad <= memd[adr][63: 0];
		bd <= memd[adr][127:64];
		cd <= memd[adr][191:128];
		if (adr < 2000)
			cd <= 'd0;
		else if (adr < 4000)
			ad <= $realtobits(1.0);
	end
	if (cnt==6)
	begin
		adr <= adr + 1;
		memdo[adr] <= {rm,od,cd,bd,ad};
//		memdo[adr] <= {od,cd17,bd17,ad17};
//		memdo[adr] <= {od,cdx,bdx,adx};
		if (adr==23999) begin
			//$writememh("d:/cores2021/ANY1/v2/rtl/fpu/test_bench/fpFMA_tvo.txt", memo);
//			$writememh("d:/cores2022/Thor/rtl/fpu/test_bench/fpFMA32_tvo.txt", memo);
			$finish;
		end
	end
	if (cnt==47)
	  $fwrite(outfile, "%h\t%h\t%h\t%h\t%h\t%h%c\n", rm, ad, bd, cd, od, sim_result,(sim_result > od ? sim_result - od : od - sim_result) > 10 ? "*":" ");
end

//fpFMAnr u1 (clk, 1'b1, 1'b0, rm[2:0], c, b, a, o);//, sign_exe, inf, overflow, underflow);
fpFMA64nrCombo u15 (1'b0, rm[2:0], ad, bd, cd, od);//, inf, overflow, underflow, inexact);

endmodule

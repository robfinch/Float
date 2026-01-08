`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpFDP_tb.v
//		- floating point dot product test bench
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

module fpFDP_tb();
reg rst;
reg clk;
reg [15:0] adr;
reg [131:0] mem [0:24000];
reg [131:0] memo [0:24000];
reg [319:0] memd [0:8191];
reg [319:0] memdo [0:8191];
reg [63:0] a,b,c,d;
reg [3:0] rm, rmx;
wire [3:0] rms;
wire [63:0] a5,b5,c5,d5;
wire [63:0] o;
wire [63:0] as,bs,cs,ds;
reg [63:0] ad,bd,cd,dd;
wire [63:0] ad5,bd5,cd5,dd5,adx,bdx,cdx,ddx;
wire [63:0] od;
reg [7:0] cnt;
integer n;

initial begin
	rst = 1'b0;
	clk = 1'b0;
	adr = 0;
	cnt = 0;
//	for (n = 0; n < 8192; n = n + 1)
//	   memd[n] = 0;
	//$readmemh("d:/cores2021/ANY1/v2/rtl/fpu/test_bench/fpFMA_tv.txt", mem);
	$readmemh("fpFDP_tvd.mem", memd);
	#20 rst = 1;
	#50 rst = 0;
end

always #5
	clk = ~clk;

wire [4:0] ddd = 5'd27;
delay5 #(32) u2 (clk, 1'b1, a, a5);
delay5 #(32) u3 (clk, 1'b1, b, b5);
delay5 #(32) u4 (clk, 1'b1, c, c5);
delay5 #(64) u5 (clk, 1'b1, ad, ad5);
delay5 #(64) u6 (clk, 1'b1, bd, bd5);
delay5 #(64) u7 (clk, 1'b1, cd, cd5);
delay5 #(64) u8 (clk, 1'b1, dd, dd5);
vtdl #(64,32) u9 (clk, 1'b1, ddd, ad, adx);
vtdl #(64,32) u10 (clk, 1'b1, ddd, bd, bdx);
vtdl #(64,32) u11 (clk, 1'b1, ddd, cd, cdx);
vtdl #(64,32) u12 (clk, 1'b1, ddd, dd, ddx);
vtdl #(4,32) u13 (clk, 1'b1, ddd, rm, rms);
vtdl #(32,32) u14 (clk, 1'b1, ddd, a, as);
vtdl #(32,32) u15 (clk, 1'b1, ddd, b, bs);
vtdl #(32,32) u16 (clk, 1'b1, ddd, c, cs);
vtdl #(32,32) u17 (clk, 1'b1, ddd, d, ds);

always @(posedge clk)
if (rst) begin
	adr <= 0;
	cnt <= 0;
end else
begin
	cnt <= cnt + 1;
	if (cnt==54)
		cnt <= 0;
	if (cnt==4) 
	begin
		a <= mem[adr][31: 0];
		b <= mem[adr][63:32];
		c <= mem[adr][95:64];
		d <= mem[adr][127:96];
		rm <= 3'd0;//mem[adr][131:128];
		ad <= memd[adr][63: 0];
		bd <= memd[adr][127:64];
		cd <= memd[adr][191:128];
		dd <= memd[adr][255:192];
	end
	if (cnt==53)
	begin
		adr <= adr + 1;
//		memo[adr] <= {rm,o,c,b,a};
//		memdo[adr] <= {od,cd17,bd17,ad17};
		memdo[adr] <= {od,ddx,cdx,bdx,adx};
		if (adr==8190) begin
			//$writememh("d:/cores2021/ANY1/v2/rtl/fpu/test_bench/fpFMA_tvo.txt", memo);
			$writememh("c:/f/f/cores2024/float/fpu/test_bench/data/fpFDP_tvdo.txt", memdo);
			$finish;
		end
	end
end

//fpFMAnr u1 (clk, 1'b1, 1'b0, rm[2:0], c, b, a, o);//, sign_exe, inf, overflow, underflow);
fpFDP64nrL8 u18 (
	.clk(clk),
	.ce(1'b1),
	.adr(adr),
	.op(1'b0),
	.rm(rm[2:0]),
	.a(ad),
	.b(bd),
	.c(cd),
	.d(dd),
	.o(od),
	.inf(),
	.zero(),
	.overflow(),
	.underflow(),
	.inexact()
);

endmodule

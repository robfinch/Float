`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2018-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpSqrt64_tb.v
//		- floating point square root test bench
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

module fpSqrt64_tb();
reg rst;
reg clk;
reg clk2x;
reg clk4x;
reg [12:0] adr;
reg [191:0] memd [0:8191];
reg [127:0] memdo [0:9000];
reg [127:0] memdo1 [0:9000];
reg [31:0] a,a6;
reg [63:0] ad;
real cd;
wire [31:0] a5;
wire [31:0] o;
wire [63:0] od;
reg [79:0] adx;
wire [79:0] odx;
reg ld;
wire done;
reg [3:0] state;
reg [7:0] count;

initial begin
	rst = 1'b0;
	clk = 1'b0;
	clk2x = 1'b0;
	clk4x = 0;
	$readmemh("f:/cores2023/Float/fpu/test_bench/data/fpSqrt64_tv.txt", memd);
	#20 rst = 1;
	#50 rst = 0;
end

always #8
	clk = ~clk;
always #4
	clk2x = ~clk2x;

always_ff @(posedge clk)
if (rst) begin
	adr <= 0;
	state <= 1;
	count <= 0;
end
else
begin
	ld <= 1'b0;
case(state)
4'd1:
	begin
		count <= 8'd0;
		ad <= memd[adr][63:0];
		ld <= 1'b1;
		state <= 2;
	end
4'd2:
	begin
		if (count==8'd2)
			cd <= $sqrt($bitstoreal(ad));
		count <= count + 2'd1;
		if (count==8'd72) begin
			memdo[adr] <= {od,ad};
			memdo1[adr] <= {$realtobits(cd),ad};
			adr <= adr + 1;
			if (adr==8191) begin
				$writememh("f:/cores2023/Float/fpu/test_bench/data/fpSqrt64_dut_tvo.txt", memdo);
				$writememh("f:/cores2023/Float/fpu/test_bench/data/fpSqrt64_tb_tvo.txt", memdo1);
				$finish;
			end
			state <= 3;
		end
	end
4'd3:	state <= 4;
4'd4:	state <= 5;
4'd5:	state <= 1;
endcase
end

fpSqrt64nr u2 (rst, clk, clk2x, 1'b1, ld, ad, od, 3'b000, done);//, sign_exe, inf, overflow, underflow);

endmodule

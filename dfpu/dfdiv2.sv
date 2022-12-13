// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	dfdiv2.v
//    Decimal Float divider primitive
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

module dfdiv2(clk, ld, a, b, q, r, done, lzcnt);
parameter N=33;
localparam FPWID = N*4;
parameter RADIX = 10;
localparam FPWID1 = FPWID;//((FPWID+2)/3)*3;    // make FPWIDth a multiple of three
localparam DMSB = FPWID1-1;
input clk;
input ld;
input [FPWID-1:0] a;
input [FPWID-1:0] b;
output reg [FPWID*2-1:0] q;
output reg [FPWID-1:0] r;
output reg done;
output reg [7:0] lzcnt;	// Leading zero digit count


reg [2:0] st;
parameter IDLE = 3'd0;
parameter DDIN1 = 3'd1;
parameter DDIN2 = 3'd2;
parameter CALC = 3'd3;
parameter DDO = 3'd4;
parameter DONE = 3'd5;
parameter DDIN3 = 3'd6;

reg rstdd;
reg ldddi,lddiv,ldddo;
reg [1:0] ddidone,ddodone;
wire ddadone,ddbdone,divdone,ddoqdone,ddordone;
wire [N*4-1:0] dda, ddb;
wire [N*4*2-1:0] qdiv;
wire [N*4-1:0] rdiv;
wire [N*4*2-1:0] qo,qo1;
wire [N*4-1:0] ro;

DDBCDToBin #(.WID(N*4)) uddi1
(
	.rst(rstdd),
	.clk(clk),
	.ld(ldddi),
	.bcd(a),
	.bin(dda),
	.done(ddadone)
);

DDBCDToBin #(.WID(N*4)) uddi2
(
	.rst(rstdd),
	.clk(clk),
	.ld(ldddi),
	.bcd(b),
	.bin(ddb),
	.done(ddbdone)
);

fpdivr2 #(.FPWID(N*4)) udiv1
(
	.clk_div(clk),
	.ld(lddiv),
	.a({{N*4{1'b0}},dda}),
	.b({{N{1'b0}},ddb}),
	.q(qdiv),
	.r(rdiv),
	.done(divdone),
	.lzcnt()
);


DDBinToBCDFract #(.WID(N*4)) udd3
(
	.rst(rstdd),
	.clk(clk),
	.ld(ldddo),
	.bin({qdiv[N*4-1:0],4'h0}),
	.bcd(qo1),
	.done(ddoqdone)
);
assign qo = {qdiv[N*4+3:N*4],qo1[N*4-1:4]};

DDBinToBCDFract #(.WID(N*4)) udd4
(
	.rst(rstdd),
	.clk(clk),
	.ld(ldddo),
	.bin(rdiv),
	.bcd(ro),
	.done(ddordone)
);

reg nz;
reg [N-1:0] zc;
genvar g;
generate begin : glzcnt
	for (g = N-1; g >= 0; g = g - 1)
	always_comb
		zc[g] = qo[g*4+3+N*4:g*4+N*4]==0;
end
endgenerate

integer n;
always_comb
begin
	nz = 1'b0;
	lzcnt = 'd0;
	for (n = N-1; n >= 0; n = n - 1)
	begin
		nz = nz | ~zc[n];
		if (!nz)
			lzcnt = lzcnt + 1;
	end
end

always_comb
	lddiv <= ddidone==2'b11 && st==DDIN3;
always_comb
	ldddo <= divdone==1'b1 && st==CALC;

always_ff @(posedge clk)
begin
	rstdd <= 1'b0;
	ldddi <= 1'b0;
case(st)
IDLE:	;
DDIN1:
	begin
		ldddi <= 1'b1;
		st <= DDIN2;
	end
DDIN2:
	st <= DDIN3;
DDIN3:
	begin
		if (ddadone) ddidone <= ddidone | {ddbdone,ddadone};
		if (ddidone==2'b11)
			st <= CALC;
	end
CALC:
	if (divdone)
		st <= DDO;
DDO:
	begin
		if (ddoqdone) ddodone <= ddodone | {ddordone,ddoqdone};
		q <= qo;
		r <= ro;
		if (ddodone==2'b11)
			st <= DONE;
	end
DONE:
	begin
		done <= 1'b1;
	end
default:
	st <= IDLE;
endcase
if (ld) begin
	done <= 1'b0;
	rstdd <= 1'b1;
	ddidone <= 'd0;
	ddodone <= 'd0;
	st <= DDIN1;
end
end

endmodule

module dfdiv2_tb();

reg clk;
reg ld;
reg [135:0] a, b;
wire [271:0] q;
wire [135:0] r;
wire [7:0] lzcnt;

initial begin
	clk = 1'b0;
	ld = 1'b0;
	a = 136'h99_99999999_00000000_00000000_00000000;
	b = 136'h50_00000000_00000000_00000000_00000000;
	#20 ld = 1'b1;
	#40 ld = 1'b0;
end

always #5 clk = ~clk;

dfdiv2 #(.N(34)) u1 (
	.clk(clk),
	.ld(ld), 
	.a(a),
	.b(b),
	.q(q),
	.r(r), 
	.done(done),
	.lzcnt(lzcnt)
);
endmodule

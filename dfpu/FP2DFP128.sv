`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	FP2DFP128.sv
//	- convert quad precision float to quad precision decimal float
//	- denormal numbers are not properly converted, the exponent will be zero
//    the significand will be flushed to zero.
//
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

import fp128Pkg::*;
import DFPPkg::*;

module FP2DFP128(rst, clk, ld, i, o, done);
input rst;
input clk;
input ld;
input [127:0] i;
output DFP128 o;
output reg done;
localparam TE = 1024;

DFP128U ou;

wire [15:0] fpBias = {EMSB{1'b1}};
wire [15:0] dfpBias = 16'h17FF;

wire [155:0] bcd_sig;
reg [113:0] siga;
wire sa;
wire [EMSB:0] xa;
wire adn;
wire az;
wire xaInf;
wire aInf;
wire aNan, qNan, sNan;
wire [FMSB:0] ma;
wire [FMSB+1:0] sig;
wire [FMSB+2:0] sig1 = {1'b0,sig,1'b0};
wire [7:0] lzcnt;
reg [7:0] cnt;
reg [113:0] bitrev;
reg [139:0] bcd_rev;

reg [2:0] state;
parameter IDLE = 3'd0;
parameter CVT = 3'd1;
parameter DONE = 3'd3;
integer n,n1;

function [63:0] fnPow;
input [11:0] g;
	fnPow = $realtobits(($pow(10,-(g/$itor(TE)))) * $pow(2,64));
endfunction

always_ff @(posedge clk)
	for (n = 0; n < 114; n = n + 1)
		bitrev[n] = siga[113-n];

genvar g;
generate begin : gRev
for (g = 0; g < 140; g = g + 4)
always_ff @(posedge clk)
	bcd_rev[g+3:g] = bcd_sig[139-g:139-g-3];
end
endgenerate

always_ff @(posedge clk)
if (rst)
	done <= 1'b1;
else begin
	if (cnt)
		cnt <= cnt - 2'd1;
	if (ld) begin
		done <= 1'b0;
		cnt <= 8'd160;
		state <= CVT;
	end
	case(state)
	IDLE:	;
	CVT:
		if (cnt=='d0)
			state <= DONE;
	DONE:
		begin
			done <= 1'b1;
			state <= IDLE;
		end
	endcase
end

fpDecompReg u1 (.clk(clk), .ce(1'b1), .i(i), .sgn(sa), .exp(xa), .man(ma), .fract(sig), .xz(adn), .vz(az), .xinf(xaInf), .inf(aInf), .nan(aNan), .qnan(qNan), .snan(sNan) );

// The target exponent is a power of ten. The FP exponent is a power of two.
// Need some math to convert the exponent.
//  x    y
// 2 = 10
//          x
// y log10 2 = x log10 2 = 0.3010299957x
// *1024 =  308
// Also the exponent is biased and we want zero to be in the same place.
reg signed [31:0] tgtexp;
reg [15:0] binexp, binexp1;
reg signed [31:0] binexp2;
reg signed [31:0] xamb;
always_comb
	xamb <= {1'b0,xa} - fpBias;
reg [3:0] bitshift;
always_ff @(posedge clk)
	tgtexp <= $signed(xamb) * 10'd308;
// Round exponent up
always_ff @(posedge clk)
	binexp2 <= {{10{tgtexp[31]}},tgtexp[31:10]};// + |tgtexp[9];
// *65536 = 217706
reg signed [45:0] back_exp; 
always_ff @(posedge clk)
	back_exp <= tgtexp * 14'h3402;
reg [45:0] shift_amt;
always_ff @(posedge clk)
	shift_amt <= back_exp - {xamb,24'd0};

reg [64:0] tab1 [0:TE-1];
genvar g3;
generate begin : gTab1
	for (g3 = 0; g3 < TE; g3 = g3 + 1)
		initial begin
			tab1[g3] = {53'h00000000000000 | fnPow(g3) & 52'hFFFFFFFFFFFFF,12'd0};
			tab1[0] = {53'h10000000000000,12'd0};
		end
end
endgenerate

reg [112:0] multiplier;
wire [9:0] shift_amt2 = shift_amt[24:15];
always_ff @(posedge clk)
	multiplier <= {tab1[shift_amt2],48'h0};

reg [226:0] sigm;
reg [226:0] prod_pipe [0:31];
always_ff @(posedge clk)
	prod_pipe[0] <= sig * multiplier;//{1'b1,shift_amt2};
integer n3;
always_ff @(posedge clk)
for (n3 = 1; n3 < 32; n3 = n3 + 1)
	prod_pipe[n3] <= prod_pipe[n3-1];
always_ff @(posedge clk)
	sigm <= prod_pipe[31];

//mult128x128 u6 (clk, 1'b1, {15'd0,sig}, {15'd0,multiplier,48'd0}, sigm);

always_ff @(posedge clk)
	siga <= sigm[226:112];

always_ff @(posedge clk)
	binexp1 <= binexp2[15:0] + dfpBias -shift_amt[14];
always_ff @(posedge clk)
	binexp <= adn ? 'd0 : binexp1;

// Convert significand, the quad precision significand has 113 bits in it.
BinFractToBCD #(.WID(116)) u3 (
	.rst(rst),
	.clk(clk), 
	.ld(state==CVT && cnt==8'd119),
	.i({3'b0,siga}),//bitrev),//bitrev),
	.o(bcd_sig),
	.done()
);

cntlz192Reg u4 (
	.clk(clk),
	.ce(1'b1),
	.i({bcd_sig,36'd0}),	// bcd_rev
	.o(lzcnt)
);

// Leadings zeros must be a multple of four as BCD digits occupy four bits,
// round down.

wire [7:0] lzcnt2 = {lzcnt[7:2],2'd0};
wire [155:0] sig3 = bcd_sig << lzcnt2;// + bitshift;	// bcd_rev
wire [135:0] sig4 = sig3[155:20];

assign ou.nan = aNan;
assign ou.qnan = qNan;
assign ou.snan = sNan;
assign ou.infinity = aInf;
assign ou.sign = sa;
assign ou.exp = binexp[13:0];
assign ou.sig = adn ? 'd0 : sig4;


DFPPack128 u5 (.i(ou), .o(o));

endmodule

module BinFractToBCD(rst, clk, ld, i, o, done);
parameter WID=116;
localparam OWID = ((WID+(WID-4)/3+3) & -4);
input rst;
input clk;
input ld;
input [WID-1:0] i;
output reg [OWID-1:0] o;
output reg done;

reg [5:0] iter;
reg [WID+4-1:0] bin;
reg [WID+4-1:0] p;
always_comb
	p = (bin + (bin << 2'd2)) << 2'd1;

reg [1:0] state;
parameter IDLE = 2'd0;
parameter CVT = 2'd1;

always_ff @(posedge clk)
if (rst)
	done <= 1'b1;
else begin
	if (ld) begin
		iter <= OWID/4;
		bin <= {4'h0,i[WID-5:0],4'h0};
		o <= i[WID-1:WID-4];	// capture leading one if present.
		state <= CVT;
		done <= 1'b0;
	end
	case(state)
	IDLE:	;
	CVT:
		begin
			iter <= iter - 2'd1;
			o <= {o,p[WID+3:WID]};
			bin <= {4'h0,p[WID-1:0]};
			if (iter==6'd2) begin
				done <= 1'b1;
				state <= IDLE;
			end
		end
	default:	state <= IDLE;
	endcase
end

endmodule

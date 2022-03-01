`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	DFP2FP128.sv
//	- convert quad precision decimal float to quad precision float
//	- denormal numbers are not properly converted, the exponent will be zero
//    the significand will be flushed to zero.
//	- on overflow (rare) the output is forced to infinity
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

`define FPWID 128

import fp::*;
import DFPPkg::*;

module DFP2FP128(rst, clk, ld, i, o, overflow, done);
input rst;
input clk;
input ld;
input DFP128 i;
output reg [127:0] o;
output reg overflow;
output reg done;

DFP128U iu;

DFPUnpack128 u5 (.i(i), .o(iu));

wire [15:0] fpBias = {EMSB{1'b1}};
wire [15:0] dfpBias = 16'h17FF;

wire [113:0] bin_sig;
wire [7:0] lzcnt;
reg [7:0] cnt;
reg [15:0] exp;

reg [2:0] state;
parameter IDLE = 3'd0;
parameter CVT = 3'd1;
parameter DONE = 3'd3;

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

// The target exponent is a power of two. The DFP exponent is a power of ten.
// Need some math to convert the exponent.
//  x    y
// 2 = 10
//            x
// y = log10 2 = x log10 2 = 0.3010299957x
//                                     -1
// y = 0.301299957x, so x = 0.301299957  y
// = 3.321928904y
// *65536 = 217706
// Also the exponent is biased and we want zero to be in the same place.
reg signed [33:0] tgtexp;
reg [15:0] binexp, binexp1;
always_ff @(posedge clk)
	tgtexp <= $signed(18'h217706) * $signed(iu.exp - dfpBias);
always_ff @(posedge clk)
	binexp1 <= tgtexp[33:18] + fpBias;
always_ff @(posedge clk)
	binexp <= iu.exp=='d0 ? 'd0 : binexp1[15] ? 16'h7fff : binexp1;

// Convert significand, the quad precision significand has 114 bits in it.
// 152 bits allocated for BCD value
DDBCDToBin #(.WID(114)) u3 (
	.rst(rst),
	.clk(clk), 
	.ld(state==CVT && cnt==8'd159),
	.bcd({16'd0,iu.sig}),
	.bin(bin_sig),
	.done()
);

cntlz128Reg u4 (
	.clk(clk),
	.ce(1'b1),
	.i({bin_sig,15'b0}),
	.o(lzcnt)
);

// There should be one leading zero. Rather than shift by the full amount
// possible the shift is restricted to 0 to 3 bits to reduce the size and
// latency of the shifter.
// If there were no leading zeros, then the number would not fit into 113
// bits. The exponent needs to be increased. The exponent might overflow
// in which case the number needs to be set to infinity.
wire [113:0] sig3 = bin_sig << lzcnt[1:0];
always_ff @(posedge clk)
	exp <= binexp + (lzcnt=='d0 ? 1'd0 : 1'd1);
always_ff @(posedge clk)
if (iu.infinity|iu.exp=='d0|binexp1[15]|exp[15])
	o[111:0] <= 'd0;
else
	o[111:0] <= sig3[112:1];	// hide MSB
always_ff @(posedge clk)
if (iu.nan|iu.infinity|exp[15])
	o[126:112] <= 15'h7fff;
else
	o[126:112] <= exp[14:0];
always_ff @(posedge clk)
	o[127] <= iu.sign;
always_ff @(posedge clk)
	overflow <= binexp1[15]|exp[15];

endmodule

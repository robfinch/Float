// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	DFPScaleb96.sv
//		- floating point Scaleb()
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

import DFPPkg::*;

module DFPScaleb96(clk, ce, a, b, o);
localparam N=25;
input clk;
input ce;
input DFP96 a;
input [31:0] b;
output DFP96 o;

wire [4:0] cmp_o;
wire nana, nanb;
wire xza, mza;

wire [11:0] infXp = 12'hBFF;	// infinite / NaN - all ones
wire [11:0] bias = 12'h5FF;
wire xinfa;
wire anan;
reg anan1;
wire sa;
reg sa1, sa2;
wire [N*4-1:0] ma;
reg [13:0] xa1a, xa1b, xa2;
reg [N*4-1:0] ma1, ma2;
wire bs = b[31];
reg bs1;

DFP96U au, bu;
DFPUnpack96 u01 (a, au);

// ----------------------------------------------------------------------------
// Clock cycle 1
// ----------------------------------------------------------------------------
always @(posedge clk)
	if (ce) xa1a <= au.exp;
always @(posedge clk)
	if (ce) xa1b <= au.exp + b;
always @(posedge clk)
	if (ce) bs1 <= bs;
always @(posedge clk)
	if (ce) anan1 <= au.nan;
always @(posedge clk)
	if (ce) sa1 <= au.sign;
always @(posedge clk)
	if (ce) ma1 <= au.sig;

// ----------------------------------------------------------------------------
// Clock cycle 2
// ----------------------------------------------------------------------------
reg nan2;
reg qnan2;
reg snan2;
reg infinity2;

always @(posedge clk)
	if (ce) sa2 <= sa1;
always @(posedge clk)
	if (ce) nan2 <= anan1;
always @(posedge clk)
	if (ce) qnan2 <= anan1 && ma1[N*4-1:N*4-4]==4'h1;
always @(posedge clk)
	if (ce) snan2 <= anan1 && ma1[N*4-1:N*4-4]==4'h0;
always @(posedge clk)
if (ce) begin
	if (anan1) begin
		xa2 <= xa1a;
		ma2 <= ma1;
	end
	// Underflow? -> limit exponent to zero
	else if (bs1 & xa1b[13]) begin
		xa2 <= 'd0;
		ma2 <= ma1;
	end
	// overflow ? -> set value to infinity
	else if (~bs1 & xa1b[12]) begin
		xa2 <= infXp;
		ma2 <= 'd0;
		infinity2 <= 1'b1;
	end
	else begin
		xa2 <= xa1b;
		ma2 <= ma1;
	end
end

assign bu.nan = nan2;
assign bu.snan = snan2;
assign bu.qnan = qnan2;
assign bu.infinity = infinity2;
assign bu.sign = sa2;
assign bu.exp = xa2;
assign bu.sig = ma2;

DFPPack96 u02 (bu, o);

endmodule

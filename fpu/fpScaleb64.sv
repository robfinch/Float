// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpScaleb64.sv
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

import fp64Pkg::*;

module fpScaleb64(clk, ce, a, b, o);
input clk;
input ce;
input FP64 a;
input FP64 b;
output FP64 o;

wire [4:0] cmp_o;
wire nana, nanb;
wire xza, mza;

wire [fp64Pkg::EMSB:0] infXp = {fp64Pkg::EMSB+1{1'b1}};
wire [fp64Pkg::EMSB:0] xa;
wire xinfa;
wire anan;
reg anan1;
wire sa;
reg sa1, sa2;
wire [fp64Pkg::FMSB:0] ma;
reg [fp64Pkg::EMSB+1:0] xa1a, xa1b, xa2;
reg [fp64Pkg::FMSB:0] ma1, ma2;
wire bs = b.sign;
reg bs1;

fpDecomp64 u1 (.i(a), .sgn(sa), .exp(xa), .man(ma), .fract(), .xz(xza), .mz(), .vz(), .inf(), .xinf(xinfa), .qnan(), .snan(), .nan(anan));

// ----------------------------------------------------------------------------
// Clock cycle 1
// ----------------------------------------------------------------------------
always @(posedge clk)
	if (ce) xa1a <= xa;
always @(posedge clk)
	if (ce) xa1b <= xa + b;
always @(posedge clk)
	if (ce) bs1 <= bs;
always @(posedge clk)
	if (ce) anan1 <= anan;
always @(posedge clk)
	if (ce) sa1 <= sa;
always @(posedge clk)
	if (ce) ma1 <= ma;

// ----------------------------------------------------------------------------
// Clock cycle 2
// ----------------------------------------------------------------------------
always @(posedge clk)
	if (ce) sa2 <= sa1;
always @(posedge clk)
if (ce) begin
	if (anan1) begin
		xa2 <= xa1a;
		ma2 <= ma1;
	end
	// Underflow? -> limit exponent to zero
	else if (bs1 & xa1b[fp64Pkg::EMSB+1]) begin
		xa2 <= 1'd0;
		ma2 <= ma1;
	end
	// overflow ? -> set value to infinity
	else if (~bs1 & xa1b[fp64Pkg::EMSB+1]) begin
		xa2 <= infXp;
		ma2 <= 1'd0;
	end
	else begin
		xa2 <= xa1b;
		ma2 <= ma1;
	end
end

assign o.sign = sa2;
assign o.exp = xa2;
assign o.sig = ma2;

endmodule

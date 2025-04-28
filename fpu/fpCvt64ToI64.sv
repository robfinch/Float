// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpCvt64ToI64.sv
//		- convert floating point to integer
//		- two cycle latency floating point unit
//		- parameterized width
//		- IEEE 754 representation
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

import fp64Pkg::*;

module fpCvt64ToI64(clk, ce, op, i, o, overflow);
input clk;
input ce;
input op;					// 1 = signed, 0 = unsigned
input [fp64Pkg::MSB:0] i;
output reg [fp64Pkg::MSB:0] o;
output overflow;

wire [fp64Pkg::MSB:0] maxInt  = op ? {fp64Pkg::MSB{1'b1}} : {fp64Pkg::FPWID{1'b1}};		// maximum integer value
wire [fp64Pkg::EMSB:0] zeroXp = {fp64Pkg::EMSB{1'b1}};	// simple constant - value of exp for zero

// Decompose fp value
reg sgn;									// sign
always_ff @(posedge clk)
	if (ce) sgn = i[fp64Pkg::MSB];
wire [fp64Pkg::EMSB:0] exp = i[fp64Pkg::MSB-1:fp64Pkg::FMSB+1];		// exponent
wire [fp64Pkg::FMSB+1:0] man = {exp!=0,i[fp64Pkg::FMSB:0]};	// mantissa including recreate hidden bit

wire iz = i[fp64Pkg::MSB-1:0]==0;					// zero value (special)

assign overflow  = exp - zeroXp > (op ? fp64Pkg::MSB : fp64Pkg::FPWID);		// lots of numbers are too big - don't forget one less bit is available due to signed values
wire underflow = exp < zeroXp - 1;			// value less than 1/2

wire [7:0] shamt = (op ? fp64Pkg::MSB : fp64Pkg::FPWID) - (exp - zeroXp);	// exp - zeroXp will be <= MSB

wire [fp64Pkg::MSB+1:0] o1 = {man,{fp64Pkg::EMSB+1{1'b0}},1'b0} >> shamt;	// keep an extra bit for rounding
wire [fp64Pkg::MSB:0] o2 = o1[fp64Pkg::MSB+1:1] + o1[0];		// round up
reg [fp64Pkg::MSB:0] o3;

always_ff @(posedge clk)
	if (ce) begin
		if (underflow|iz)
			o3 <= 'd0;
		else if (overflow)
			o3 <= maxInt;
		// value between 1/2 and 1 - round up
		else if (exp==zeroXp-1)
			o3 <= 64'd1;
		// value > 1
		else
			o3 <= o2;
	end
		
always_ff @(posedge clk)
	if (ce)
		o <= (op & sgn) ? -o3 : o3;					// adjust output for correct signed value

endmodule


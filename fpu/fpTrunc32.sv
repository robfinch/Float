// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpTrunc32.sv
//		- convert floating point to integer (chop off fractional bits)
//		- single cycle latency floating point unit
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

import fp32Pkg::*;

module fpTrunc32(clk, ce, i, o, overflow);
input clk;
input ce;
input FP32 i;
output FP32 o;
output overflow;


integer n;
FP32 maxInt;
assign maxInt.sign = 1'b0;
assign maxInt.exp = 8'hFE;
assign maxInt.sig = 23'h7FFFFF;			// maximum unsigned integer value
wire [fp32Pkg::EMSB:0] zeroXp = {fp32Pkg::EMSB{1'b1}};	// simple constant - value of exp for zero

// Decompose fp value
reg sgn;									// sign
reg [fp32Pkg::EMSB:0] exp;
reg [fp32Pkg::FMSB:0] man;
reg [fp32Pkg::FMSB:0] mask;

wire [7:0] shamt = fp32Pkg::FMSB - (exp - zeroXp);
always_comb
for (n = 0; n <= fp32Pkg::FMSB; n = n +1)
	mask[n] = (n > shamt);

always_comb
	sgn = i.sign;
always_comb
	exp = i.exp;
always_comb
	if (exp > zeroXp + fp32Pkg::FMSB)
		man = i.sig;
	else
		man = i.sig & mask;

always_ff @(posedge clk)
	if (ce) begin
		if (exp < zeroXp)
			o <= 1'd0;
		else begin
			o.sign <= sgn;
			o.exp <= exp;
			o.sig <= man;
		end
	end

endmodule

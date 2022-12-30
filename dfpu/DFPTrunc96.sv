// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	DFPTrunc96.sv
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

import DFPPkg::*;

module DFPTrunc96(clk, ce, i, o, overflow);
parameter N=25;	// number of sig. digits
input clk;
input ce;
input DFP96 i;
output DFP96 o;
output reg overflow;


integer n;
DFP96U maxInt;
DFP96U iu, ou;

DFPUnpack96 u01 (i, iu);
DFPPack96 u02 (ou, o);

assign maxInt.sign = 1'b0;
assign maxInt.exp = 12'hBFE;
assign maxInt.sig = 100'h9999999999999999999999999;// maximum unsigned integer value
wire [11:0] zeroXp = 12'h5FF;		// simple constant - value of exp for zero

// Decompose fp value
reg sgn;									// sign
reg [11:0] exp;
reg [N*4-1:0] man;
reg [N*4-1:0] mask;

wire [12:0] shamt = (N - 1) - (exp - zeroXp);

genvar g;
generate begin : gMask
for (g = 0; g < N; g = g +1)
	always_comb
		mask[g*4+3:g*4] = (g > shamt) ? 4'hF : 4'h0;
end
endgenerate

always_comb
	sgn = iu.sign;
always_comb
	exp = iu.exp;
always_comb
	if (exp > zeroXp + (N-1))
		man = iu.sig;
	else
		man = iu.sig & mask;

always_ff @(posedge clk)
	if (ce) begin
		if (exp < zeroXp) begin
			ou <= 'd0;
			ou.sign <= sgn;	// retain sign
		end
		else begin
			ou.sign <= sgn;
			ou.exp <= exp;
			ou.sig <= man;
		end
	end

always_comb
	overflow <= 1'b0;

endmodule

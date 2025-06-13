`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	DFP32To96.sv
//    - decimal floating convert single to triple
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

module DFP96To32(i, o);
input DFP96 i;
output DFP32 o;

wire [11:0] bias96 = 12'h5FF;
wire [ 7:0] bias32 = 8'h5F;

reg [12:0] texp;
DFP32U ou;
DFP96U iu;

DFPUnpack96 u1 (i, iu);

always_comb
	ou.sign = iu.sign;
always_comb
begin
	ou.infinity = iu.infinity;
	if (iu.infinity|iu.nan)
		ou.exp = 8'hBF;
	else begin
		texp = bias32 + (iu.exp - bias96);
		if (texp > 13'hBF) begin
			ou.exp = 13'hBF;
			ou.infinity = 1'b1;
		end
		else
			ou.exp = bias32 + (iu.exp - bias96);
	end
end
always_comb
	ou.nan = iu.nan;
always_comb
	ou.qnan = iu.qnan;
always_comb
	ou.snan = iu.snan;
always_comb
	ou.sig = iu.sig[99:72];

DFPPack32 u2 (ou, o);

endmodule

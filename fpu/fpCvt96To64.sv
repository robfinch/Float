`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpCvt96To64.sv
//    - floating convert triple to double
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
import fp96Pkg::*;

module fpCvt96To64(i, o);
input FP96 i;
output FP64 o;

wire [14:0] bias96 = 15'h3FFF;
wire [10:0] bias64 = 11'h3FF;

always_comb
	o.sign = i.sign;
always_comb
	// When keeping infinity/nan status the four least significant bits of the
	// significand are retained. For infinity these will be zero, for nans
	// they may be significant depending on the nan value.
	if (i.exp==15'h7FFF) begin
		o.exp = 11'h3FF;
		o.sig = {i.sig[79:32],i.sig[3:0]};
	end
	// If the converted exponent will be too high set result to infinity.
	else if (i.exp > 15'h43FE) begin
		o.exp = 11'h3FF;
		o.sig = 'd0;
	end
	// If the converted exponent will be too low set result to zero or subnormal.
	else if (i.exp < 15'h3C00) begin
		o.exp = 11'h0;
		if (i.exp < 15'h3BCC)
			o.sig = 'd0;
		else
			o.sig = i.sig[79:28] >> (15'h3C00 - i.exp);	// attempt to keep subnormals
	end
	else begin
		o.exp = bias64 + i.exp - bias96;
		o.sig = i.seg[79:28];
	end

endmodule

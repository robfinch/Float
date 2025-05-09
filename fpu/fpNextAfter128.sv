// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpNextAfter128.v
//		- floating point nextafter()
//		- return next representable value
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

module fpNextAfter128(clk, ce, a, b, o);
input clk;
input ce;
input FP128 a;
input FP128 b;
output reg FP128 o;

FP128 o1;
wire [4:0] cmp_o;
wire nana, nanb;
wire xza, mza;

fpCompare128 u1 (.a(a), .b(b), .o(cmp_o), .nanx(nanxab) );
fpDecomp128 u2 (.i(a), .sgn(), .exp(), .man(), .fract(), .xz(xza), .mz(mza), .vz(), .inf(), .xinf(), .qnan(), .snan(), .nan(nana));
fpDecomp128 u3 (.i(b), .sgn(), .exp(), .man(), .fract(), .xz(), .mz(), .vz(), .inf(), .xinf(), .qnan(), .snan(), .nan(nanb));
wire FP128 ap1 = a + 2'd1;
wire FP128 am1 = a - 2'd1;
wire [fp128Pkg::EMSB:0] infXp = {fp128Pkg::EMSB+1{1'b1}};

always_ff  @(posedge clk)
if (ce) begin
	o1 <= a;
	casez({a.sign,cmp_o})
	6'b?1????:	o1 <= nana ? a : b;	// Unordered
	6'b????1?:	o1 <= a;							// a,b Equal
	6'b0????1:
		if (ap1.exp==infXp) begin
			o1.sign <= a.sign;
			o1.exp <= a.exp;
			o1.sig <= {fp128Pkg::FMSB+1{1'b0}};
		end
		else
			o1 <= ap1;
	6'b0????0:
		if (xza && mza)
			;
		else
			o1 <= am1;
	6'b1????0:
		if (ap1.exp==infXp) begin
			o1.sign <= a.sign;
			o1.exp <= a.exp;
			o1.sig <= {fp128Pkg::FMSB+1{1'b0}};
		end
		else
			o1 <= ap1;
	6'b1????1:
		if (xza && mza)
			;
		else
			o1 <= am1;
	default:	o1 <= a;
	endcase
end

always_ff  @(posedge clk)
if (ce)
	o <= o1;

endmodule

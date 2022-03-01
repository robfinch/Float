// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpNextAfter32.v
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

import fp32Pkg::*;

module fpNextAfter32(clk, ce, a, b, o);
input clk;
input ce;
input FP32 a;
input FP32 b;
output reg FP32 o;

wire [4:0] cmp_o;
wire nana, nanb;
wire xza, mza;

fpCompare32 u1 (.a(a), .b(b), .o(cmp_o), .nanx(nanxab) );
fpDecomp32 u2 (.i(a), .sgn(), .exp(), .man(), .fract(), .xz(xza), .mz(mza), .vz(), .inf(), .xinf(), .qnan(), .snan(), .nan(nana));
fpDecomp32 u3 (.i(b), .sgn(), .exp(), .man(), .fract(), .xz(), .mz(), .vz(), .inf(), .xinf(), .qnan(), .snan(), .nan(nanb));
wire FP32 ap1 = a + 2'd1;
wire FP32 am1 = a - 2'd1;
wire [fp32Pkg::EMSB:0] infXp = {fp32Pkg::EMSB+1{1'b1}};

always_ff  @(posedge clk)
if (ce) begin
	o <= a;
	casez({a.sign,cmp_o})
	6'b?1????:	o <= nana ? a : b;	// Unordered
	6'b????1?:	o <= a;							// a,b Equal
	6'b0????1:
		if (ap1.exp==infXp) begin
			o.sign <= a.sign;
			o.exp <= a.exp;
			o.sig <= {fp32Pkg::FMSB+1{1'b0}};
		end
		else
			o <= ap1;
	6'b0????0:
		if (xza && mza)
			;
		else
			o <= am1;
	6'b1????0:
		if (ap1.exp==infXp) begin
			o.sign <= a.sign;
			o.exp <= a.exp;
			o.sig <= {fp32Pkg::FMSB+1{1'b0}};
		end
		else
			o <= ap1;
	6'b1????1:
		if (xza && mza)
			;
		else
			o <= am1;
	default:	o <= a;
	endcase
end

endmodule

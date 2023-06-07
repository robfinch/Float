// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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

module fpSincos64(rst, clk, rm, ld, a, sin, cos);
input rst;
input clk;
input [2:0] rm;
input ld;
input FP64 a;
output FP64 sin;
output FP64 cos;

FP64 aa;
FP64X sinx, cosx;
wire FP64N fpn_sin, fpn_cos;
reg [59:0] phase_i;
wire [fp64Pkg::EMSB:0] exp;
reg [fp64Pkg::EMSB:0] exp1,exp2,exp3,exp4;
wire [fp64Pkg::FMSB+1:0] fract;
reg [fp64Pkg::FMSB+10:0] fract1,fract2,fract3,fract4;
wire [53:0] xval, yval;
wire [59:0] phase;
wire nan;
wire cdone;
wire vz;
reg ld1, ld2, ld3, ld4, ld5;

fpDecomp64Reg u4
(
	.clk(clk),
	.ce(1'b1),
	.i(aa),
	.o(),
	.sgn(sgn),
	.exp(exp),
	.man(),
	.fract(fract),
	.xz(),
	.mz(),
	.vz(vz),
	.inf(),
	.xinf(),
	.qnan(),
	.snan(),
	.nan(nan)
);

wire signed [11:0] expdif = 11'h3ff - exp;

always_ff @(posedge clk)
if (rst) begin
	fract1 <= 'd0;
	fract2 <= 'd0;
	ld1 <= 'd0;
	ld2 <= 'd0;
	ld3 <= 'd0;
	ld4 <= 'd0;
	ld5 <= 'd0;
	aa <= 'd0;
end
else begin
	if (ld)
		aa <= a;
	ld1 <= ld;
	ld2 <= ld1;
	ld3 <= ld2;
	ld4 <= ld3;
	ld5 <= ld4;
	if (vz) begin
		fract1 <= 'd0;
		exp1 <= 'd0;
	end
	else if (expdif[11]) begin	// expdif < 0?
		fract1 <= {fract,7'b0} << -expdif;
		exp1 <= exp + expdif;
	end
	else if (expdif > 13'd53) begin
		fract1 <= 'd0;
		exp1 <= exp + 6'd53;
	end
	else if (expdif > 0) begin// negative?
		fract1 <= {fract,7'b0} >> expdif[5:0];
		exp1 <= exp + expdif;
	end
	else if (expdif=='d0) begin
		fract1 <= {fract,7'b0};
		exp1 <= exp;
	end
	exp2 <= exp1;
	exp3 <= exp2;
	exp4 <= exp3;
	fract2 <= ({61'd0,fract1} * 61'h517cc1b727220c0) >> 8'd61;
	fract3 <= fract2;
	fract4 <= fract3;
end

wire [6:0] ylz, xlz;
cntlz64 uclzy(
	.i({yval[53] ? -yval[52:0] : yval[52:0],11'd0}),
	.o(ylz)
);
cntlz64 uclzx (
	.i({xval[53] ? -xval[52:0] : xval[52:0],11'd0}),
	.o(xlz)
);

always_ff @(posedge clk)
if (rst) begin
	sinx <= 'd0;
	cosx <= 'd0;
end
else begin
	if (cdone) begin
		if (nan) begin
			sinx.sign <= a.sign;
			sinx.exp <= a.exp;
			sinx.sig <= {a.sig,a.sig};
			cosx.sign <= a.sign;
			cosx.exp <= a.exp;
			cosx.sig <= {a.sig,a.sig};
		end
		else begin
			sinx.sign <= yval[53];
			sinx.exp <= exp4 - 2'd1 - ylz;	// 2^1
			if (yval[53])
				sinx.sig <= {-yval[51:0],54'd0} << ylz;
			else
				sinx.sig <= {yval[51:0],54'd0} << ylz;
			cosx.sign <= xval[53];
			cosx.exp <= exp4 - 2'd1 - xlz;
			if (xval[53]) begin
				cosx.sig <= {-xval[51:0],54'd0} << xlz;
			end
			else
				cosx.sig <= {xval[51:0],54'd0} << xlz;
		end
	end
end

fpCordic u1
(
	.rst(rst),
	.clk(clk),
	.arctan(1'b0),
	.ld(ld5),
	.phase_i({fract4[fp64Pkg::FMSB+8:0],1'b0}),
	.xval_i(54'h10000000000000),
	.yval_i(54'h00000000000000),
	.xval_o(xval),
	.yval_o(yval),
	.phase_o(phase),
	.done(cdone)
);

fpNormalize64 u2
(
	.clk(clk),
	.ce(1'b1),
	.under_i(1'b0),
	.i(sinx),
	.o(fpn_sin)
);

fpRound64 u3
(
	.clk(clk),
	.ce(1'b1),
	.rm(rm),
	.i(fpn_sin),
	.o(sin)
);

fpNormalize64 u5
(
	.clk(clk),
	.ce(1'b1),
	.under_i(1'b0),
	.i(cosx),
	.o(fpn_cos)
);

fpRound64 u6
(
	.clk(clk),
	.ce(1'b1),
	.rm(rm),
	.i(fpn_cos),
	.o(cos)
);

vtdl #(.WID(1), .DEP(16)) u7
(
	.clk(clk),
	.ce(1'b1),
	.a(4'd11),
	.d(cdone),
	.q(done)
);

endmodule

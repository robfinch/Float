// ============================================================================
//        __
//   \\__/ o\    (C) 2020  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	positDivide.sv
//    - posit number division function
//    - parameterized width
//    - parameterized latency
//
// Parts of this code extracted from the PACoGen project:
//    Copyright (c) 2019, Manish Kumar Jaiswal
//    All rights reserved.
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

`include "positConfig.sv"

module positDivide(clk, ce, a, b, o, start, done, zero, inf);
`include "positSize.sv"
parameter LATENCY = 25;
localparam rs = $clog2(PSTWID-1);
input clk;
input ce;
input [PSTWID-1:0] a;
input [PSTWID-1:0] b;
output reg [PSTWID-1:0] o;
input start;
output done;
output zero;
output inf;

localparam N = PSTWID;
localparam M = N-es;
localparam Bs = $clog2(N-1);
localparam NR_Iter = M > 88 ? 4 : M > 44 ? 3 : M > 22 ? 2 : M > 11 ? 1 : 0;		// 2 for 32 bits, 1 for 16 bits, 0 for 8bits
localparam NRB = 2**NR_Iter;
localparam IW_MAX = 10;							//Max intial approximation storage bit-width
localparam IW = 10;//(NRB == 1 ) ? M : (M/NRB*2 + ((M%NRB > 0) ? 1 : 0));	//(must be <= IW_MAX) 1/4th width of Mantissa: inverse width to be used in NR iterations multiplication 
localparam AW_MAX = 11;							//Max Address width of the intial approximation storage
localparam AW = 11;//(NRB == 1) ? M : (M/NRB*2 + ((M%NRB > 0) ? 1 : 0));	//Actual address width used for initial approximation (AW must be <= AW_MAX)

wire sa, sb;
reg so;
wire [rs:0] rgma, rgmb;
wire rgsa, rgsb;
wire [es-1:0] expa, expb;
wire [M-1:0] siga, sigb;
wire sigbd;
wire zera, zerb;
wire infa, infb;
wire inf1 = infa|zerb;
wire zero1 = zera|infb;
wire inf2, zero2;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Clock #1
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

positDecomposeReg #(PSTWID,es) u1 (
  .clk(clk),
  .ce(ce),
  .i(a),
  .sgn(sa),
  .rgs(rgsa),
  .rgm(rgma),
  .exp(expa),
  .sig(siga),
  .zer(zera),
  .inf(infa)
);

positDecomposeReg #(PSTWID,es) u2 (
  .clk(clk),
  .ce(ce),
  .i(b),
  .sgn(sb),
  .rgs(rgsb),
  .rgm(rgmb),
  .exp(expb),
  .sig(sigb),
  .zer(zerb),
  .inf(infb)
);

wire [M:0] m1 = {siga,1'b0};
wire [M:0] m2 = {sigb,1'b0};
wire [15:0] m2_inv0_tmp;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Clock #2
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg [Bs+1:0] argma;
reg [Bs+1:0] argmb;
reg so2, inf2, zero2;
// Register signals to match LUT timing.
wire [M:0] m1d, m2d;

always @(posedge clk)
  if (ce) so2 <= sa ^ sb;
always @(posedge clk)
  if (ce) zero2 <= zera|zerb;
always @(posedge clk)
  if (ce) inf2 <= infa|infb;  
always @(posedge clk)
  argma <= rgsa ? {2'b0,rgma} : -rgma;
always @(posedge clk)
  argmb <= rgsb ? {2'b0,rgmb} : -rgmb;

generate begin : gDivLut
if (M < AW_MAX)
div_lut lut1 (.clk(clk), .ce(ce), .i({m2[M-1:0],{AW_MAX-M{1'b0}}}), .o(m2_inv0_tmp));
else if (M==AW_MAX)
div_lut lut1 (.clk(clk), .ce(ce), .i(m2[M-1:0]), .o(m2_inv0_tmp));
else if (M > AW_MAX) begin
wire [AW_MAX-1:0] m2ndx = m2[M-1:M-AW_MAX];
div_lut lut1 (.clk(clk), .ce(ce), .i(m2ndx), .o(m2_inv0_tmp));
end
end
endgenerate

delay #(.WID(M+1),.DEP(1+NR_Iter)) ud1 (.clk(clk), .ce(ce), .i(m1), .o(m1d));
delay #(.WID(M+1),.DEP(1)) ud2 (.clk(clk), .ce(ce), .i(m2), .o(m2d));
delay #(.WID(1),.DEP(1+NR_Iter)) ud3 (.clk(clk), .ce(ce), .i(~|sigb[M-2:0]), .o(sigbd));

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Clock #3
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


wire [IW:0] m2_inv0;
assign m2_inv0 = m2_inv0_tmp[15:5];
delay1 #(1) ud4 (.clk(clk), .ce(ce), .i(start), .o(done));
delay1 #(1) ud5 (.clk(clk), .ce(ce), .i(inf1), .o(inf2));
delay1 #(1) ud6 (.clk(clk), .ce(ce), .i(zero1), .o(zero2));

reg [2*M+1:0] div_m;

genvar i;
generate begin
	reg [2*M+1:0] m2_inv  [NR_Iter:0];
	reg [M:0] m2dr [NR_Iter:0];

	if (NR_Iter > 0) begin
		reg [2*M+1:0] m2_inv_X_m2 [NR_Iter-1:0];
		reg [M+1:0] two_m2_inv_X_m2 [NR_Iter-1:0];

	  always @(posedge clk)
		  if (ce) m2_inv[0] <= {1'b0,m2_inv0,{M-IW{1'b0}},{M{1'b0}}};
	  always @(posedge clk)
	    if (ce) m2dr[0] <= m2d;
	  for (i = 0; i < NR_Iter - 1; i = i + 1)
	    always @(posedge clk)
	      if (ce) m2dr[i+1] <= m2dr[i];
		for (i = 0; i < NR_Iter; i=i+1) begin : NR_Iteration
		  always @(posedge clk) begin
			  m2_inv_X_m2[i] = {m2_inv[i][2*M:2*M-IW*(i+1)],{2*M-IW*(i+1)-M{1'b0}}} * m2dr[i];
			  two_m2_inv_X_m2[i] = {1'b1,{M{1'b0}}} - {1'b0,m2_inv_X_m2[i][2*M+1:M+3],|m2_inv_X_m2[i][M+2:0]};
			  if (ce) m2_inv[i+1] = {m2_inv2[i][2*M:2*M-IW*(i+1)],{M-IW*(i+1){1'b0}}} * {two_m2_inv_X_m2[i][M-1:0],1'b0};
			end
		end
	end
	else begin
	  always @(posedge clk)
		  if (ce) m2_inv[0] <= {1'b0,m2_inv0,{M{1'b0}}};
	end
	always @(posedge clk)
	  if (ce) div_m <= sigbd ? {1'b0,m1d,{M{1'b0}}} : m1d * m2_inv[NR_Iter][2*M:M];
end
endgenerate

wire div_m_udf = div_m[2*M+1];
wire [2*M+1:0] div_mN = ~div_m_udf ? div_m << 1'b1 : div_m;

//Exponent and Regime Computation
wire bin = (sigbd | div_m_udf) ? 0 : 1;
wire [Bs+es+1:0] div_e = {argma, expa} - {argmb, expb} - bin;// 1 + ~|mant2 + div_m_udf;
wire [es-1:0] e_o = div_e[es-1:0];
wire [Bs+es:0] exp_oN = div_e[es+Bs+1] ? -div_e[es+Bs:0] : div_e[es+Bs:0];
wire [Bs:0] r_o = (~div_e[es+Bs+1] || |(exp_oN[es-1:0])) ? exp_oN[Bs+es:es] + 1 : exp_oN[es+Bs:es];

//Exponent and Mantissa Packing
wire [2*N-1+3:0] tmp_o = {{N{~div_e[es+Bs+1]}},div_e[es+Bs+1],e_o,div_mN[2*M:M],|div_mN[M-1:0] };

//Including Regime bits in Exponent-Mantissa Packing
wire [3*N-1+3:0] tmp1_o = {tmp_o,{N{1'b0}}} >> (r_o[Bs] ? {Bs{1'b1}} : r_o);

//Rounding RNE : ulp_add = G.(R + S) + L.G.(~(R+S))
wire L = tmp1_o[N+4], G = tmp1_o[N+3], R = tmp1_o[N+2], St = |tmp1_o[N+1:0],
     ulp = ((G & (R | St)) | (L & G & ~(R | St)));
wire [N-1:0] rnd_ulp = {{N-1{1'b0}},ulp};

wire [N:0] tmp1_o_rnd_ulp = tmp1_o[2*N-1+3:N+3] + rnd_ulp;
wire [N-1:0] tmp1_o_rnd = (r_o < M-2) ? tmp1_o_rnd_ulp[N-1:0] : tmp1_o[2*N-1+3:N+3];

//Final Output
wire [N-1:0] tmp1_oN = so ? -tmp1_o_rnd : tmp1_o_rnd;

wire [PSTWID-1:0] o1 = inf|zero|(~div_mN[2*M+1]) ? {inf,{N-1{1'b0}}} : {so, tmp1_oN[N-1:1]};

genvar g;
reg [PSTWID+1:0] rtff [0:LATENCY-1];
generate begin : gRetiming
  always @(posedge clk)
    if (ce) rtff[0] <= {inf2,zero2,o1};
  for (g = 0; g < LATENCY-1; g = g + 1)
    always @(posedge clk)
      if (ce) rtff[g+1] <= rtff[g];
  assign {inf,zero,o} = rtff[LATENCY-1];
end
endgenerate

endmodule

// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpFMA96LN.sv
//		- floating point fused multiplier + adder
//		- combinational logic only
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
// 1075 LUTs / 0 FFs / 5 DSPs
// ============================================================================

import fp96Pkg::*;


// Multiplier-Adder with normalization and rounding.

module fpFMA96LN(clk, op, rm, a, b, c, o, inf, zero, overflow, underflow, inexact);
parameter LATENCY=4;
input clk;
input op;
input [2:0] rm;
input  FP96 a, b, c;
	(* RETIMING_BACKWARD = 1 *)
output FP96 o;
	(* RETIMING_BACKWARD = 1 *)
output reg zero;
	(* RETIMING_BACKWARD = 1 *)
output reg inf;
	(* RETIMING_BACKWARD = 1 *)
output reg overflow;
	(* RETIMING_BACKWARD = 1 *)
output reg underflow;
	(* RETIMING_BACKWARD = 1 *)
output reg inexact;

integer n;
genvar g;
FP96 o1;
wire underflow1;
wire overflow1;
wire inexact1;
wire inf1;
wire zero1;

always_comb
	if (LATENCY < 1) begin
		$display("FP: Latency must be > 0");
		$finish;
	end

fpFMA96nrCombo u1
(
	.op(op),
	.rm(rm),
	.a(a),
	.b(b),
	.c(c),
	.o(o1),
	.underflow(underflow1),
	.overflow(overflow1),
	.zero(zero1),
	.inf(inf1),
	.inexact(inexact1)
);
//assign overflow = inf;
generate begin : gRegs
	(* RETIMING_BACKWARD = 1 *)
	FP96 [LATENCY-1:0] res;
	(* RETIMING_BACKWARD = 1 *)
	reg [LATENCY-1:0] ovr;
	(* RETIMING_BACKWARD = 1 *)
	reg [LATENCY-1:0] und;
	(* RETIMING_BACKWARD = 1 *)
	reg [LATENCY-1:0] zer;
	(* RETIMING_BACKWARD = 1 *)
	reg [LATENCY-1:0] nnf;
	(* RETIMING_BACKWARD = 1 *)
	reg [LATENCY-1:0] ine;
	
	always_ff @(posedge clk) res[0] <= o1;
	always_ff @(posedge clk) ovr[0] <= overflow1;
	always_ff @(posedge clk) und[0] <= underflow1;
	always_ff @(posedge clk) zer[0] <= zero1;
	always_ff @(posedge clk) nnf[0] <= inf1;
	always_ff @(posedge clk) ine[0] <= inexact1;

	always_ff @(posedge clk) for (n = 1; n < LATENCY; n = n + 1) res[n] <= res[n-1];
	always_ff @(posedge clk) for (n = 1; n < LATENCY; n = n + 1) ovr[n] <= ovr[n-1];
	always_ff @(posedge clk) for (n = 1; n < LATENCY; n = n + 1) und[n] <= und[n-1];
	always_ff @(posedge clk) for (n = 1; n < LATENCY; n = n + 1) zer[n] <= zer[n-1];
	always_ff @(posedge clk) for (n = 1; n < LATENCY; n = n + 1) nnf[n] <= nnf[n-1];
	always_ff @(posedge clk) for (n = 1; n < LATENCY; n = n + 1) ine[n] <= ine[n-1];

	always_comb o = res[LATENCY-1];
	always_comb overflow = ovr[LATENCY-1];
	always_comb underflow = und[LATENCY-1];
	always_comb zero = zer[LATENCY-1];
	always_comb inf = nnf[LATENCY-1];
	always_comb inexact = ine[LATENCY-1];
end
endgenerate
	
endmodule


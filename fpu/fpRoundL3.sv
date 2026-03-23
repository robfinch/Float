// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpRoundL3.sv
//    - floating point rounding unit
//    - IEEE 754 representation
//		- 3 clock latency
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
// 120 LUTs / 250 FFs / 400 MHz		(64-bit)
// ============================================================================

module fpRoundL3(clk, ce, rm, i, o);
parameter EMSB = fp64Pkg::EMSB;
parameter MSB = fp64Pkg::MSB;
parameter FMSB = fp64Pkg::FMSB;
input clk;
input ce;
input [2:0] rm;			// rounding mode
input [MSB+3:0] i;	// intermediate format input
output [MSB:0] o;		// rounded output

//------------------------------------------------------------
// variables
wire xInf = &i[MSB+2:FMSB+4];
wire so0 = i[MSB+3];

wire l = i[3];
wire g = i[2];	// guard bit: always the same bit for all operations
wire r = i[1];	// rounding bit
wire s = i[0];	// sticky bit
reg rnd;

//------------------------------------------------------------
// Clock #1
// - determine round amount (add 1 or 0)
//------------------------------------------------------------

reg so1;
reg [EMSB:0] xo1;
reg [FMSB+3:0] mo1;

always_ff @(posedge clk)
	if (ce) so1 <= so0;
always_ff @(posedge clk)
	if (ce) xo1 <= i[MSB+2:FMSB+4];
always_ff @(posedge clk)
	if (ce) mo1 <= i[FMSB+3:0];

wire tie = g & ~(r|s);
// Compute the round bit
// Infinities and NaNs are not rounded!
always_ff @(posedge clk)
if (ce) 
	casez ({xInf,rm})
	4'b0000:  rnd <= (g & (r|s)) | (l & tie); // round to nearest ties to even
	4'b0001:	rnd <= 1'd0;				// round to zero (truncate)
	4'b0010:	rnd <= g & !so0;		// round towards +infinity
	4'b0011:	rnd <= g & so0;			// round towards -infinity
	4'b0100:  rnd <= (g & (r|s)) | tie; // round to nearest ties away from zero
	4'b1???:	rnd <= 1'd0;	// no rounding if exponent indicates infinite or NaN
	default:	rnd <= 0;				
	endcase

//------------------------------------------------------------
// Clock #2
// round the number, check for carry
// note: inf. exponent checked above (if the exponent was infinite already, then no rounding occurs as rnd = 0)
// note: exponent increments if there is a carry (can only increment to infinity)
//------------------------------------------------------------

reg [MSB:0] rounded2;
reg carry2;
reg rnd2;
reg dn2;
reg so2;
reg [EMSB:0] xo2;
reg [FMSB+3:0] mo2;
wire [MSB:0] rounded1 = {xo1,mo1[FMSB+3:3],1'b0} + {rnd,1'b0};	// Add onto LSB, GRS=0

always_ff @(posedge clk)
	if (ce) so2 <= so1;
always_ff @(posedge clk)
	if (ce) mo2 <= mo1;
always_ff @(posedge clk)
	if (ce) rounded2 <= rounded1;
always_ff @(posedge clk)
	if (ce) carry2 <= mo1[FMSB+3] & !rounded1[FMSB+1];
always_ff @(posedge clk)
	if (ce) rnd2 <= rnd;
always_ff @(posedge clk)
	if (ce) dn2 <= !(|xo1);
assign xo2 = rounded2[MSB:FMSB+2];

//------------------------------------------------------------
// Clock #3
// - shift mantissa if required.
//------------------------------------------------------------

reg so;
reg [EMSB:0] xo;
reg  [FMSB:0] mo;

always_ff @(posedge clk)
	if (ce) so <= so2;
always_ff @(posedge clk)
	if (ce) xo <= xo2;

always_ff @(posedge clk)
if (ce)
	casez({rnd2,&xo2,carry2,dn2})
	4'b0??0:	mo <= mo2[FMSB+2:2];		// not rounding, not denormalized, => hide MSB
	4'b0??1:	mo <= mo2[FMSB+3:3];		// not rounding, denormalized
	4'b1000:	mo <= rounded2[FMSB  :0];	// exponent didn't change, number was normalized, => hide MSB,
	4'b1001:	mo <= rounded2[FMSB+1:1];	// exponent didn't change, but number was denormalized, => retain MSB
	4'b1010:	mo <= rounded2[FMSB+1:1];	// exponent incremented (new MSB generated), number was normalized, => hide 'extra (FMSB+2)' MSB
	4'b1011:	mo <= rounded2[FMSB+1:1];	// exponent incremented (new MSB generated), number was denormalized, number became normalized, => hide 'extra (FMSB+2)' MSB
	4'b11??:	mo <= 1'd0;						// number became infinite, no need to check carry etc., rnd would be zero if input was NaN or infinite
	endcase

assign o[MSB] = so;
assign o[MSB-1:MSB-EMSB-1] = xo;
assign o[FMSB:0] = mo;

endmodule

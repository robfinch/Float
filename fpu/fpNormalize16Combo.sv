// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpNormalize16Combo.sv
//    - floating point normalization unit
//    - combinational logic
//    - IEEE 754 representation
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
//	This unit takes a floating point number in an intermediate
// format and normalizes it. No normalization occurs
// for NaN's or infinities. The unit has a two cycle latency.
//
// The mantissa is assumed to start with two whole bits on
// the left. The remaining bits are fractional.
//
// The width of the incoming format is reduced via a generation
// of sticky bit in place of the low order fractional bits.
//
// On an underflowed input, the incoming exponent is assumed
// to be negative. A right shift is needed.
// ============================================================================

import fp16Pkg::*;

module fpNormalize16Combo(i, o, under_i, under_o, inexact_o);
input FP16X i;		// expanded format input
output FP16N o;		// normalized output + guard, sticky and round bits, + 1 whole digit
input under_i;
output reg under_o;
output reg inexact_o;

integer n,n2;
// ----------------------------------------------------------------------------
// No Clock required
// ----------------------------------------------------------------------------
reg [fp16Pkg::EMSB:0] xo0;
reg so0;

always_comb
	xo0 <= i.exp;
always_comb
	so0 <= i.sign;		// sign doesn't change

// ----------------------------------------------------------------------------
// Clock #1
// - Capture exponent information
// ----------------------------------------------------------------------------
reg xInf1a, xInf1b, xInf1c;
FP16X i1;

always_comb
	i1 <= i;
always_comb
	xInf1a <= &xo0 & !under_i;
always_comb
	xInf1b <= &xo0[fp16Pkg::EMSB:1] & !under_i;
always_comb
	xInf1c = &xo0;

// ----------------------------------------------------------------------------
// Clock #2
// - determine exponent increment
// Since the there are *three* whole digits in the incoming format
// the number of whole digits needs to be reduced. If the MSB is
// set, then increment the exponent and no shift is needed.
// ----------------------------------------------------------------------------
reg xInf2c, xInf2b;
reg [fp16Pkg::EMSB:0] xo2;
reg incExpByOne2, incExpByTwo2;
reg under2;
always_comb
	xInf2c <= xInf1c;
always_comb
	xInf2b <= xInf1b;
always_comb
	xo2 <= xo0;
always_comb
	under2 <= under_i;

always_comb
	incExpByTwo2 <= !xInf1b & i1[fp16Pkg::FX];
always_comb
	incExpByOne2 <= !xInf1a & i1[fp16Pkg::FX-1];

// ----------------------------------------------------------------------------
// Clock #3
// - increment exponent
// - detect a zero mantissa
// ----------------------------------------------------------------------------

reg incExpByTwo3;
reg incExpByOne3;
FP16X i3;
reg [fp16Pkg::EMSB:0] xo3;
reg zeroMan3;
reg xInf3c;
reg under3;
reg so3;
always_comb
	 incExpByTwo3 <= incExpByTwo2;
always_comb
	 incExpByOne3 <= incExpByOne2;
always_comb
	 i3 <= i;
always_comb
	 xInf3c <= xInf2c;
always_comb
	 under3 <= under_i;
always_comb
	 so3 <= so0;

wire [fp16Pkg::EMSB+1:0] xv3a = xo2 + {incExpByTwo2,1'b0};
wire [fp16Pkg::EMSB+1:0] xv3b = xo2 + incExpByOne2;

always_comb
	 xo3 <= xo2 + (incExpByTwo2 ? 2'd2 : incExpByOne2 ? 2'd1 : 2'd0);

always_comb
	 zeroMan3 <= ((xv3b[fp16Pkg::EMSB+1]|| &xv3b[fp16Pkg::EMSB:0])||(xv3a[fp16Pkg::EMSB+1]| &xv3a[fp16Pkg::EMSB:0]))
							 && !under2 && !xInf2c;

// ----------------------------------------------------------------------------
// Clock #4
// - Shift mantissa left
// - If infinity is reached then set the mantissa to zero
//   shift mantissa left to reduce to a single whole digit
// - create sticky bit
// ----------------------------------------------------------------------------

reg [fp16Pkg::FMSB+5:0] mo4;
reg inexact4;

always_comb
casez({zeroMan3,incExpByTwo3,incExpByOne3})
3'b1??:	mo4 <= 1'd0;
3'b01?:	mo4 <= {i3[fp16Pkg::FX:fp16Pkg::FMSB],|i3[fp16Pkg::FMSB-1:0]};
3'b001:	mo4 <= {i3[fp16Pkg::FX-1:fp16Pkg::FMSB-1],|i3[fp16Pkg::FMSB-2:0]};
default:	mo4 <= {i3[fp16Pkg::FX-2:fp16Pkg::FMSB-2],|i3[fp16Pkg::FMSB-3:0]};
endcase

always_comb
casez({zeroMan3,incExpByTwo3,incExpByOne3})
3'b1??:	inexact4 <= 1'd0;
3'b01?:	inexact4 <= |i3[fp16Pkg::FMSB+1:0];
3'b001:	inexact4 <= |i3[fp16Pkg::FMSB:0];
default:	inexact4 <= |i3[fp16Pkg::FMSB-1:0];
endcase

// ----------------------------------------------------------------------------
// Clock edge #5
// - count leading zeros
// ----------------------------------------------------------------------------
reg [7:0] leadingZeros5;
reg [fp16Pkg::EMSB:0] xo5;
reg xInf5;
always_comb
	xo5 <= xo3;
always_comb
	xInf5 <= xInf3c;

/* Lookup table based leading zero count modules give slightly better
   performance but cases must be coded.
generate
begin
if (FPWID <= 32) begin
cntlz32Reg clz0 (.clk(clk), .ce(ce), .i({mo4,4'b0}), .o(leadingZeros5) );
assign leadingZeros5[7:6] = 2'b00;
end
else if (FPWID<=32) begin
assign leadingZeros5[7] = 1'b0;
cntlz32Reg clz0 (.clk(clk), .ce(ce), .i({mo4,7'h0}), .o(leadingZeros5) );
end
else if (FPWID<=80) begin
assign leadingZeros5[7] = 1'b0;
cntlz80Reg clz0 (.clk(clk), .ce(ce), .i({mo4,11'b0}), .o(leadingZeros5) );
end
else if (FPWID<=84) begin
assign leadingZeros5[7] = 1'b0;
cntlz96Reg clz0 (.clk(clk), .ce(ce), .i({mo4,23'b0}), .o(leadingZeros5) );
end
else if (FPWID<=96) begin
assign leadingZeros5[7] = 1'b0;
cntlz96Reg clz0 (.clk(clk), .ce(ce), .i({mo4,11'b0}), .o(leadingZeros5) );
end
else if (FPWID<=128)
cntlz128Reg clz0 (.clk(clk), .ce(ce), .i({mo4,11'b0}), .o(leadingZeros5) );
end
endgenerate
*/

// Sideways add.
// Normally there would be only one to two leading zeros. It is tempting then
// to check for only one or two. But, denormalized numbers might have more
// leading zeros. If denormals were not supported this could be made smaller
// and faster.
`ifdef SUPPORT_DENORMALS
reg [7:0] lzc;
reg got_one;
always_comb
begin
  got_one = 1'b0;
  lzc = 8'h00;
  for (n2 = fp16Pkg::FMSB+5; n2 >= 0; n2 = n2 - 1) begin
    if (!got_one) begin
      if (mo4[n2])
        got_one = 1'b1;
      else
        lzc = lzc + 1'b1;
    end
  end
end      
always_comb
  leadingZeros5 <= lzc;
`else
always_comb
casez(mo4[fp16Pkg::FMSB+5:fp16Pkg::FMSB+4])
2'b1?:  leadingZeros5 <= 8'd0;
2'b01:  leadingZeros5 <= 8'd1;
2'b00:  leadingZeros5 <= 8'd2;
endcase
`endif


// ----------------------------------------------------------------------------
// Clock edge #6
// - Compute how much we want to decrement exponent by
// - compute amount to shift left and right
// - at infinity the exponent can't be incremented, so we can't shift right
//   otherwise it was an underflow situation so the exponent was negative
//   shift amount needs to be negated for shift register
// If the exponent underflowed, then the shift direction must be to the
// right regardless of mantissa bits; the number is denormalized.
// Otherwise the shift direction must be to the left.
// ----------------------------------------------------------------------------
reg [7:0] lshiftAmt6;
reg [7:0] rshiftAmt6;
reg rightOrLeft6;	// 0=left,1=right
reg xInf6;
reg [fp16Pkg::EMSB:0] xo6;
reg [fp16Pkg::FMSB+5:0] mo6;
reg zeroMan6;
always_comb
	rightOrLeft6 <= under3;
always_comb
	xo6 <= xo5;
always_comb
	mo6 <= mo4;
always_comb
	xInf6 <= xInf5;
always_comb
	zeroMan6 <= zeroMan3;

always_comb
	lshiftAmt6 <= leadingZeros5 > xo5 ? xo5 : leadingZeros5;

always_comb
	rshiftAmt6 <= xInf5 ? 1'd0 : $signed(xo5) > 1'd0 ? 1'd0 : ~xo5+2'd1;	// xo2 is negative !

// ----------------------------------------------------------------------------
// Clock edge #7
// - figure exponent
// - shift mantissa
// - figure sticky bit
// ----------------------------------------------------------------------------

reg [fp16Pkg::EMSB:0] xo7;
reg rightOrLeft7;
reg [fp16Pkg::FMSB+5:0] mo7l, mo7r;
reg St6,St7;
always_comb
	rightOrLeft7 <= rightOrLeft6;
always_comb
	xo7 <= zeroMan6 ? xo6 :
		xInf6 ? xo6 :					// an infinite exponent is either a NaN or infinity; no need to change
		rightOrLeft6 ? 1'd0 :	// on a right shift, the exponent was negative, it's being made to zero
		xo6 - lshiftAmt6;			// on a left shift, the exponent can't be decremented below zero

always_comb
	mo7r <= mo6 >> rshiftAmt6;
always_comb
	mo7l <= mo6 << lshiftAmt6;

// The sticky bit is set if the bits shifted out on a right shift are set.
always_comb
begin
  St6 = 1'b0;
  for (n = 0; n < fp16Pkg::FMSB+5; n = n + 1)
    if (n <= rshiftAmt6 + 1) St6 = St6|mo6[n];
end
always_comb
  St7 <= St6;

// ----------------------------------------------------------------------------
// Clock edge #8
// - select mantissa
// ----------------------------------------------------------------------------

reg so;
reg [fp16Pkg::EMSB:0] xo;
reg [fp16Pkg::FMSB+5:0] mo;

always_comb
	 so <= so3;
always_comb
	 xo <= xo7;
always_comb
	 inexact_o <= inexact4;
always_comb
	 under_o <= rightOrLeft7;
always_comb
	 mo <= rightOrLeft7 ? mo7r|{St7,2'b0} : mo7l;

assign o.sign = so;
assign o.exp = xo;
assign o.sig = mo[fp16Pkg::FMSB+5:2];

endmodule
	

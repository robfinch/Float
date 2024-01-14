// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpNormalize128Combo.sv
//    - floating point normalization unit
//    - combinational logic
//    - IEEE 754 representation
//
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
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

import fp128Pkg::*;

module fpNormalize128Combo(i, o, under_i, under_o, inexact_o);
input [fp128Pkg::EX:0] i;		// expanded format input
output [fp128Pkg::MSB+3:0] o;		// normalized output + guard, sticky and round bits, + 1 whole digit
input under_i;
output under_o;
output inexact_o;

integer n;
// ----------------------------------------------------------------------------
// No Clock required
// ----------------------------------------------------------------------------
reg [fp128Pkg::EMSB:0] xo0;
reg so0;

always_comb
	xo0 <= i[fp128Pkg::EX-1:fp128Pkg::FX+1];
always_comb
	so0 <= i[fp128Pkg::EX];		// sign doesn't change

// ----------------------------------------------------------------------------
// Clock #1
// - Capture exponent information
// ----------------------------------------------------------------------------
reg xInf1a, xInf1b, xInf1c;
wire [fp128Pkg::FX:0] i1;
assign i1 = i;

always_comb
	 xInf1a <= &xo0 & !under_i;
always_comb
	 xInf1b <= &xo0[fp128Pkg::EMSB:1] & !under_i;
always_comb
	 xInf1c = &xo0;

// ----------------------------------------------------------------------------
// Clock #2
// - determine exponent increment
// Since the there are *three* whole digits in the incoming format
// the number of whole digits needs to be reduced. If the MSB is
// set, then increment the exponent and no shift is needed.
// ----------------------------------------------------------------------------
wire xInf2c, xInf2b;
wire [fp128Pkg::EMSB:0] xo2;
reg incExpByOne2, incExpByTwo2;
assign xInf2c = xInf1c;
assign xInf2b = xInf1b;
assign xo2 = xo0;
assign under2 = under_i;

always_comb
	 incExpByTwo2 <= !xInf1b & i1[fp128Pkg::FX];
always_comb
	 incExpByOne2 <= !xInf1a & i1[fp128Pkg::FX-1];

// ----------------------------------------------------------------------------
// Clock #3
// - increment exponent
// - detect a zero mantissa
// ----------------------------------------------------------------------------

wire incExpByTwo3;
wire incExpByOne3;
wire [fp128Pkg::FX:0] i3;
reg [fp128Pkg::EMSB:0] xo3;
reg zeroMan3;
assign incExpByTwo3 = incExpByTwo2;
assign incExpByOne3 = incExpByOne2;
assign i3 = i[fp128Pkg::FX:0];
wire [fp128Pkg::EMSB+1:0] xv3a = xo2 + {incExpByTwo2,1'b0};
wire [fp128Pkg::EMSB+1:0] xv3b = xo2 + incExpByOne2;

always_comb
	 xo3 <= xo2 + (incExpByTwo2 ? 2'd2 : incExpByOne2 ? 2'd1 : 2'd0);

always_comb
	if(ce) zeroMan3 <= ((xv3b[fp128Pkg::EMSB+1]|| &xv3b[fp128Pkg::EMSB:0])||(xv3a[fp128Pkg::EMSB+1]| &xv3a[fp128Pkg::EMSB:0]))
											 && !under2 && !xInf2c;

// ----------------------------------------------------------------------------
// Clock #4
// - Shift mantissa left
// - If infinity is reached then set the mantissa to zero
//   shift mantissa left to reduce to a single whole digit
// - create sticky bit
// ----------------------------------------------------------------------------

reg [fp128Pkg::FMSB+5:0] mo4;
reg inexact4;

always_comb
if(ce)
casez({zeroMan3,incExpByTwo3,incExpByOne3})
3'b1??:	mo4 <= 1'd0;
3'b01?:	mo4 <= {i3[fp128Pkg::FX:fp128Pkg::FMSB],|i3[fp128Pkg::FMSB-1:0]};
3'b001:	mo4 <= {i3[fp128Pkg::FX-1:fp128Pkg::FMSB-1],|i3[fp128Pkg::FMSB-2:0]};
default:	mo4 <= {i3[fp128Pkg::FX-2:fp128Pkg::FMSB-2],|i3[fp128Pkg::FMSB-3:0]};
endcase

always_comb
if(ce)
casez({zeroMan3,incExpByTwo3,incExpByOne3})
3'b1??:	inexact4 <= 1'd0;
3'b01?:	inexact4 <= |i3[fp128Pkg::FMSB+1:0];
3'b001:	inexact4 <= |i3[fp128Pkg::FMSB:0];
default:	inexact4 <= |i3[fp128Pkg::FMSB-1:0];
endcase

// ----------------------------------------------------------------------------
// Clock edge #5
// - count leading zeros
// ----------------------------------------------------------------------------
reg [7:0] leadingZeros5;
wire [fp128Pkg::EMSB:0] xo5;
wire xInf5;
assign xo5 = xo3;
assign xInf5 = xInf2c;

/* Lookup table based leading zero count modules give slightly better
   performance but cases must be coded.
generate
begin
if (FPWID <= 32) begin
cntlz32Reg clz0 (.clk(clk), .ce(ce), .i({mo4,4'b0}), .o(leadingZeros5) );
assign leadingZeros5[7:6] = 2'b00;
end
else if (FPWID<=64) begin
assign leadingZeros5[7] = 1'b0;
cntlz64Reg clz0 (.clk(clk), .ce(ce), .i({mo4,7'h0}), .o(leadingZeros5) );
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
always @*
begin
  got_one = 1'b0;
  lzc = 8'h00;
  for (n = fp128Pkg::FMSB+5; n >= 0; n = n - 1) begin
    if (!got_one) begin
      if (mo4[n])
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

casez(mo4[fp128Pkg::FMSB+5:fp128Pkg::FMSB+4])
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
wire rightOrLeft6;	// 0=left,1=right
wire xInf6;
wire [fp128Pkg::EMSB:0] xo6;
wire [fp128Pkg::FMSB+5:0] mo6;
wire zeroMan6;

assign rightOrLeft6 = under_i;
assign xo6 = xo5;
assign mo6 = mo4;
assign xInf6 = xInf5;
assign zeroMan6 = zeroMan3;

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

reg [fp128Pkg::EMSB:0] xo7;
wire rightOrLeft7;
reg [fp128Pkg::FMSB+5:0] mo7l, mo7r;
reg St6,St7;

assign rightOrLeft7 = rightOrLeft6;

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
  for (n = 0; n < FMSB+5; n = n + 1)
    if (n <= rshiftAmt6 + 1) St6 = St6|mo6[n];
end
always_comb
   St7 <= St6;

// ----------------------------------------------------------------------------
// Clock edge #8
// - select mantissa
// ----------------------------------------------------------------------------

wire so;
wire [fp128Pkg::EMSB:0] xo;
reg [fp128Pkg::FMSB+5:0] mo;

assign so = so0;
assign xo = xo7;
assign inexact_o = inexact4;
assign under_o = rightOrLeft7;

always_comb
	 mo <= rightOrLeft7 ? mo7r|{St7,2'b0} : mo7l;

assign o = {so,xo,mo[FMSB+5:2]};

endmodule
	

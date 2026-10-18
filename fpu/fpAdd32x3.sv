// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpAddsub32x3.sv
//    - 3 input floating point adder
//    - can issue every clock cycle
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
// Operand a, b, c are all assumed to be positive.
// ============================================================================

import fp32Pkg::*;

module fpAdd32x3(clk, ce, rm, a, b, c, o);
input clk;		// system clock
input ce;		// core clock enable
input [2:0] rm;	// rounding mode
input FP32 a;	// operand a
input FP32 b;	// operand b
input FP32 c;	// operand c
output FP32X o;	// output


// variables
// operands sign,exponent,mantissa
wire sa, sb, sc;
wire [fp32Pkg::EMSB:0] xa, xb, xc;
wire [fp32Pkg::FMSB:0] ma, mb, mc;
wire [fp32Pkg::FMSB+1:0] fracta, fractb, fractc;
wire az, bz;	// operand a,b is zero

wire adn, bdn, cdn;		// a,b,c denormalized ?
wire xaInf, xbInf, xcInf;
wire aInf, bInf, cInf;
wire aNan, bNan, cNan;

wire [fp32Pkg::EMSB:0] xad = xa|(adn&~az);	// operand a exponent, compensated for denormalized numbers
wire [fp32Pkg::EMSB:0] xbd = xb|(bdn&~bz); // operand b exponent, compensated for denormalized numbers
wire [fp32Pkg::EMSB:0] xcd = xc|(cdn&~cz); // operand c exponent, compensated for denormalized numbers

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Clock #1
// - decode the input operands
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
reg op1;

fpDecomp32Reg u1a (.clk(clk), .ce(ce), .i(a), .sgn(sa), .exp(xa), .man(ma), .fract(fracta), .xz(adn), .vz(az), .xinf(xaInf), .inf(aInf), .nan(aNan) );
fpDecomp32Reg u1b (.clk(clk), .ce(ce), .i(b), .sgn(sb), .exp(xb), .man(mb), .fract(fractb), .xz(bdn), .vz(bz), .xinf(xbInf), .inf(bInf), .nan(bNan) );
fpDecomp32Reg u1c (.clk(clk), .ce(ce), .i(c), .sgn(sc), .exp(xc), .man(mc), .fract(fractc), .xz(cdn), .vz(cz), .xinf(xcInf), .inf(cInf), .nan(cNan) );

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Clock #2
//
// Compute output exponent
//
// The output exponent is the largest of the three exponents.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

reg [fp32Pkg::EMSB:0] xa4, xb4, xc4;
reg [fp32Pkg::EMSB:0] xo4;

always @(posedge clk)
  if (ce) xa4 <= xad;
always @(posedge clk)
  if (ce) xb4 <= xbd;
always @(posedge clk)
  if (ce) xc4 <= xcd;
always @(posedge clk)
	if (ce) xo4 <= (xaInf|xbInf|xcInf) ? {fp32Pkg::EMSB+1{1'b1}} : az&bz&cz ? 0 : xad > xbd && xad > xcd ? xad : xbd > xcd ? xbd : xcd;

// Compute output sign
reg so4;
always_comb
	so4 = 1'b0;

// Compute the difference in exponents, provides shift amount
reg [fp32Pkg::EMSB+1:0] xdiff5a,xdiff5b,xdiff5c;
always_ff @(posedge clk)
	if (ce)
		if (xad > xbd && xad > xcd) begin
			xdiff5a <= 0;
			xdiff5b <= xad - xbd;
			xdiff5c <= xad - xcd;
		end
		else if (xbd > xcd) begin
			xdiff5b <= 0;
			xdiff5a <= xbd - xad;
			xdiff5c <= xbd - xcd;
		end
		else begin
			xdiff5c <= 0;
			xdiff5a <= xcd - xad;
			xdiff5b <= xcd - xbd;
		end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Clock #3
//
// Limit
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// If the difference in the exponent is 128 or greater (assuming 128 bit fp or
// less) then all of the bits will be shifted out to zero. There is no need to
// keep track of a difference more than 128.
reg [7:0] xdif6a,xdif6b,xdif6c;
wire [fp32Pkg::FMSB+1:0] mfs6a,mfs6b,mfs6c;
always @(posedge clk) if (ce) xdif6a <= xdiff5a > fp32Pkg::FMSB+4 ? fp32Pkg::FMSB+4 : xdiff5a;
always @(posedge clk) if (ce) xdif6b <= xdiff5b > fp32Pkg::FMSB+4 ? fp32Pkg::FMSB+4 : xdiff5b;
always @(posedge clk) if (ce) xdif6c <= xdiff5c > fp32Pkg::FMSB+4 ? fp32Pkg::FMSB+4 : xdiff5c;
ft_delay #(.WID(fp32Pkg::FMSB+2), .DEP(2)) udly6a (.clk(clk), .ce(ce), .i(ma), .o(mfs6a));
ft_delay #(.WID(fp32Pkg::FMSB+2), .DEP(2)) udly6b (.clk(clk), .ce(ce), .i(mb), .o(mfs6b));
ft_delay #(.WID(fp32Pkg::FMSB+2), .DEP(2)) udly6c (.clk(clk), .ce(ce), .i(mc), .o(mfs6c));

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Clock #4
//
// Determine the sticky bit. The sticky bit is the bitwise or of all the bits
// being shifted out the right side. The sticky bit is computed here to
// reduce the number of regs required.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
reg sticky6a,sticky6b,sticky6c;
wire sticky7a,sticky7b,sticky7c;
wire [7:0] xdif7a,xdif7b,xdif7c;
wire [fp32Pkg::FMSB+1:0] mfs7a,mfs7b,mfs7c;
integer n;
always_comb begin
	sticky6a = 1'b0;
	for (n = 0; n < fp32Pkg::FMSB+2; n = n + 1)
		if (n <= xdif6a)
			sticky6a = sticky6a|mfs6a[n];
end
always_comb begin
	sticky6b = 1'b0;
	for (n = 0; n < fp32Pkg::FMSB+2; n = n + 1)
		if (n <= xdif6b)
			sticky6b = sticky6b|mfs6b[n];
end
always_comb begin
	sticky6c = 1'b0;
	for (n = 0; n < fp32Pkg::FMSB+2; n = n + 1)
		if (n <= xdif6c)
			sticky6c = sticky6c|mfs6c[n];
end

// register inputs to shifter and shift
delay1 #(1)      d70(.clk(clk), .ce(ce), .i(sticky6a), .o(sticky7a) );
delay1 #(1)      d71(.clk(clk), .ce(ce), .i(sticky6b), .o(sticky7b) );
delay1 #(1)      d72(.clk(clk), .ce(ce), .i(sticky6c), .o(sticky7c) );
delay1 #(8)      d73(.clk(clk), .ce(ce), .i(xdif6a),   .o(xdif7a) );
delay1 #(8)      d74(.clk(clk), .ce(ce), .i(xdif6b),   .o(xdif7b) );
delay1 #(8)      d75(.clk(clk), .ce(ce), .i(xdif6c),   .o(xdif7c) );
delay1 #(fp32Pkg::FMSB+2) d76(.clk(clk), .ce(ce), .i(mfs6a),    .o(mfs7a) );
delay1 #(fp32Pkg::FMSB+2) d77(.clk(clk), .ce(ce), .i(mfs6b),    .o(mfs7b) );
delay1 #(fp32Pkg::FMSB+2) d78(.clk(clk), .ce(ce), .i(mfs6c),    .o(mfs7c) );

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Clock #5
// align significands
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
reg [fp32Pkg::FMSB+4:0] md8a, md8b, md8c;
wire [fp32Pkg::FMSB+1:0] fracta8, fractb8, fractc8;
always @(posedge clk) if (ce) md8a <= ({mfs7a,3'b0} >> xdif7a)|sticky7a;
always @(posedge clk) if (ce) md8b <= ({mfs7b,3'b0} >> xdif7b)|sticky7b;
always @(posedge clk) if (ce) md8c <= ({mfs7c,3'b0} >> xdif7c)|sticky7c;

// sync control signals
ft_delay #(.WID(fp32Pkg::FMSB+2), .DEP(4)) udly8d (.clk(clk), .ce(ce), .i(fracta), .o(fracta8));
ft_delay #(.WID(fp32Pkg::FMSB+2), .DEP(4)) udly8e (.clk(clk), .ce(ce), .i(fractb), .o(fractb8));
ft_delay #(.WID(fp32Pkg::FMSB+2), .DEP(4)) udly8f (.clk(clk), .ce(ce), .i(fractc), .o(fractc8));

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Clock #6
// Perform add
// addition can generate an extra bit
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
reg [fp32Pkg::FMSB+4:0] mo9;
wire [fp32Pkg::FMSB+1:0] fracta9, fractb9, fractc9;
wire [fp32Pkg::EMSB:0] xo8;
wire abcInf9;
wire aNan9, bNan9, cNan9;
reg xoinf9;
always_ff @(posedge clk)
  if (ce) mo9 <= md8a + md8b + md8c;

ft_delay #(.WID(fp32Pkg::EMSB+1), .DEP(3)) udly11i (.clk(clk), .ce(ce), .i(xo4), .o(xo8));
ft_delay #(.WID(1), .DEP(5)) udly11a (.clk(clk), .ce(ce), .i(aInf|bInf|cInf), .o(abcInf9));
ft_delay #(.WID(1), .DEP(5)) udly11c (.clk(clk), .ce(ce), .i(aNan), .o(aNan9));
ft_delay #(.WID(1), .DEP(5)) udly11d (.clk(clk), .ce(ce), .i(bNan), .o(bNan9));
ft_delay #(.WID(1), .DEP(5)) udly11e (.clk(clk), .ce(ce), .i(cNan), .o(cNan9));
ft_delay #(.WID(fp32Pkg::FMSB+2), .DEP(1)) udly11f (.clk(clk), .ce(ce), .i(fracta8), .o(fracta9));
ft_delay #(.WID(fp32Pkg::FMSB+2), .DEP(1)) udly11g (.clk(clk), .ce(ce), .i(fractb8), .o(fractb9));
ft_delay #(.WID(fp32Pkg::FMSB+2), .DEP(1)) udly11h (.clk(clk), .ce(ce), .i(fractc8), .o(fractc9));

always_ff @(posedge clk)
  if (ce) xoinf9 <= &xo8;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Clock #7
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
reg [fp32Pkg::FX:0] mo10;	// mantissa output
wire [fp32Pkg::EMSB:0] xo10;

ft_delay #(.WID(fp32Pkg::EMSB+1), .DEP(2)) udly7i (.clk(clk), .ce(ce), .i(xo8), .o(xo10));

always @(posedge clk)
if (ce)
	casez({abcInf9,aNan9,bNan9,cNan9,xoinf9})
	5'b1????:	mo10 <= {1'b0,1'b0,{fp32Pkg::FMSB-1{1'b0}},1'b0,{fp32Pkg::FMSB{1'b0}}};	// inf + inf = inf
	5'b01???:	mo10 <= {1'b0,fracta9[fp32Pkg::FMSB+1:0],{fp32Pkg::FMSB{1'b0}}};
	5'b001??: mo10 <= {1'b0,fractb9[fp32Pkg::FMSB+1:0],{fp32Pkg::FMSB{1'b0}}};
	5'b0001?: mo10 <= {1'b0,fractc9[fp32Pkg::FMSB+1:0],{fp32Pkg::FMSB{1'b0}}};
	5'b00001:	mo10 <= 'd0;
	default:	mo10 <= {mo9,{fp32Pkg::FMSB-2{1'b0}}};	// mab has an extra lead bit and three trailing bits
	endcase

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Clock #8
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
wire so;			// sign output
wire [fp32Pkg::EMSB:0] xo;	// de normalized exponent output
wire [fp32Pkg::FX:0] mo;	// mantissa output

ft_delay #(.WID(1), .DEP(7)) udly13a (.clk(clk), .ce(ce), .i(so4), .o(so));
ft_delay #(.WID(fp32Pkg::EMSB+1), .DEP(3)) udly13b (.clk(clk), .ce(ce), .i(xo10), .o(xo));
ft_delay #(.WID(fp32Pkg::FX+1), .DEP(1)) u13c (.clk(clk), .ce(ce), .i(mo10), .o(mo) );

assign o.sign = so;
assign o.exp = xo;
assign o.sig = mo;

endmodule


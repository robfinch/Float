`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpSincos_tb.sv
//		- floating point sin/cosine test bench
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
//	Floating Point Multiplier / Divider
//
//	This multiplier/divider handles denormalized numbers.
//	The output format is of an internal expanded representation
//	in preparation to be fed into a normalization unit, then
//	rounding. Basically, it's the same as the regular format
//	except the mantissa is doubled in size, the leading two
//	bits of which are assumed to be whole bits.
//
//
// ============================================================================

import fp64Pkg::*;

module fpSincos_tb();
reg rst;
reg clk;
reg [15:0] adr;
reg [63:0] b;
wire [63:0] o;
reg [63:0] ad,bd;
wire [63:0] od;
reg [3:0] rm;
wire [63:0] sin, cos;
real a,aa,ab,ac;
//wire [63:0] doubleA = {a[31], a[30], {3{~a[30]}}, a[29:23], a[22:0], {29{1'b0}}};
//wire [63:0] doubleB = {b[31], b[30], {3{~b[30]}}, b[29:23], b[22:0], {29{1'b0}}};

integer outfile;

initial begin
	rst = 1'b0;
	clk = 1'b0;
	adr = 0;
	a = $urandom(1);
	#20 rst = 1;
	#50 rst = 0;
	#1000000  $fclose(outfile);
	#10 $finish;
end

always #5
	clk = ~clk;

reg [7:0] count;
wire ld = count==4;
always @(posedge clk)
if (rst) begin
	adr <= 0;
	count <= 0;
	a <= 0.0;
end
else
begin
  if (adr==0) begin
    outfile = $fopen("f:/cores2023/Float/fpu/test_bench/fpSincos_tvo.txt", "wb");
    $fwrite(outfile, "rm ------ A ------  ------ SIN -----  ---- SIM sin ---- ------ COS -----  ---- SIM cos ---\n");
  end
	count <= count + 1;
	if (count > 76)
		count <= 1'd1;
	if (ld) begin	
		a <= a + 0.01;
//		a.sign = 1'b0;
//		a.exp = 11'h3fe;
//		a.sig = {$urandom(),20'd0};
		rm <= 3'd0;
//		a[31:0] <= $urandom();
//		a[63:32] <= $urandom();
//		rm <= adr[15:13];
		//ad <= memd[adr][63: 0];
		//bd <= memd[adr][127:64];
	end
	if (count==76) begin
		aa <= a;
		ab <= aa;
		ac <= ab;
	  $fwrite(outfile, "%h\t%h\t%h\t%h\t%h\t%h\n", rm, $realtobits(ab), sin, $realtobits($sin(ab)), cos, $realtobits($cos(ab)));
		adr <= adr + 1;
	end
end

fpSincos64 u6 (rst, clk, 3'd0, ld, $realtobits(a), sin, cos);

endmodule

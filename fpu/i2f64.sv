// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	i2f64.sv
//  - convert integer to floating point
//  - parameterized width
//  - IEEE 754 representation
//  - pipelineable
//  - single cycle latency
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
// ============================================================================

import fp64Pkg::*;

module i2f64 (clk, ce, op, rm, i, o);
input clk;
input ce;
input op;						// 1 = signed, 0 = unsigned
input [2:0] rm;			// rounding mode
input [fp64Pkg::FPWID-1:0] i;		// integer input
output [fp64Pkg::FPWID-1:0] o;		// float output

wire [fp64Pkg::EMSB:0] zeroXp = {fp64Pkg::EMSB{1'b1}};

wire iz;			// zero input ?
wire [fp64Pkg::MSB:0] imag;	// get magnitude of i
wire [fp64Pkg::MSB:0] imag1 = (op & i[fp64Pkg::MSB]) ? -i : i;
wire [7:0] lz;		// count the leading zeros in the number
wire [fp64Pkg::EMSB:0] wd;	// compute number of whole digits
wire so;			// copy the sign of the input (easy)
wire [2:0] rmd;

delay1 #(3)   u0 (.clk(clk), .ce(ce), .i(rm),     .o(rmd) );
delay1 #(1)   u1 (.clk(clk), .ce(ce), .i(i==0),   .o(iz) );
delay1 #(fp64Pkg::FPWID) u2 (.clk(clk), .ce(ce), .i(imag1),  .o(imag) );
delay1 #(1)   u3 (.clk(clk), .ce(ce), .i(i[MSB]), .o(so) );
cntlz128Reg    u4 (.clk(clk), .ce(ce), .i(imag1), .o(lz[5:0]) );
assign lz[7:6]=2'b00;

assign wd = zeroXp - 1 + fp64Pkg::FPWID - lz;	// constant except for lz

wire [fp64Pkg::EMSB:0] xo = iz ? 0 : wd;
wire [fp64Pkg::MSB:0] simag = imag << lz;		// left align number

wire g =  simag[fp64Pkg::EMSB+2];	// guard bit (lsb)
wire r =  simag[fp64Pkg::EMSB+1];	// rounding bit
wire s = |simag[fp64Pkg::EMSB:0];	// "sticky" bit
reg rnd;

// Compute the round bit
always @(rmd,g,r,s,so)
	case (rmd)
	3'd0:	rnd = (g & r) | (r & s);	// round to nearest even
	3'd1:	rnd = 0;					// round to zero (truncate)
	3'd2:	rnd = (r | s) & !so;		// round towards +infinity
	3'd3:	rnd = (r | s) & so;			// round towards -infinity
	3'd4:   rnd = (r | s);
	default:	rnd = (g & r) | (r & s);	// round to nearest even
	endcase

// "hide" the leading one bit = MSB-1
// round the result
wire [fp64Pkg::FMSB:0] mo = simag[fp64Pkg::MSB-1:fp64Pkg::EMSB+1]+rnd;

assign o = {op & so,xo,mo};

endmodule

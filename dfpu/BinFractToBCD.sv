`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	BinFractToBCD.sv
//	- convert binary fraction to BCD
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

module BinFractToBCD(rst, clk, ld, i, o, done);
parameter WID=116;
localparam OWID = ((WID+(WID-4)/3+3) & -4);
input rst;
input clk;
input ld;
input [WID-1:0] i;
output reg [OWID-1:0] o;
output reg done;

reg [5:0] iter;
reg [WID+4-1:0] bin;
reg [WID+4-1:0] p;
always_comb
	p = (bin + (bin << 2'd2)) << 2'd1;

reg [1:0] state;
parameter IDLE = 2'd0;
parameter CVT = 2'd1;

always_ff @(posedge clk)
if (rst)
	done <= 1'b1;
else begin
	if (ld) begin
		iter <= OWID/4;
		bin <= {4'h0,i[WID-5:0],4'h0};
		o <= i[WID-1:WID-4];	// capture leading one if present.
		state <= CVT;
		done <= 1'b0;
	end
	case(state)
	IDLE:	;
	CVT:
		begin
			iter <= iter - 2'd1;
			o <= {o,p[WID+3:WID]};
			bin <= {4'h0,p[WID-1:0]};
			if (iter==6'd2) begin
				done <= 1'b1;
				state <= IDLE;
			end
		end
	default:	state <= IDLE;
	endcase
end

endmodule

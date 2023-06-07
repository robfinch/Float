`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2010-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	isqrt.v
//	- integer square root
//  - uses the standard long form calc.
//	- geared towards use in an floating point unit
//	- calculates to WID fractional precision (double width output)
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

module isqrt(rst, clk, ce, ld, a, o, done);
parameter WID = 32;
localparam MSB = WID-1;
input rst;
input clk;
input ce;
input ld;
input [MSB:0] a;
output [WID*2-1:0] o;
output done;

typedef enum logic [1:0] {
	IDLE = 2'd0,
	CALC,
	DONE
} state_t;
state_t state;

reg [WID*2:0] root;
wire [WID*2-1:0] testDiv;
reg [WID*2-1:0] remLo;
reg [WID*2-1:0] remHi;
wire [WID*2-1:0] remHiShift;

wire cnt_done;
assign testDiv = {root[WID*2-2:0],1'b1};
assign remHiShift = {remHi[WID*2-3:0],remLo[WID*2-1:WID*2-2]};
wire doesGoInto = remHiShift >= testDiv;
assign o = root[WID*2:1];

// Iteration counter
reg [7:0] cnt;

always_ff @(posedge clk)
if (rst) begin
	cnt <= WID*2;
	remLo <= {WID*2{1'b0}};
	remHi <= {WID*2{1'b0}};
	root <= {WID*2+1{1'b0}};
	state <= IDLE;
end
else
begin
	if (ce) begin
		if (!cnt_done)
			cnt <= cnt + 8'd1;
		case(state)
		IDLE:	;
		CALC:
			if (!cnt_done) begin
				// Shift the remainder low
				remLo <= {remLo[WID*2-3:0],2'd0};
				// Shift the remainder high
				remHi <= doesGoInto ? remHiShift - testDiv: remHiShift;
				// Shift the root
				root <= {root+doesGoInto,1'b0};	// root * 2 + 1/0
			end
			else begin
				cnt <= 8'h00;
				state <= DONE;
			end
		DONE:
			begin
				cnt <= cnt + 8'd1;
				if (cnt == 8'd6)
					state <= IDLE;
			end
		default: state <= IDLE;
		endcase
		if (ld) begin
			cnt <= 8'd0;
			state <= CALC;
			remLo <= {a,32'd0};
			remHi <= {WID*2{1'b0}};
			root <= {WID*2+1{1'b0}};
		end
	end
end
assign cnt_done = (cnt==WID);
assign done = state==DONE;

endmodule


module isqrt_tb();

reg clk;
reg rst;
reg [31:0] a;
wire [63:0] o;
reg ld;
wire done;
reg [7:0] state;

initial begin
	clk = 1;
	rst = 0;
	#100 rst = 1;
	#100 rst = 0;
end

always #10 clk = ~clk;	//  50 MHz

always @(posedge clk)
if (rst) begin
	state <= 8'd0;
	a <= 32'h912345;
end
else
begin
ld <= 1'b0;
case(state)
8'd0:
	begin	
		a <= 32'h9123456;
		ld <= 1'b1;
		state <= 8'd1;
	end
8'd1:
	if (done) begin
		$display("i=%h o=%h", a, o);
	end
endcase
end

isqrt #(32) u1 (.rst(rst), .clk(clk), .ce(1'b1), .ld(ld), .a(a), .o(o), .done(done));

endmodule



module BCDSubtract(clk, a, b, o, co);
parameter N=25;
input clk;
input [N*4-1:0] a;
input [N*4-1:0] b;
output reg [N*4-1:0] o;
output reg co;

wire [(N+1)*4-1:0] bc;
wire [(N+1)*4-1:0] o1, o2, o3;
wire c;

BCDNinesComplementN #(N+1) u1 (.i({4'h0,b}), .o(bc));
BCDAdd8NClk #(.N(N/2+1)) u2 (.clk(clk), .a({8'h00,a}), .b(bc), .o(o1), .ci(1'b0), .co(c));
BCDNinesComplementN #(N) u3 (.i(o1), .o(o2));
BCDAdd8NClk #(.N(N/2+1)) u4 (.clk(clk), .a(o1), .b({{N*8{1'b0}},1'b1}), .o(o3), .ci(1'b0), .co());

always_ff @(posedge clk)
	if (c)
		o <= o3;
	else
		o <= o2;
always_ff @(posedge clk)
	co <= c;

endmodule

module BCDNinesComplement(i, o);
input [3:0] i;
output reg [3:0] o;

always_comb
	case(i)
	4'd0:	o = 4'd9;
	4'd1:	o = 4'd8;
	4'd2:	o = 4'd7;
	4'd3:	o = 4'd6;
	4'd4: o = 4'd5;
	4'd5:	o = 4'd4;
	4'd6:	o = 4'd3;
	4'd7:	o = 4'd2;
	4'd8:	o = 4'd1;
	4'd9:	o = 4'd0;
	4'd10:	o = 4'd9;
	4'd11:	o = 4'd8;
	4'd12:	o = 4'd7;
	4'd13:	o = 4'd6;
	4'd14:	o = 4'd5;
	4'd15:	o = 4'd4;
	endcase

endmodule

module BCDNinesComplementN(i, o);
parameter N=25;
input [N*4-1:0] i;
output [N*4-1:0] o;

genvar g;
generate begin : gNC
	for (g = 0; g < N; g = g + 1)
		BCDNinesComplement utc1 (i[g*4+3:g*4],o[g*4+3:g*4]);
end
endgenerate

endmodule

module BCDTensComplement(i, o);
input [3:0] i;
output reg [3:0] o;

always_comb
	case(i)
	4'd0:	o = 4'd0;
	4'd1:	o = 4'd9;
	4'd2:	o = 4'd8;
	4'd3:	o = 4'd7;
	4'd4: o = 4'd6;
	4'd5:	o = 4'd5;
	4'd6:	o = 4'd4;
	4'd7:	o = 4'd3;
	4'd8:	o = 4'd2;
	4'd9:	o = 4'd1;
	4'd10:	o = 4'd0;
	4'd11:	o = 4'd9;
	4'd12:	o = 4'd8;
	4'd13:	o = 4'd7;
	4'd14:	o = 4'd6;
	4'd15:	o = 4'd5;
	endcase

endmodule

module BCDTensComplementN(i, o);
parameter N=25;
input [N*4-1:0] i;
output [N*4-1:0] o;

genvar g;
generate begin : gTC
	for (g = 0; g < N; g = g + 1)
		BCDTensComplement utc1 (i[g*4+3:g*4],o[g*4+3:g*4]);
end
endgenerate

endmodule

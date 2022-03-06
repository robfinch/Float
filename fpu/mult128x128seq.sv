module mult128x128seq(clk, ld, a, b, o);
input clk;
input ld;
input [127:0] a;
input [127:0] b;
output reg [255:0] o;

reg [127:0] aa = 'd0, bb ='d0;
reg [256:0] acc = 'd0;
wire [255:0] p1 = acc + bb;
reg [11:0] count = 'd0;

always_ff @(posedge clk)
begin
	if (ld) begin
		aa <= a;
		bb <= b;
		acc <= 'd0;
		count <= 12'd128;
	end
	else begin
		if (count) begin
			count <= count - 2'd1;
			if (aa[127])
				acc <= {p1,1'b0};
			else
				acc <= {acc,1'b0};
			aa <= {aa[126:0],1'b0};
		end
		else begin
			o <= acc[256:1];
		end
	end
end

endmodule

module quire();

reg [63:0] qmem [0:511];
reg [63:0] cgmem [0:31];

always @(posedge clk)
if (ce)
case(state)
  case(op)
endcase
endmodule

module positToQuire(clk, ce, i, o);
localparam M = PSTWID-es;
reg qs;
reg [2111:0] q;

wire s;
wire rgs;
wire [M-1:0] sig;
wire [rs:0] rgm;
wire [es:0] exp;
wire zer;
wire inf;

positDecomposeReg #(PSTWID) u1 (
  .clk(clk),
  .ce(ce),
  .i(i),
  .sgn(s),
  .rgs(rgs),
  .rgm(rgm),
  .exp(exp),
  .sig(sig),
  .zer(zer),
  .inf(inf)
);

always @(posedge clk)
if (ld) begin
end
else begin
case(state)
LD:
  begin
    rgmr <= rgm;
    q <= {2112{1'b0}};
    if (inf) begin
      qs <= 1'b1;
      state <= DONE;
    end
    else if (zer) begin
      qs <= 1'b0;
      state <= DONE;
    end
    else begin
      qs <= s;
      q[1024:1024-M] <= sig;
      state <= rs ? SHIFT_LEFT : SHIFT_RIGHT;
    end
  end
SHIFT_LEFT:
  begin
    if (rgm=={rs+1{1'b0}}) begin
      q <= q << exp;
      state <= DONE;
    end
    else begin
      q <= q << es;
      rgmr <= rgmr - 2'd1;
    end
  end
SHIFT_RIGHT:
  begin
    if (rgm=={rs+1{1'b0}}) begin
      q <= q >> exp;
      state <= DONE;
    end
    else begin
      q <= q >> es;
      rgmr <= rgmr - 2'd1;
    end
  end
endcase
end

endmodule

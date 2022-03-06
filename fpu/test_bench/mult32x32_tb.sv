// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	mult32x32_tb.sv
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

module mult32x32_tb();
reg clk;
reg [23:0] count;
reg [31:0] adr;

reg rst;
reg [31:0] a, b;
wire [63:0] o;
wire [63:0] p = a * b;

always #5 clk = ~clk;

mult32x32 u1 (clk, 1'b1, a, b, o);

integer outfile;

initial begin
	rst = 1'b0;
	clk = 1'b0;
	#20 rst = 1;
	#50 rst = 0;
	#10000000  $fclose(outfile);
	#10 $finish;
end

always #5
	clk = ~clk;
//a25e46ad	a76da76d	6a320c6f94e7f2a9	6a310c6f94e7f2a9*
//147c147c	67589e7f	08460393acd2b184	08450393acd2b184*

always_ff @(posedge clk)
if (rst) begin
	adr <= 0;
	count <= 0;
	a <= $urandom(1);
end
else
begin
  if (adr==0) begin
    outfile = $fopen("d:/cores2022/rf6809/rtl/fpu/test_bench/mult32x32_tvo.txt", "wb");
    $fwrite(outfile, "--- A ---  ---- B ----  - DUT Product -  - SIM Product -\n");
  end
	count <= count + 1;
	if (count > 12)
		count <= 1'd1;
	if (count==2) begin	
		case (adr)
	  1:
	    begin
	      a <= 32'ha25e46ad;
	      b <= 32'ha76da76d;
	    end
	  2:
	    begin
	      a <= 32'h147c147c;
	      b <= 32'h67589e7f;
	    end 
	  3:
	    begin
	      a <= 32'd215000;
	      b <= 32'd11;
	    end
	  default:
	  	begin
				a[31:0] <= $urandom();
				b[31:0] <= $urandom();
			end
	  endcase 
	end
	if (count==12) begin
	  $fwrite(outfile, "%h\t%h\t%h\t%h%c\n", a, b, o, p,p!=o ? "*":" ");
		adr <= adr + 1;
	end
end

endmodule

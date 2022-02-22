// ============================================================================
//        __
//   \\__/ o\    (C) 2020  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	positToQuire.sv
//    - convert posit number to quire format
//    - parameterized width
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

import posit::*;

module positToQuire(clk, ce, i, o);
input clk;
input ce;
input [PSTWID-1:0] i;
localparam NQ = PSTWID*PSTWID/4 - PSTWID/2;
output reg [PSTWIDTH+NQ*2-1:0] o;
localparam M = PSTWID-es;
reg qs;
reg [NQ+PSTWID-1:-NQ] q;

wire s;
wire rgs;
wire [M-1:0] sig;
wire [rs:0] rgm;
wire [es:0] exp;
wire zer;
wire inf;
reg [rs:0] rgmr;

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

reg [2:0] state = IDLE;
parameter IDLE = 3'd0;
parameter LOAD = 3'd1;
parameter SHIFT_LEFT = 3'd2;
parameter SHIFT_RIGHT = 3'd3;
parameter DONE = 3'd4;

reg [es-1:0] shamt;

// Determine amount to shift
always @*
begin
  if (rgmr=={rs+1{1'b0}})
    shamt <= exp;
  else if (rgmr >= es * 2)
    shamt <= (es * 2);
  else
    shamt <= es;
end

always @(posedge clk)
if (ce) begin
done <= 1'b0;
state <= IDLE;
case(state)
IDLE: ;
LOAD:
  begin
    rgmr <= rgs ? rgm : -rgm;
    q <= {PSTWIDTH+NQ*2{1'b0}};
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
      q[1:1-PSTWID] <= sig;  // "center" the value
      state <= rs ? SHIFT_LEFT : SHIFT_RIGHT;
    end
  end
SHIFT_LEFT:
  begin
    if (rgm=={rs+1{1'b0}})
      state <= DONE;
    else if (rgmr >= es * 2) begin
      rgmr <= rgmr - 2'd2;
      state <= SHIFT_LEFT;
    end
    else begin
      rgmr <= rgmr - 2'd1;
      state <= SHIFT_LEFT;
    end
    q <= q << shamt;
  end
SHIFT_RIGHT:
  begin
    if (rgm=={rs+1{1'b0}})
      state <= DONE;
    if (rgmr >= es * 2) begin
      rgmr <= rgmr - 2'd2;
      state <= SHIFT_RIGHT;
    end
    else begin
      rgmr <= rgmr - 2'd1;
      state <= SHIFT_RIGHT;
    end
    q <= q >> shamt;
  end
DONE:
  begin
    o <= {qs,q};
    done <= 1'b1;
    state <= IDLE;
  end
endcase
// Placed outside the case statment to allow operation to abort on a load.
if (ld)
  state <= LOAD;
end

endmodule

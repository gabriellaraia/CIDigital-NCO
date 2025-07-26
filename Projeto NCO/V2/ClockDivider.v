module ClockDividerFF (
  clk_in, clk_out
);

parameter CLK_IN_FREQ = 50000000;
parameter CLK_OUT_FREQ = 1000000;
parameter integer DIVISOR = CLK_IN_FREQ / (2 * CLK_OUT_FREQ);

`include "util.vh"

parameter TIMER_WIDTH = clog2(DIVISOR);

input clk_in;
output reg clk_out;

reg [TIMER_WIDTH:0] timer;

initial begin
  clk_out = 0;
  timer = 0;
end

always @(posedge clk_in) begin
  if (timer >= DIVISOR) begin
    clk_out <= ~clk_out;
    timer <= 0;
  end else begin
    timer <= timer + 1;
  end
end

endmodule
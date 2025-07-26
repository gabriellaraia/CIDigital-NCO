module ClockDividerFF #(
  parameter CLK_IN_FREQ, CLK_OUT_FREQ,
  parameter integer DIVISOR = ((1.0 / CLK_OUT_FREQ) / (1.0 / CLK_IN_FREQ)) / 2.0,
  parameter TIMER_WIDTH = clog2(DIVISOR)
)(
  input clk_in,
  output reg clk_out = 0
);
`include "util.vh"

reg [TIMER_WIDTH-1:0] timer = 0; // Correção
always @(posedge clk_in) begin
  timer <= timer + 1;

  if (timer >= DIVISOR -1) begin // Correção
    clk_out <= ~clk_out;
    timer <= 0;
  end
end

endmodule
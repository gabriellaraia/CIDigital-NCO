module ClockDividerFF #(
  parameter CLK_IN_FREQ, CLK_OUT_FREQ,
  parameter integer DIVISOR = ((1.0 * CLK_IN_FREQ) / (1.0 * CLK_OUT_FREQ)) / 2.0

)(
  input clk_in,
  output reg clk_out = 0
);
function integer clog2 (input integer value);
    integer temp;
    begin
        temp = value - 1;
        for (clog2 = 0; temp > 0; clog2 = clog2 + 1) begin
            temp = temp >> 1;
        end
    end
endfunction

  localparam TIMER_WIDTH = clog2(DIVISOR);

reg [TIMER_WIDTH-1:0] timer = 0;

always @(posedge clk_in) begin
  timer <= timer + 1;

  if (timer >= DIVISOR -1) begin
    clk_out <= ~clk_out;
    timer <= 0;
  end
end

endmodule
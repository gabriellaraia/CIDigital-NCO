module top_module (
  clk, rst, scl, sda, nco_out
);

parameter CLK_FREQ = 50000000;
parameter BIT_DEPTH = 12;
parameter SAMPLE_RATE = 1000000;
parameter [6:0] I2C_ADDR = 7'b1101010;

input clk;
input rst;
input scl;
inout sda;
output [BIT_DEPTH-1:0] nco_out;

wire enable;
wire [1:0] wave;
wire [63:0] frequency;
wire [15:0] duty_cycle;
wire nco_rst;

// Reset do NCO quando não habilitado
assign nco_rst = rst || ~enable;

// Instância do slave I2C
i2c_slave #(.ADDRESS(I2C_ADDR)) i2c_inst (
  .clk(clk),
  .rst(rst),
  .scl(scl),
  .sda(sda),
  .enable(enable),
  .wave(wave),
  .frequency(frequency),
  .duty_cycle(duty_cycle)
);

// Instância do NCO
NCO #(
  .CLK_FREQ(CLK_FREQ),
  .BIT_DEPTH(BIT_DEPTH),
  .SAMPLE_RATE(SAMPLE_RATE)
) nco_inst (
  .frequency(frequency),
  .wave(wave),
  .duty_cycle(duty_cycle[BIT_DEPTH-1:0]),
  .clk(clk),
  .rst(nco_rst),
  .out(nco_out)
);

endmodule
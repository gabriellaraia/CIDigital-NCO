`timescale 1ns / 100ps

`define SINE 		  0
`define TRIANGLE	1
`define SAWTOOTH	2
`define SQUARE		3

module NCO_tb;
  localparam MCLK = 100_000_000;
  localparam SAMPLE_RATE = 100_000_000;
  localparam BIT_DEPTH = 12;
  localparam SAMPLE_MAX = (1 << BIT_DEPTH) - 1;
  localparam DUTY_10 = SAMPLE_MAX / 10,
             DUTY_20 = DUTY_10 * 2,
             DUTY_30 = DUTY_10 * 3,
             DUTY_40 = DUTY_10 * 4,
             DUTY_50 = DUTY_10 * 5,
             DUTY_60 = DUTY_10 * 6,
             DUTY_70 = DUTY_10 * 7,
             DUTY_80 = DUTY_10 * 8,
             DUTY_90 = DUTY_10 * 9;


  reg [63:0] frequency;
  reg [1:0] wave [3:0];
  reg [BIT_DEPTH - 1: 0] duty_cycle = DUTY_50;
  reg clk = 0;
  wire [BIT_DEPTH - 1:0] out [3:0];
  
  

  NCO #(MCLK, BIT_DEPTH, SAMPLE_RATE) uut_saw (
    .frequency(frequency),
    .wave(wave[0]),
    .duty_cycle(duty_cycle),
    .clk(clk),
    .out(out[0])
  );

  NCO #(MCLK, BIT_DEPTH, SAMPLE_RATE) uut_tri (
    .frequency(frequency),
    .wave(wave[1]),
    .duty_cycle(duty_cycle),
    .clk(clk),
    .out(out[1])
  );

  NCO #(MCLK, BIT_DEPTH, SAMPLE_RATE) uut_sin (
    .frequency(frequency),
    .wave(wave[2]),
    .duty_cycle(duty_cycle),
    .clk(clk),
    .out(out[2])
  );

  NCO #(MCLK, BIT_DEPTH, SAMPLE_RATE) uut_sqr (
    .frequency(frequency),
    .wave(wave[3]),
    .duty_cycle(duty_cycle),
    .clk(clk),
    .out(out[3])
  );

  always #5 clk = ~clk;

  // Testa as frequencias de Dó[0:8]
  task run_test_C_octaves();
  begin
    frequency = 64'b0000000000000000000000000001000001011001100110011001100110011010; // 16.35Hz
    #125_000_000; // 125ms
    frequency = 64'b0000000000000000000000000010000010110011001100110011001100110011; // 32.70Hz
    #65_000_000;  // 65ms
    frequency = 64'b0000000000000000000000000100000101101000111101011100001010001111; // 65.41Hz
    #35_000_000;  // 35ms
    frequency = 64'b0000000000000000000000001000001011001111010111000010100011110110; // 130.81Hz
    #20_000_000;  // 20ms
    frequency = 64'b0000000000000000000000010000010110100001010001111010111000010100; // 261.63Hz
    #9_000_000;  // 12ms
    frequency = 64'b0000000000000000000000100000101101000000000000000000000000000000; // 523.25Hz
    #5_000_000;  // 5ms
    frequency = 64'b0000000000000000000001000001011010000000000000000000000000000000; // 1046.50Hz
    #3_000_000;  // 3ms
    frequency = 64'b0000000000000000000010000010110100000000000000000000000000000000; // 2093.0Hz
    #2_000_000;  // 2ms
    frequency = 64'b0000000000000000000100000101101000000010100011110101110000101001; // 4186.01Hz
    #1_000_000;  // 1ms
  end
  endtask

  // Testa frequencias arbitrarias de 10kHz até 50MHz
  task run_test_10K_to_50M();
  begin
    frequency = 64'b0000000000000000001001110001000000000000000000000000000000000000; // 10.0kHz
    #300_000;    // 300us
    frequency = 64'b0000000000000000111101000010010000000000000000000000000000000000; // 62.5kHz
    #32_500;     // 32.5us
    frequency = 64'b0000000000000001111010000100100000000000000000000000000000000000; // 125kHz
    #16_500;     // 16.5us
    frequency = 64'b0000000000000011110100001001000000000000000000000000000000000000; // 250kHz
    #8_500;      // 8.5us
    frequency = 64'b0000000000000111101000010010000000000000000000000000000000000000; // 500kHz
    #4_500;      // 4.5us
    frequency = 64'b0000000000001111010000100100000000000000000000000000000000000000; // 1.0MHz
    #2_500;      // 2.5us
    frequency = 64'b0000000001011111010111100001000000000000000000000000000000000000; // 6.25MHz
    #325;        // 325ns
    frequency = 64'b0000000010111110101111000010000000000000000000000000000000000000; // 12.5MHz
    #165;        // 165ns
    frequency = 64'b0000000101111101011110000100000000000000000000000000000000000000; // 25.0MHz
    #85;         // 80ns
    frequency = 64'b0000001011111010111100001000000000000000000000000000000000000000; // 50.0MHz
    #45;         // 45ns
  end
  endtask

  // Testa os diferentes valores de duty cycle
  task run_test_duty_cycle();
  begin
    frequency = 64'b0000000000000000001001110001000000000000000000000000000000000000; // 10.0kHz
    duty_cycle = DUTY_10; #300_000; // 10% duty | 300us
    duty_cycle = DUTY_20; #300_000; // 20% duty | 300us
    duty_cycle = DUTY_30; #300_000; // 30% duty | 300us
    duty_cycle = DUTY_40; #300_000; // 40% duty | 300us
    duty_cycle = DUTY_50; #300_000; // 50% duty | 300us
    duty_cycle = DUTY_60; #300_000; // 60% duty | 300us
    duty_cycle = DUTY_70; #300_000; // 70% duty | 300us
    duty_cycle = DUTY_80; #300_000; // 80% duty | 300us
    duty_cycle = DUTY_90; #300_000; // 90% duty | 300us
    duty_cycle = DUTY_80; #300_000; // 80% duty | 300us
    duty_cycle = DUTY_70; #300_000; // 70% duty | 300us
    duty_cycle = DUTY_60; #300_000; // 60% duty | 300us
    duty_cycle = DUTY_50; #300_000; // 50% duty | 300us
    duty_cycle = DUTY_40; #300_000; // 40% duty | 300us
    duty_cycle = DUTY_30; #300_000; // 30% duty | 300us
    duty_cycle = DUTY_20; #300_000; // 20% duty | 300us
    duty_cycle = DUTY_10; #300_000; // 10% duty | 300us
  end
  endtask

  initial begin
    wave[0] = `SAWTOOTH;
    wave[1] = `TRIANGLE;
    wave[2] = `SINE;
    wave[3] = `SQUARE;
    
    run_test_C_octaves();
    // run_test_10K_to_50M();
    // run_test_duty_cycle();
    
    $stop;
  end
endmodule
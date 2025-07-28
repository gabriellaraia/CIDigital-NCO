`timescale 1ns / 1ps

module tb_i2c_slave;

  reg clk;
  reg reset;
  reg scl;
  reg sda_driver;  
  wire sda;

  // Sinais de saída do escravo
  wire enable;
  wire [1:0] wave;
  wire [63:0] frequency;
  wire [15:0] duty_cycle;

  // SDA open-drain Força o 0 ou 1 (Simula alta impedância)
  assign sda = sda_driver ? 1'b1 : 1'b0;

  i2c_slave dut (
    .clk(clk),
    .reset(reset),
    .scl(scl),
    .sda(sda),
    .enable(enable),
    .wave(wave),
    .frequency(frequency),
    .duty_cycle(duty_cycle)
  );

  always #5 clk = ~clk;
  always #100 scl = ~scl;

  initial begin
    clk = 0;
    scl = 1;
    reset = 1;
    sda_driver = 1;
    #20 reset = 0;

    

    // ---- Teste 1 
    i2c_start();
    i2c_send_byte(8'b11010100);  // Endereço do escravo  
    i2c_ack();
    i2c_stop();

    // ---- Teste 2 
    #100;
    i2c_start();
    i2c_send_byte(8'b11010100);  // Endereço do escravo
    i2c_ack();
    i2c_send_byte(8'b00000001);  // enable=1 wave=00
    i2c_ack();
    i2c_stop();

    // ---- Teste 3 
    #100;
    i2c_start();
    i2c_send_byte(8'b11010100);  // Endereço do escravo
    i2c_ack();
    i2c_send_byte(8'b00000010);  // controle: Enable=0 Wave=01 Duty Cicle=0
    i2c_ack();
    i2c_send_byte(8'h2A);        // duty[15:8]
    i2c_ack();
    i2c_send_byte(8'h10);        // duty[7:0]
    i2c_ack();
    i2c_stop();

    // ---- Teste 4 - 
    #100;
    i2c_start();
    i2c_send_byte(8'b11010100);  // Endereço do escravo
    i2c_ack();
    i2c_send_byte(8'b00001000);  // controle: enable=0, wave=10 
    i2c_ack();
    i2c_send_byte(8'h00);        // frequency[63:56]
    i2c_ack();
    i2c_send_byte(8'h1A);        // ...
    i2c_ack();
    i2c_send_byte(8'h23);
    i2c_ack();
    i2c_send_byte(8'h33);
    i2c_ack();
    i2c_send_byte(8'hFE);
    i2c_ack();
    i2c_send_byte(8'h89);
    i2c_ack();
    i2c_send_byte(8'h50);
    i2c_ack();
    i2c_send_byte(8'h01);        // frequency[7:0] = 1
    i2c_ack();
    i2c_stop();

    #500;
    $stop;
  end

  // ---------------------------
  // TAREFAS AUXILIARES I2C
  // ---------------------------

  task i2c_start;
    begin
      sda_driver = 1; #5;
      sda_driver = 0; #5; // SDA desce com SCL alto
      scl = 0;
    end
  endtask

  task i2c_stop;
    begin
      scl = 1; #5;
      sda_driver = 0; #5;
      sda_driver = 1; #5; // SDA sobe com SCL alto
    end
  endtask

  task i2c_send_byte(input [7:0] byte);
    integer i;
    begin
      for (i = 7; i >= 0; i = i - 1) begin
        sda_driver = byte[i]; #5;
        scl = 1; #5;
        scl = 0; #5;
      end
    end
  endtask

  task i2c_ack;
    begin
      sda_driver = 1; // libera SDA
      #2;
      scl = 1; #5;
      scl = 0; #5;
    end
  endtask

endmodule

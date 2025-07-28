`timescale 1ns/100ps

module testbench;

reg clk;
reg rst;
reg scl;
reg sda_driver;
reg sda_drive_en;
wire sda;
wire [11:0] nco_out;

parameter [6:0] I2C_ADDR = 7'b1101010;

assign sda = sda_drive_en ? sda_driver : 1'bz;

// Instância do módulo top
top_module #(
  .CLK_FREQ(50000000),
  .BIT_DEPTH(12),
  .SAMPLE_RATE(1000000),
  .I2C_ADDR(I2C_ADDR)
) dut (
  .clk(clk),
  .rst(rst),
  .scl(scl),
  .sda(sda),
  .nco_out(nco_out)
);

// Clock de 50 MHz
initial begin
  clk = 0;
  forever #10 clk = ~clk;
end

initial begin
  $dumpfile("simulation.vcd");
  $dumpvars(0, testbench);
  
  rst = 1;
  scl = 1;
  sda_drive_en = 0;
  sda_driver = 1;
  #100;
  rst = 0;
  #100;

  $display("=== Test 1: Square wave at 1kHz ===");
  // Byte de controle: enable=1, wave=11 (square), update_freq=1, update_duty=1
  // Frequência: 1000 Hz = 0x000003E8
  // Duty cycle: 50% = 0x0800 (para 12 bits)
  i2c_write_control_and_data(8'h07, 64'h00000000000003E8, 16'h0800);
  #2000;

  $display("=== Test 2: Sine wave at 500Hz ===");
  // Byte de controle: enable=1, wave=00 (sine), update_freq=1
  i2c_write_control_and_freq(8'h03, 64'h00000000000001F4);
  #2000;

  $display("=== Test 3: Triangle wave at 2kHz ===");
  // Byte de controle: enable=1, wave=01 (triangle), update_freq=1
  i2c_write_control_and_freq(8'h05, 64'h00000000000007D0);
  #2000;

  $display("=== Test 4: Disable NCO ===");
  // Byte de controle: enable=0
  i2c_write_control_only(8'h00);
  #1000;

  $display("Simulation completed");
  $finish;
end

// Task para escrever apenas controle
task i2c_write_control_only;
  input [7:0] control;
  begin
    i2c_start();
    i2c_send_byte({I2C_ADDR, 1'b0});
    i2c_send_byte(control);
    i2c_stop();
    #200;
  end
endtask

// Task para escrever controle e frequência
task i2c_write_control_and_freq;
  input [7:0] control;
  input [63:0] freq_data;
  integer i;
  begin
    i2c_start();
    i2c_send_byte({I2C_ADDR, 1'b0});
    i2c_send_byte(control);
    
    // Envia 8 bytes de frequência (little endian)
    for (i = 0; i < 8; i = i + 1) begin
      i2c_send_byte(freq_data[i*8 +: 8]);
    end
    
    i2c_stop();
    #200;
  end
endtask

// Task para escrever controle, frequência e duty cycle
task i2c_write_control_and_data;
  input [7:0] control;
  input [63:0] freq_data;
  input [15:0] duty_data;
  integer i;
  begin
    i2c_start();
    i2c_send_byte({I2C_ADDR, 1'b0});
    i2c_send_byte(control);
    
    // Envia 8 bytes de frequência (little endian)
    for (i = 0; i < 8; i = i + 1) begin
      i2c_send_byte(freq_data[i*8 +: 8]);
    end
    
    // Envia 2 bytes de duty cycle (little endian)
    i2c_send_byte(duty_data[7:0]);
    i2c_send_byte(duty_data[15:8]);
    
    i2c_stop();
    #200;
  end
endtask

// START condition
task i2c_start;
  begin
    sda_driver = 1;
    sda_drive_en = 1;
    scl = 1;
    #50;
    sda_driver = 0;
    #50;
    scl = 0;
    #50;
  end
endtask

// STOP condition
task i2c_stop;
  begin
    sda_driver = 0;
    sda_drive_en = 1;
    scl = 0;
    #50;
    scl = 1;
    #50;
    sda_driver = 1;
    #50;
    sda_drive_en = 0;
  end
endtask

// Enviar um bit
task i2c_send_bit;
  input bit_val;
  begin
    sda_driver = bit_val;
    sda_drive_en = 1;
    #25;
    scl = 1;
    #50;
    scl = 0;
    #25;
  end
endtask

// Ler ACK
task i2c_read_ack;
  begin
    sda_drive_en = 0;
    #25;
    scl = 1;
    #50;
    if (sda !== 1'b0) begin
      $display("WARNING: No ACK received at time %t", $time);
    end
    scl = 0;
    #25;
  end
endtask

// Enviar um byte
task i2c_send_byte;
  input [7:0] byte_data;
  integer i;
  begin
    for (i = 7; i >= 0; i = i - 1) begin
      i2c_send_bit(byte_data[i]);
    end
    i2c_read_ack();
  end
endtask

endmodule
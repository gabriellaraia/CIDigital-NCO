`timescale 1ns/100ps

module i2c_slave_tb;
  reg clk;
  reg rst;
  reg scl;
  reg sda_driver = 1;
  reg sda_drive_en = 1;
  wire sda;

  wire        enable;
  wire [1:0]  wave;
  wire [63:0] frequency;
  wire [15:0] duty_cycle;
  

  assign sda = sda_drive_en ? sda_driver : 1'bz;
  pulldown(sda);

  parameter I2C_ADDR = 7'b1101010;

  i2c_slave #(.ADDRESS(I2C_ADDR)) dut (
    .clk(clk),
    .rst(rst),
    .scl(scl),
    .sda(sda),
    .enable(enable),
    .wave(wave),
    .frequency(frequency),
    .duty_cycle(duty_cycle)
  );
  
  localparam [7:0] CTRL_UPDATE_FQ = 8'b0000_1000;  // internal_control_reg[3]=1, [4]=0
  localparam [63:0] FREQ_DATA     = 64'b00000000_00000001_11010100_11000000_00000000_00000000_00000000_00000000;


  initial begin
    clk = 0;
    forever #10 clk = ~clk;  // 50 MHz clock
  end

  initial begin
    rst = 1;
    scl = 1;
    sda_drive_en = 1;
    sda_driver = 1;
    #50;
    rst = 0;

    //Test1: Send frequency data: 8 bytes
    //i2c_write_sequential_data({I2C_ADDR, 1'b0}, 64'b0000000000000001110101001100000000000000000000000000000000000000, 64);
	
	i2c_write_sequential_data(
		{I2C_ADDR,1'b0},
		{CTRL_UPDATE_FQ, FREQ_DATA},
		9*8
	);

    // Test2: Send duty cycle data: 2 bytes
    // 64'b00000000 0000000 1110101 0011000 0000000 0000000 0000000 0000000 0000000
    // 00z00000001z11010100z11000000z00000000z00000000z00000000z0000000
    //i2c_write_sequential_data({I2C_ADDR, 1'b0}, 16'hFACE, 16);

    $stop;
  end

  // Send a sequence of bits (multiple of 8)
    task i2c_write_sequential_data(input [7:0] slave_addr, input [8*9-1:0] data, input integer num_bits);
    integer i;
    integer num_bytes;
    begin
      num_bytes = (num_bits + 7) / 8; 

      i2c_start();
      i2c_send_byte(slave_addr);

      for (i = num_bytes - 1; i >= 0; i = i - 1) begin
          i2c_send_byte(data[8*i +: 8]);
      end

      i2c_stop();
      #200;
    end
  endtask


  // START condition (SDA falling while SCL is high)
  task i2c_start();
    begin
      sda_driver = 1;
      sda_drive_en = 1;
      scl = 1;
      #50;

      sda_driver = 0;
      #50;

      scl = 0;
      #100;
    end
  endtask

  // STOP condition (SDA raising while SCL is high)
  task i2c_stop();
    begin
      sda_driver = 0;
      scl = 1;
      #50;

      sda_driver = 1;
      sda_drive_en = 0;
      #50;
    end
  endtask

  // Send a single bit (0 or 1) to the slave
  task i2c_send_bit(input b);
    begin
      sda_driver = b;
      sda_drive_en = 1;
      #20;

      scl = 1;
      #100;
      
      scl = 0;
      #100;
    end
  endtask

  // Wait for Slave ACK
  task i2c_read_ack();
    begin
    sda_drive_en = 0;
    #20;

    scl = 1;
    #100;

    scl = 0;
    #100;

    sda_drive_en = 1;
    end
  endtask

  // Send a byte (8 bits) to the slave and read ACK
  task i2c_send_byte(input [7:0] byte);
    integer i;
    begin
      for (i = 7; i >= 0; i = i - 1)
        i2c_send_bit(byte[i]);
      i2c_read_ack();
    end
  endtask

endmodule
`timescale 1ns/1ps
module tb_i2c_slave;
    reg clk;	// Clock do sistema
    reg reset;	// Reset do sistema
    wire scl;	// Linha de clock I2C
    wire sda;	// Linha de dados I2C
    reg scl_o, sda_o, sda_oe;
    assign scl = scl_o;
    //assign sda = sda_oe ? sda_o : 1'bz;
	assign sda = sda_oe ? sda_o : 1'b1;

    wire [63:0] frequency;	//Dado da frequencia
    wire [15:0] duty_cycle;	//Dado do duty cycle
    wire  [1:0]  wave;	// Forma de onda
    wire        enable;	// Habilitação
    wire [7:0] ctrl_reg;

    i2c_slave #(.ADDRESS(7'b1101010)) dut (
        .clk(clk),
        .reset(reset),
        .scl(scl),
        .sda(sda),
        .frequency(frequency),
        .duty_cycle(duty_cycle),
        .wave(wave),
        .enable(enable)
    );

    // gerador de clock
    initial clk = 0;
    always #5 clk = ~clk; //Frequencia do clock 100 MHz

    // START
    task i2c_start(); begin
        sda_o = 1; scl_o = 1; sda_oe = 1; #10;
        sda_o = 0; #10;
        scl_o = 0; #10;
    end endtask
    // STOP
    task i2c_stop(); begin
        sda_o = 0; scl_o = 1; sda_oe = 1; #10;
        sda_o = 1; #10;
        sda_oe = 0;
    end endtask

    // task write bit e write byte
    task i2c_write_byte(input [7:0] b); integer i; 
	begin
    // loop que escreve os 8 bits, MSB primeiro
        for (i = 7; i >= 0; i = i - 1) begin
            sda_o  = b[i]; //carrega o bit mais signficativo primeiro
            sda_oe = 1;  //SDA
            scl_o  = 1; #10; //sobre o clock - escravo lê o bit
            scl_o  = 0; #10; //desde o clock - prepara próximo bit
        end
        // ACK bit (Leitura de ACK do escravo)
        sda_oe = 0;  // solta SDA para o escravo enviar ACK
        scl_o  = 1; #10; // sobe o clock - lê o ACK
        scl_o  = 0; #10; //desce o clock, fim do ciclo de ACK
    end endtask

    initial begin
        // reset
        reset  = 1;
        scl_o  = 0;
        sda_oe = 0;
        #100;
        reset = 0;
		
		// START
        i2c_start();

        // Enviar endereço do escravo (7 bits + 0 de write): 11010100
        i2c_write_byte(8'b11010100);

        // Enviar byte de controle: habilita = 1, wave = 01, freq_enable = 1
        i2c_write_byte(8'b00001101);  // enable=1, wave=01, freq=1, duty=0

        // Enviar 8 bytes de frequência (ex: 0x0000000000000FA0 = 4000)
        i2c_write_byte(8'h01);
        i2c_write_byte(8'h05);
        i2c_write_byte(8'h70);
        i2c_write_byte(8'hEB);
        i2c_write_byte(8'h13);
        i2c_write_byte(8'h45);
        i2c_write_byte(8'h23);
        i2c_write_byte(8'hA0);

        i2c_stop();

        #1000;

        // Comando 2
        i2c_start();

        i2c_write_byte(8'b11010100);
        i2c_write_byte(8'b00010011); // enable=1, wave=10, freq=0, duty=1

        // Enviar 2 bytes do duty cycle (ex: 0x1F40 = 8000)
        i2c_write_byte(8'h01);
        i2c_write_byte(8'h05);
        i2c_write_byte(8'h70);
        i2c_write_byte(8'hEB);
        i2c_write_byte(8'h13);
        i2c_write_byte(8'h45);
        i2c_write_byte(8'h23);
        i2c_write_byte(8'hA0);

        i2c_stop();

        #1000;
		
		
		
		
		
		
		
		
		
		
		

        /* 1) Teste: somente CTRL (enable + square)
        i2c_start();
        i2c_write_byte(7'h42 << 1 | 1'b0);
        i2c_write_byte(8'b00000011); // E=1,S=1,F=1,D=1
        i2c_stop();
        #50;
        $display("CTRL_REG=0x%0h, WAVE=%b, EN=%b", ctrl_reg, wave, enable);

        // 2) Teste: CTRL + FREQ (0xA5A5A5A5A5A5A5A5)
        i2c_start();
        i2c_write_byte(7'h42 << 1);
        i2c_write_byte(8'b00000100); // F=0
        repeat (8) i2c_write_byte(8'hA5);
        i2c_stop();
        #50;
        $display("FREQ_REG=0x%016h", frequency);

        // 3) Teste: CTRL + FREQ + DUTY (0xFF..FF, 0x1234)
        i2c_start();
        i2c_write_byte(7'h42 << 1);
        i2c_write_byte(8'b00001100); // F=0,D=0
        repeat (8) i2c_write_byte(8'hFF);
        i2c_write_byte(8'h12);
        i2c_write_byte(8'h34);
        i2c_stop();
        #50;
        $display("FREQ_REG=0x%016h, DUTY_REG=0x%04h", frequency, duty_cycle);
		*/
        $stop;
    end
endmodule



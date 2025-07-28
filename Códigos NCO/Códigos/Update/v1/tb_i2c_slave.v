`timescale 1ns/1ps
module tb_i2c_slave;
    reg clk;	// Clock do sistema
    reg rst_n;	// Reset do sistema
    wire scl;	// Linha de clock I2C
    wire sda;	// Linha de dados I2C
    reg scl_o, sda_o, sda_oe;
    assign scl = scl_o;
    assign sda = sda_oe ? sda_o : 1'bz;

    wire [63:0] freq_reg;	//Dado da frequencia
    wire [15:0] duty_reg;	//Dado do duty cycle
    wire        wave_sel;	// Forma de onda
    wire        nco_enable;	// Habilitação
    i2c_slave #(.ADDRESS(7'b1101010)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .freq_reg(freq_reg),
        .duty_reg(duty_reg),
        .wave_sel(wave_sel),
        .nco_enable(nco_enable)
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
        rst_n  = 0;
        scl_o  = 0;
        sda_oe = 0;
        #100;
        rst_n = 1;

        // 1) Teste: somente CTRL (enable + square)
        i2c_start();
        i2c_write_byte(7'h42 << 1 | 1'b0);
        i2c_write_byte(8'b00000011); // E=1,S=1,F=1,D=1
        i2c_stop();
        #50;
        $display("CTRL_REG=0x%0h, WAVE=%b, EN=%b", dut.ctrl_reg, wave_sel, nco_enable);

        // 2) Teste: CTRL + FREQ (0xA5A5A5A5A5A5A5A5)
        i2c_start();
        i2c_write_byte(7'h42 << 1);
        i2c_write_byte(8'b00000100); // F=0
        repeat (8) i2c_write_byte(8'hA5);
        i2c_stop();
        #50;
        $display("FREQ_REG=0x%016h", freq_reg);

        // 3) Teste: CTRL + FREQ + DUTY (0xFF..FF, 0x1234)
        i2c_start();
        i2c_write_byte(7'h42 << 1);
        i2c_write_byte(8'b00001100); // F=0,D=0
        repeat (8) i2c_write_byte(8'hFF);
        i2c_write_byte(8'h12);
        i2c_write_byte(8'h34);
        i2c_stop();
        #50;
        $display("FREQ_REG=0x%016h, DUTY_REG=0x%04h", freq_reg, duty_reg);

        $stop;
    end
endmodule

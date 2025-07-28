`timescale 1ns/1ps

module i2c_tb_final;

    reg clk = 0;
    reg reset = 0;
    reg scl = 1;
    reg sda_driver = 1;
    wire sda;

    reg [7:0] wave = 8'b10101010;
    reg [7:0] frequency = 8'd2;
    reg [7:0] duty_cycle = 8'd1;

    integer bit_count;

    // Clock principal (50 MHz)
    always #10 clk = ~clk;

    assign sda = sda_driver;

    i2c_slave uut (
        .clk(clk),
        .reset(reset),
        .scl(scl),
        .sda(sda),
        .wave(wave),
        .frequency(frequency),
        .duty_cycle(duty_cycle)
    );

    initial begin
        // Inicialização
        reset = 1;
        sda_driver = 1;
        #100;
        reset = 0;

        // START: SDA desce com SCL alto
        #20000;
        sda_driver = 1;
        scl = 1;
        #20000;
        sda_driver = 0;
        #20000;
        scl = 0;
        #20000;

        // Enviar endereço (8 bits)
        bit_count = 0;
        repeat (8) begin
            scl = 0; #10000;
            sda_driver = wave[7 - bit_count];
            #1000;
            scl = 1; #10000;
            bit_count = bit_count + 1;
        end

        // ACK
        scl = 0;
        sda_driver = 1'bz;
        #10000;
        scl = 1;
        #10000;
        scl = 0;
        #10000;

        // STOP
        sda_driver = 0;
        #10000;
        scl = 1;
        #10000;
        sda_driver = 1;

        #50000;
        $stop;
    end

endmodule

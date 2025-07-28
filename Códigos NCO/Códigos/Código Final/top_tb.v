`timescale 1ns / 100ps

module top_tb;

    // Inputs
    reg clk;
    reg rst;
    reg scl;
    reg sda_in;

    // Bidirectional SDA line com alta-impedancia forcada em 1
    tri1 sda;

    // Outputs
    wire start;
    wire ack_error;
    wire nco_enable;
    wire [1:0] wave;
    wire [63:0] frequency;
    wire [15:0] duty_cycle;
    wire [31:0] frequency_int;

    assign frequency_int = frequency[63:32];

    // Internal variables
    reg [7:0] address = 8'b11101010; // Endereco do mestre (7 bits + bit R/W)

    reg sda_controle;
    integer negedge_detected;
    integer i;

    wire [11:0] nco_output;
    top_module #(
        100_000_000,    // 100 MHz
        12,            // 12 bits de resolução
        50_000_000       // 48 kHz sample rate
    ) uut (
        clk,                      // Clock principal do sistema
        rst,                    // Reset do sistema
        scl,                      // I2C Clock
        sda,                      // I2C Data
        nco_output,  // Saída do NCO
        start,               // Status da comunicação I2C
        ack_error            // Erro de ACK do I2C
    );
    // Controla a linha SDA
    assign sda = sda_controle ? 1'bz : sda_in;

    // Clock SCL
    always begin
        #100 scl = ~scl; // Frequencia do clock 5 MHz 
    end
	 
	 always begin
        #5 clk = ~clk; // Frequencia do clock 100 MHz
    end

    task start_transmission();
        begin
            // Enviar start condition (SDA vai de 1 para 0 com SCL = 1)
            @(posedge scl) #20 sda_in = 0;

            @(negedge scl);

            // Enviar endereco (7 bits + R/W = 0 para escrita)
            negedge_detected = 0; // Inicializar o sinal
    
            for (i = 7; i >= 0; i = i - 1) begin
                sda_in = address[i];

                // Aguardar uma das condicoes: borda de descida ou estado 2
                wait (uut.i2c_slave_inst.state == 2 || negedge_detected);

                // Resetar o sinal apos deteccao
                negedge_detected = 0;
            end
            
            // Libera o barramento (espera ACK do escravo)
            sda_controle = 1;
        
            wait (uut.i2c_slave_inst.state == 3); 
            
            sda_controle = 0;

        end
    endtask

    task stop_transmission();
        begin
            // Libera o barramento (espera ACK do escravo)
            // sda_in = 0;
            sda_controle = 1;
            wait (uut.i2c_slave_inst.state == 0)
            sda_controle = 0;

            // Enviar stop condition (SDA vai de 0 para 1 com SCL = 1)
            @(negedge scl) sda_in = 0;
            @(posedge scl) #20 sda_in = 1;
        end
    endtask

    task send_data(input [63:0] data, input integer size);
        begin
            negedge_detected = 0; // Inicializar o sinal
            for (i = size - 1; i >= 0; i = i - 1) begin
                sda_in = data[i];
                    
                // Aguardar uma das condicoes: borda de descida ou estado 2
                wait (uut.i2c_slave_inst.state == 2 || negedge_detected);

                // Resetar o sinal apos deteccao
                negedge_detected = 0;
            end
        end
    endtask

    task send_ctrl(input [7:0] ctrl);
        begin
           send_data({56'b0, ctrl}, 8);
        end
    endtask
    
    task send_freq(input [63:0] freq);
        begin
            send_data(freq, 64);
        end
    endtask

    task send_duty(input [15:0] duty);
        begin
            send_data({48'b0, duty}, 16);
        end
    endtask

    initial begin
        // Inicializacao
        rst = 1;
        clk = 1;
        scl = 0;
        
        sda_controle = 0;
        sda_in = 1;
		  
        // Libera o reset
        #15 rst = 0;

        // Simulacao do envio do endereco pelo mestre no modo escrita
        $display("Iniciando operacao de escrita...");

         start_transmission();
        send_ctrl(8'b00010011);
        send_freq(64'b0000000000000001110101001100000000000000000000000000000000000000);
        send_duty(16'b1000000000000000);
        stop_transmission();
        #300_0000;
        
        start_transmission();
        send_ctrl(8'b00001101);
        send_freq(64'b0000011000000001110101001100000000000000000000000000000000000000);
        send_duty(16'b1000000000000000);
        stop_transmission();
        #300_0000;

        // #100;
        start_transmission();
        send_ctrl(8'b00010001);
        send_freq(64'b0000000000000001110101001100000000000000000000000000000000000111);
        send_duty(16'b1000000000000000);
        stop_transmission();
        #300_0000;

          start_transmission();
        send_ctrl(8'b0000111);
        send_freq(64'b0000000000000001110101001100000000000000000000000000000000001010);
        send_duty(16'b1000000000000000);
        stop_transmission();
        #300_0000;

        $stop;
    end
	 
	 // Detectar a borda de descida de SCL
    always @(negedge scl) begin
        negedge_detected = 1;
    end
endmodule

`timescale 1ns / 1ps
`include "util.vh"

module top_module #(
    parameter CLK_FREQ = 100_000_000,    // 100 MHz
    parameter BIT_DEPTH = 12,            // 12 bits de resolução
    parameter SAMPLE_RATE = 48_000       // 48 kHz sample rate
)(
    input wire clk,                      // Clock principal do sistema
    input wire reset,                    // Reset do sistema
    input wire scl,                      // I2C Clock
    inout wire sda,                      // I2C Data
    output wire [BIT_DEPTH-1:0] nco_output,  // Saída do NCO
    output wire i2c_start,               // Status da comunicação I2C
    output wire i2c_ack_error            // Erro de ACK do I2C
);

    // Sinais de controle do NCO vindos do I2C slave
    wire nco_enable;
    wire [1:0] nco_wave;
    wire [63:0] nco_frequency;
    wire [15:0] nco_duty_cycle;
    
    // Saída interna do NCO
    wire [BIT_DEPTH-1:0] nco_out_internal;
    
    // Instância do I2C Slave
    i2c_slave i2c_slave_inst (
        .clk(clk),
        .reset(reset),
        .scl(scl),
        .sda(sda),
        .nco_enable(nco_enable),
        .nco_wave(nco_wave),
        .nco_frequency(nco_frequency),
        .nco_duty_cycle(nco_duty_cycle),
        .ack_error(i2c_ack_error),
        .start(i2c_start)
    );
    
    // Instância do NCO
    NCO #(
        .CLK_FREQ(CLK_FREQ),
        .BIT_DEPTH(BIT_DEPTH),
        .SAMPLE_RATE(SAMPLE_RATE)
    ) nco_inst (
        .frequency(nco_frequency),
        .wave(nco_wave),
        .duty_cycle(nco_duty_cycle[BIT_DEPTH-1:0]), // Adapta para a largura correta
        .clk(clk),
        .reset(reset), // Adicionado sinal de reset
        .out(nco_out_internal)
    );
    
    // Controle de habilitação da saída
    // Quando NCO está desabilitado, saída fica no meio da escala (silêncio)
    localparam [BIT_DEPTH-1:0] SAMPLE_HALF = 1 << (BIT_DEPTH-1);
    assign nco_output = nco_enable ? nco_out_internal : SAMPLE_HALF;

endmodule
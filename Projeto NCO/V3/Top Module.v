`timescale 1ns / 1ps

//=============================================================================
// Módulo TOP - Integração de todos os módulos
//=============================================================================
module top_module #(
  parameter CLK_FREQ = 50000000,        // Clock do sistema (50MHz)
  parameter SAMPLE_RATE = 1000000,      // Taxa de amostragem (1MHz)
  parameter BIT_DEPTH = 16,             // Profundidade de bits da saída
  parameter [6:0] I2C_ADDRESS = 7'b1101010  // Endereço I2C
)(
  // Sinais do sistema
  input wire clk,           // Clock principal
  input wire rst,           // Reset
  
  // Interface I2C
  input wire scl,           // Clock I2C
  inout wire sda,           // Dados I2C
  
  // Saída do NCO
  output wire [BIT_DEPTH-1:0] nco_out,
  
  // Sinais de status (opcionais para debug)
  output wire nco_enable_status,
  output wire [1:0] nco_wave_type_status,
  output wire [63:0] nco_frequency_status,
  output wire [15:0] nco_duty_cycle_status
);

  // Sinais internos de conexão entre I2C slave e NCO
  wire i2c_enable;
  wire [1:0] i2c_wave;
  wire [63:0] i2c_frequency;
  wire [15:0] i2c_duty_cycle;

  // Instância do módulo I2C Slave
  i2c_slave #(
    .ADDRESS(I2C_ADDRESS)
  ) i2c_inst (
    .clk(clk),
    .rst(rst),
    .scl(scl),
    .sda(sda),
    .enable(i2c_enable),
    .wave(i2c_wave),
    .frequency(i2c_frequency),
    .duty_cycle(i2c_duty_cycle)
  );

  // Instância do módulo NCO
  NCO #(
    .CLK_FREQ(CLK_FREQ),
    .BIT_DEPTH(BIT_DEPTH),
    .SAMPLE_RATE(SAMPLE_RATE)
  ) nco_inst (
    .frequency(i2c_frequency),
    .wave(i2c_wave),
    .duty_cycle(i2c_duty_cycle),
    .clk(clk),
    .enable(i2c_enable),
    .out(nco_out)
  );

  // Conectar sinais de status às saídas (opcional para debug)
  assign nco_enable_status = i2c_enable;
  assign nco_wave_type_status = i2c_wave;
  assign nco_frequency_status = i2c_frequency;
  assign nco_duty_cycle_status = i2c_duty_cycle;

endmodule
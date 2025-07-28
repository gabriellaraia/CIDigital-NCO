`define SINE 		  2'b00
`define TRIANGLE	2'b01
`define SAWTOOTH	2'b10
`define SQUARE		2'b11

module NCO (
  frequency, wave, duty_cycle, clk, rst, out
);

parameter CLK_FREQ = 50000000;
parameter BIT_DEPTH = 12;
parameter SAMPLE_RATE = 1000000;

input [63:0] frequency; // Ponto Fixo Q32.32
input [1:0] wave;
input [BIT_DEPTH - 1:0] duty_cycle;
input clk;
input rst;
output reg [BIT_DEPTH - 1:0] out;

// Valores máximos
wire [BIT_DEPTH - 1:0] SAMPLE_MAX;
wire [BIT_DEPTH - 1:0] SAMPLE_HALF;
assign SAMPLE_MAX = (1 << BIT_DEPTH) - 1;
assign SAMPLE_HALF = (1 << (BIT_DEPTH - 1));

/*-------------------------------------- Acumulador de fase --------------------------------------*/
// Acumulador de fase, incremento de fase
reg [31:0] phase_acc;
reg [31:0] phase_inc;
// Registrador auxiliar pra aquisição da fase
wire [BIT_DEPTH-1:0] phase;

assign phase = phase_acc[31:32-BIT_DEPTH];

initial begin
  phase_acc = 0;  
  phase_inc = 0;
end

// Cálculo do incremento de fase
always @(frequency) begin 
  // Para frequência simples em Hz (usando apenas os 32 bits inferiores)
  // phase_inc = (frequency * 2^32) / SAMPLE_RATE
  // Simplificando: phase_inc = (frequency << 32) / SAMPLE_RATE
  phase_inc = (frequency[31:0] << 16) / (SAMPLE_RATE >> 16);
end

/*----------------------------------------- Sample Clock -----------------------------------------*/
// Clock do circuito igual ao sample rate
parameter CLK_FREQ_EQ_SAMPLE_RATE = (CLK_FREQ == SAMPLE_RATE) ? 1 : 0;
wire sample_clk_cd;
wire sample_clk;

ClockDividerFF #(.CLK_IN_FREQ(CLK_FREQ), .CLK_OUT_FREQ(SAMPLE_RATE)) cd(
  .clk_in(clk), 
  .clk_out(sample_clk_cd)
);  

// Escolhe entre o clock do circuito e o clock do divisor
assign sample_clk = (CLK_FREQ_EQ_SAMPLE_RATE == 1) ? clk : sample_clk_cd;

/*--------------------------------------- Estágio de Saída ---------------------------------------*/
reg [BIT_DEPTH-1:0] phase_temp;
reg [2*BIT_DEPTH-1:0] mult_temp;

always @(posedge sample_clk or posedge rst) begin
  if (rst) begin
    phase_acc <= 0;
    out <= SAMPLE_HALF;
  end else begin
    // Incrementa a fase
    phase_acc <= phase_acc + phase_inc;
    
    case (wave)
      // Senoidal com aproximação simples
      `SINE: begin 
        phase_temp = phase;
        if (phase[BIT_DEPTH-1]) begin
          // Segunda metade - inverte
          phase_temp = SAMPLE_MAX - phase;
        end
        
        // Aproximação triangular da senoide
        if (phase_temp <= SAMPLE_HALF) begin
          out <= SAMPLE_HALF + (phase_temp >> 1);
        end else begin
          out <= SAMPLE_MAX - (phase_temp >> 1);
        end
      end
      
      `SQUARE: begin
        out <= (phase <= duty_cycle) ? SAMPLE_MAX : 0;
      end
      
      `TRIANGLE: begin
        if (phase[BIT_DEPTH-1]) begin
          // Segunda metade - declive descendente
          out <= SAMPLE_MAX - ((phase - SAMPLE_HALF) << 1);
        end else begin
          // Primeira metade - declive ascendente
          out <= phase << 1;
        end
      end
      
      `SAWTOOTH: begin
        out <= phase;
      end
      
      default: out <= SAMPLE_HALF;
    endcase
  end
end

endmodule
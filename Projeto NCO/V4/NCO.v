`define SINE 		  0
`define TRIANGLE	1
`define SAWTOOTH	2
`define SQUARE		3


module NCO #(parameter CLK_FREQ, parameter BIT_DEPTH, parameter SAMPLE_RATE) (
  input [63:0] frequency, // Ponto Fixo Q32.32
  input [1:0] wave, //Corrigido
  input [BIT_DEPTH - 1:0] duty_cycle,
  input clk,
  output reg [BIT_DEPTH - 1:0] out
);
  // Valor máximo, Metade do valor máximo
  localparam [BIT_DEPTH - 1: 0] SAMPLE_MAX = 2 ** BIT_DEPTH - 1, SAMPLE_HALF = 2 ** (BIT_DEPTH - 1);

  /*-------------------------------------- Acumulador de fase --------------------------------------*/
  /*                      Baseado em: https://www.fpga4fun.com/DDS3.html                            */
  /*   Um contador que vai de 0 a SAMPLE_MAX num periodo de 1/freq baseado na taxa de amostragem    */
  /*              É incrementado a cada aquisição de amostra por um valor definido como:            */
  /*              incremento = freq / (resolucao); onde resolucao = sample_rate / 1^32;             */
  /*              O acumulador tem largura de 32 bits, mas o valor em si (0:SAMPLE_MAX)             */
  /*              fica nos bits mais significativos e tem largura definida por BIT_DEPTH            */
  /*                            ou seja, fase = acc[31: 32 - BIT_DEPTH]                             */
  /*              Isso se deve ao método, presente no link acima, pra aumento da resolução          */
  /*    que acaba tratando o acumulador como um numero de ponto fixo Q(BIT_DEPTH).(32-BIT_DEPTH)    */
  /*    e permite incrementos mais finos de fase e tambem a interpolação de amostras no caso de     */
  /*                          uma LUT estar sendo usada no estagio de saída                         */
  /*------------------------------------------------------------------------------------------------*/
  // Resolução de incremento da fase (1 / (SAMPLE_RATE / (1 ** 32)))
  localparam PHASE_ACC_RESOLUTION = ((64'd1 << 64'd32) / (SAMPLE_RATE));
  // Acumulador de fase, incremento de fase
  reg [31: 0] phase_acc, phase_inc;
  // Registrador auxiliar pra armazenar a multiplicação da frequencia pela resolução
  reg [127:0] phase_inc_mul_reg; 
  // Registrador auxiliar pra aquisição da fase
  reg [BIT_DEPTH-1:0] phase; 

  initial begin
    phase_acc = 0;  
    phase_inc = 0;
  end

  always @(frequency) begin 
    // Multiplica frequencia pela resolução da fase pra definir o incremento de fase
    phase_inc_mul_reg = ((frequency) * PHASE_ACC_RESOLUTION) >> 32; //Ajustado >> 32
    phase_inc = phase_inc_mul_reg[31:0]; //Ajustado valor
  end
  /*------------------------------------------------------------------------------------------------*/

  /*----------------------------------------- Sample Clock -----------------------------------------*/
  /* Serve como gatilho pra aquisição de uma amostra de acordo com a taxa de amostragem configurada */
  /*------------------------------------------------------------------------------------------------*/
  // Clock do circuito igual ao sample rate
  localparam CLK_FREQ_EQ_SAMPLE_RATE = CLK_FREQ == SAMPLE_RATE;
  // Divisor de frequencia pro sample clock
  wire sample_clk_cd, sample_clk;
  ClockDividerFF #(CLK_FREQ, SAMPLE_RATE) cd(clk, sample_clk_cd);  
  
  // Escolhe entre o clock do circuito e o clock do divisor 
  // dependendo se o clock do circuito é igual ao sample rate
  assign sample_clk = CLK_FREQ_EQ_SAMPLE_RATE ? clk : sample_clk_cd;
  /*------------------------------------------------------------------------------------------------*/

  /*--------------------------------------- Estágio de Saída ---------------------------------------*/
  // Tamanho do valor de saida em ponto fixo QBIT_DEPTH.BIT_DEPTH
  localparam FP_WIDTH = BIT_DEPTH * 2 - 1;
  reg [FP_WIDTH:0] out_fp = 0; // Saída em ponto fixo
  reg p_dir; // Direção da concavidade da parabola (0: cima; 1: baixo)

  always @(posedge sample_clk) begin
    phase = phase_acc[31:32 - BIT_DEPTH];
    case (wave)
      // Senoidal com duas parabolas (https://www.desmos.com/calculator/f3udcjzrst)
      `SINE: begin 
        // A direção da concavidade é definida pelo MSB da fase
        p_dir = phase[BIT_DEPTH - 1]; 
        // Seleciona p1 (x) quando a parabola tem concavidade pra cima ou p2 (x - s_half) quando a parabola tem concavidade pra baixo
        phase = p_dir ? phase - SAMPLE_HALF : phase; 

        // Calculo da sample (0 a 1 em ponto fixo)
        out_fp = ((phase * phase) >> BIT_DEPTH) << 3; // 8p²
        // Parabola 1 (concavidade pra baixo)
        if (p_dir) out_fp = out_fp - (phase << 2) + SAMPLE_HALF; // 8p² - 4p + 0.5
        // Parabola 2 (concavidade pra cima)
        else out_fp = (phase << 2) - out_fp + SAMPLE_HALF; // 4p - 8p² + 0.5
        
        
        if (out_fp[FP_WIDTH:BIT_DEPTH] > 2)       out_fp = 0;          // Zera se tiver underflow
        else if (out_fp[FP_WIDTH:BIT_DEPTH] >= 1) out_fp = SAMPLE_MAX; // Coloca valor maximo se tiver overflow

        // Coloca a parte fracional do valor em ponto fixo na saida
        // Mesma coisa que multiplicar pelo valor maximo ja que, 
        // apesar de em ponto fixo o valor ir de 0 a 1, 
        // a parte fracional é representada por um valor que vai de 
        //  0 a (1 << BIT_DEPTH) que é o valor maximo
        out = out_fp[BIT_DEPTH - 1:0];
      end
      `SQUARE: out = phase <= duty_cycle ? SAMPLE_MAX : 0;
      // No caso padrão fica em "silencio"
      default: out = SAMPLE_HALF;
    endcase
    // Incrementa a fase
    phase_acc = phase_acc + phase_inc;
  end

  /*------------------------------------------------------------------------------------------------*/

endmodule


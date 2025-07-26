module i2c_slave (
  clk, rst, scl, sda, enable, wave, frequency, duty_cycle
);

parameter [6:0] ADDRESS = 7'b1101010;

input wire clk;
input wire rst;
input wire scl;
inout wire sda;

output reg enable;
output reg [1:0] wave;
output reg [63:0] frequency;
output reg [15:0] duty_cycle;

reg sda_out;
reg sda_oe;
wire sda_in;

reg [1:0] scl_sync;
reg [1:0] sda_sync;

assign sda = sda_oe ? sda_out : 1'bz;
assign sda_in = sda;

// Estados do protocolo I2C
parameter [2:0] IDLE      = 3'b000;
parameter [2:0] ADDR      = 3'b001;
parameter [2:0] ACK_ADDR  = 3'b010;
parameter [2:0] READ_DATA = 3'b011;
parameter [2:0] ACK_DATA  = 3'b100;
parameter [2:0] STOP      = 3'b101;

reg [2:0] state;
reg [7:0] shift_reg;
reg [2:0] bit_count;
reg [3:0] byte_count;
reg [6:0] received_addr;
reg write_mode;

// Registradores internos
reg [7:0] control_reg;
reg [63:0] internal_frequency_reg;
reg [15:0] internal_duty_cycle_reg;

// Detecção de bordas e condições
wire scl_rising;
wire scl_falling;
wire start_condition;
wire stop_condition;

assign scl_rising = (scl_sync == 2'b01);
assign scl_falling = (scl_sync == 2'b10);
assign start_condition = (sda_sync == 2'b10 && scl_sync[1]);
assign stop_condition = (sda_sync == 2'b01 && scl_sync[1]);

// Interpretação do byte de controle
wire update_freq;
wire update_duty;
assign update_freq = control_reg[1];
assign update_duty = control_reg[2];

// Número de bytes esperados
parameter FREQ_BYTES = 8;
parameter DUTY_BYTES = 2;

// Sincronização dos sinais
always @(posedge clk) begin
  scl_sync <= {scl_sync[0], scl};
  sda_sync <= {sda_sync[0], sda_in};
end

// Máquina de estados principal
always @(posedge clk or posedge rst) begin
  if (rst) begin
    state <= IDLE;
    sda_oe <= 0;
    sda_out <= 1;
    bit_count <= 0;
    byte_count <= 0;
    received_addr <= 0;
    write_mode <= 0;
    control_reg <= 0;
    internal_frequency_reg <= 0;
    internal_duty_cycle_reg <= 0;
    enable <= 0;
    wave <= 0;
    frequency <= 0;
    duty_cycle <= 0;
    shift_reg <= 0;
  end else begin
    
    // Condição de STOP sempre retorna ao IDLE
    if (stop_condition) begin
      state <= IDLE;
      sda_oe <= 0;
      // Atualiza saídas quando recebe STOP
      if (byte_count > 0) begin
        enable <= control_reg[0];
        wave <= control_reg[2:1];
        if (update_freq)
          frequency <= internal_frequency_reg;
        if (update_duty)
          duty_cycle <= internal_duty_cycle_reg;
      end
    end else begin
      case (state)
        IDLE: begin
          sda_oe <= 0;
          if (start_condition) begin
            state <= ADDR;
            bit_count <= 0;
            byte_count <= 0;
            shift_reg <= 0;
          end
        end

        ADDR: begin
          if (scl_rising) begin
            shift_reg <= {shift_reg[6:0], sda_in};
            bit_count <= bit_count + 1;
            if (bit_count == 3'd7) begin
              received_addr <= shift_reg[6:0];
              write_mode <= sda_in; // R/W bit
              state <= ACK_ADDR;
            end
          end
        end

        ACK_ADDR: begin
          if (scl_falling) begin
            if (received_addr == ADDRESS && write_mode == 0) begin
              sda_out <= 0; // ACK
              sda_oe <= 1;
              state <= READ_DATA;
              bit_count <= 0;
            end else begin
              sda_out <= 1; // NACK
              sda_oe <= 1;
              state <= IDLE;
            end
          end else if (scl_rising) begin
            sda_oe <= 0;
          end
        end

        READ_DATA: begin
          if (scl_rising) begin
            shift_reg <= {shift_reg[6:0], sda_in};
            bit_count <= bit_count + 1;
            if (bit_count == 3'd7) begin
              // Processa o byte recebido
              if (byte_count == 0) begin
                // Primeiro byte é o controle
                control_reg <= {shift_reg[6:0], sda_in};
              end else if (byte_count <= FREQ_BYTES && update_freq) begin
                // Bytes de frequência (little endian)
                internal_frequency_reg[(byte_count-1)*8 +: 8] <= {shift_reg[6:0], sda_in};
              end else if (byte_count <= (FREQ_BYTES + DUTY_BYTES) && update_duty && 
                         (!update_freq || byte_count > FREQ_BYTES)) begin
                // Bytes de duty cycle
                if (update_freq) begin
                  internal_duty_cycle_reg[(byte_count-FREQ_BYTES-1)*8 +: 8] <= {shift_reg[6:0], sda_in};
                end else begin
                  internal_duty_cycle_reg[(byte_count-1)*8 +: 8] <= {shift_reg[6:0], sda_in};
                end
              end
              
              state <= ACK_DATA;
              bit_count <= 0;
            end
          end
        end

        ACK_DATA: begin
          if (scl_falling) begin
            sda_out <= 0; // ACK
            sda_oe <= 1;
            byte_count <= byte_count + 1;
            state <= READ_DATA;
          end else if (scl_rising) begin
            sda_oe <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end
end

endmodule
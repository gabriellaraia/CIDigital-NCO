`timescale 1ns / 1ps

module i2c_slave (
    input wire clk,         // Clock do sistema
    input wire reset,       // Reset do sistema
    input wire scl,         // Linha de clock I2C
    inout wire sda,         // Linha de dados I2C
    output reg nco_enable,
    output reg [1:0] nco_wave,
    output reg [63:0] nco_frequency,
    output reg [15:0] nco_duty_cycle,
    output reg ack_error,      // Flag para indicar erro no ACK do mestre
    output reg start           // Indica inicio e fim da transmissao
);

    // Constantes
    localparam ADDRESS = 8'b11101010; // 6Ah
	 
    localparam IDLE = 3'b000;
    localparam ADDR = 3'b001;
    localparam ADDR_ACK = 3'b010;
    localparam READ = 3'b011;

    localparam WRITE = 3'b100;
    localparam READ_ACK = 3'b101;

    localparam READ_CTRL = 2'b00;
    localparam READ_FREQ = 2'b01;
    localparam READ_DUTY = 2'b10;

    // Registradores internos
    reg [63:0] shift_reg;  // Registrador de deslocamento para leitura de dados
    reg [6:0] bit_count;  // Contador de bits
    reg [2:0] state;      // Estado atual da maquina de estados
    reg [2:0] next_state; // Proximo estado da maquina de estados
    reg [1:0] read_type;  // Tipo de leitura (frequencia, duty cycle, etc)
    reg sda_out;          // Controle de saida para SDA
    reg sda_drive;        // Define se o escravo controla diretamente a linha SDA
    reg scl_sync;         // Valor sincronizado de SCL
    reg sda_sync;         // Valor sincronizado de SDA
    reg scl_last;         // Estado anterior de SCL
    reg sda_last;         // Estado anterior de SDA

    reg [7:0] ctrl_reg;
    reg [63:0] freq_reg;
    reg [15:0] duty_reg;
    // Controle bidirecional da linha SDA
    assign sda = (sda_drive) ? sda_out : 1'bz;

    // Sincronizacao de SCL e SDA no clock do sistema
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            scl_sync <= 1;
            sda_sync <= 1;
            scl_last <= 1;
            sda_last <= 1;
        end else begin
            scl_sync <= scl;
            sda_sync <= sda;
            scl_last <= scl_sync;
            sda_last <= sda_sync;
        end
    end

    // Deteccao de borda de start/stop
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            start <= 0;
        end else begin
            if (!start && scl_sync && sda_last && !sda_sync) begin
                // Condicao de start
                start <= 1;
            end else if (start && scl_sync && !sda_last && sda_sync) begin
                // Condicao de stop
                start <= 0;
            end
        end
    end

    // Logica sequencial para o estado atual
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Logica combinacional para o proximo estado
    always @(*) begin
        // Estados padrao
        next_state = state;
		  
		  if (!start) begin
		      next_state = IDLE;
		  end else begin
            case (state)
                IDLE: begin
                    if (start && scl_last && !scl_sync) next_state = ADDR;
                end

                ADDR: begin
                    if (scl_last && !scl_sync) begin
                        if (bit_count == 0) begin
                            next_state = ADDR_ACK;
                        end
                    end
                end

                ADDR_ACK: begin
                    if (scl_last && !scl_sync) begin
                        if (shift_reg[7:0] == ADDRESS) begin
                            next_state = READ;
                        end else begin
                            next_state = IDLE; // Endereco invalido
                        end
                    end
                end

                READ: begin
                    if (scl_last && !scl_sync) begin
                        if (bit_count == 0) begin
                            if (read_type == READ_CTRL) begin
                                if (shift_reg[4] == 1'b1 && shift_reg[3] == 1'b0) begin
                                    bit_count = 64;
                                    read_type = READ_FREQ;
                                end else if (shift_reg[4] == 1'b0 && shift_reg[3] == 1'b1) begin
                                    bit_count = 16;
                                    read_type = READ_DUTY;
                                end else begin
                                    next_state = READ_ACK;
                                end
                            end else begin
                                next_state = READ_ACK; 
                            end
                        end
                    end
                end
                READ_ACK: begin
                    if (scl_last && !scl_sync) begin
                        next_state = IDLE;
                    end
                end

                default: next_state = IDLE;
            endcase
	     end
    end

    // Logica combinacional e de saida
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bit_count <= 7;
            shift_reg <= 63'b0;
            read_type <= READ_CTRL;
            ack_error <= 0;
            sda_drive <= 0;
            sda_out <= 1;
        end else begin
            case (state)
                IDLE: begin
                    bit_count <= 7;
                    shift_reg <= 63'b0;
                    read_type <= READ_CTRL;
                    ack_error <= 0;
                    sda_drive <= 0;
                    sda_out <= 1;
                end

                ADDR: begin
                    if (!scl_last && scl_sync) shift_reg[bit_count] <= sda_sync;
                    if (scl_last && !scl_sync) bit_count <= bit_count - 1'd1;
                end

                ADDR_ACK: begin
                    sda_drive <= 1;
                    sda_out <= 0;
                    if (scl_last && !scl_sync) begin
                        if (shift_reg[7:0] == ADDRESS) begin
                            bit_count <= 7;
                        end
                    end
                end

                READ: begin
                    sda_drive <= 0;
                    if (!scl_last && scl_sync) begin
                        shift_reg[bit_count] = sda_sync;
                        if (bit_count == 0) begin
                            case (read_type)
                                READ_CTRL: ctrl_reg = shift_reg[7:0];
                                READ_FREQ: freq_reg = shift_reg[63:0];
                                READ_DUTY: duty_reg = shift_reg[15:0];
                            endcase
                        end
                    end
                    if (scl_last && !scl_sync) bit_count <= bit_count - 1'd1;
                end

                READ_ACK: begin
                    sda_drive <= 1;
                    sda_out <= 0;
                    if (!scl_last && scl_sync) begin
                        nco_enable <= ctrl_reg[0];
                        nco_wave <= ctrl_reg[2:1];
                        if (ctrl_reg[4] == 1 && ctrl_reg[3] == 0) begin
                            nco_frequency <= freq_reg;
                        end else if (ctrl_reg[4] == 0 && ctrl_reg[3] == 1) begin
                            nco_duty_cycle <= duty_reg; // Frequencia zero se bit 3 for 0
                        end
                    end
                end
            endcase
        end
    end
endmodule

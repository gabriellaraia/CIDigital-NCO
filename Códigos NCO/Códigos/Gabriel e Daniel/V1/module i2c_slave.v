module i2c_slave (
    input wire clk,     // Clock do sistema
    input wire reset,   // Reset do sistema
    input wire scl,     // Linha de clock I2C
    inout wire sda,     // Linha de dados I2C
    output reg enable,      // Habilitação
    output reg [1:0] wave,  // Forma de onda
    output reg [63:0] frequency,        //Dado da frequencia
    output reg [15:0] duty_cycle       //Dado do duty cycle
);

    parameter ADDRESS = 7'b1101010; //Endereço do escravo

    localparam IDLE      	= 3'b000;   // Estado de início
    localparam ADDR      	= 3'b001;   // Estado de endereçamento
    localparam ACK       	= 3'b010;   // Estado de verificação
    localparam READ_CONTROL = 3'b011;   // Estado de leitura de byte de controle
    localparam READ_FREQ    = 3'b100;   // Estado de leitura da frequencia
    localparam READ_DUTY    = 3'b101;   // Estado de leitura do duty cycle
 
    reg [2:0] state, next_state;        // Estado atual e estado próximo da maquina de estados
    reg [7:0] shift_reg;                // Registrador de deslocamento para leitura de dados
    reg [6:0] bit_count;                // Contador de bits
    reg sda_out;                        // Controle de saida para SDA
    reg sda_drive;                      // Define se o escravo controla diretamente a linha SDA
    reg scl_sync, sda_sync;             // Valor sincronizado de SCL e SDA
    reg scl_last, sda_last;             // Estado anterior de SCL e SDA
    reg start;                           // Indica inicio e fim da transmissao

    reg [3:0]  byte_counter;            
    reg [7:0]  internal_control_reg;
    reg [63:0] internal_frequency_reg;
    reg [15:0] internal_duty_cycle_reg;
    reg update_frequency_flag;    //Flag indicando frequencia atualizada
    reg update_duty_cycle_flag;   //Flag indicando duty cicle atualizado

    // Controle bidirecional da linha SDA
    assign sda = (sda_drive) ? sda_out : 1'bz;

    assign update_frequency_flag =  internal_control_reg[3] && !internal_control_reg[4];
    assign update_duty_cycle_flag = !internal_control_reg[3] && internal_control_reg[4];

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
            // Condição de START: SDA vai para baixo enquanto SCL está alto
            if (!start && scl_sync && sda_last && !sda_sync) begin
                start <= 1;
            // Condição de STOP: SDA vai para cima enquanto SCL está alto
            end else if (start && scl_sync && !sda_last && sda_sync) begin
                start <= 0;
            end
        end
    end


    // --- Máquina de Estados: Lógica Sequencial ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            bit_count <= 3'd7;
            byte_counter <= 4'd0;
            sda_drive <= 1'b0;
            update_frequency_flag <= 1'b0;
            update_duty_cycle_flag <= 1'b0;
        end else begin
            state <= next_state;
            // Flags de atualização são pulsos de 1 ciclo de clock
            if (state == IDLE) begin
                update_frequency_flag <= 1'b0;
                update_duty_cycle_flag <= 1'b0;
            end

            // Lógica de deslocamento de bits na borda de subida do SCL
            if (state == ADDR || state >= READ_CONTROL) begin
                if (!scl_last && scl_sync) begin // Borda de subida do SCL
                    shift_reg <= {shift_reg[6:0], sda_sync};
                    bit_count <= bit_count - 1;
                end
            end

            // Lógica de atualização e controle na borda de descida do SCL
            if (scl_last && !scl_sync) begin // Borda de descida do SCL
                if (state == ACK) begin
                    // Libera SDA após o ACK
                    sda_drive <= 1'b0;
                    bit_count <= 3'd7; // Reinicia contador de bits para o próximo byte
                end
                else if (state >= READ_CONTROL & bit_count == 3'b111) begin // Após receber 8 bits
                    // Armazena o byte recebido no registrador correto
                    case (state)
                        READ_CONTROL: internal_control_reg <= shift_reg;
                        READ_FREQ:    internal_frequency_reg = shift_reg << (8 - byte_counter);
                        READ_DUTY:    internal_duty_cycle_reg = shift_reg << (4 - byte_counter);
                    endcase

                    byte_counter <= byte_counter + 1;
                end
            end

            // Reseta contadores se a transmissão for interrompida (STOP)
            if (!start) begin
                bit_count <= 3'd7;
                byte_counter <= 4'd0;
            end
        end
    end

    // --- Máquina de Estados: Lógica Combinacional ---
    always @(*) begin
        next_state = state;
        sda_out = 1'b0; // Padrão para ACK

        if (!start) begin
            next_state = IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start && scl_last && !scl_sync) begin
                        next_state = ADDR;
                    end
                end

                ADDR: begin
                    if (bit_count == 3'b111) begin // 8 bits recebidos
                        next_state = ACK;
                    end
                end

                ACK: begin
                    if (scl_last && !scl_sync) begin // Na borda de descida do SCL
                        if (shift_reg[7:1] == ADDRESS && shift_reg[0] == 1'b0) begin 
                            next_state = READ_CONTROL;
                        end else begin
                            enable = internal_control_reg[0];
                            wave = internal_control_reg[2:1];
                            if(update_frequency_flag) frequency = internal_frequency_reg;
                            if(update_duty_cycle_flag) duty_cycle = internal_duty_cycle_reg;

                            next_state = IDLE; // Endereço/operação inválida
                        end
                    end
                end

                READ_CONTROL: begin
                    if (bit_count == 3'b111) begin // 8 bits de dados recebidos
                        if (update_frequency_flag) next_state = READ_DUTY;
                        else if(update_duty_cycle_flag) next_state = READ_FREQ;
                        else next_state = ACK;
                    end
                end
                READ_FREQ: begin
                    if (bit_count == 6'd64) begin // 8 bits de dados recebidos
                        next_state = ACK;
                    end
                end
                READ_DUTY: begin
                    if (bit_count == 6'd16) begin // 8 bits de dados recebidos
                        next_state = ACK;
                    end
                end
                default: begin
                    next_state = IDLE;
                end
            endcase
        end
        
    end

endmodule

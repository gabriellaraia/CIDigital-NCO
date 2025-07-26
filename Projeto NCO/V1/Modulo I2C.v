module i2c_slave #(
  parameter ADDRESS = 7'b1101010
)(
  input wire clk,
  input wire rst,
  input wire scl,
  inout wire sda,

  output reg        enable,
  output reg [1:0]  wave,
  output reg [63:0] frequency,
  output reg [15:0] duty_cycle
);
    reg sda_out;
    reg sda_oe;
    wire sda_in;

    reg [1:0] scl_sync;
    reg [1:0] sda_sync;

    assign sda = sda_oe ? sda_out : 1'bz;
    assign sda_in = sda;

    localparam IDLE      	 = 3'b000;
    localparam ADDR      	 = 3'b001;
    localparam ACK_ADDR    = 3'b010;
    localparam READ_CTRL   = 3'b011;
    localparam READ_FREQ   = 3'b100;
    localparam READ_DUTY   = 3'b101;
    localparam ACK         = 3'b110;
    localparam STOP        = 3'b111;
    
    reg [2:0] state;
    reg [7:0] shift_reg;
    reg [7:0] internal_control_reg;
    reg [63:0] internal_frequency_reg;
    reg [15:0] internal_duty_cycle_reg;
    reg [2:0] bit_count; 
    reg [3:0] byte_count;

    wire scl_rising      = (scl_sync == 2'b01);
    wire scl_falling     = (scl_sync == 2'b10);
    wire start_condition = (sda_sync == 2'b10 && scl_sync[1]);
    wire stop_condition  = (sda_sync == 2'b01 && scl_sync[1]); 

    wire update_fq_condition  = (internal_control_reg[3] && !internal_control_reg[4]);
    wire update_dc_condition  = (!internal_control_reg[3] && internal_control_reg[4]);


    localparam FQ_NUM_BYTES = 8;
    localparam DC_NUM_BYTES = 2;

    always @(posedge clk)
    begin
      scl_sync <= {scl_sync[0], scl};
      sda_sync <= {sda_sync[0], sda};
    end

    always @(posedge clk or posedge rst)
    begin
      if (rst) begin
        state <= IDLE;
        sda_oe <= 0;
        sda_out <= 1;
        internal_control_reg <= 0;
        internal_frequency_reg <= 0;
        internal_duty_cycle_reg <= 0;
        bit_count <= 0;
        byte_count <= 0;
      end else begin
        case (state)
          IDLE: begin
            sda_oe <= 0;
            if (start_condition) begin
              $display("Start condition detected at %t", $time);
              state <= ADDR;
              bit_count <= 0;
              byte_count <= 0;
            end
          end

          ADDR: begin
            if (scl_rising) begin
              shift_reg <= {shift_reg[6:0], sda_in};
              bit_count <= bit_count + 1;
              if (bit_count == 3'd7) begin
                $display("Address received: %b", {shift_reg[6:0], sda_in});
                state <= ACK_ADDR;
              end
            end
          end

          ACK_ADDR: begin
            if (scl_falling) begin
              $display("Address received (ACK always): %b", shift_reg[7:1]);
              sda_out <= 0; 
              sda_oe <= 1;
              internal_control_reg <= shift_reg[7:1];
              state <= READ_CTRL;
              bit_count <= 0;
              byte_count <= 0;
            end
            if (scl_rising)
              sda_oe <= 0;
          end

          READ_CTRL: begin
            sda_oe <= 0;
            if (scl_rising) begin
              shift_reg <= {shift_reg[6:0], sda_in};
              bit_count <= bit_count + 1;
              if (bit_count == 3'd7) begin
                byte_count <= 0;
                if (update_fq_condition) begin
                  $display("Frequency byte received: %b", shift_reg);
                  state <= READ_FREQ;
                end else if (update_dc_condition) begin
                  $display("Duty cycle byte received: %b", shift_reg);
                  state <= READ_DUTY;
                end else begin
                  $display("No update requested, returning to IDLE state at %t", $time);
                  state <= STOP;
                end
              end
            end
          end

          READ_FREQ: begin
            $display("Reading frequency byte %d at %t", byte_count, $time);
            sda_oe <= 0;
            if (scl_rising) begin
              shift_reg <= {shift_reg[6:0], sda_in};
              bit_count <= bit_count + 1;

              if (bit_count == 3'd7) begin
                $display("Frequency Shift register value: %b at %t", shift_reg, $time);
                internal_frequency_reg[(byte_count * 8) +: 8] <= shift_reg;
                $display("Frequency value set to %b at %t", internal_frequency_reg, $time);
                state <= ACK;
              end
            end
          end

          READ_DUTY: begin
            $display("Reading duty cycle byte %d at %t", byte_count, $time);
            sda_oe <= 0;
            if (scl_rising) begin
              shift_reg <= {shift_reg[6:0], sda_in};
              bit_count <= bit_count + 1;

              if (bit_count == 3'd7) begin
                $display("Frequency Shift register value: %b at %t", shift_reg, $time);
                internal_duty_cycle_reg[(byte_count * 8) +: 8] <= shift_reg;
                $display("Duty cycle value set to %b at %t", internal_duty_cycle_reg, $time);
                state <= ACK;
              end
            end
          end

          ACK: begin
            if (scl_rising) begin
              sda_oe <= 0;
              bit_count <= 0;
            end
            if (scl_falling) begin
              sda_out <= 0;
              sda_oe <= 1;
              bit_count <= 0;

              $display("Total bytes received: %d, expected: %d at %t", byte_count, FQ_NUM_BYTES, $time);
              $display("Update frequency condition: %b, update duty cycle condition: %b at %t", update_fq_condition, update_dc_condition, $time);
              if (update_fq_condition && byte_count <= FQ_NUM_BYTES) begin
                byte_count <= byte_count + 1;
                $display("Received control byte %d: %b, moving to READ_FREQ state at %t", byte_count, shift_reg, $time);
                state <= READ_FREQ;
              end else if (update_dc_condition && byte_count <= DC_NUM_BYTES) begin
                byte_count <= byte_count + 1;
                $display("Received control byte %d: %b, moving to READ_DUTY state at %t", byte_count, shift_reg, $time);
                state <= READ_DUTY;
              end else begin
                $display("No further updates requested, returning to IDLE state at %t", $time);
                enable <= internal_control_reg[0];
                wave <= internal_control_reg[2:1];
                frequency <= internal_frequency_reg;
                duty_cycle <= internal_duty_cycle_reg;
                $display("Frequency VALUE SET TO %b from internal_frequency_reg at %t", internal_frequency_reg, $time);
                $display("Duty Cycle VALUE SET TO %b from duty_cycle at %t", internal_duty_cycle_reg, $time);
                state <= STOP;
              end
            end
          end

          STOP: begin
            if (stop_condition) begin
              sda_oe <= 0;
              state <= IDLE;
            end
          end

          default: state <= IDLE;
      endcase
      end
    end

endmodule

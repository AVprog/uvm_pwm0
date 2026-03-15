`timescale 1ns / 1ps

module pwm_channel (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [31:0] period,
    input  logic [31:0] duty,
    input  logic       reset_counter,  // синхронный сброс счётчика
    output logic       pwm_out
);

    logic [31:0] counter;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            counter <= 0;
        end else if (reset_counter) begin
            counter <= 0;
        end else begin
            if (period != 0) begin
                if (counter >= period - 1)
                    counter <= 0;
                else
                    counter <= counter + 1;
            end
            // если period == 0, счётчик стоит на месте (остаётся 0)
        end
    end

    assign pwm_out = (period != 0) && (counter < duty);

endmodule
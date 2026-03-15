`timescale 1ns / 1ps

module pwm_axi #(
    parameter integer C_S_AXI_ADDR_WIDTH = 4,
    parameter integer C_S_AXI_DATA_WIDTH = 32
)(
    // Тактирование и сброс
    input logic s_axi_aclk,
    input logic s_axi_aresetn,

    // AXI4-Lite интерфейс
    input logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input logic [2:0] s_axi_awprot,
    input logic s_axi_awvalid,
    output logic s_axi_awready,

    input logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input logic s_axi_wvalid,
    output logic s_axi_wready,

    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input logic s_axi_bready,

    input logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input logic [2:0] s_axi_arprot,
    input logic s_axi_arvalid,
    output logic s_axi_arready,

    output logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input logic s_axi_rready,

    // Выход PWM
    output logic pwm_out0,
    output logic pwm_out1
);

    // Регистры управления
    logic [31:0] period_reg0 = 0;
    logic [31:0] duty_reg0   = 0;
    logic [31:0] period_reg1 = 0;
    logic [31:0] duty_reg1   = 0;

    // Сигналы сброса счётчиков (выдаются на один такт при изменении периода)
    logic reset_counter0;
    logic reset_counter1;

    // Состояния конечного автомата AXI
    enum logic [1:0] {
        IDLE,
        WRITE,
        READ
    } state = IDLE;

    // Временные сигналы
    logic [31:0] awaddr_reg;
    logic [31:0] araddr_reg;

    // Инстанцирование двух независимых PWM-каналов
    pwm_channel ch0 (
        .clk           (s_axi_aclk),
        .rst_n         (s_axi_aresetn),
        .period        (period_reg0),
        .duty          (duty_reg0),
        .reset_counter (reset_counter0),
        .pwm_out       (pwm_out0)
    );

    pwm_channel ch1 (
        .clk           (s_axi_aclk),
        .rst_n         (s_axi_aresetn),
        .period        (period_reg1),
        .duty          (duty_reg1),
        .reset_counter (reset_counter1),
        .pwm_out       (pwm_out1)
    );

    // ------------------- Логика AXI Lite -------------------
    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            state <= IDLE;
            s_axi_awready <= 1'b1;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            reset_counter0 <= 1'b0;
            reset_counter1 <= 1'b0;
        end else begin
            reset_counter0 <= 1'b0;  // по умолчанию сброс не активен
            reset_counter1 <= 1'b0;

            case (state)
                IDLE: begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        awaddr_reg <= s_axi_awaddr;
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b1;
                        state <= WRITE;
                    end else if (s_axi_arvalid && s_axi_arready) begin
                        araddr_reg <= s_axi_araddr;
                        s_axi_arready <= 1'b0;
                        state <= READ;
                    end
                end

                WRITE: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wready <= 1'b0;
                        s_axi_bvalid <= 1'b1;

                        case (awaddr_reg)
                            4'h0: begin // период канала 0
                                period_reg0 <= s_axi_wdata;
                                reset_counter0 <= 1'b1;          // сброс счётчика
                                if (duty_reg0 > s_axi_wdata)
                                    duty_reg0 <= s_axi_wdata;    // автокоррекция
                            end
                            4'h4: begin // скважность канала 0
                                duty_reg0 <= (s_axi_wdata < period_reg0) ?
                                             s_axi_wdata : period_reg0;
                            end
                            4'h8: begin // период канала 1
                                period_reg1 <= s_axi_wdata;
                                reset_counter1 <= 1'b1;          // сброс счётчика
                                if (duty_reg1 > s_axi_wdata)
                                    duty_reg1 <= s_axi_wdata;    // автокоррекция
                            end
                            4'hC: begin // скважность канала 1
                                duty_reg1 <= (s_axi_wdata < period_reg1) ?
                                             s_axi_wdata : period_reg1;
                            end
                        endcase
                        state <= IDLE;
                    end
                end

                READ: begin
                    s_axi_rvalid <= 1'b1;
                    case (araddr_reg)
                        4'h0:   s_axi_rdata <= period_reg0;
                        4'h4:   s_axi_rdata <= duty_reg0;
                        4'h8:   s_axi_rdata <= period_reg1;
                        4'hC:   s_axi_rdata <= duty_reg1;
                        default: s_axi_rdata <= 32'h0;
                    endcase

                    if (s_axi_rready && s_axi_rvalid) begin
                        s_axi_rvalid <= 1'b0;
                        s_axi_arready <= 1'b1;
                        state <= IDLE;
                    end
                end
            endcase

            // Завершение транзакции записи
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                s_axi_awready <= 1'b1;
            end
        end
    end

    // Всегда успешные ответы
    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;

endmodule
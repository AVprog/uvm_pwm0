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
    output logic pwm_out
);

// Регистры управления
logic [31:0] period_reg = 0;
logic [31:0] duty_reg = 0;
logic [31:0] counter = 0;
logic reset_counter;

// Состояния конечного автомата AXI
enum logic [1:0] {
    IDLE,
    WRITE,
    READ
} state = IDLE;

// Временные сигналы
logic [31:0] awaddr_reg;
logic [31:0] araddr_reg;

// Управление счетчиком PWM
always_ff @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        counter <= 0;        
    end else begin
        // Сброс счетчика при изменении периода
        if (reset_counter) begin
            counter <= 0;
        end else if (period_reg != 0) begin
            if (counter >= period_reg - 1)
                counter <= 0;
            else
                counter <= counter + 1;
        end
    end
end

// Генерация выхода PWM
assign pwm_out = (period_reg != 0) && (counter < duty_reg);

// Логика конечного автомата AXI
always_ff @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        state <= IDLE;
        s_axi_awready <= 1'b1;
        s_axi_wready <= 1'b0;
        s_axi_bvalid <= 1'b0;
        s_axi_arready <= 1'b1;
        s_axi_rvalid <= 1'b0;
        reset_counter <= 1'b0;
    end else begin
        reset_counter <= 1'b0; // Сброс флага по умолчанию
        
        case (state)
            IDLE: begin
                if (s_axi_awvalid && s_axi_awready) begin
                    // Начало транзакции записи
                    awaddr_reg <= s_axi_awaddr;
                    s_axi_awready <= 1'b0;
                    s_axi_wready <= 1'b1;
                    state <= WRITE;
                end else if (s_axi_arvalid && s_axi_arready) begin
                    // Начало транзакции чтения
                    araddr_reg <= s_axi_araddr;
                    s_axi_arready <= 1'b0;
                    state <= READ;
                end
            end
            
            WRITE: begin
                if (s_axi_wvalid && s_axi_wready) begin
                    // Обработка записи данных                    
                    s_axi_wready <= 1'b0;
                    s_axi_bvalid <= 1'b1;
                    
                    // Запись в регистры
                    case (awaddr_reg)
                        4'h0: begin // Регистр периода
                            period_reg <= s_axi_wdata;
                            reset_counter <= 1'b1; // Инициировать сброс счетчика
                            if (duty_reg > s_axi_wdata)
                                duty_reg <= s_axi_wdata; // Автокоррекция duty
                        end
                        4'h4: begin // Регистр скважности
                            duty_reg <= (s_axi_wdata < period_reg) ? 
                                       s_axi_wdata : period_reg;
                        end
                    endcase
                    state <= IDLE;
                end
            end
            
            READ: begin
                s_axi_rvalid <= 1'b1;
                case (araddr_reg)
                    4'h0: s_axi_rdata <= period_reg;
                    4'h4: s_axi_rdata <= duty_reg;
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
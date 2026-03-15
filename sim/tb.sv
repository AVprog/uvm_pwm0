`timescale 1ns/1ps


    // bind         
    interface pwm_ch_if (input logic clk);
        logic [31:0] period;
        logic [31:0] duty;
        logic [31:0] counter;
        logic        pwm_out;
        logic        reset_counter; // может быть полезно для отладки

        modport mon (input clk, period, duty, counter, pwm_out, reset_counter);
    endinterface

// Модуль проверок для одного PWM‑канала
module pwm_assertions (
    input logic       clk,
    input logic       rst_n,
    input logic [31:0] period,
    input logic [31:0] duty,
    input logic       reset_counter,
    input logic       pwm_out,
    input logic [31:0] counter
);

    import uvm_pkg::*;

    pwm_ch_if if_pwm (.clk(clk)); 
    assign if_pwm.period        = period;        // сигнал из модуля pwm_channel
    assign if_pwm.duty          = duty;          // сигнал из модуля pwm_channel
    assign if_pwm.counter       = counter;       // сигнал из модуля pwm_channel
    assign if_pwm.pwm_out       = pwm_out;       // сигнал из модуля pwm_channel
    assign if_pwm.reset_counter = reset_counter; // сигнал из модуля pwm_channel

    // После reset_counter счётчик должен стать 0 на следующем такте
    property reset_check;
        @(posedge clk) reset_counter |=> (counter == 0);
    endproperty
    assert property (reset_check)
        else $error("%t: Counter not reset after reset_counter", $time);

    initial begin

        uvm_config_db#(virtual pwm_ch_if)::set(
            null,                          // Нет контекста, используем абсолютный путь
            "uvm_test_top.*",                   // Путь к экземпляру pwm_channel, который "владеет" интерфейсом
            "pwm_vif",                     // Имя поля в конфигурационной базе
            if_pwm                         // Виртуальный интерфейс для сохранения
        );

    end

endmodule

// //     // Модуль для bind, который создаёт интерфейс внутри pwm_channel
// module pwm_channel_bind;
//     // Импортируем пакет UVM, чтобы пользоваться uvm_config_db
//     import uvm_pkg::*;

//     // Инстанцируем физический интерфейс
//     pwm_ch_if if_pwm (.clk(clk)); // Сигнал clk нужно будет пробросить или взять из области видимости

//     // Подключаем сигналы интерфейса к сигналам модуля pwm_channel
//     // (используем относительные имена, так как bind-модуль находится внутри pwm_channel)
//     assign if_pwm.period        = period;        // сигнал из модуля pwm_channel
//     assign if_pwm.duty          = duty;          // сигнал из модуля pwm_channel
//     assign if_pwm.counter       = counter;       // сигнал из модуля pwm_channel
//     assign if_pwm.pwm_out       = pwm_out;       // сигнал из модуля pwm_channel
//     assign if_pwm.reset_counter = reset_counter; // сигнал из модуля pwm_channel

//     // Регистрируем интерфейс в uvm_config_db
//     initial begin
//         // Формируем уникальный путь для этого экземпляра. %m вернёт что-то вроде
//         // "top.dut.ch0.pwm_channel_bind.if_pwm"
//        string inst_path = $sformatf("%m");
//         // Убираем суффикс, чтобы получить путь к родительскому модулю pwm_channel
//         string module_name = "pwm_channel_bind.if_pwm";
//        string target_path = inst_path.substr(0, inst_path.len() - 1 - module_name.len());
//        $display("!!!!!! inst_path: %s target_path: %s", inst_path, target_path);
//        target_path = "tb.dut.ch0.*";

//         uvm_config_db#(virtual pwm_ch_if)::set(
//             null,                          // Нет контекста, используем абсолютный путь
//             target_path,                   // Путь к экземпляру pwm_channel, который "владеет" интерфейсом
//             "pwm_vif",                     // Имя поля в конфигурационной базе
//             if_pwm                         // Виртуальный интерфейс для сохранения
//         );
//     end
// endmodule

module tb;
    import uvm_pkg::*;
    import pwm_axi_pkg::*;
    
    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Instantiate interfaces
    axi_if axi_if0(clk);
    
    // PWM output
    logic pwm_out0;
    logic pwm_out1;
    
    // Generate clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Generate reset
    initial begin
        rst_n = 0;
        axi_if0.reset();
        #20;
        rst_n = 1;
    end
    
    // DUT instance
    pwm_axi #(
        .C_S_AXI_ADDR_WIDTH(4),
        .C_S_AXI_DATA_WIDTH(32)
    ) dut (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rst_n),
        .s_axi_awaddr(axi_if0.awaddr),
        .s_axi_awprot(0),
        .s_axi_awvalid(axi_if0.awvalid),
        .s_axi_awready(axi_if0.awready),
        .s_axi_wdata(axi_if0.wdata),
        .s_axi_wstrb(4'b1111),
        .s_axi_wvalid(axi_if0.wvalid),
        .s_axi_wready(axi_if0.wready),
        .s_axi_bresp(axi_if0.bresp),
        .s_axi_bvalid(axi_if0.bvalid),
        .s_axi_bready(axi_if0.bready),
        .s_axi_araddr(axi_if0.araddr),
        .s_axi_arprot(0),
        .s_axi_arvalid(axi_if0.arvalid),
        .s_axi_arready(axi_if0.arready),
        .s_axi_rdata(axi_if0.rdata),
        .s_axi_rresp(axi_if0.rresp),
        .s_axi_rvalid(axi_if0.rvalid),
        .s_axi_rready(axi_if0.rready),
        .pwm_out0(pwm_out0),
        .pwm_out1(pwm_out1)
    );

    //bind dut.ch0 pwm_ch_if ch0_if (.clk(s_axi_aclk)); // Подключаем такты из топ-уровня
    //bind dut.ch0 pwm_channel_bind ch0_bind();
    //bind dut.ch1 pwm_channel_bind ch1_bind();

    bind dut.ch0 pwm_assertions ch0_assertions (
        .clk           (dut.s_axi_aclk),
        .rst_n         (dut.s_axi_aresetn),
        .period        (dut.period_reg0),
        .duty          (dut.duty_reg0),
        .reset_counter (dut.reset_counter0),
        .pwm_out       (dut.pwm_out0),
        .counter       (dut.ch0.counter)          // прямой доступ к внутреннему счётчику
    );
    
    // UVM start
    initial begin
        // Set virtual interface
        uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env.*", "vif", axi_if0); 

        // uvm_config_db#(virtual pwm_ch_if)::set(
        //     null,                          // Нет контекста, используем абсолютный путь
        //     "uvm_test_top.*",                   // Путь к экземпляру pwm_channel, который "владеет" интерфейсом
        //     "pwm_vif",                     // Имя поля в конфигурационной базе
        //     dut.ch0.ch0_if                          // Виртуальный интерфейс для сохранения
        // );
        // Run test
        run_test("base_test");
    end
    
    integer clk_count=0;
    // PWM waveform monitoring
    initial begin
        $timeformat(-9, 3, " ns", 10);        
        forever begin
            @(posedge clk);
            //$display("[%t] PWM_OUT = %b clk_count = %d", $realtime, pwm_out, clk_count);
            clk_count++;
        end
    end
    
    // Simulation control
    // initial begin
    //     #10000;
    //     $display("\n\nSimulation completed successfully");
    //     $finish;
    // end
    
    // VCD dumping
    initial begin
        $dumpfile("pwm_axi_tb.vcd");
        $dumpvars(0, tb);
    end
endmodule
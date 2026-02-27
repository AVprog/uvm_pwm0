// AXI Coverage Collector
class axi_coverage_collector extends uvm_subscriber #(axi_transaction);
    `uvm_component_utils(axi_coverage_collector)

    // Covergroup for address and data analysis
    covergroup cg_addr_data with function sample(bit [31:0] addr, bit [31:0] data, bit is_write, bit [1:0] resp);
        option.per_instance = 1;
        option.name = "AXI addr/data coverage";

        // Address coverage: учитываем ограничения транзакции
        cp_addr: coverpoint addr {
            bins low_addr[] = {0, 4};                     // Допустимые по constraint адреса
            bins others    = default;                      // Остальные (если появятся)
            bins addr_zero = {0};                           // Специальный бин для 0
            bins addr_four = {4};                           // Специальный бин для 4
        }

        // // Data coverage: разбиваем на диапазоны
        cp_data: coverpoint data {
            bins zero_data     = {0};
            bins small_data    = {[1:10]};                        // Маленькие числа
            bins medium_data   = {[11:100]};                       // Средние
            bins large_data    = {[101:1000]};                     // Большие
            bins huge_data     = {[1001:32'hFFFF_FFFF]};           // Огромные (почти все)
            bins max_data      = {32'hFFFF_FFFF};                  // Максимальное значение
        }

        // Тип операции: чтение/запись
        cp_is_write: coverpoint is_write {
            bins read  = {0};
            bins write = {1};
        }

        // Ответ AXI (можно анализировать отдельно)
        cp_resp: coverpoint resp {
            bins ok    = {2'b00};
            bins exok  = {2'b01};
            bins slverr= {2'b10};
            bins decerr= {2'b11};
        }

        // Перекрёстное покрытие: адрес и данные для записей
        cross_addr_data_write: cross cp_addr, cp_data, cp_is_write {
            ignore_bins ignore_read = binsof(cp_is_write) intersect {0};
        }

        // Перекрёстное покрытие: адрес и ответ
        cross_addr_resp: cross cp_addr, cp_resp;

    endgroup
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_addr_data = new();
    endfunction

    // Функция write вызывается при получении транзакции от анализатора (например, из монитора)
    function void write(axi_transaction t);
        `uvm_info("COV", $sformatf("Sampling transaction: %s", t.convert2string()), UVM_MEDIUM)
        cg_addr_data.sample(t.addr, t.data, t.is_write, t.resp);
    endfunction

    // Функция отчёта о покрытии
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf("Coverage value = %0.2f%%", cg_addr_data.get_inst_coverage()), UVM_MEDIUM)
    endfunction
endclass

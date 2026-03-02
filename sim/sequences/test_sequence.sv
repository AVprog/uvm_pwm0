    import uvm_pkg::*;
    `include "uvm_macros.svh"
   
   // Test Sequence
    class test_sequence extends uvm_sequence #(axi_transaction);
        `uvm_object_utils(test_sequence)
        
        virtual axi_if vif;         // Для доступа к тактовому сигналу
        
        function new(string name = "test_sequence");
            super.new(name);

        endfunction

    // Задача для ожидания указанного числа тактов
    task wait_delay(int cycles);
        if (cycles <= 0) return;
        `uvm_info("SEQ_DELAY", $sformatf("Waiting for %0d cycles", cycles), UVM_MEDIUM)
        repeat (cycles) @(posedge vif.clk);
    endtask
        
        task body();
            axi_transaction tr;   
            
        // Получаем виртуальный интерфейс
        if (!uvm_config_db#(virtual axi_if)::get(null, get_full_name(), "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface not set for sequence")   
        // Задержка перед началом последовательности
            wait_delay(20);                  
        
            // Initialize PWM
            `uvm_do_with(tr, { 
                addr == 0; 
                data == 90; 
                is_write == 1; 
            })
            
            `uvm_do_with(tr, { 
                addr == 4; 
                data == 10; 
                is_write == 1; 
            })

            wait_delay(50);

            `uvm_do_with(tr, { 
                addr == 8; 
                data == 90; 
                is_write == 1; 
            })
            
            `uvm_do_with(tr, { 
                addr == 4'hC; 
                data == 50; 
                is_write == 1; 
            })

  
            // // Read registers
            // `uvm_do_with(tr, { 
            //     addr == 0; 
            //     is_write == 0; 
            // })
            
            // `uvm_do_with(tr, { 
            //     addr == 4; 
            //     is_write == 0; 
            // })
            
            // // Test boundary conditions
            // `uvm_do_with(tr, { 
            //     addr == 4; 
            //     data == 145;  // Should be clipped to 100
            //     is_write == 1; 
            // })
            
            // `uvm_do_with(tr, { 
            //     addr == 4;                 
            //     is_write == 0; 
            // })
            
            // // Change period
            // `uvm_do_with(tr, { 
            //     addr == 0; 
            //     data == 200; 
            //     is_write == 1; 
            // })

            // `uvm_do_with(tr, { 
            //     addr == 0; 
            //     data == 10; 
            //     is_write == 1; 
            // })
            
            // `uvm_do_with(tr, { 
            //     addr == 4; 
            //     data == 5; 
            //     is_write == 1; 
            // })
        endtask
    endclass
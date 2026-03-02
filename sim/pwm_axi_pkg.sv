package pwm_axi_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `include "sequences/test_sequence.sv"
    `include "scoreboards/pwm_scoreboard.sv"
    `include "coverages/axi_coverage_collector.sv"

    // AXI Transaction
    class axi_transaction extends uvm_sequence_item;
        rand logic [31:0] addr;
        rand logic [31:0] data;
        rand bit is_write;
        logic [1:0] resp = 2'b00;
        real start_time;
        real end_time;
        
        constraint addr_c {
            addr[31:5] == 0;
            addr[4:0] inside {0, 4, 8, 4'hC};
        }
        
        constraint period_data_c {
            if (is_write && addr[3:0] == 0) data > 0;
        }
        
        `uvm_object_utils_begin(axi_transaction)
            `uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(data, UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(is_write, UVM_ALL_ON)
            `uvm_field_int(resp, UVM_ALL_ON | UVM_BIN)
            `uvm_field_real(start_time, UVM_ALL_ON | UVM_TIME)
            `uvm_field_real(end_time, UVM_ALL_ON | UVM_TIME)
        `uvm_object_utils_end
        
        function new(string name = "axi_transaction");
            super.new(name);
        endfunction
        
        function void set_start_time();
            start_time = $realtime;
        endfunction
        
        function void set_end_time();
            end_time = $realtime;
        endfunction
        
        function string convert2string();
            string s;
            s = $sformatf("Addr=0x%0h Data=0x%0h %s Resp=%b",
                          addr,
                          data,
                          (is_write) ? "WRITE" : "READ",
                          resp);
            s = $sformatf("%s [%0.3f ns - %0.3f ns]", s, start_time, end_time);
            return s;
        endfunction
    endclass

    // AXI Driver
    class axi_driver extends uvm_driver #(axi_transaction);
        `uvm_component_utils(axi_driver)
        virtual axi_if vif;
        
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
        
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set")
        endfunction
        
        task run_phase(uvm_phase phase);
            vif.reset();
            forever begin
                axi_transaction tr;
                seq_item_port.get_next_item(tr);
                `uvm_info("DRIVER", $sformatf("Driving transaction: %s", tr.convert2string()), UVM_MEDIUM)
                
                if (tr.is_write) begin
                    vif.drive_write(tr.addr, tr.data);
                end else begin
                    logic [31:0] rd_data;
                    vif.drive_read(tr.addr, rd_data);
                    tr.data = rd_data;
                end
                
                seq_item_port.item_done();
                `uvm_info("DRIVER", "Transaction completed", UVM_MEDIUM)
            end
        endtask
    endclass

    // AXI Monitor
    class axi_monitor extends uvm_monitor;
        `uvm_component_utils(axi_monitor)
        virtual axi_if vif;
        uvm_analysis_port #(axi_transaction) ap;
        
        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction
        
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set")
        endfunction
        
        task run_phase(uvm_phase phase);
            forever begin
                axi_transaction tr;
                tr = axi_transaction::type_id::create("tr");
                tr.set_start_time();
                
                // Wait for transaction start
                @(posedge vif.clk iff (vif.awvalid && vif.awready) || 
                                  (vif.arvalid && vif.arready));
                
                if (vif.awvalid && vif.awready) begin
                    // Write transaction
                    tr.addr = vif.awaddr;
                    tr.is_write = 1;
                    
                    // Wait for data phase
                    @(posedge vif.clk iff vif.wvalid && vif.wready);
                    tr.data = vif.wdata;
                    
                    // Wait for response
                    @(posedge vif.clk iff vif.bvalid && vif.bready);
                    tr.resp = vif.bresp;
                end
                else if (vif.arvalid && vif.arready) begin
                    // Read transaction
                    tr.addr = vif.araddr;
                    tr.is_write = 0;
                    
                    // Wait for data phase
                    @(posedge vif.clk iff vif.rvalid && vif.rready);
                    tr.data = vif.rdata;
                    tr.resp = vif.rresp;
                end
                
                tr.set_end_time();
                ap.write(tr);
                `uvm_info("MONITOR", $sformatf("Monitored transaction: %s", tr.convert2string()), UVM_MEDIUM)
            end
        endtask
    endclass

    // Test Environment
    class test_env extends uvm_env;
        `uvm_component_utils(test_env)
        axi_driver driver;
        axi_monitor monitor;
        pwm_scoreboard scoreboard;
        uvm_sequencer #(axi_transaction) sequencer;
        axi_coverage_collector coverage_collector;
        
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
        
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            driver = axi_driver::type_id::create("driver", this);
            monitor = axi_monitor::type_id::create("monitor", this);
            scoreboard = pwm_scoreboard::type_id::create("scoreboard", this);
            sequencer = uvm_sequencer #(axi_transaction)::type_id::create("sequencer", this);
            coverage_collector = axi_coverage_collector::type_id::create("axi_coverage_collector", this);
        endfunction
        
        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export); 
            monitor.ap.connect(scoreboard.item_collected_export);
            monitor.ap.connect(coverage_collector.analysis_export);
        endfunction
    endclass

    // Base Test
    class base_test extends uvm_test;
        `uvm_component_utils(base_test)
        test_env env;
        test_sequence seq;
        
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
        
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = test_env::type_id::create("env", this);
            seq = test_sequence::type_id::create("seq");
        endfunction
        
        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            seq.start(env.sequencer);
            #8000; // Allow time for PWM operation
            phase.drop_objection(this);
        endtask
    endclass
endpackage
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // PWM Scoreboard
    class pwm_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(pwm_scoreboard)
        uvm_analysis_imp #(axi_transaction, pwm_scoreboard) item_collected_export;
        
        // Reference model storage
        logic [31:0] period_reg = 0;
        logic [31:0] duty_reg = 0;
        
        function new(string name, uvm_component parent);
            super.new(name, parent);
            item_collected_export = new("item_collected_export", this);
        endfunction
        
        function void write(axi_transaction tr);
            // Update reference model
            if (tr.is_write) begin
                case (tr.addr[3:0])
                    4'h0: period_reg = tr.data;
                    4'h4: duty_reg = (tr.data < period_reg) ? tr.data : period_reg;
                endcase
                `uvm_info("SCOREBOARD", $sformatf("Updated registers: Period=%0d, Duty=%0d", 
                                                 period_reg, duty_reg), UVM_MEDIUM)
            end 
            else begin
                logic [31:0] expected;
                case (tr.addr[3:0])
                    4'h0: expected = period_reg;
                    4'h4: expected = duty_reg;
                    default: expected = 32'h0;
                endcase
                
                if (tr.data !== expected) begin
                    `uvm_error("SCOREBOARD", $sformatf("Read mismatch! Addr=0x%0h: Exp=0x%0h, Got=0x%0h", 
                                                      tr.addr, expected, tr.data))
                end
                else begin
                    `uvm_info("SCOREBOARD", $sformatf("Read match: Addr=0x%0h, Data=0x%0h", 
                                                     tr.addr, tr.data), UVM_MEDIUM)
                end
            end
        endfunction
    endclass
   
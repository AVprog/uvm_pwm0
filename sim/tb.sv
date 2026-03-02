`timescale 1ns/1ps

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
    
    // UVM start
    initial begin
        // Set virtual interface
        uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env.*", "vif", axi_if0); 
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
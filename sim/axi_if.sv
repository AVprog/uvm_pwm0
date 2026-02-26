interface axi_if(input bit clk);
    logic [3:0] awaddr;
    logic awvalid;
    logic awready;
    logic [31:0] wdata;
    logic wvalid;
    logic wready;
    logic [1:0] bresp;
    logic bvalid;
    logic bready;
    logic [3:0] araddr;
    logic arvalid;
    logic arready;
    logic [31:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready;
    
    // Reset interface signals
    task reset();
        awvalid <= 0;
        awaddr <= 0;
        wvalid <= 0;
        wdata <= 0;
        bready <= 0;
        arvalid <= 0;
        araddr <= 0;
        rready <= 0;
    endtask
    
    // Drive write transaction
    task drive_write(input logic [31:0] addr, input logic [31:0] data);
        // Address phase
        @(posedge clk);
        awaddr <= addr[3:0];
        awvalid <= 1;
        
        // Data phase
        wdata <= data;
        wvalid <= 1;
        
        // Wait for handshake
        fork
            begin
                wait(awready);
                @(posedge clk);
                awvalid <= 0;
            end
            begin
                wait(wready);
                @(posedge clk);
                wvalid <= 0;
            end
        join
        
        // Response phase
        bready <= 1;
        wait(bvalid);
        @(posedge clk);
        bready <= 0;
    endtask
    
    // Drive read transaction
    task drive_read(input logic [31:0] addr, output logic [31:0] data);
        // Address phase
        @(posedge clk);
        araddr <= addr[3:0];
        arvalid <= 1;
        
        // Wait for address ready
        wait(arready);
        @(posedge clk);
        arvalid <= 0;
        
        // Data phase
        rready <= 1;
        wait(rvalid);
        data = rdata;
        @(posedge clk);
        rready <= 0;
    endtask
endinterface
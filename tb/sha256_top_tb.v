`timescale 1ns/1ps
module sha256_top_tb;
    reg clk;
    reg rst_n;
    reg input_start;
    reg input_done;
    reg [7:0] inp_data; 
    wire [255:0] hash;
    wire hash_valid;
    localparam [255:0] EXP_TOI_YEU_UIT    = 256'h920c567af0b7856f601b3b9b5e31fd8dfbf4c8658514d672818b5e10dc7ea28b;
    localparam [255:0] EXP_TANPRODZ       = 256'h1c241145f61fecc7e5fb3d2811558e68b589548a671f5ad6d8b19b497539648b;
    localparam [255:0] EXP_THACOMOBIHOME  = 256'haf7b22556046c054aeaf26c243188cbe9723544cf03ccc7a79916cb9c56b01d3;
    localparam [255:0] EXP_100A           = 256'h2816597888e4a0d3a36b82b83316ab32680eb8f00f8cd3b904d681246d285a0e; 
    localparam [255:0] EXP_60B            = 256'hbbeb514bf12fdef276e7fde1f3cadc8fd1ec8ec070d893bd98f5d1b383de66cf;
    integer i;
    sha256_top dut (
        .clk(clk), .rst_n(rst_n), .input_start(input_start),
        .input_done(input_done), .inp_data(inp_data),
        .hash(hash), .hash_valid(hash_valid)
    );

    always #5 clk = ~clk; 
    initial begin
        // Khoi tao he thong
        clk = 0;
        rst_n = 1; 
        input_start = 0; 
        input_done = 0; 
        inp_data = 8'd0;
        
        // Reset lan dau
        #20 rst_n = 0; 
        #10 rst_n = 1; 
        #10;

        // -------------------------------------------------------
        // TEST 1: "toi_yeu_uit"
        // -------------------------------------------------------
        $display("\n=======================================================");
        $display("TEST 1: Hashing 'toi_yeu_uit'");
        $display("=======================================================");
        
        input_start = 1; @(posedge clk); input_start = 0; 
        wait(dut.padding_inst.curr == 2'b01); 
        @(negedge clk);                       
        
        inp_data = "t"; #10; 
        inp_data = "o"; #10; 
        inp_data = "i"; #10; 
        inp_data = "_"; #10; 
        inp_data = "y"; #10; 
        inp_data = "e"; #10; 
        inp_data = "u"; #10; 
        inp_data = "_"; #10; 
        inp_data = "u"; #10; 
        inp_data = "i"; #10; 
        inp_data = "t"; #10;
        
        input_done = 1; #10; input_done = 0; 
        
        // Kiem tra ket qua Test 1
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_TOI_YEU_UIT);
        $display("Got   : %h", hash);
        if (hash == EXP_TOI_YEU_UIT) $display("[PASS] toi_yeu_uit"); 
        else                         $display("[FAIL] toi_yeu_uit");
        
        // Reset cho Test tiep theo
        #20 rst_n = 0; #10 rst_n = 1; #10;

        // -------------------------------------------------------
        // TEST 2: "tanprodz"
        // -------------------------------------------------------
        $display("\n=======================================================");
        $display("TEST 2: Hashing 'tanprodz'");
        $display("=======================================================");
        
        input_start = 1; @(posedge clk); input_start = 0; 
        wait(dut.padding_inst.curr == 2'b01); 
        @(negedge clk);
        
        inp_data = "t"; #10; 
        inp_data = "a"; #10;  
        inp_data = "n"; #10; 
        inp_data = "p"; #10; 
        inp_data = "r"; #10; 
        inp_data = "o"; #10; 
        inp_data = "d"; #10;  
        inp_data = "z"; #10;
        
        input_done = 1; #10; input_done = 0; 
        
        // Kiem tra ket qua Test 2
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_TANPRODZ);
        $display("Got   : %h", hash);
        if (hash == EXP_TANPRODZ) $display("[PASS] tanprodz"); 
        else                      $display("[FAIL] tanprodz");
        
        // Reset cho Test tiep theo
        #20 rst_n = 0; #10 rst_n = 1; #10;

        // -------------------------------------------------------
        // TEST 3: "thacomobihome"
        // -------------------------------------------------------
        $display("\n=======================================================");
        $display("TEST 3: Hashing 'thacomobihome'");
        $display("=======================================================");
        
        input_start = 1; @(posedge clk); input_start = 0;
        wait(dut.padding_inst.curr == 2'b01); 
        @(negedge clk);
        
        inp_data = "t"; #10; 
        inp_data = "h"; #10;  
        inp_data = "a"; #10;  
        inp_data = "c"; #10; 
        inp_data = "o"; #10; 
        inp_data = "m"; #10; 
        inp_data = "o"; #10; 
        inp_data = "b"; #10; 
        inp_data = "i"; #10;  
        inp_data = "h"; #10;  
        inp_data = "o"; #10; 
        inp_data = "m"; #10; 
        inp_data = "e"; #10; 
        
        input_done = 1; #10; input_done = 0; 
        
        // Kiem tra ket qua Test 3
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_THACOMOBIHOME);
        $display("Got   : %h", hash);
        if (hash == EXP_THACOMOBIHOME) $display("[PASS] thacomobihome"); 
        else                           $display("[FAIL] thacomobihome");
        
        // Reset cho Test tiep theo
        #20 rst_n = 0; #10 rst_n = 1; #10;

        // -------------------------------------------------------
        // TEST 4: 100 ky tu 'a'(len > 64, can them block rong)
        // -------------------------------------------------------
        $display("\n=======================================================");
        $display("TEST 4: Hashing 100 ky tu 'a'");
        $display("=======================================================");
        
        input_start = 1; @(posedge clk); input_start = 0;
        
        for (i = 0; i < 100; i = i + 1) begin
            wait(dut.padding_inst.curr == 2'b01);
            @(negedge clk);
            inp_data = "a"; 
            #10;
        end
        
        wait(dut.padding_inst.curr == 2'b01);
        @(negedge clk); 
        input_done = 1; #10; input_done = 0; 
        
        // Kiem tra ket qua Test 4
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_100A);
        $display("Got   : %h", hash);
        if (hash == EXP_100A) $display("[PASS] 100_a"); 
        else                  $display("[FAIL] 100_a");
        #20 rst_n = 0; #10 rst_n = 1; #10;
        // -------------------------------------------------------
        // TEST 5: 64 ky tu 'b' (55<len<64, can them block rong)
        // -------------------------------------------------------
        $display("\n=======================================================");
        $display("TEST 5: Hashing 60 ky tu 'b' (Block Boundary Case)");
        $display("=======================================================");
        
        input_start = 1; @(posedge clk); input_start = 0;
        
        for (i = 0; i < 60; i = i + 1) begin
            wait(dut.padding_inst.curr == 2'b01); // Chờ Padding rảnh
            @(negedge clk);
            inp_data = "b"; 
            #10;
        end
        
        wait(dut.padding_inst.curr == 2'b01);
        @(negedge clk); 
        input_done = 1; #10; input_done = 0; 
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_60B);
        $display("Got : %h", hash);
        if (hash == EXP_60B) $display("[PASS] 60_b"); 
        else     $display("[FAIL] 60_b");
        
        $display("\n=======================================================");
        $display("ALL TESTS COMPLETED"); 
        $display("=======================================================\n");
        
        #100; $finish;
    end
endmodule
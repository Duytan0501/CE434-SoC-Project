`timescale 1ns/1ps

module sha256_top_tb;
    reg clk;
    reg rst_n;
    reg input_start;
    reg input_done;
    
    // Ngõ vào 32-bit và Byte Strobe
    reg [31:0] inp_data; 
    reg [ 3:0] inp_strb; 
    
    // Tín hiệu giao tiếp lấy kết quả
    reg  [ 2:0] hash_rd_addr;
    wire [31:0] hash_out_32;
    wire ready_for_input;
    wire hash_valid;

    // Biến phụ trợ trong TB để ráp lại kết quả 256-bit phục vụ việc so sánh
    reg [255:0] hash_reconstructed;
    integer j; // Biến chạy vòng lặp đọc MUX

    localparam [255:0] EXP_TOI_YEU_UIT    = 256'h920c567af0b7856f601b3b9b5e31fd8dfbf4c8658514d672818b5e10dc7ea28b;
    localparam [255:0] EXP_TANPRODZ       = 256'h1c241145f61fecc7e5fb3d2811558e68b589548a671f5ad6d8b19b497539648b;
    localparam [255:0] EXP_THACOMOBIHOME  = 256'haf7b22556046c054aeaf26c243188cbe9723544cf03ccc7a79916cb9c56b01d3;
    localparam [255:0] EXP_1000A          = 256'h41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3;
    localparam [255:0] EXP_EMPTY          = 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855;
    localparam [255:0] EXP_NIST_56        = 256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1;

    integer i;
    reg[447:0] nist_str;
    time start_hash;
    time end_hash;
    integer cycle_count;

    // Cập nhật port map DUT
    sha256_top dut (
        .clk(clk), 
        .rst_n(rst_n), 
        .input_start(input_start),
        .input_done(input_done), 
        .inp_data(inp_data),
        .inp_strb(inp_strb),
        .hash_rd_addr(hash_rd_addr),
        .hash_out_32(hash_out_32),
        .ready_for_input(ready_for_input), 
        .hash_valid(hash_valid)
    );

    always #10 clk = ~clk; 

    initial begin
        $dumpfile("sha256_wave.vcd"); 
        $dumpvars(0, sha256_top_tb);
        clk = 0;
        rst_n = 1; 
        input_start = 0; 
        input_done = 0; 
        inp_data = 32'd0;
        inp_strb = 4'd0;
        hash_rd_addr = 3'd0;
        hash_reconstructed = 256'h0;
        
        #20 rst_n = 0; 
        #10 rst_n = 1; 
        #10;

        // -------------------------------------------------------
        // TEST 1: "toi_yeu_uit" (11 bytes)
        // -------------------------------------------------------
        $display("TEST 1: Hashing 'toi_yeu_uit'");
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1); 
        @(negedge clk); 
        start_hash = $time;
        input_start = 0; 
        
        inp_data = "toi_"; inp_strb = 4'b1111; @(negedge clk);
        inp_data = "yeu_"; inp_strb = 4'b1111; @(negedge clk);
        inp_data = {"uit", 8'h00}; inp_strb = 4'b1110; @(negedge clk);
        
        inp_strb = 4'b0000; input_done = 1; @(negedge clk); 
        input_done = 0;
        
        wait(hash_valid == 1);
        end_hash=$time;
        @(negedge clk);
        
        // --- Bắt đầu vòng lặp đọc kết quả qua MUX ---
        for (j = 0; j < 8; j = j + 1) begin
            hash_rd_addr = j;
            @(negedge clk); // Đợi 1 nhịp cho mạch trả dữ liệu ra
            hash_reconstructed[255 - j*32 -: 32] = hash_out_32;
        end
        // ---------------------------------------------
        
        $display("Expected : %h", EXP_TOI_YEU_UIT);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_TOI_YEU_UIT) $display("[PASS] toi_yeu_uit");
        else                                       $display("[FAIL] toi_yeu_uit");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        repeat(2) @(negedge clk);
        rst_n = 0; repeat(2) @(negedge clk); rst_n = 1; repeat(2) @(negedge clk);

        // -------------------------------------------------------
        // TEST 2: "tanprodz" (8 bytes)
        // -------------------------------------------------------
        $display("\nTEST 2: Hashing 'tanprodz'");
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1); 
        @(negedge clk); 
        start_hash=$time;
        input_start = 0; 
        
        inp_data = "tanp"; inp_strb = 4'b1111; @(negedge clk);
        inp_data = "rodz"; inp_strb = 4'b1111; @(negedge clk);
        
        inp_strb = 4'b0000; input_done = 1; @(negedge clk); 
        input_done = 0;
        
        wait(hash_valid == 1);
        end_hash = $time;
        @(negedge clk);
        
        for (j = 0; j < 8; j = j + 1) begin
            hash_rd_addr = j;
            @(negedge clk);
            hash_reconstructed[255 - j*32 -: 32] = hash_out_32;
        end
        
        $display("Expected : %h", EXP_TANPRODZ);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_TANPRODZ) $display("[PASS] tanprodz");
        else                                    $display("[FAIL] tanprodz");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        repeat(2) @(negedge clk);
        rst_n = 0; repeat(2) @(negedge clk); rst_n = 1; repeat(2) @(negedge clk);

        // -------------------------------------------------------
        // TEST 3: "thacomobihome" (13 bytes)
        // -------------------------------------------------------
        $display("\nTEST 3: Hashing 'thacomobihome'");  
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1);        
        @(negedge clk); 
        start_hash=$time;
        input_start = 0;
        
        inp_data = "thac"; inp_strb = 4'b1111; @(negedge clk);
        inp_data = "omob"; inp_strb = 4'b1111; @(negedge clk);
        inp_data = "ihom"; inp_strb = 4'b1111; @(negedge clk);
        inp_data = {"e", 24'h000000}; inp_strb = 4'b1000; @(negedge clk);
        
        inp_strb = 4'b0000; input_done = 1; @(negedge clk); 
        input_done = 0;
        
        wait(hash_valid == 1);
        end_hash=$time;
        @(negedge clk);
        
        for (j = 0; j < 8; j = j + 1) begin
            hash_rd_addr = j;
            @(negedge clk);
            hash_reconstructed[255 - j*32 -: 32] = hash_out_32;
        end
        
        $display("Expected : %h", EXP_THACOMOBIHOME);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_THACOMOBIHOME) $display("[PASS] thacomobihome");
        else                                         $display("[FAIL] thacomobihome");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        repeat(2) @(negedge clk);
        rst_n = 0; repeat(2) @(negedge clk); rst_n = 1; repeat(2) @(negedge clk);

        // -------------------------------------------------------
        // TEST 4: Hash 1000 ky tu a
        // -------------------------------------------------------
        $display("\nTEST 4: Hashing 1000 ky tu 'a'");
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1);
        @(negedge clk); 
        start_hash = $time;
        input_start = 0;
        
        for (i = 0; i < 250; i = i + 1) begin
            inp_data = "aaaa"; 
            inp_strb = 4'b1111;
            @(negedge clk); 
            while (ready_for_input == 1'b0) begin
                @(negedge clk);
            end
        end
        
        inp_strb = 4'b0000; input_done = 1; @(negedge clk); 
        input_done = 0; 
        
        wait(hash_valid == 1);
        end_hash=$time;
        @(negedge clk);
        
        for (j = 0; j < 8; j = j + 1) begin
            hash_rd_addr = j;
            @(negedge clk);
            hash_reconstructed[255 - j*32 -: 32] = hash_out_32;
        end
        
        $display("Expected : %h", EXP_1000A);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_1000A) $display("[PASS] 1000_a");
        else                                 $display("[FAIL] 1000_a");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        repeat(2) @(negedge clk);
        rst_n = 0; repeat(2) @(negedge clk); rst_n = 1; repeat(2) @(negedge clk);

        // -------------------------------------------------------
        // TEST 5: Empty String
        // -------------------------------------------------------
        $display("\nTEST 5: Empty String");
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1);
        @(negedge clk); 
        start_hash = $time;
        input_start = 0;
        inp_strb = 4'b0000; 
        input_done = 1; @(negedge clk);
        input_done = 0; 
        
        wait(hash_valid == 1);
        end_hash = $time;
        @(negedge clk);
        
        for (j = 0; j < 8; j = j + 1) begin
            hash_rd_addr = j;
            @(negedge clk);
            hash_reconstructed[255 - j*32 -: 32] = hash_out_32;
        end
        
        $display("Expected : %h", EXP_EMPTY);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_EMPTY) $display("[PASS] Empty String"); 
        else                                 $display("[FAIL] Empty String");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        repeat(2) @(negedge clk);
        rst_n = 0; repeat(2) @(negedge clk); rst_n = 1; repeat(2) @(negedge clk);

        // -------------------------------------------------------
        // TEST 6: NIST SHA256 Example (Long Message - 56 bytes)
        // -------------------------------------------------------
        $display("\nTEST 6: NIST long message example "); 
        nist_str = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1);
        @(negedge clk); 
        start_hash = $time;
        input_start = 0;
        
        for (i = 0; i < 14; i = i + 1) begin
            inp_data = nist_str >> ((13 - i) * 32); 
            inp_strb = 4'b1111;
            @(negedge clk);
            while (ready_for_input == 1'b0) @(negedge clk);
        end
        
        inp_strb = 4'b0000; input_done = 1; @(negedge clk); 
        input_done = 0; 
        
        wait(hash_valid == 1);
        end_hash = $time;
        @(negedge clk);
        
        for (j = 0; j < 8; j = j + 1) begin
            hash_rd_addr = j;
            @(negedge clk);
            hash_reconstructed[255 - j*32 -: 32] = hash_out_32;
        end
        
        $display("Expected : %h", EXP_NIST_56);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_NIST_56) $display("[PASS] NIST long message");
        else                                   $display("[FAIL] NIST long message");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        $display("\n=======================================================");
        $display("ALL TESTS COMPLETED"); 
        $display("=======================================================\n");        
        #100; $finish;
    end
endmodule
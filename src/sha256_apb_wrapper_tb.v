`timescale 1ns/1ps

module sha256_apb_wrapper_tb;
    reg         PCLK;
    reg         PRESETn;
    reg  [31:0] PADDR;
    reg         PSEL;
    reg         PENABLE;
    reg         PWRITE;
    reg  [31:0] PWDATA;
    reg  [ 3:0] PSTRB;
    wire [31:0] PRDATA;
    wire        PREADY;
    wire        PSLVERR;

    // Biến phụ trợ
    reg [255:0] hash_reconstructed;
    reg [31:0]  read_val;
    integer j, i;
    reg[447:0] nist_str;
    time start_hash, end_hash;
    integer cycle_count;

    // Các hằng số kết quả mong đợi
    localparam [255:0] EXP_TOI_YEU_UIT    = 256'h920c567af0b7856f601b3b9b5e31fd8dfbf4c8658514d672818b5e10dc7ea28b;
    localparam [255:0] EXP_TANPRODZ       = 256'h1c241145f61fecc7e5fb3d2811558e68b589548a671f5ad6d8b19b497539648b;
    localparam [255:0] EXP_THACOMOBIHOME  = 256'haf7b22556046c054aeaf26c243188cbe9723544cf03ccc7a79916cb9c56b01d3;
    localparam [255:0] EXP_1000A          = 256'h41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3;
    localparam [255:0] EXP_EMPTY          = 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855;
    localparam [255:0] EXP_NIST_56        = 256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1;

    // ĐÃ SỬA: Nối dây tường minh (Explicit Port Mapping) thay vì dùng (.*)
    sha256_apb_wrapper dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PSTRB(PSTRB),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)
    );

    always #10 PCLK = ~PCLK; 

    // =======================================================
    // TASK: AMBA APB WRITE
    // =======================================================
    task apb_write(
        input [31:0] addr,
        input [31:0] data,
        input [ 3:0] strb
    );
        begin
            @(negedge PCLK); 
            PADDR   = addr; PWDATA  = data; PSTRB   = strb;
            PWRITE  = 1'b1; PSEL    = 1'b1; PENABLE = 1'b0;
            @(negedge PCLK); 
            PENABLE = 1'b1;
            wait(PREADY == 1'b1);
            @(negedge PCLK); 
            PSEL    = 1'b0; PENABLE = 1'b0;
        end
    endtask

    // =======================================================
    // TASK: AMBA APB READ
    // =======================================================
    task apb_read(
        input  [31:0] addr,
        output [31:0] data
    );
        begin
            @(negedge PCLK); 
            PADDR   = addr; PWRITE  = 1'b0; PSEL    = 1'b1; PENABLE = 1'b0;
            @(negedge PCLK); 
            PENABLE = 1'b1;
            wait(PREADY == 1'b1);
            data = PRDATA;
            @(negedge PCLK); 
            PSEL    = 1'b0; PENABLE = 1'b0;
        end
    endtask

    // =======================================================
    // TASK: CHỜ MẠCH SẴN SÀNG (Polling ready_for_input)
    // =======================================================
    task wait_ready_for_input;
        begin
            read_val = 0;
            while ((read_val & 32'h01) == 0) begin
                apb_read(32'h00, read_val);
            end
        end
    endtask

    initial begin
        $dumpfile("sha256_apb_wave.vcd"); 
        $dumpvars(0, sha256_apb_wrapper_tb);
        PCLK = 0; PRESETn = 1; 
        PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = 0; PWDATA = 0; PSTRB = 0;
        hash_reconstructed = 256'h0;
        
        #20 PRESETn = 0; 
        #10 PRESETn = 1; 
        #10;

        // -------------------------------------------------------
        // TEST 1: "toi_yeu_uit" (11 bytes)
        // -------------------------------------------------------
        $display("TEST 1: Hashing 'toi_yeu_uit'");
        apb_write(32'h00, 32'h0000_0001, 4'b1111); // START
        wait_ready_for_input(); 
        start_hash = $time;
        
        apb_write(32'h04, "toi_", 4'b1111);
        apb_write(32'h04, "yeu_", 4'b1111);
        apb_write(32'h04, {"uit", 8'h00}, 4'b1110);
        
        apb_write(32'h00, 32'h0000_0002, 4'b1111); // DONE
        
        // Polling chờ hash_valid
        read_val = 0;
        while ((read_val & 32'h02) == 0) apb_read(32'h00, read_val);
        end_hash = $time;
        
        // Đọc 8 word mã băm từ địa chỉ 0x20 đến 0x3C
        for (j = 0; j < 8; j = j + 1) begin
            apb_read(32'h20 + (j*4), read_val);
            hash_reconstructed[255 - j*32 -: 32] = read_val;
        end
        
        $display("Expected : %h", EXP_TOI_YEU_UIT);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_TOI_YEU_UIT) $display("[PASS] toi_yeu_uit");
        else                                       $display("[FAIL] toi_yeu_uit");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        #40 PRESETn = 0; #40 PRESETn = 1; #40;

        // -------------------------------------------------------
        // TEST 2: "tanprodz" (8 bytes)
        // -------------------------------------------------------
        $display("\nTEST 2: Hashing 'tanprodz'");
        apb_write(32'h00, 32'h0000_0001, 4'b1111); 
        wait_ready_for_input(); 
        start_hash=$time;
        
        apb_write(32'h04, "tanp", 4'b1111);
        apb_write(32'h04, "rodz", 4'b1111);
        apb_write(32'h00, 32'h0000_0002, 4'b1111); 
        
        read_val = 0;
        while ((read_val & 32'h02) == 0) apb_read(32'h00, read_val);
        end_hash = $time;
        
        for (j = 0; j < 8; j = j + 1) begin
            apb_read(32'h20 + (j*4), read_val);
            hash_reconstructed[255 - j*32 -: 32] = read_val;
        end
        
        $display("Expected : %h", EXP_TANPRODZ);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_TANPRODZ) $display("[PASS] tanprodz");
        else                                    $display("[FAIL] tanprodz");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        #40 PRESETn = 0; #40 PRESETn = 1; #40;

        // -------------------------------------------------------
        // TEST 3: "thacomobihome" (13 bytes)
        // -------------------------------------------------------
        $display("\nTEST 3: Hashing 'thacomobihome'");  
        apb_write(32'h00, 32'h0000_0001, 4'b1111);
        wait_ready_for_input();        
        start_hash=$time;
        
        apb_write(32'h04, "thac", 4'b1111);
        apb_write(32'h04, "omob", 4'b1111);
        apb_write(32'h04, "ihom", 4'b1111);
        apb_write(32'h04, {"e", 24'h000000}, 4'b1000);
        apb_write(32'h00, 32'h0000_0002, 4'b1111); 
        
        read_val = 0;
        while ((read_val & 32'h02) == 0) apb_read(32'h00, read_val);
        end_hash=$time;
        
        for (j = 0; j < 8; j = j + 1) begin
            apb_read(32'h20 + (j*4), read_val);
            hash_reconstructed[255 - j*32 -: 32] = read_val;
        end
        
        $display("Expected : %h", EXP_THACOMOBIHOME);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_THACOMOBIHOME) $display("[PASS] thacomobihome");
        else                                         $display("[FAIL] thacomobihome");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        #40 PRESETn = 0; #40 PRESETn = 1; #40;

        // -------------------------------------------------------
        // TEST 4: Hash 1000 ky tu a
        // -------------------------------------------------------
        $display("\nTEST 4: Hashing 1000 ky tu 'a'");
        apb_write(32'h00, 32'h0000_0001, 4'b1111);
        wait_ready_for_input();
        start_hash = $time;
        
        for (i = 0; i < 250; i = i + 1) begin
            apb_write(32'h04, "aaaa", 4'b1111);
            wait_ready_for_input();
        end
        
        apb_write(32'h00, 32'h0000_0002, 4'b1111); 
        
        read_val = 0;
        while ((read_val & 32'h02) == 0) apb_read(32'h00, read_val);
        end_hash=$time;
        
        for (j = 0; j < 8; j = j + 1) begin
            apb_read(32'h20 + (j*4), read_val);
            hash_reconstructed[255 - j*32 -: 32] = read_val;
        end
        
        $display("Expected : %h", EXP_1000A);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_1000A) $display("[PASS] 1000_a");
        else                                 $display("[FAIL] 1000_a");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        #40 PRESETn = 0; #40 PRESETn = 1; #40;

        // -------------------------------------------------------
        // TEST 5: Empty String
        // -------------------------------------------------------
        $display("\nTEST 5: Empty String");
        apb_write(32'h00, 32'h0000_0001, 4'b1111); 
        wait_ready_for_input();
        start_hash = $time;
        
        apb_write(32'h00, 32'h0000_0002, 4'b1111); 
        
        read_val = 0;
        while ((read_val & 32'h02) == 0) apb_read(32'h00, read_val);
        end_hash = $time;
        
        for (j = 0; j < 8; j = j + 1) begin
            apb_read(32'h20 + (j*4), read_val);
            hash_reconstructed[255 - j*32 -: 32] = read_val;
        end
        
        $display("Expected : %h", EXP_EMPTY);
        $display("Got      : %h", hash_reconstructed);
        if (hash_reconstructed == EXP_EMPTY) $display("[PASS] Empty String"); 
        else                                 $display("[FAIL] Empty String");
        cycle_count = (end_hash-start_hash) / 20;
        $display("Time elapsed: %0dns (%0d clock cycles)", (end_hash - start_hash), cycle_count);
        #40 PRESETn = 0; #40 PRESETn = 1; #40;

        // -------------------------------------------------------
        // TEST 6: NIST SHA256 Example (Long Message - 56 bytes)
        // -------------------------------------------------------
        $display("\nTEST 6: NIST long message example "); 
        nist_str = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
        apb_write(32'h00, 32'h0000_0001, 4'b1111);
        wait_ready_for_input();
        start_hash = $time;
        
        for (i = 0; i < 14; i = i + 1) begin
            apb_write(32'h04, nist_str >> ((13 - i) * 32), 4'b1111);
            wait_ready_for_input();
        end
        
        apb_write(32'h00, 32'h0000_0002, 4'b1111);
        
        read_val = 0;
        while ((read_val & 32'h02) == 0) apb_read(32'h00, read_val);
        end_hash = $time;
        
        for (j = 0; j < 8; j = j + 1) begin
            apb_read(32'h20 + (j*4), read_val);
            hash_reconstructed[255 - j*32 -: 32] = read_val;
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
        #100; $stop;
    end
endmodule
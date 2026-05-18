`timescale 1ns/1ps
module sha256_top_tb;
    reg clk;
    reg rst_n;
    reg input_start;
    reg input_done;
    reg [7:0] inp_data; 
    wire [255:0] hash;
    wire ready_for_input;
    wire hash_valid;
    localparam [255:0] EXP_TOI_YEU_UIT    = 256'h920c567af0b7856f601b3b9b5e31fd8dfbf4c8658514d672818b5e10dc7ea28b;
    localparam [255:0] EXP_TANPRODZ       = 256'h1c241145f61fecc7e5fb3d2811558e68b589548a671f5ad6d8b19b497539648b;
    localparam [255:0] EXP_THACOMOBIHOME  = 256'haf7b22556046c054aeaf26c243188cbe9723544cf03ccc7a79916cb9c56b01d3;
    localparam [255:0] EXP_1000A          = 256'h41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3;
    localparam [255:0] EXP_EMPTY          = 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855;
    localparam [255:0] EXP_NIST_56        = 256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1;
    integer i;
    reg[447:0] nist_str;
    sha256_top dut (
        .clk(clk), .rst_n(rst_n), .input_start(input_start),
        .input_done(input_done), .inp_data(inp_data),
        .hash(hash), 
        .ready_for_input(ready_for_input), 
        .hash_valid(hash_valid)
    );
    always #10 clk = ~clk; 
    initial begin
        clk = 0;
        rst_n = 1; 
        input_start = 0; 
        input_done = 0; 
        inp_data = 8'd0;
        #20 rst_n = 0; 
        #10 rst_n = 1; 
        #10;
        // -------------------------------------------------------
        // TEST 1: "toi_yeu_uit"
        // -------------------------------------------------------
        $display("TEST 1: Hashing 'toi_yeu_uit'");
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1); 
        @(negedge clk); 
        input_start = 0; 
        inp_data = "t"; 
        @(negedge clk); inp_data = "o"; 
        @(negedge clk); inp_data = "i"; 
        @(negedge clk); inp_data = "_"; 
        @(negedge clk); inp_data = "y"; 
        @(negedge clk); inp_data = "e"; 
        @(negedge clk); inp_data = "u"; 
        @(negedge clk); inp_data = "_"; 
        @(negedge clk); inp_data = "u"; 
        @(negedge clk); inp_data = "i"; 
        @(negedge clk); inp_data = "t"; 
        @(negedge clk); input_done = 1; 
        @(negedge clk); input_done = 0;
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_TOI_YEU_UIT);
        $display("Got      : %h", hash);
        if (hash == EXP_TOI_YEU_UIT) $display("[PASS] toi_yeu_uit");
        else                         $display("[FAIL] toi_yeu_uit");
        repeat(2) @(negedge clk);
        rst_n = 0; repeat(2) @(negedge clk); rst_n = 1; repeat(2) @(negedge clk);
        // -------------------------------------------------------
        // TEST 2: "tanprodz"
        // -------------------------------------------------------
        $display("\nTEST 2: Hashing 'tanprodz'");
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1); 
        @(negedge clk); 
        input_start = 0; 
        inp_data = "t"; 
        @(negedge clk); inp_data = "a";  
        @(negedge clk); inp_data = "n"; 
        @(negedge clk); inp_data = "p"; 
        @(negedge clk); inp_data = "r"; 
        @(negedge clk); inp_data = "o"; 
        @(negedge clk); inp_data = "d";  
        @(negedge clk); inp_data = "z"; 
        @(negedge clk); input_done = 1; 
        @(negedge clk); input_done = 0;
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_TANPRODZ);
        $display("Got      : %h", hash);
        if (hash == EXP_TANPRODZ) $display("[PASS] tanprodz");
        else                      $display("[FAIL] tanprodz");
        repeat(2) @(negedge clk);
        rst_n = 0; repeat(2) @(negedge clk); rst_n = 1; repeat(2) @(negedge clk);
        // -------------------------------------------------------
        // TEST 3: "thacomobihome"
        // -------------------------------------------------------
        $display("\nTEST 3: Hashing 'thacomobihome'");  
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1);        
        @(negedge clk); 
        input_start = 0;
        inp_data = "t";        
        @(negedge clk); inp_data = "h";  
        @(negedge clk); inp_data = "a";  
        @(negedge clk); inp_data = "c"; 
        @(negedge clk); inp_data = "o"; 
        @(negedge clk); inp_data = "m"; 
        @(negedge clk); inp_data = "o"; 
        @(negedge clk); inp_data = "b"; 
        @(negedge clk); inp_data = "i";  
        @(negedge clk); inp_data = "h"; 
        @(negedge clk); inp_data = "o"; 
        @(negedge clk); inp_data = "m"; 
        @(negedge clk); inp_data = "e";        
        @(negedge clk); input_done = 1; 
        @(negedge clk); input_done = 0;
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_THACOMOBIHOME);
        $display("Got      : %h", hash);
        if (hash == EXP_THACOMOBIHOME) $display("[PASS] thacomobihome");
        else                           $display("[FAIL] thacomobihome");
        repeat(2) @(negedge clk);
        rst_n = 0; repeat(2) @(negedge clk); rst_n = 1; repeat(2) @(negedge clk);
        // -------------------------------------------------------
        // TEST 4: Hash 1000 ky tu a
        // -------------------------------------------------------
        $display("TEST 4: Hashing 1000 ky tu 'a'");
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1);
        @(negedge clk); 
        input_start = 0;
        for (i = 0; i < 1000; i = i + 1) begin
            inp_data = "a"; 
            @(negedge clk); 
            while (ready_for_input == 1'b0) begin
                @(negedge clk);
            end
        end
        input_done = 1; 
        @(negedge clk); 
        input_done = 0; 
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_1000A);
        $display("Got      : %h", hash);
        if (hash == EXP_1000A) $display("[PASS] 1000_a");
        else                  $display("[FAIL] 1000_a");
        repeat(2) @(negedge clk);
        rst_n = 0; repeat(2) @(negedge clk); rst_n = 1; repeat(2) @(negedge clk);
        // -------------------------------------------------------
        // TEST 5: Empty String
        // -------------------------------------------------------
        $display("\nTEST 5: Empty String");
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1);
        @(negedge clk); 
        input_start = 0;
        input_done = 1; 
        @(negedge clk);
         input_done = 0; 
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_EMPTY);
        $display("Got      : %h", hash);
        if (hash == EXP_EMPTY) $display("[PASS] Empty String"); 
        else                   $display("[FAIL] Empty String");
        repeat(2) @(negedge clk);
        rst_n = 0; repeat(2) @(negedge clk); rst_n = 1; repeat(2) @(negedge clk);
        // -------------------------------------------------------
        // TEST 6: NIST SHA256 Example(Long Message)
        // -------------------------------------------------------
        $display("\nTEST 6: NIST long message example "); 
        nist_str = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
        @(negedge clk); input_start = 1; 
        wait(ready_for_input == 1'b1);
        @(negedge clk); 
        input_start = 0;
        for (i = 0; i < 56; i = i + 1) begin
            inp_data = nist_str >> ((55 - i) * 8); 
            @(negedge clk);
            while (ready_for_input == 1'b0) @(negedge clk);
        end
        input_done = 1; @(negedge clk); input_done = 0; 
        
        wait(hash_valid == 1);
        @(negedge clk);
        $display("Expected : %h", EXP_NIST_56);
        $display("Got      : %h", hash);
        if (hash == EXP_NIST_56) $display("[PASS] NIST long message");
        else                     $display("[FAIL] NIST long message");
        $display("\n=======================================================");
        $display("ALL TESTS COMPLETED"); 
        $display("=======================================================\n");        
        #100; $finish;
    end
endmodule
`timescale 1ns/1ps

module sha256_top_tb;
    reg clk;
    reg rst_n;
    reg input_start;
    reg input_done;
    
    // SỬA: Nâng lên 8-bit cho khớp với sha256_top và sha256_decode_mapping
    reg [7:0] inp_data; 
    
    wire [255:0] hash;
    wire hash_valid;

    // Expected Hashes
    localparam [255:0] EXP_TOI_YEU_UIT    = 256'h920c567af0b7856f601b3b9b5e31fd8dfbf4c8658514d672818b5e10dc7ea28b;
    localparam [255:0] EXP_TANPRODZ       = 256'h1c241145f61fecc7e5fb3d2811558e68b589548a671f5ad6d8b19b497539648b;
    localparam [255:0] EXP_THACOMOBIHOME  = 256'haf7b22556046c054aeaf26c243188cbe9723544cf03ccc7a79916cb9c56b01d3;

    sha256_top dut (
        .clk(clk), .rst_n(rst_n), .input_start(input_start),
        .input_done(input_done), .inp_data(inp_data),
        .hash(hash), .hash_valid(hash_valid)
    );

    always #5 clk = ~clk; // 100MHz [cite: 129]

    // === MONITOR: Hiển thị 8 thanh ghi sau mỗi Round ===
    always @(posedge clk) begin
        // Trạng thái RUN_ROUNDS = 3'b010, Stage cuối = 2'd2 [cite: 129]
        if (dut.comp_inst.state == 3'b010 ) begin
            $strobe("Round %2d | a=%h b=%h c=%h d=%h e=%h f=%h g=%h h=%h", 
                    dut.comp_inst.round, dut.comp_inst.a, dut.comp_inst.b, dut.comp_inst.c, 
                    dut.comp_inst.d, dut.comp_inst.e, dut.comp_inst.f, dut.comp_inst.g, dut.comp_inst.h); 
        end
    end

    // SỬA: Đầu vào task cũng phải là 8-bit
    task send_char(input [7:0] data);
    begin
        inp_data = data;
        #10; 
    end
    endtask

    initial begin
        clk = 0;
        rst_n = 1; input_start = 0; input_done = 0; inp_data = 8'd0;
        #20 rst_n = 0; 
        #10 rst_n = 1; 
        #10;

        // TEST 1: "toi_yeu_uit"
        $display("\n========== TEST 1: Hashing 'toi_yeu_uit' ==========");
        input_start = 1; #10; input_start = 0; 
        
        // SỬA: Truyền dữ liệu 8-bit thay vì 6-bit
        send_char(8'd19); send_char(8'd14); send_char(8'd8);  send_char(8'd47); 
        send_char(8'd24); send_char(8'd4);  send_char(8'd20); send_char(8'd47); 
        send_char(8'd20); send_char(8'd8);  send_char(8'd19);
        
        input_done = 1; #10; input_done = 0; 
        wait(hash_valid == 1);
        if (hash == EXP_TOI_YEU_UIT) $display("✅ [PASS] toi_yeu_uit | Got: %h", hash); 
        else $display("❌ [FAIL] toi_yeu_uit | Got: %h", hash);
        #20 rst_n = 0; 
        #10 rst_n = 1; 
        #10;
        // TEST 2: "tanprodz"
        #50; $display("\n========== TEST 2: Hashing 'tanprodz' =========="); 
        input_start = 1; #10; input_start = 0; 
        
        send_char(8'd19); send_char(8'd0);  send_char(8'd13); send_char(8'd15); 
        send_char(8'd17); send_char(8'd14); send_char(8'd3);  send_char(8'd25);
        
        input_done = 1; #10; input_done = 0; 
        wait(hash_valid == 1);
        if (hash == EXP_TANPRODZ) $display("✅ [PASS] tanprodz | Got: %h", hash); 
        else $display("❌ [FAIL] tanprodz | Got: %h", hash);
        #20 rst_n = 0; 
        #10 rst_n = 1; 
        #10;
        // TEST 3: "thacomobihome"
        #50; $display("\n========== TEST 3: Hashing 'thacomobihome' ==========");
        input_start = 1; #10; input_start = 0;
        
        send_char(8'd19); send_char(8'd7);  send_char(8'd0);  send_char(8'd2); 
        send_char(8'd14); send_char(8'd12); send_char(8'd14); send_char(8'd1); 
        send_char(8'd8);  send_char(8'd7);  send_char(8'd14); send_char(8'd12); send_char(8'd4); 
        
        input_done = 1; #10; input_done = 0; 
        wait(hash_valid == 1);
        if (hash == EXP_THACOMOBIHOME) $display("✅ [PASS] thacomobihome | Got: %h", hash); 
        else $display("❌ [FAIL] thacomobihome | Got: %h", hash);

        $display("\n========== ALL TESTS COMPLETED =========="); 
        #100; $finish;
    end
endmodule

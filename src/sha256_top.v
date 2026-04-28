module sha256_top(
    input              clk,
    input              rst_n,
    input              input_start,
    input              input_done,
    input      [7:0]   inp_data,        // SỬA: 8-bit (1 byte) thay vì 6-bit
    output     [255:0] hash,
    output             hash_valid  
);
    wire [511:0] padded_msg;
    wire         padding_done;
    wire         ready_for_next_block;  // Thêm wire này
    
    // Instance message padding module
    sha256_message_padding padding_inst (
        .clk(clk),
        .rst_n(rst_n),
        .input_start(input_start),
        .input_done(input_done),
        .inp_data(inp_data),
        .padded_msg(padded_msg),
        .padding_done(padding_done)
    );
    
    // Instance round computation module (dùng module bạn đã viết)
    v2_sha256_round_scheduler_include comp_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(padding_done),           // Bắt đầu khi padding xong
        .message_block(padded_msg),     // Block 512-bit từ padding
        .last_block(1'b1),              // Top-level chỉ xử lý 1 block (message ngắn)
        .final_hash(hash),                    // Hash cuối cùng
        .hash_valid(hash_valid),        // Valid signal
        .ready_for_next_block(ready_for_next_block)  // Không dùng ở top
    );

endmodule

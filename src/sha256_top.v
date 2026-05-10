module sha256_top(
    input              clk,
    input              rst_n,
    input              input_start,
    input              input_done,
    input      [7:0]   inp_data,        
    output     [255:0] hash,
    output             ready_for_input,  
    output             hash_valid
);
    wire [511:0] padded_msg;
    wire         padding_done;
    wire         ready_for_next_block;  //Round san sang cho block moi
    wire         last_block;            //Block cuoi cung
    // Instance message padding module
    v2_sha256_message_padding padding_inst (
        .clk(clk),
        .rst_n(rst_n),
        .input_start(input_start),
        .input_done(input_done),
        .ready_for_next_block(ready_for_next_block), //Cờ báo từ round đã sắn sàng
        .inp_data(inp_data),                         //inp 8 bit
        .padded_msg(padded_msg),                     
        .padding_done(padding_done),                 //Đã pad xong 1 block
        .ready_for_input(ready_for_input),           //Sẵn sàng cho input mới
        .last_block(last_block)                      //Báo cho round là block cuối cùng
    );
    
    // Instance round computation module (dùng module bạn đã viết)
    v2_sha256_round_scheduler_include comp_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(padding_done),           // Bắt đầu khi padding xong
        .message_block(padded_msg),     // Block 512-bit từ padding
        .last_block(last_block),        // Top-level chỉ xử lý 1 block (message ngắn)
        .final_hash(hash),              // Hash cuối cùng
        .hash_valid(hash_valid),        // Valid signal
        .ready_for_next_block(ready_for_next_block) //Sẵn sàng cho block mới
    );

endmodule
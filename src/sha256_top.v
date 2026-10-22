module sha256_top(
    input              clk,
    input              rst_n,
    input              input_start,
    input              input_done,
    input      [31:0]  inp_data,        
    input      [3:0]   inp_strb, 
    input      [2:0]   hash_rd_addr,
    output     [31:0]  hash_out_32,
    output             ready_for_input,  
    output             hash_valid
);
    wire         padding_done;
    wire         ready_for_next_block;  //Round san sang cho block moi
    wire         last_block;            //Block cuoi cung
	 wire         pad_wren;
    wire [3:0]   pad_waddr;
    wire [3:0]   pad_wstrb;
    wire [31:0]  pad_wdata;
    wire         pad_clear;
    // Instance message padding module
    v2_sha256_message_padding padding_inst (
        .clk(clk),
        .rst_n(rst_n),
        .input_start(input_start),
        .input_done(input_done),
        .ready_for_next_block(ready_for_next_block), //Cờ báo từ round đã sắn sàng
        .inp_data(inp_data),                         //inp 8 bit
        .inp_strb(inp_strb),                    
        .padding_done(padding_done),                 //Đã pad xong 1 block
        .ready_for_input(ready_for_input),           //Sẵn sàng cho input mới
		  .pad_wren(pad_wren),
        .pad_waddr(pad_waddr),
        .pad_wstrb(pad_wstrb),
        .pad_wdata(pad_wdata),
        .pad_clear(pad_clear),
        .last_block(last_block)                      //Báo cho round là block cuối cùng
    );
    v2_sha256_round_scheduler_include comp_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(padding_done),           // Bắt đầu khi padding xong
        .pad_wren(pad_wren),
        .pad_waddr(pad_waddr),
        .pad_wstrb(pad_wstrb),
        .pad_wdata(pad_wdata),
        .pad_clear(pad_clear),     			
        .last_block(last_block),        // Top-level chỉ xử lý 1 block (message ngắn)
        .hash_rd_addr(hash_rd_addr),    // Địa chỉ đọc
        .hash_out_32(hash_out_32),      // 32 bit hash
        .hash_valid(hash_valid),        // Valid signal
        .ready_for_next_block(ready_for_next_block) //Sẵn sàng cho block mới
    );

endmodule
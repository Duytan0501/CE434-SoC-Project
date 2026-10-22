module v2_sha256_message_padding (
    input              clk,
    input              rst_n,                 //reset active low
    input              input_start,           //bat dau nhap
    input              input_done,            //nhap xong
    input              ready_for_next_block,  //schedule doi block moi   
    input      [31:0]  inp_data,              //input
    input      [3:0]   inp_strb,
    output             ready_for_input,
    output             pad_wren,
    output reg [ 3:0]  pad_waddr,
    output reg [ 3:0]  pad_wstrb,
    output reg [31:0]  pad_wdata,
    output 	           pad_clear,       		 //msg da pad xong      
    output reg         padding_done,          //co bao da pad xong 1 block
    output reg         last_block             //block cuoi
);
  localparam IDLE = 3'd0;  //trang thai cho
  localparam PROCESSING = 3'd1;  //trang thai xu ly
  localparam PAD_80     = 3'd2;
  localparam PAD_LEN_H  = 3'd3;
  localparam PAD_LEN_L  = 3'd4;
  localparam WAIT_ROUND = 3'd5;
  localparam WAIT_EXTRA = 3'd6;
  reg  [2:0] curr, next;  //luu trang thai
  reg  [ 5:0] write_ptr;  //con tro ghi
  reg [29:0] msg_length_low;
  reg [30:0] msg_length_high;
  wire [63:0] msg_length = {msg_length_high, msg_length_low, 3'b000};//Chia doi msg_length(64 bit lam giam fmax)
  wire [2:0] bytes_valid = {2'b0, inp_strb[3]} + {2'b0, inp_strb[2]} + {2'b0, inp_strb[1]} + {2'b0, inp_strb[0]};
  assign ready_for_input = (curr == PROCESSING);//Chi khi dang pad moi cho phep nhan du lieu\
  assign pad_wren = (curr == PROCESSING && inp_strb != 0) || 
                      (curr == PAD_80) || 
                      (curr == PAD_LEN_H) || 
                      (curr == PAD_LEN_L);
  assign pad_clear = (curr == IDLE && input_start) || 
                      (curr == WAIT_EXTRA && ready_for_next_block && !padding_done) ||
                      (curr == WAIT_ROUND && ready_for_next_block && !padding_done && !last_block);
    always @(*) begin
        pad_wdata = 32'd0; 
        pad_waddr = 4'd0; 
        pad_wstrb = 4'd0;
        if (curr == PROCESSING) begin
            pad_wdata = inp_data;
            pad_waddr = write_ptr[5:2]; 
            pad_wstrb = inp_strb;
        end else if (curr == PAD_80) begin
            pad_waddr = write_ptr[5:2];
            case (write_ptr[1:0])
                2'b00: begin pad_wdata = 32'h8000_0000; pad_wstrb = 4'b1000; end
                2'b01: begin pad_wdata = 32'h0080_0000; pad_wstrb = 4'b0100; end
                2'b10: begin pad_wdata = 32'h0000_8000; pad_wstrb = 4'b0010; end
                2'b11: begin pad_wdata = 32'h0000_0080; pad_wstrb = 4'b0001; end
            endcase
        end else if (curr == PAD_LEN_H) begin
            pad_waddr = 4'd14; 
            pad_wdata = msg_length[63:32];
            pad_wstrb = 4'b1111;
        end else if (curr == PAD_LEN_L) begin
            pad_waddr = 4'd15; 
            pad_wdata = msg_length[31:0];
            pad_wstrb = 4'b1111;
        end
    end
 always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        curr <= IDLE;
        write_ptr <= 0;
        msg_length_low <= 0;
        msg_length_high <= 0;
        padding_done <= 0;
        last_block <= 0;
    end else begin
        curr <= next;

        case (curr)
            IDLE: begin
                padding_done <= 0;
                last_block <= 0;
                if (input_start) begin
                    write_ptr <= 0;
                    msg_length_low <= 0;
                    msg_length_high <= 0;
                end
            end
            PROCESSING: begin
                if (!input_done && inp_strb != 0) begin
                    if (msg_length_low > (30'h3FFF_FFFF - bytes_valid)) begin
                        msg_length_high <= msg_length_high + 1'b1;
                        msg_length_low <= msg_length_low + bytes_valid - 30'h4000_0000;
                    end else begin
                        msg_length_low <= msg_length_low + bytes_valid;
                    end

                    if ((write_ptr + bytes_valid) >= 7'd64) begin
                        padding_done <= 1;
                        last_block <= 0;
                        write_ptr <= 0;
                    end else begin
                        write_ptr <= write_ptr + bytes_valid;
                    end
                end
            end
            PAD_80: begin
                if (write_ptr >= 6'd56) padding_done <= 1;
                else padding_done <= 0;
            end
            WAIT_EXTRA: begin
                last_block <= 0;
                if (!ready_for_next_block) padding_done <= 0;
            end
            PAD_LEN_H: begin
                padding_done <= 0;
            end
            PAD_LEN_L: begin
                padding_done <= 1;
                last_block <= 1;
            end
            WAIT_ROUND: begin
                if (!ready_for_next_block) padding_done <= 0;
            end
        endcase
    end
end
always @(*) begin
        next = curr;
        case (curr)
            IDLE: if (input_start) next = PROCESSING;
            PROCESSING: begin
                if (input_done) next = PAD_80;
                else if ((write_ptr + bytes_valid) >= 7'd64) next = WAIT_ROUND;
            end
            PAD_80: begin
                if (write_ptr >= 6'd56) next = WAIT_EXTRA;
                else next = PAD_LEN_H;
            end
            WAIT_EXTRA: if (ready_for_next_block && !padding_done) next = PAD_LEN_H;
            PAD_LEN_H: next = PAD_LEN_L;
            PAD_LEN_L: next = WAIT_ROUND;
            WAIT_ROUND: begin
                if (ready_for_next_block && !padding_done) begin
                    if (last_block) next = IDLE;
                    else next = PROCESSING;
                end
            end
            default: next = IDLE;
        endcase
    end
endmodule
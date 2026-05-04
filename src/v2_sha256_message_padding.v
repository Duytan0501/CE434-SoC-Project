module v2_sha256_message_padding (
    input              clk,
    input              rst_n,                 //reset active low
    input              input_start,           //bat dau nhap
    input              input_done,            //nhap xong
    input              ready_for_next_block,  //schedule doi block moi   
    input      [  7:0] inp_data,              //input
    output reg [511:0] padded_msg,            //msg da pad xong      
    output reg         padding_done,          //co bao da pad xong 1 block
    output reg         last_block             //block cuoi
);
  localparam IDLE = 2'b00;  //trang thai cho
  localparam PROCESSING = 2'b01;  //trang thai xu ly
  localparam WAIT_ROUND = 2'b10; //cho round
  reg  [1:0] curr, next;  //luu trang thai
  reg  [ 5:0] write_ptr;  //con tro ghi
  reg [29:0] msg_length_low;
  reg [30:0] msg_length_high;
  wire [63:0] msg_length = {msg_length_high, msg_length_low, 3'b000};//Chia doi msg_length(64 bit lam giam fmax)
  reg  extra_block;//can them block rong
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin  //reset
      curr <= IDLE;
      padded_msg <= 512'b0;
      padding_done <= 0;
      write_ptr <= 0;
      msg_length_low <= 0;
      msg_length_high <= 0;
      last_block <=0;
    end else begin
      curr <= next;
      case (curr) 
        IDLE: begin //Trang thai cho
          padding_done <= 0;
          extra_block <= 0;
          if (input_start) begin
            padded_msg <= 512'b0;
            write_ptr <= 6'd0;
            msg_length_low <= 0;
				    msg_length_high <= 0;
            last_block <= 0;
          end
        end
        PROCESSING: begin //Trang thai xu ly
          // ----------------------------------------------------
          // Neu so bit chia het cho 512, nghia la can 1 block phu de them msg_length
          // ----------------------------------------------------
          if(extra_block) begin//Neu can them block rong
            padded_msg [63:0] <= msg_length;//Gan 64 bit cuoi la msg_length
            padding_done <= 1;
            last_block <= 1;//Block cuoi
            extra_block <= 0;//Ko can block moi
          end 
          // ----------------------------------------------------
          // Xu ly input_done
          // ----------------------------------------------------
          else if(input_done) begin//Neu nhap xong
            padded_msg[511 - {write_ptr, 3'b000} -: 8] <= 8'h80;//Gan bit 1
            if(write_ptr <= 6'd55) begin//Neu con tro ghi van chua du 448 bit
              padded_msg[63:0] <= msg_length;//Gan 64 bit cuoi la msg_length
              padding_done <= 1;//Pad xong
              last_block <= 1;//Block cuoi
            end else begin//Neu con tro ghi vuot qua 448 bit
              extra_block <= 1;//Can them block rong
              padding_done <= 1;//Pad block hien tai
              last_block <=0;//Chua phai block cuoi
            end
          end
          // ----------------------------------------------------
          // Dang nhap input
          // ---------------------------------------------------- 
          else begin//Dang nhap du lieu
            padded_msg[511 - {write_ptr, 3'b000} -: 8] <= inp_data;//Gan du lieu vao msg
            if (msg_length_low == 30'h3FFF_FFFF) begin//byte count low dat max
                  msg_length_high <= msg_length_high + 1'b1;//tang phan high
                  msg_length_low <= 0; //reset phan low
            end else msg_length_low <= msg_length_low + 1'b1;//tang phan low
          // ----------------------------------------------------
          // Cap nhat con tro ghi
          // ---------------------------------------------------- 
            if (write_ptr == 6'd63) begin
              padding_done <= 1;//Neu da ghi du 512 bit
              last_block <= 0;//Khong phai block cuoi
            end else write_ptr <= write_ptr + 1;//tang con tro ghi
          end
        end
        WAIT_ROUND: begin//Trang thai cho round xu ly
          if(!ready_for_next_block) padding_done <= 0;//Neu round chua xong, phai ha co done de cho cho round xong vi done la start cua round
          else if(!padding_done) begin//Neu round da san sang
            padded_msg <= 512'b0;// nen thoa man dieu kien
            write_ptr<= 0;
          end
        end
      endcase
    end
  end
  always @(*) begin
	 next = curr;
    case (curr)
      IDLE: next = input_start ? PROCESSING : IDLE;
      PROCESSING: begin
        if(extra_block||input_done||write_ptr==6'd63) next = WAIT_ROUND;//Neu can them 1 block moi, nhap xong,
        else next = PROCESSING;                       //Hoac da ghi du 512 bit thi dua cho round xu ly va cho, nguoc lai thi pad tiep
      end 
      WAIT_ROUND: begin
        if(ready_for_next_block && !padding_done) begin//Neu round da san sang va dang cho block moi(padding_done = start cua round)
          if(last_block) next = IDLE;//Neu da la block cuoi thi ve idle
          else next = PROCESSING;//Chua la block cuoi thi pad block moi
        end
      end
      default: next = IDLE;
    endcase
  end
endmodule
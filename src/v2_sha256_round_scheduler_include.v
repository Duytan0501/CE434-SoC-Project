module v2_sha256_round_scheduler_include (
    input clk,
    input rst_n,
    input start,
    input pad_wren,
    input [3:0] pad_waddr,
    input [3:0] pad_wstrb,
    input [31:0] pad_wdata,
    input pad_clear,
    input last_block,
    input [2:0] hash_rd_addr,
    output reg [31:0] hash_out_32,
    output reg hash_valid,
    output reg ready_for_next_block
);

    // ========== FSM STATES ==========
    localparam IDLE       = 3'b000;
    localparam LOAD_IV    = 3'b001;
    localparam RUN_ROUNDS = 3'b010;
    localparam UPDATE_HASH= 3'b011;
    localparam WAIT_LAST  = 3'b100;
    localparam DONE       = 3'b101;

    reg [2:0] state, next_state;
    reg [5:0] round;
    reg first_block; 
    // ========== HASH STATE ==========
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] a_old, b_old, c_old, d_old, e_old, f_old, g_old, h_old;
    reg [2:0] hash_stage;//Chia stage update hash
    // ========== MESSAGE SCHEDULE ==========
    reg [31:0] W [0:15];
	 // ===== PIPELINE STAGE REGISTERS (Đã rút gọn còn 3 Stage) =====
    // Stage 0 registers (tính toán các hàm logic)
    reg [31:0] s0_sigma0, s0_sigma1, s0_ch_W0, s0_maj;
    reg [31:0] s0_K;
	     reg [31:0] s0_sigma_lower0, s0_sigma_lower1;
    // Stage 1 registers (Thực hiện cộng dồn)
    reg [31:0] s1_T1;       // T1 đầy đủ
    reg [31:0] s1_T2;       // T2
    reg [31:0] s1_W_next;   // W tiếp theo (W[16])
    // ===== PIPELINE CONTROL =====
    reg [1:0] round_stage;      
    // ========== CONSTANTS ==========
    reg [31:0] K [0:63];//look up table cho K constants
	 function [31:0] get_K;
        input [5:0] round_idx;
        begin
            case (round_idx)
                6'd00: get_K = 32'h428a2f98; 6'd01: get_K = 32'h71374491; 6'd02: get_K = 32'hb5c0fbcf; 6'd03: get_K = 32'he9b5dba5;
                6'd04: get_K = 32'h3956c25b; 6'd05: get_K = 32'h59f111f1; 6'd06: get_K = 32'h923f82a4; 6'd07: get_K = 32'hab1c5ed5;
                6'd08: get_K = 32'hd807aa98; 6'd09: get_K = 32'h12835b01; 6'd10: get_K = 32'h243185be; 6'd11: get_K = 32'h550c7dc3;
                6'd12: get_K = 32'h72be5d74; 6'd13: get_K = 32'h80deb1fe; 6'd14: get_K = 32'h9bdc06a7; 6'd15: get_K = 32'hc19bf174;
                6'd16: get_K = 32'he49b69c1; 6'd17: get_K = 32'hefbe4786; 6'd18: get_K = 32'h0fc19dc6; 6'd19: get_K = 32'h240ca1cc;
                6'd20: get_K = 32'h2de92c6f; 6'd21: get_K = 32'h4a7484aa; 6'd22: get_K = 32'h5cb0a9dc; 6'd23: get_K = 32'h76f988da;
                6'd24: get_K = 32'h983e5152; 6'd25: get_K = 32'ha831c66d; 6'd26: get_K = 32'hb00327c8; 6'd27: get_K = 32'hbf597fc7;
                6'd28: get_K = 32'hc6e00bf3; 6'd29: get_K = 32'hd5a79147; 6'd30: get_K = 32'h06ca6351; 6'd31: get_K = 32'h14292967;
                6'd32: get_K = 32'h27b70a85; 6'd33: get_K = 32'h2e1b2138; 6'd34: get_K = 32'h4d2c6dfc; 6'd35: get_K = 32'h53380d13;
                6'd36: get_K = 32'h650a7354; 6'd37: get_K = 32'h766a0abb; 6'd38: get_K = 32'h81c2c92e; 6'd39: get_K = 32'h92722c85;
                6'd40: get_K = 32'ha2bfe8a1; 6'd41: get_K = 32'ha81a664b; 6'd42: get_K = 32'hc24b8b70; 6'd43: get_K = 32'hc76c51a3;
                6'd44: get_K = 32'hd192e819; 6'd45: get_K = 32'hd6990624; 6'd46: get_K = 32'hf40e3585; 6'd47: get_K = 32'h106aa070;
                6'd48: get_K = 32'h19a4c116; 6'd49: get_K = 32'h1e376c08; 6'd50: get_K = 32'h2748774c; 6'd51: get_K = 32'h34b0bcb5;
                6'd52: get_K = 32'h391c0cb3; 6'd53: get_K = 32'h4ed8aa4a; 6'd54: get_K = 32'h5b9cca4f; 6'd55: get_K = 32'h682e6ff3;
                6'd56: get_K = 32'h748f82ee; 6'd57: get_K = 32'h78a5636f; 6'd58: get_K = 32'h84c87814; 6'd59: get_K = 32'h8cc70208;
                6'd60: get_K = 32'h90befffa; 6'd61: get_K = 32'ha4506ceb; 6'd62: get_K = 32'hbef9a3f7; 6'd63: get_K = 32'hc67178f2;
                default: get_K = 32'd0;
            endcase
        end
    endfunction

    // ========== HAM LOGIC ==========
    function [31:0] maj;
        input [31:0] x, y, z;
        begin
            maj = (x & y) ^ (x & z) ^ (y & z);
        end
    endfunction

    function [31:0] ch;
        input [31:0] x, y, z;
        begin
            ch = (x & y) ^ (~x & z);
        end
    endfunction

    function [31:0] sigma_lower_0;
        input [31:0] x;
        begin
            sigma_lower_0 = {x[6:0], x[31:7]} ^ {x[17:0], x[31:18]} ^ (x >> 3);
        end
    endfunction

    function [31:0] sigma_lower_1;
        input [31:0] x;
        begin
            sigma_lower_1 = {x[16:0], x[31:17]} ^ {x[18:0], x[31:19]} ^ (x >> 10);
        end
    endfunction

    function [31:0] sigma_upper_0;
        input [31:0] x;
        begin
            sigma_upper_0 = {x[1:0], x[31:2]} ^ {x[12:0], x[31:13]} ^ {x[21:0], x[31:22]};
        end
    endfunction

    function [31:0] sigma_upper_1;
        input [31:0] x;
        begin
            sigma_upper_1 = {x[5:0], x[31:6]} ^ {x[10:0], x[31:11]} ^ {x[24:0], x[31:25]};
        end
    endfunction

    // ========== FSM: NEXT STATE ==========
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: 
                if (start) next_state = LOAD_IV;
            LOAD_IV: 
                next_state = RUN_ROUNDS;
            RUN_ROUNDS: 
                //Ket thuc khi xong 64 roung cung nhu stage thu 4
                if (round == 63 && round_stage == 2'd2) 
                    next_state = UPDATE_HASH;
            UPDATE_HASH: 
                if (hash_stage == 3'd4) begin//Chi khi hash den stage 4, cap nhat current_hash xong moi chuyen state
                    if (last_block) next_state = WAIT_LAST;
                    else next_state = IDLE;
                end else next_state = UPDATE_HASH;
            WAIT_LAST: next_state = DONE;
            DONE: 
                if (!start) next_state = IDLE;
        endcase
    end

    // ========== MAIN multicycle LOGIC ==========
    // mach Sequential logic for current state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            round <= 0;
            round_stage <= 0;
            ready_for_next_block <= 0;
            hash_stage <= 3'd0;
            hash_valid <= 0;
            first_block <= 1'b1;//Vì mới reset nên chắc chắn block nạp vào là block đầu
            // Reset tất cả thanh ghi 
            s0_sigma0 <= 0; s0_sigma1 <= 0; s0_ch_W0 <= 0; s0_maj <= 0;
            s0_K <= 0;
            s0_sigma_lower0 <= 0; s0_sigma_lower1 <= 0;
            s1_T1 <= 0;
            s1_T2 <= 0;
				s1_W_next <= 0;
				end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    round <= 0;
                    round_stage <= 0;
                    ready_for_next_block <= 1;
                    hash_stage <= 3'd0;
						  if (pad_clear) begin
                        W[0]<=0; W[1]<=0; W[2]<=0; W[3]<=0; 
                        W[4]<=0; W[5]<=0; W[6]<=0; W[7]<=0; 
                        W[8]<=0; W[9]<=0; W[10]<=0; W[11]<=0; 
                        W[12]<=0; W[13]<=0; W[14]<=0; W[15]<=0;
                    end else if (pad_wren) begin
                        if (pad_wstrb[3]) W[pad_waddr][31:24] <= pad_wdata[31:24];
                        if (pad_wstrb[2]) W[pad_waddr][23:16] <= pad_wdata[23:16];
                        if (pad_wstrb[1]) W[pad_waddr][15:8]  <= pad_wdata[15:8];
                        if (pad_wstrb[0]) W[pad_waddr][7:0]   <= pad_wdata[7:0];
                    end
                end
                LOAD_IV: begin
                    round <= 0;
                    round_stage <= 0;
                    ready_for_next_block <= 0;  
                    hash_valid <= 0;
                    // Load IV
                    if (first_block) begin//Chỉ xài 1 lần ở block đầu
                        a <= 32'h6a09e667; b <= 32'hbb67ae85;
                        c <= 32'h3c6ef372; d <= 32'ha54ff53a;
                        e <= 32'h510e527f; f <= 32'h9b05688c;
                        g <= 32'h1f83d9ab; h <= 32'h5be0cd19;
                        a_old <= 32'h6a09e667; b_old <= 32'hbb67ae85;
                        c_old <= 32'h3c6ef372; d_old <= 32'ha54ff53a;
                        e_old <= 32'h510e527f; f_old <= 32'h9b05688c;
                        g_old <= 32'h1f83d9ab; h_old <= 32'h5be0cd19;
                        first_block <= 1'b0;//Nếu đã load IV thì chắc chắn ko còn block đầu nữa
                    end else begin//Cập nhật lại các thanh ghi a,b,c,d,e,f,g,h
                        {a, b, c, d, e, f, g, h} <= {a_old, b_old, c_old, d_old, e_old, f_old, g_old, h_old};
                    end
                end
                
                RUN_ROUNDS: begin
                    // ==========================================
                    // STAGE 0: Tính tất cả hàm logic + đọc K
                    // ==========================================
                    if (round_stage == 2'd0) begin
                        // Tính sigma cho message schedule (W[16] trong tương lai)
                        s0_sigma_lower0 <= sigma_lower_0(W[1]);
                        s0_sigma_lower1 <= sigma_lower_1(W[14]);
                        
                        // Tính các hàm cho round computation
                        s0_sigma0 <= sigma_upper_0(a);
                        s0_sigma1 <= sigma_upper_1(e);
                        //Tính luôn ch + W[0 để stage sau khỏi tính
                        s0_ch_W0  <= ch(e, f, g) + W[0];
                        s0_maj    <= maj(a, b, c);
                        //Đọc trước K
                        s0_K  <= get_K(round);
                        round_stage <= 2'd1;
                    end
						  // ==========================================
                    // STAGE 1: Cộng dồn T1, T2 và W_next
                    // ==========================================
						  else if (round_stage == 2'd1) begin
                        s1_T1 <= h + s0_sigma1 + s0_K + s0_ch_W0;
                        s1_T2 <= s0_sigma0 + s0_maj;
                        s1_W_next <= s0_sigma_lower0 + s0_sigma_lower1 + W[0] + W[9];
                        round_stage <= 2'd2;
                    end
                    // ==========================================
                    // STAGE 3: Cập nhật thanh ghi + shift W
                    // ==========================================
                    else if (round_stage == 2'd2) begin
                        // Cập nhật a và e mới(các thanh gh này ko thay đổi ở state trước nên ko cần lưu lại)
                        a <= s1_T1 + s1_T2;        // a_new = T1 + T2
                        b <= a;                  // b_new = a_cũ
                        c <= b;                  // c_new = b_cũ
                        d <= c;                  // d_new = c_cũ
                        e <= d + s1_T1;          // e_new = d_cũ + T1
                        f <= e;                  // f_new = e_cũ
                        g <= f;                  // g_new = f_cũ
                        h <= g;                  // h_new = g_cũ
                        // Shift W array (dịch trái 1 vị trí)
                        W[0]  <= W[1];
                        W[1]  <= W[2];
                        W[2]  <= W[3];
                        W[3]  <= W[4];
                        W[4]  <= W[5];
                        W[5]  <= W[6];
                        W[6]  <= W[7];
                        W[7]  <= W[8];
                        W[8]  <= W[9];
                        W[9]  <= W[10];
                        W[10] <= W[11];
                        W[11] <= W[12];
                        W[12] <= W[13];
                        W[13] <= W[14];
                        W[14] <= W[15];
                        W[15] <= s1_W_next;  // W[16] được tính từ stage 2
                        round_stage <= 2'd0;
                        // Tăng round counter
                        if (round < 63) 
                            round <= round + 6'd1;
                    end
                end
                UPDATE_HASH: begin//Chia thành 4 stage, mỗi stage chỉ tính 2 thanh ghi.
                    // Các thanh ghi cũ a_old, b_old,... lúc này mang chính giá trị của hash, nên ko cần gán lại a cũ ở round 0 của block mới nữa
                    case(hash_stage) 
                        3'd0: begin
                            a_old <= a+a_old;
                            b_old <= b+b_old;
                            hash_stage <= 3'd1;
                        end
                        3'd1: begin
                            c_old <= c+c_old;
                            d_old <= d+d_old;
                            hash_stage <= 3'd2;
                        end
                        3'd2: begin
                            e_old <= e+e_old;
                            f_old <= f+f_old;
                            hash_stage <= 3'd3;
                        end
                        3'd3:begin
                            g_old <= g+g_old;
                            h_old <= h+h_old;
                            hash_stage <= 3'd4;
                        end
                        3'd4:begin
                            hash_stage <= 3'd0;
                        end
                    endcase
                end
                WAIT_LAST: begin
                    hash_valid <= 1;
                end
                DONE: begin
                    first_block <= 1'b1;
						  if (pad_clear) begin
                        W[0]<=0; W[1]<=0; W[2]<=0; W[3]<=0; 
                        W[4]<=0; W[5]<=0; W[6]<=0; W[7]<=0; 
                        W[8]<=0; W[9]<=0; W[10]<=0; W[11]<=0; 
                        W[12]<=0; W[13]<=0; W[14]<=0; W[15]<=0;
                    end else if (pad_wren) begin
                        if (pad_wstrb[3]) W[pad_waddr][31:24] <= pad_wdata[31:24];
                        if (pad_wstrb[2]) W[pad_waddr][23:16] <= pad_wdata[23:16];
                        if (pad_wstrb[1]) W[pad_waddr][15:8]  <= pad_wdata[15:8];
                        if (pad_wstrb[0]) W[pad_waddr][7:0]   <= pad_wdata[7:0];
                    end
                end
            endcase
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hash_out_32 <= 32'd0;
        end else if (hash_valid) begin
            case (hash_rd_addr)
                3'd0: hash_out_32 <= a_old;
                3'd1: hash_out_32 <= b_old;
                3'd2: hash_out_32 <= c_old;
                3'd3: hash_out_32 <= d_old;
                3'd4: hash_out_32 <= e_old;
                3'd5: hash_out_32 <= f_old;
                3'd6: hash_out_32 <= g_old;
                3'd7: hash_out_32 <= h_old;
                default: hash_out_32 <= 32'd0;
            endcase
        end else begin
            hash_out_32 <= 32'd0; 
        end
    end
endmodule
module v2_sha256_round_scheduler_include (
    input clk,
    input rst_n,
    input start,
    input [511:0] message_block,
    input last_block,
    output reg [255:0] final_hash,
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
    reg [255:0] current_hash;
    reg first_block; 
    // ========== HASH STATE ==========
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] a_old, b_old, c_old, d_old, e_old, f_old, g_old, h_old;
    reg [2:0] hash_stage;//Chia stage update hash
    // ========== MESSAGE SCHEDULE ==========
    reg [31:0] W [0:15];

    // ===== PIPELINE STAGE REGISTERS =====
    // Stage 0 registers (tính toán các hàm logic)
    reg [31:0] s0_sigma0, s0_sigma1, s0_ch_W0, s0_maj;
    reg [31:0] s0_K;

    // Stage 1 registers (tinh T1_partialA, T1_partialB va� T2)
	reg [31:0] s1_T1_partialA; // h + sigma1(e)
	reg [31:0] s1_T1_partialB; // ch_W0(e,f,g) + K[round]
    reg [31:0] s2_T2;          // sigma0 + maj
	 
    // Stage 2 registers (hoàn thành T1 và tổng cuối)
    reg [31:0] s2_T1;          // T1 đầy đủ sau khi cộng
    // ===== PIPELINE CONTROL =====
    reg [1:0] round_stage;      

    // ===== MESSAGE SCHEDULE PIPELINE =====
    reg [31:0] s0_sigma_lower0, s0_sigma_lower1;
	reg [31:0] s1_W_nextA;
	reg [31:0] s1_W_nextB;
	reg [31:0] s2_W_next;

    // ========== CONSTANTS ==========
    reg [31:0] K [0:63];//look up table cho K constants
    initial begin
        K[0]  = 32'h428a2f98; K[1]  = 32'h71374491; K[2]  = 32'hb5c0fbcf; K[3]  = 32'he9b5dba5;
        K[4]  = 32'h3956c25b; K[5]  = 32'h59f111f1; K[6]  = 32'h923f82a4; K[7]  = 32'hab1c5ed5;
        K[8]  = 32'hd807aa98; K[9]  = 32'h12835b01; K[10] = 32'h243185be; K[11] = 32'h550c7dc3;
        K[12] = 32'h72be5d74; K[13] = 32'h80deb1fe; K[14] = 32'h9bdc06a7; K[15] = 32'hc19bf174;
        K[16] = 32'he49b69c1; K[17] = 32'hefbe4786; K[18] = 32'h0fc19dc6; K[19] = 32'h240ca1cc;
        K[20] = 32'h2de92c6f; K[21] = 32'h4a7484aa; K[22] = 32'h5cb0a9dc; K[23] = 32'h76f988da;
        K[24] = 32'h983e5152; K[25] = 32'ha831c66d; K[26] = 32'hb00327c8; K[27] = 32'hbf597fc7;
        K[28] = 32'hc6e00bf3; K[29] = 32'hd5a79147; K[30] = 32'h06ca6351; K[31] = 32'h14292967;
        K[32] = 32'h27b70a85; K[33] = 32'h2e1b2138; K[34] = 32'h4d2c6dfc; K[35] = 32'h53380d13;
        K[36] = 32'h650a7354; K[37] = 32'h766a0abb; K[38] = 32'h81c2c92e; K[39] = 32'h92722c85;
        K[40] = 32'ha2bfe8a1; K[41] = 32'ha81a664b; K[42] = 32'hc24b8b70; K[43] = 32'hc76c51a3;
        K[44] = 32'hd192e819; K[45] = 32'hd6990624; K[46] = 32'hf40e3585; K[47] = 32'h106aa070;
        K[48] = 32'h19a4c116; K[49] = 32'h1e376c08; K[50] = 32'h2748774c; K[51] = 32'h34b0bcb5;
        K[52] = 32'h391c0cb3; K[53] = 32'h4ed8aa4a; K[54] = 32'h5b9cca4f; K[55] = 32'h682e6ff3;
        K[56] = 32'h748f82ee; K[57] = 32'h78a5636f; K[58] = 32'h84c87814; K[59] = 32'h8cc70208;
        K[60] = 32'h90befffa; K[61] = 32'ha4506ceb; K[62] = 32'hbef9a3f7; K[63] = 32'hc67178f2;
    end

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
                if (round == 63 && round_stage == 2'd3) 
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
            hash_valid <= 0;
            current_hash <= 256'h0;
            final_hash <= 256'h0;
            hash_stage <= 3'd0;
            first_block <= 1'b1;//Vì mới reset nên chắc chắn block nạp vào là block đầu
            // Reset tất cả thanh ghi 
            s0_sigma0 <= 0; s0_sigma1 <= 0; s0_ch_W0 <= 0; s0_maj <= 0;
            s0_K <= 0;
            s0_sigma_lower0 <= 0; s0_sigma_lower1 <= 0;
            s2_T2 <= 0;
			s1_T1_partialA <= 0;
			s1_T1_partialB <= 0;
            s2_T1 <= 0;
			s2_W_next <= 0;
			s1_W_nextA <= 0;s1_W_nextB <= 0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    round <= 0;
                    round_stage <= 0;
                    ready_for_next_block <= 1;
                    hash_valid <= 0;
                    hash_stage <= 3'd0;
                end
                LOAD_IV: begin
                    round <= 0;
                    round_stage <= 0;
                    ready_for_next_block <= 0;  
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
                        {a, b, c, d, e, f, g, h} <= current_hash;
                    end
                    
                    // Load W[0:15] từ message_block
                    W[0]  <= message_block[511:480];
                    W[1]  <= message_block[479:448];
                    W[2]  <= message_block[447:416];
                    W[3]  <= message_block[415:384];
                    W[4]  <= message_block[383:352];
                    W[5]  <= message_block[351:320];
                    W[6]  <= message_block[319:288];
                    W[7]  <= message_block[287:256];
                    W[8]  <= message_block[255:224];
                    W[9]  <= message_block[223:192];
                    W[10] <= message_block[191:160];
                    W[11] <= message_block[159:128];
                    W[12] <= message_block[127:96];
                    W[13] <= message_block[95:64];
                    W[14] <= message_block[63:32];
                    W[15] <= message_block[31:0];
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
                        s0_K  <= K[round];
                        round_stage <= 2'd1;
                    end
                    
                    // ==========================================
                    // STAGE 1: Tính T1_partial + T2 (CHƯA cộng W[0])
                    // ==========================================
                    else if (round_stage == 2'd1) begin
                        // Message schedule: tính W tiếp theo, chia đôi để thành phép cộng 2 ngôi
                        s1_W_nextA <= s0_sigma_lower0 + s0_sigma_lower1;
						s1_W_nextB <= W[0] + W[9];
                        
                        // Round computation: Chia T1 thành 2 phần(phép cộng 2 ngôi)
                        // T1_partialA = h + sigma1(e) 
                        // T1_partialB = ch(e,f,g) + K[round] + W[0] (đã tính ở stage 0)
                        s1_T1_partialA <= h + s0_sigma1;
						s1_T1_partialB <= s0_K + s0_ch_W0;
                        round_stage <= 2'd2;
                    end
                    
                    // ==========================================
                    // STAGE 2: Hoàn thành T1 = T1_partial
                    // ==========================================
                    else if (round_stage == 2'd2) begin
                        // T1 đầy đủ
                        s2_T1 <= s1_T1_partialA + s1_T1_partialB;
						s2_W_next <= s1_W_nextA+s1_W_nextB;
                        // Tính T2 ở stage này để tối ưu trễ truyền cho stage 3 thay vì phải giữ tận 2 stage
                        // T2 = sigma0(a) + maj(a,b,c)
                        s2_T2 <= s0_sigma0 + s0_maj;
                        round_stage <= 2'd3;
                    end
                    
                    // ==========================================
                    // STAGE 3: Cập nhật thanh ghi + shift W
                    // ==========================================
                    else if (round_stage == 2'd3) begin
                        // Cập nhật a và e mới(các thanh gh này ko thay đổi ở state trước nên ko cần lưu lại)
                        a <= s2_T1 + s2_T2;        // a_new = T1 + T2
                        b <= a;                  // b_new = a_cũ
                        c <= b;                  // c_new = b_cũ
                        d <= c;                  // d_new = c_cũ
                        e <= d + s2_T1;          // e_new = d_cũ + T1
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
                        W[15] <= s2_W_next;  // W[16] được tính từ stage 2
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
                            //Current hash chính là a+a cũ
                            current_hash <= {a_old,b_old,c_old,d_old,e_old,f_old,g_old,h_old};
                            hash_stage <= 3'd0;
                        end
                    endcase
                end
                
                WAIT_LAST: begin
                    hash_valid <= 1;//Chỉ khi nào last block mới cập nhật
                    if(last_block) final_hash <= current_hash;
                end
                DONE: begin
                    hash_valid <= 0;
                    first_block <= 1'b1;
                end
            endcase
        end
    end
endmodule
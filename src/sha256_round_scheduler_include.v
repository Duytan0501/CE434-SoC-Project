module sha256_round_scheduler_include (
    input clk,
    input rst_n,
    input start,                    // bÃƒÂ¡Ã‚ÂºÃ‚Â¯t Ãƒâ€žÃ¢â‚¬ËœÃƒÂ¡Ã‚ÂºÃ‚Â§u xÃƒÂ¡Ã‚Â»Ã‚Â­ lÃƒÆ’Ã‚Â½
    input [511:0] message_block,    // block hiÃƒÂ¡Ã‚Â»Ã¢â‚¬Â¡n tÃƒÂ¡Ã‚ÂºÃ‚Â¡i
    input last_block,               // 1 = Ãƒâ€žÃ¢â‚¬ËœÃƒÆ’Ã‚Â¢y lÃƒÆ’Ã‚Â  block cuÃƒÂ¡Ã‚Â»Ã¢â‚¬Ëœi cÃƒÆ’Ã‚Â¹ng
    output reg [255:0] final_hash,        // hash cuÃƒÂ¡Ã‚Â»Ã¢â‚¬Ëœi cÃƒÆ’Ã‚Â¹ng
    output reg hash_valid,          // 1 = hash Ãƒâ€žÃ¢â‚¬ËœÃƒÆ’Ã‚Â£ sÃƒÂ¡Ã‚ÂºÃ‚Âµn sÃƒÆ’Ã‚Â ng
    output reg ready_for_next_block // 1 = cÃƒÆ’Ã‚Â³ thÃƒÂ¡Ã‚Â»Ã†â€™ nÃƒÂ¡Ã‚ÂºÃ‚Â¡p block tiÃƒÂ¡Ã‚ÂºÃ‚Â¿p theo
);

    // ========== FSM STATES ==========
    localparam IDLE       = 3'b000;
    localparam LOAD_IV    = 3'b001;
    localparam RUN_ROUNDS = 3'b010;
    localparam UPDATE_HASH= 3'b011;
    localparam WAIT_LAST  = 3'b100;
    localparam DONE       = 3'b101;

    reg [2:0] state, next_state;
    reg [5:0] round;           // 0..63
    reg [255:0] current_hash;  // hash Ãƒâ€žÃ¢â‚¬Ëœang xÃƒÆ’Ã‚Â¢y dÃƒÂ¡Ã‚Â»Ã‚Â±ng
    
    // ========== HASH STATE (8 registers) ==========
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] a_old, b_old, c_old, d_old, e_old, f_old, g_old, h_old;
    
    // ========== MESSAGE SCHEDULING ==========
    reg [31:0] W [0:15];
    reg [1:0] pipe_step;
    // W_pipe tinh truoc gia tri cho W[data]
    reg [31:0] W_pipe1, W_pipe2;
    reg [31:0] W_next;
    integer i;
    reg [31:0] Kt;//tinh K[round]+W[0]
    reg [31:0] sigma0_a, sigma1_e, ch_efg, maj_abc;

    // Stage 2 registers  
    reg [31:0] T1, T2;  // T1_stage1, T2_stage1


    // Khai báo W là wire thay vì reg

    assign W[0]  = message_block[511:480];
    assign W[1]  = message_block[479:448];
    assign W[2]  = message_block[447:416];
    assign W[3]  = message_block[415:384];
    assign W[4]  = message_block[383:352];
    assign W[5]  = message_block[351:320];
    assign W[6]  = message_block[319:288];
    assign W[7]  = message_block[287:256];
    assign W[8]  = message_block[255:224];
    assign W[9]  = message_block[223:192];
    assign W[10] = message_block[191:160];
    assign W[11] = message_block[159:128];
    assign W[12] = message_block[127:96];
    assign W[13] = message_block[95:64];
    assign W[14] = message_block[63:32];
    assign W[15] = message_block[31:0];


    // ========== CONSTANTS ==========
    (* romstyle = "M9K" *) reg [31:0] K [0:63];
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
    // ========== HÃƒÆ’Ã¢â€šÂ¬M LOGIC ==========
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
                if (round == 63 && pipe_step == 2'd2) next_state = UPDATE_HASH;
                
            UPDATE_HASH: 
                if (last_block) next_state = WAIT_LAST;
                else next_state = IDLE;  //con block tiep theo
                
            WAIT_LAST: 
                next_state = DONE;
                
            DONE: 
                if (!start) next_state = IDLE;
        endcase
    end
    // ========== FSM: STATE UPDATE ==========
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin//reset tat ca thanh ghi
            state <= IDLE;
            W_pipe1 <= 32'b0;
            W_pipe2 <= 32'b0;
            W_next <= 32'b0;
            round <= 0;
            pipe_step <= 0;
            ready_for_next_block <= 0;
            hash_valid <= 0;
            current_hash <= 256'h0;
            final_hash <= 256'h0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    round <= 0;
                    pipe_step <= 0;
                    ready_for_next_block <= 1;
                    hash_valid <= 0;
                end
                LOAD_IV: begin
                    round <= 0;
                    pipe_step <= 0;
                    ready_for_next_block <= 0;
                    //IMPORTANT: Load IV tu current_hash (block truoc)
                    // hoac gia tri khoi tao neu la block đau tien
                    if (current_hash == 256'h0) begin
                        // Block dau tien: dung IV chuan
                        a <= 32'h6a09e667;
                        b <= 32'hbb67ae85;
                        c <= 32'h3c6ef372;
                        d <= 32'ha54ff53a;
                        e <= 32'h510e527f;
                        f <= 32'h9b05688c;
                        g <= 32'h1f83d9ab;
                        h <= 32'h5be0cd19;
                    end else begin
                        // Block tiep theo lay lai ket qua hash truoc lam IV
                        {a, b, c, d, e, f, g, h} <= current_hash;
                    end
                    
                    //Luu lai gia tri cu de tiep tuc tinh block phia sau
                    {a_old, b_old, c_old, d_old, e_old, f_old, g_old, h_old} <=     
                    {a, b, c, d, e, f, g, h};
                    
                    // Khởi tạo W[0:15] từ message_block
                    // for (i = 0; i < 16; i=i+1) begin
                    //     W[i] <= message_block[511 - 32*i -: 32];
                    // end
                end
                
                RUN_ROUNDS: begin

                    if (round == 0) {a_old, b_old, c_old, d_old, e_old, f_old, g_old, h_old} <= 
                            {a, b, c, d, e, f, g, h};
                    case (pipe_step)//Step 1
                        2'd0: begin
                            // vd W_pipe1, W_pipe2 duoc tinh truoc 1, vd round nay la 16 thi
                            // round cycle truoc la round = 15, su dung round = 15 
                            W_pipe1 <= W[0] + sigma_lower_0(W[1]);
                            W_pipe2 <= W[9] + sigma_lower_1(W[14]);
                            // vd W[16] = W_pipe1 + W_pipe2 = W[0] + sigma_lower_0(W[1]) + W[9]
                            // + sigma_lower_1(W[14])
                            sigma0_a <= sigma_upper_0(a);
                            sigma1_e <= sigma_upper_1(e);
                            ch_efg <= ch(e, f, g);
                            maj_abc <= maj(a, b, c);
                            Kt<=K[round];//Doc truoc K
                            pipe_step <= 2'd1;
                        end
                        2'd1:begin
                            W_next <= W_pipe1 + W_pipe2;
                            T1 <= h + sigma1_e + ch_efg + Kt + W[0];//Tinh 1 phan T1
                            T2 <= sigma0_a + maj_abc;//Tinh T2
                            pipe_step <= 2'd2; 
                        end
                        2'd2:begin
                            //Cap nhat lai cac thanh ghi chinh
                            a <= T1 + T2;
                            b <= a; 
                            c <= b; 
                            d <= c;
                            e <= d + T1;
                            f <= e; 
                            g <= f; 
                            h <= g;
                            W[0] <= W[1];W[1] <= W[2]; W[2] <= W[3];//Shift W[i] sang trai 1 don vi
                            W[3] <= W[4];W[4] <= W[5]; W[5] <= W[6];
                            W[6] <= W[7];W[7] <= W[8]; W[8] <= W[9];
                            W[9] <= W[10];W[10] <= W[11]; W[11] <= W[12];
                            W[12] <= W[13];W[13] <= W[14];W[14] <= W[15];
                            W[15]<=W_next; // W[16] duoc tinh truoc o pipe_step 1
                            pipe_step <= 2'd0;
                            if (round < 63) round <= round + 6'd1;
                        end
                    endcase
                end
                UPDATE_HASH: begin
                    current_hash <= {a_old+a, b_old+b, c_old+c, d_old+d,
                                e_old+e, f_old+f, g_old+g, h_old+h};
                    if (last_block) final_hash <= {a_old+a, b_old+b, c_old+c, d_old+d,
                                e_old+e, f_old+f, g_old+g, h_old+h};
                end
                WAIT_LAST: begin
                    hash_valid <= 1;
                end
                DONE: begin
                    hash_valid <= 0;
                end
            endcase
        end
    end
endmodule

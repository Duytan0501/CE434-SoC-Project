`define QUARTUS_SYNTH
module sha256_apb_wrapper (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire [31:0] PADDR,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    input  wire [ 3:0] PSTRB,
    output reg  [31:0] PRDATA,
    output wire        PREADY,
    output wire        PSLVERR
);
    reg         core_start;
    reg         core_done;
    reg  [31:0] core_data;
    reg  [ 3:0] core_strb;
    wire [ 2:0] core_hash_rd_addr;
    wire [31:0] core_hash_out_32;
    wire        core_ready_for_input;
    wire        core_hash_valid;
    wire apb_write_en = PSEL && PENABLE && PWRITE;
    wire apb_read_en  = PSEL && !PWRITE;
    reg core_hash_valid_d;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) core_hash_valid_d <= 1'b0;
        else          core_hash_valid_d <= core_hash_valid;
    end
    wire hash_valid_edge = core_hash_valid && !core_hash_valid_d;
    reg core_is_busy;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            core_is_busy <= 1'b0;
        end else begin
            if (apb_write_en && (PADDR[7:0] == 8'h00) && PWDATA[0]) 
                core_is_busy <= 1'b1;
            else if (hash_valid_edge)
                core_is_busy <= 1'b0;
        end
    end

    wire clk_enable = PSEL | core_is_busy;
    wire core_clk;
`ifdef QUARTUS_SYNTH
    assign core_clk = PCLK;
`else
    reg clk_en_latch;
    always @(*) begin
        if (!PCLK) clk_en_latch = clk_enable;
    end
    assign core_clk = PCLK & clk_en_latch;
`endif
    sha256_top core_inst (
        .clk(core_clk),
        .rst_n(PRESETn),
        .input_start(core_start),
        .input_done(core_done),
        .inp_data(core_data),
        .inp_strb(core_strb),
        .hash_rd_addr(core_hash_rd_addr),
        .hash_out_32(core_hash_out_32),
        .ready_for_input(core_ready_for_input),
        .hash_valid(core_hash_valid)
    );
    assign PSLVERR = 1'b0; 
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            core_start <= 1'b0;
            core_done  <= 1'b0;
            core_data  <= 32'd0;
            core_strb  <= 4'd0;
        end else begin
            core_start <= 1'b0;
            core_done  <= 1'b0;
            core_strb  <= 4'd0; 
            if (apb_write_en) begin
                case (PADDR[7:0])
                    8'h00: begin 
                        if (PWDATA[0]) core_start <= 1'b1;
                        if (PWDATA[1]) core_done  <= 1'b1;
                    end
                    8'h04: begin 
                        core_data <= PWDATA;
                        core_strb <= PSTRB;
                    end
                endcase
            end
        end
    end
    assign core_hash_rd_addr = PADDR[4:2]; 
    reg r_pready;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PRDATA   <= 32'd0;
            r_pready <= 1'b1;
        end else begin
            if (PSEL && !PWRITE && !PENABLE) begin
                r_pready <= 1'b0;
                case (PADDR[7:0])
                    8'h00: PRDATA <= {30'd0, core_hash_valid, core_ready_for_input};
                    8'h20, 8'h24, 8'h28, 8'h2C, 
                    8'h30, 8'h34, 8'h38, 8'h3C: PRDATA <= core_hash_out_32;
                    default: PRDATA <= 32'd0;
                endcase
            end 
            else if (PSEL && !PWRITE && PENABLE && !r_pready) begin
                r_pready <= 1'b1; 
            end 
            else begin
                r_pready <= 1'b1;
            end
        end
    end
    
    assign PREADY = r_pready;

endmodule
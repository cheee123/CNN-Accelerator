`timescale 1ns / 1ps

module connect #(
           parameter C_S00_AXI_DATA_WIDTH = 32,
           parameter C_S00_AXIS_TDATA_WIDTH = 32,
           parameter C_M00_AXIS_TDATA_WIDTH = 32
       )(
           input clk,
           input reset_n,
           //AXI Lite Slave
           input [C_S00_AXI_DATA_WIDTH-1 : 0] AXI_Lite_input0,
           input [C_S00_AXI_DATA_WIDTH-1 : 0] AXI_Lite_input1,
           input [C_S00_AXI_DATA_WIDTH-1 : 0] AXI_Lite_input2,
           input [C_S00_AXI_DATA_WIDTH-1 : 0] AXI_Lite_input3,
           //AXIS Slave
           output reg rx_ready,
           input rx_valid,
           input rx_last,
           input [C_S00_AXIS_TDATA_WIDTH-1 : 0] rx_data,
           input [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] rx_keep,
           //AXIS Master
           input tx_ready,
           output reg tx_valid,
           output reg tx_last,
           output [C_M00_AXIS_TDATA_WIDTH-1:0] tx_data,
           output reg [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] tx_keep,
           
           // NN
           input [7:0]NN_out_male,
           input [7:0]NN_out_female,           
           input NN_end,
           output NN_start,
           
           // BRAM
           output reg [11:0]NN_addra,
           output reg [7:0]NN_dina,
           output  [0:0]NN_en,
           output  [0:0]NN_wea
       );

// Bool Define
localparam TRUE  = 1'b1;
localparam FALSE = 1'b0;

/*********************/
/*   State Define    */
/*********************/
// FSM
localparam  IDLE = 2'd0,
            RECEIVE_STREAM = 2'b1,
            WRITE_BRAM = 2'd2,
            TRANSMIT_OUTPUT = 2'd3;

/*********************/
/*  reg/wire Define  */
/*********************/
// FSM
reg [1:0]cur_state;
reg [1:0]nxt_state;
//  - Start Control
wire start_signal;
//  - Finish Control
wire finish_signal;

// Write BRAM
reg [1:0]transmit_state;

// - Receive Control
reg [31:0] Receive_buffer;
reg rx_last_flag;

/*********************/
/*   Hardware Logic  */
/*********************/
// FSM
//  - cur_state
always @(posedge clk) begin
    if(!reset_n) begin
        cur_state <= IDLE;
    end
    else begin
        cur_state <= nxt_state;
    end
end
//  - nxt_state logic
always @(*) begin
    case(cur_state)
        IDLE : begin
            if(start_signal)
                nxt_state = RECEIVE_STREAM;
            else
                nxt_state = IDLE;
        end
        RECEIVE_STREAM : begin
            if(rx_valid)
                nxt_state = WRITE_BRAM;
            else
                nxt_state = RECEIVE_STREAM;
        end
        WRITE_BRAM: begin
            if(transmit_state == 2'd3) begin
                if(rx_last_flag)    nxt_state = TRANSMIT_OUTPUT;
                else                nxt_state = RECEIVE_STREAM;
            end
            else    nxt_state = WRITE_BRAM; 
        end
        TRANSMIT_OUTPUT: begin
            if(NN_end && tx_ready)  nxt_state = IDLE;
            else                    nxt_state = TRANSMIT_OUTPUT;
        end
        default : begin
            // Do nothing. No other unused state.
        end
    endcase
end

//  - Start Control
assign start_signal = (AXI_Lite_input0==32'd4) && (AXI_Lite_input1==32'd3) && (AXI_Lite_input2==32'd2) && (AXI_Lite_input3==32'd1);

// NN_dina Control
always @(*) begin
    case(transmit_state)
        2'd0:   NN_dina = Receive_buffer[7:0];
        2'd1:   NN_dina = Receive_buffer[15:8];
        2'd2:   NN_dina = Receive_buffer[23:16];
        2'd3:   NN_dina = Receive_buffer[31:24];
    endcase
end

// Receive_buffer & rx_last_flag Control
always @(posedge clk) begin
    if(cur_state == RECEIVE_STREAM && nxt_state == WRITE_BRAM) begin    
        Receive_buffer <= rx_data; 
        rx_last_flag <= rx_last; 
    end
    else begin  
        Receive_buffer <= Receive_buffer; 
        rx_last_flag <= rx_last_flag;
    end
end

// transmit_state Control
always @(posedge clk) begin
    case(cur_state)
        WRITE_BRAM:     transmit_state <= transmit_state + 2'd1;
        default:        transmit_state <= 2'd0;
    endcase
end

// NN_addra Control
always @(posedge clk) begin
    if(!reset_n)    NN_addra <= 12'd0;
    else begin
        case(cur_state)
            RECEIVE_STREAM: NN_addra <= NN_addra;
            WRITE_BRAM:     NN_addra <= NN_addra + 12'd1;
            default:        NN_addra <= 12'd0;
        endcase
    end
end

// NN_wea Control
assign NN_wea = (cur_state==WRITE_BRAM);
assign NN_en = (cur_state==WRITE_BRAM);

reg [4:0]start_cnt;
always @(posedge clk) begin
    if(!reset_n) start_cnt <=0;    
    else if(cur_state==TRANSMIT_OUTPUT)begin
        if(start_cnt==5) start_cnt <= 6;
        else             start_cnt <= start_cnt+1;
    end
    else    start_cnt <= 0;
end


// NN_start Control
assign NN_start = (cur_state == TRANSMIT_OUTPUT && start_cnt<=5);  

// - rx_ready Control
// - # Ready to receive the next data from S_AXIS
always @(*) begin
    if(cur_state == RECEIVE_STREAM)     rx_ready = 1'b1;
    else                                rx_ready = 1'b0;
end

// - Transmit Control
always @(posedge clk) begin
   if(!reset_n)begin
        tx_valid <= 1'b0;
        tx_last <=  1'b0;
        tx_keep <= 0;
    end    
    else begin
        if(cur_state == TRANSMIT_OUTPUT && nxt_state == IDLE) begin
            tx_valid <= 1'b1;
            tx_last <=  1'b1;
            tx_keep <= {(C_M00_AXIS_TDATA_WIDTH/8){1'b1}};
        end
        else begin
            tx_valid <= 1'b0;
            tx_last <=  1'b0;
            tx_keep <= {(C_M00_AXIS_TDATA_WIDTH/8){1'b1}};
        end
    end    
end
// - # Transmit data.
assign tx_data = {16'd0,NN_out_male,NN_out_female};


endmodule

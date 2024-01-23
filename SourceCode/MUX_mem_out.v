`timescale 1ns / 1ns
module MUX_mem_out
(
  input clk,
  input rst_n,
  
  input start_flag,
  output end_flag,
  output [7:0] NN_out_female,
  output [7:0] NN_out_male,

  // testbench read
//  input [15:0]ram_addr_rtb,
//  input ram_en_rtb,
  input [11:0] ram_addr_wtb,
  input [7:0] ram_data_wtb,
  input ram_en_wtb,
  input ram_wea_wtb,
  
  // ConV1
  input [15:0]ram_addr_wi_ConV1,
  input [7:0]ram_data_wi_ConV1,
  input ram_en_wi_ConV1,
  input ram_wea_wi_ConV1,

  input [15:0] rom_addr_ri_ConV1,
  input rom_en_ri_ConV1,
  output reg [7:0] rom_data_ri_ConV1,

  input [14:0]rom_addr_rw_ConV1,
  input rom_en_rw_ConV1,
  input [8:0]rom_addr_row_ConV1,
  input rom_en_row_ConV1,

  output reg [5:0] ifmap_h,
  output reg [5:0] ifmap_w,
  output reg [5:0] ifmap_c,
  output reg [5:0] outfmap_c,
  output reg [14:0] offset_w, 
  output reg [8:0] offset_ow,

  output reg start_ConV1,
  input end_ConV1,
  
  // Pooling1 and 2
  output reg start_MP1,
  output reg start_MP2,
  input [15:0]ram_addr_w_MP,
  input [7:0]ram_data_w_MP,
  input ram_en_MP,
  input ram_wea_MP,
  input [15:0]ram_addr_r_MP,
  input ram_en_r_MP,
  input end_MP1,
  input end_MP2,

  // FC
  output reg start_FC,
  input end_FC,
  input [11:0]ram_addr_r_FC,
  input ram_en_r_FC,
  input [14:0]rom_addr_rw_FC,
  input rom_en_rw_FC,
  input [8:0]rom_addr_row_FC,
  input rom_en_row_FC,
  input [7:0] NN_out_female_FC,
  input [7:0] NN_out_male_FC,


  // ROM but RAM
  output reg [15:0]rom_addr_wi,
  output reg [7:0]rom_data_wi,
  output reg rom_en_wi,
  output reg rom_wea_wi,

  output reg [15:0]rom_addr_ri,
  output reg rom_en_ri,
  input [7:0] rom_data_ri,

  // RAM temp
  output reg [15:0]ram_addr_w_temp,
  output reg [7:0]ram_data_w_temp,
  output reg ram_en_w_temp,
  output reg ram_wea_w_temp,
  output reg [15:0]ram_addr_r_temp,
  output reg ram_en_r_temp,
  input [7:0] ram_data_r_temp,
  
  // ROM weights and other weights
  output reg [14:0]rom_addr_rw,
  output reg rom_en_rw,
  output reg [8:0]rom_addr_row,
  output reg rom_en_row
);

parameter IDLE  = 4'b0000;
parameter ConV1 = 4'b0001;
parameter MP1   = 4'b0010;
parameter ConV2 = 4'b0011;
parameter ConV3 = 4'b0100;
parameter MP2   = 4'b0101;
parameter FC    = 4'b0110;
parameter DONE  = 4'b0111;
parameter tb    = 4'b1111;

parameter ifmap1_h = 6'd50,  ifmap2_h = 6'd24,   ifmap3_h = 6'd22;
parameter ifmap1_w = 6'd50,  ifmap2_w = 6'd24,   ifmap3_w = 6'd22; 
parameter ifmap1_c = 6'd1,   ifmap2_c = 6'd8,    ifmap3_c = 6'd12;
parameter outfmap1_c = 6'd8, outfmap2_c = 6'd12, outfmap3_c = 6'd16;
parameter offset1_w = 15'd0, offset2_w = 15'd72, offset3_w = 15'd936;
parameter offset1_ow = 9'd0, offset2_ow = 9'd24, offset3_ow = 9'd60;

reg [1:0] cnt_end;
reg [3:0] cur_state;
reg [7:0] NN_out_female_d;
reg [7:0] NN_out_male_d;

assign end_flag = cur_state == DONE;
// assign end_flag = cur_state == tb;
assign NN_out_female = NN_out_female_d;
assign NN_out_male = NN_out_male_d;

//==============================================================
//current state 
always@(posedge clk,negedge rst_n)begin
  if(!rst_n)begin
    cur_state <= IDLE;
  end
  else begin
    case(cur_state)
      IDLE:begin
        if(start_flag)  cur_state<=ConV1; 
        else  cur_state<=IDLE;
      end
      ConV1:begin
        if(end_ConV1)  cur_state<=MP1;
        else  cur_state<=ConV1;
      end
      MP1:begin
        if(end_MP1)  cur_state<=ConV2;
        else  cur_state<=MP1;
      end
      ConV2:begin
        if(end_ConV1)  cur_state<=ConV3;
        else  cur_state<=ConV2;
      end
      ConV3:begin
        if(end_ConV1)  cur_state<=MP2;
        else  cur_state<=ConV3;
      end
      MP2:begin
        if(end_MP2)  cur_state<=FC;
        else  cur_state<=MP2;
      end
      FC:begin
        if(end_FC)  cur_state<=DONE;
        else  cur_state<=FC;
      end
      DONE: cur_state <= (cnt_end==2'd2)? IDLE : DONE; ///////////////////////
    //   DONE: cur_state <= DONE; ///////////////////////
      
      // tb:
      //   cur_state<=tb;
      default:
        cur_state<=cur_state;
    endcase
  end
end

always@(*)begin
  case(cur_state)
  ConV1,ConV3: begin
    start_ConV1 = 'd1;
    rom_data_ri_ConV1 = rom_data_ri;
    start_MP1 = 'd0;
    start_MP2 = 'd0;
    start_FC  = 'd0;
  end
  MP1: begin
    start_ConV1 = 'd0;
    rom_data_ri_ConV1 = 'd0;
    start_MP1 = 'd1;
    start_MP2 = 'd0;
    start_FC  = 'd0;
  end
  ConV2: begin
    start_ConV1 = 'd1;
    rom_data_ri_ConV1 = ram_data_r_temp;
    start_MP1 = 'd0;
    start_MP2 = 'd0;
    start_FC  = 'd0;
  end
  MP2: begin
    start_ConV1 = 'd0;
    rom_data_ri_ConV1 = 'd0;
    start_MP1 = 'd0;
    start_MP2 = 'd1;
    start_FC  = 'd0;
  end
  FC: begin
    start_ConV1 = 'd0;
    rom_data_ri_ConV1 = 'd0;
    start_MP1 = 'd0;
    start_MP2 = 'd0;
    start_FC  = 'd1;
  end
  default: begin
    start_ConV1 = 'd0;
    rom_data_ri_ConV1 = 'd0;
    start_MP1 = 'd0;
    start_MP2 = 'd0;
    start_FC  = 'd0;
  end
  endcase
end

//==============================================================
// ROM_write_i
always@(*)begin
  case(cur_state)
  ConV1,ConV3: begin
    rom_addr_wi = 'd0;
    rom_data_wi = 'd0;
    rom_en_wi   = 'd0;  
    rom_wea_wi  = 'd0; 
  end
  ConV2: begin
    rom_addr_wi = ram_addr_wi_ConV1;
    rom_data_wi = ram_data_wi_ConV1;
    rom_en_wi   = ram_en_wi_ConV1; 
    rom_wea_wi  = ram_wea_wi_ConV1;
  end
  IDLE: begin
    rom_addr_wi = {4'd0,ram_addr_wtb};
    rom_data_wi = ram_data_wtb;
    rom_en_wi   = ram_en_wtb; 
    rom_wea_wi  = ram_wea_wtb;
  end
  default: begin
    rom_addr_wi = 'd0;
    rom_data_wi = 'd0;
    rom_en_wi   = 'd0;
    rom_wea_wi  = 'd0;
  end
  endcase
end

// ROM_read_i
always@(*)begin
  case(cur_state)
  ConV1,ConV3: begin
    rom_addr_ri = rom_addr_ri_ConV1;
    rom_en_ri   = rom_en_ri_ConV1;  
  end
  ConV2: begin
    rom_addr_ri = 'd0;
    rom_en_ri   = 'd0;
  end
  default: begin
    rom_addr_ri = 'd0;
    rom_en_ri   = 'd0;
  end
  endcase
end

//==============================================================
//Ram_write temp
always@(*)begin
  case(cur_state)
  ConV1,ConV3: begin
    ram_addr_w_temp = ram_addr_wi_ConV1;
    ram_data_w_temp = ram_data_wi_ConV1;
    ram_en_w_temp   = ram_en_wi_ConV1;
    ram_wea_w_temp  = ram_wea_wi_ConV1;
  end
  MP1,MP2: begin
    ram_addr_w_temp = ram_addr_w_MP;
    ram_data_w_temp = ram_data_w_MP;
    ram_en_w_temp   = ram_en_MP;
    ram_wea_w_temp  = ram_wea_MP;
  end
  ConV2: begin // being read
    ram_addr_w_temp = 'd0;
    ram_data_w_temp = 'd0;
    ram_en_w_temp   = 'd0;
    ram_wea_w_temp  = 'd0;
  end

  //tb
  default: begin
    ram_addr_w_temp = 'd0;
    ram_data_w_temp = 'd0;
    ram_en_w_temp   = 'd0;
    ram_wea_w_temp  = 'd0;
  end
  endcase
end

//==============================================================
//Ram_temp_read
always@(*)begin
  case(cur_state)
  ConV1: begin
    ram_addr_r_temp = 'd0;
    ram_en_r_temp = 'd0;
  end
  ConV2: begin
    ram_addr_r_temp = rom_addr_ri_ConV1;
    ram_en_r_temp = rom_en_ri_ConV1;
  end
  ConV3: begin
    ram_addr_r_temp = 'd0;
    ram_en_r_temp = 'd0;
  end
  MP1,MP2: begin
    ram_addr_r_temp = ram_addr_r_MP;
    ram_en_r_temp = ram_en_r_MP;
  end
  FC: begin
    ram_addr_r_temp = {4'd0,ram_addr_r_FC};
    ram_en_r_temp   = ram_en_r_FC;
  end
//   DONE: begin//////////////////////////////////////////////
//     ram_addr_r_temp = ram_addr_rtb;
//     ram_en_r_temp = ram_en_rtb;
//   end
  default: begin
    ram_addr_r_temp = 'd0;
    ram_en_r_temp = 'd0;
  end
  endcase
end

always@(*) begin
  case(cur_state)
  // ConV1: begin
  // end
  ConV2: begin
    ifmap_h = ifmap2_h;
    ifmap_w = ifmap2_w;
    ifmap_c = ifmap2_c;
    outfmap_c = outfmap2_c;
    offset_w  = offset2_w;
    offset_ow = offset2_ow;
  end
  ConV3: begin
    ifmap_h = ifmap3_h;
    ifmap_w = ifmap3_w;
    ifmap_c = ifmap3_c;
    outfmap_c = outfmap3_c;
    offset_w  = offset3_w;
    offset_ow = offset3_ow;
  end
  default: begin
    ifmap_h = ifmap1_h;
    ifmap_w = ifmap1_w;
    ifmap_c = ifmap1_c;
    outfmap_c = outfmap1_c;
    offset_w  = offset1_w;
    offset_ow = offset1_ow;
  end
  endcase
end

//==============================================================
//ROM_read_weight
always@(*)begin
  case(cur_state)
  ConV1,ConV2,ConV3: begin
    rom_addr_rw = rom_addr_rw_ConV1;
    rom_en_rw   = rom_en_rw_ConV1;  
  end
  FC: begin
    rom_addr_rw = rom_addr_rw_FC;
    rom_en_rw   = rom_en_rw_FC;  
  end
  default: begin
    rom_addr_rw = 'd0;
    rom_en_rw   = 'd0;
  end
  endcase
end

//==============================================================
//ROM_read_other weight
always@(*)begin
  case(cur_state)
  ConV1,ConV2,ConV3: begin
    rom_addr_row = rom_addr_row_ConV1;
    rom_en_row   = rom_en_row_ConV1;  
  end
  FC: begin
    rom_addr_row = rom_addr_row_FC;
    rom_en_row   = rom_en_row_FC;  
  end
  default: begin
    rom_addr_row = 'd0;
    rom_en_row   = 'd0;
  end
  endcase
end

always@(posedge clk,negedge rst_n)begin
  if(!rst_n)begin
    NN_out_female_d <= 'd0;
    NN_out_male_d <= 'd0;
  end
  else begin
    if(end_FC) begin
      NN_out_female_d <= NN_out_female_FC;
      NN_out_male_d   <= NN_out_male_FC;
    end
    else if(cur_state==DONE) begin
      NN_out_female_d <= NN_out_female_d;
      NN_out_male_d   <= NN_out_male_d;
    end
    else begin
      NN_out_female_d <= 'd0;
      NN_out_male_d   <= 'd0;
    end
  end
end

always@(posedge clk or negedge rst_n) begin
  if(!rst_n)
    cnt_end <= 'd0;
  else if(cur_state==DONE)
    cnt_end <= cnt_end + 1'b1;
  else
    cnt_end <= 'd0;
end
endmodule

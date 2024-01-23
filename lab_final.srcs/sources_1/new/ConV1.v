`timescale 1ns / 1ns
// (* use_dsp = "yes" *)
module ConV1
(
  input clk,
  input rst_n,

  input start_ConV1,
  output reg end_ConV1,

  //write temp or ROM
  output reg [15:0] ram_addr_wi,
  output reg [7:0]  ram_data_wi,
  output reg        ram_en_wi,
  output reg        ram_wea_wi,

  //read temp or ROM
  output reg [15:0] rom_addr_ri,
  input  [7:0]      rom_data_ri,
  output reg        rom_en_ri, 

  //ROM read weight
  output reg [14:0] rom_addr_rw,
  input  [7:0]      rom_data_rw,
  output reg        rom_en_rw,

  //ROM read other_weight
  output reg [8:0]  rom_addr_row,
  input  [31:0]     rom_data_row,
  output reg        rom_en_row, 
  
  input [5:0] ifmap_h,
  input [5:0] ifmap_w,
  input [5:0] ifmap_c,
  input [5:0] outfmap_c,
  input [14:0] offset_w, 
  input [8:0] offset_ow
);

/*
write ConV operation code here
*/
reg [3:0] ns,cs;
reg signed [7:0] acti [0:4][0:49];
reg signed [7:0] filter [0:1][0:2][0:2];
reg signed [31:0] ow [0:1][0:2];
reg signed [31:0] outbuf [0:1][0:2][0:47];
reg [5:0] y_acti, x_acti, x_ow, m_out, y_out, x_out;
reg [3:0] c_acti,  c_w, m_w, m_ow;
reg [1:0] y_w, x_w;
reg [7:0] c_w_temp, m_w_temp, y_w_temp, m_ow_temp;
wire [5:0] outfmap_h, outfmap_w;
reg [2:0] m_out1, m_out1_inc;  //0~7
reg m_out2, m_out2_inc;  //0~1
reg [3:0] y_acti1; //0~15
reg [2:0] y_acti2, y_acti2_inc; //0~4
reg m_ow2, m_ow2_inc, m_w2, m_w2_inc; //0~1
reg [3:0] y_out1, y_out1_inc;  //0~15
reg [1:0] y_out2, y_out2_inc;  //0~2
reg [5:0] x_acti_inc, x_w_inc, y_w_inc, x_ow_inc, x_out_inc;

reg [5:0] ifmap_h_dec, ifmap_w_dec, ifmap_c_dec, outfmap_h_dec, outfmap_w_dec, outfmap_m_dec;
reg last_acti_load, last_m_out1;

reg [7:0] cnt_LOAD;
reg last_cnt_LOAD;
reg [5:0] cnt_ROW_RUN;
reg last_cnt_ROW_RUN;

reg signed [17:0] PE [0:1][0:2][0:2];
reg signed [19:0] psum [0:1][0:2];

reg signed [31:0] outbuf_d, Z1a2, bias;
reg signed [31:0] sum, M0;
reg signed [63:0] Msum;
reg [15:0] ram_addr_w_pre;
reg m_out2_d;
reg [7:0] q3;
wire signed [31:0] wit;

assign wit = $signed(Msum[63:32]) - 32'd128 + {31'd0,Msum[31]};

parameter IDLE=4'd0,LOAD=4'd1,ROW_RUN=4'd2,NEXT_C=4'd3,WR_OUT=4'd4,NEXT_M=4'd5,NEXT_H=4'd6,DONE=4'd7;

integer i,j,k;

always@(*) begin
  M0 = ow[m_out2_d][0];
  Z1a2 = ow[m_out2_d][1];
  bias = ow[m_out2_d][2];
  sum = outbuf_d - Z1a2 + bias;
  Msum = M0 * sum;
  q3 = (Msum[63])? 8'd128 : wit[7:0];
end

always@(*) begin
  case(cs)
  IDLE: ns = start_ConV1? LOAD : IDLE;
  LOAD: ns = last_cnt_LOAD? ROW_RUN : LOAD;
  ROW_RUN: begin
    if(last_cnt_ROW_RUN) begin
      if(c_acti==ifmap_c_dec[3:0])
        ns = WR_OUT;
      else
        ns = NEXT_C;
    end
    else
      ns = ROW_RUN;
  end
  NEXT_C,NEXT_M,NEXT_H: ns = LOAD;
  WR_OUT: begin
    if(m_out2==1'd1 && (y_out2==2'd2 || y_out==outfmap_h_dec) && x_out==outfmap_w_dec) begin
      if(last_m_out1) begin
        if(y_out==outfmap_h_dec)
          ns = DONE;
        else
          ns = NEXT_H;
      end
      else
        ns = NEXT_M;
    end
    else
      ns = WR_OUT;
  end
  // DONE: ns = start_ConV1? DONE : IDLE;
  DONE: ns = IDLE;
  default: ns = IDLE;
  endcase
end


assign outfmap_h = ifmap_h - 2'd2;
assign outfmap_w = ifmap_w - 2'd2;


always@(*) begin
  c_w_temp  = {c_w[3:0],3'd0} + c_w[3:0];   // c_w * 3 * 3
  m_w_temp  = {m_w[3:0],3'd0} + m_w[3:0];   // m_w * 3 * 3
  y_w_temp  = {y_w,1'd0} + y_w;             // y_w * 3
  m_ow_temp = {m_ow[3:0],1'd0} + m_ow[3:0]; // m_ow * 3
end

always@(*) begin
  rom_en_ri = (cs==LOAD);
  rom_en_rw = (cs==LOAD);
  rom_en_row = (cs==LOAD);
  ram_addr_w_pre = m_out*outfmap_h*outfmap_w + y_out*outfmap_w + x_out;
  rom_addr_ri = c_acti*ifmap_h*ifmap_w + y_acti*ifmap_w + x_acti;
  rom_addr_rw = offset_w + c_w_temp*outfmap_c + m_w_temp + y_w_temp + x_w;
  rom_addr_row = offset_ow + m_ow_temp + x_ow;
  ram_wea_wi = ram_en_wi;
end

always@(*) begin
  c_w = c_acti;
  m_out = {m_out1,1'b0} + m_out2;
  m_w = {m_out1,1'b0} + m_w2;
  m_ow = {m_out1,1'b0} + m_ow2;
  y_acti1 = y_out1;
  y_acti = y_acti1*3'd3 + y_acti2;
  y_out = y_out1 + y_out1 + y_out1 + y_out2; // y_out1*3 + y_out2

end

always@(*) begin
  ifmap_h_dec   = ifmap_h - 1'd1;
  ifmap_w_dec   = ifmap_w - 1'd1;
  ifmap_c_dec   = ifmap_c - 1'd1;
  outfmap_h_dec = outfmap_h - 1'd1;
  outfmap_w_dec = outfmap_w - 1'd1;
  outfmap_m_dec = outfmap_c - 1'd1;
end

always@(*) begin
  last_acti_load = (y_acti2==3'd4) && (x_acti==ifmap_w_dec);
  last_cnt_LOAD = cnt_LOAD == ((3'd5*ifmap_w) + 2'd2); // 5*50 + 2
  last_cnt_ROW_RUN = cnt_ROW_RUN == outfmap_w_dec;
  last_m_out1 = m_out1==(outfmap_c[5:1]-1'd1);
end

always@(*) begin
  m_out1_inc = m_out1 + 1'd1; //0~7
  m_out2_inc = ((x_out==outfmap_w_dec)&&(y_out2==2'd2))? m_out2 + 1'd1 : m_out2; //0~1
  x_acti_inc = (x_acti==ifmap_w_dec)? 6'd0 : x_acti + 1'd1;
  y_acti2_inc = (x_acti==ifmap_w_dec)? y_acti2 + 1'd1 : y_acti2; //0~4
  y_out1_inc = y_out1 + 1'd1;  //0~15
  y_out2_inc = (x_out==outfmap_w_dec)? ((y_out2==2'd2)? 2'd0 : y_out2 + 2'd1) : y_out2;  //0~2
  x_w_inc = (x_w=='d2)? 'd0 : x_w + 1'd1;
  y_w_inc = (x_w=='d2)? ((y_w=='d2)? 'd0 : y_w + 1'd1) : y_w;
  m_w2_inc = (x_w=='d2 && y_w=='d2)? m_w2 + 1'd1 : m_w2;
  x_ow_inc = (x_ow=='d2)? 'd0 : x_ow + 1'd1;
  m_ow2_inc = (x_ow=='d2)? m_ow2 + 1'd1 : m_ow2;
  x_out_inc = (x_out==outfmap_w_dec)? 'd0 : x_out + 1'd1;
end

always@(*) begin
  ram_data_wi = q3;
  end_ConV1 = cs==DONE;
end

always@(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    ram_en_wi   <= 'd0;
    ram_addr_wi <= 'd0;
    outbuf_d    <= 'd0;
    m_out2_d    <= 'd0;
  end
  else begin
    ram_en_wi <= (cs==WR_OUT) && (y_out<outfmap_h);
    ram_addr_wi <= ram_addr_w_pre;
    case({m_out2,y_out2,x_out})
    9'd0: outbuf_d <= outbuf[0][0][0];9'd1: outbuf_d <= outbuf[0][0][1];9'd2: outbuf_d <= outbuf[0][0][2];9'd3: outbuf_d <= outbuf[0][0][3];9'd4: outbuf_d <= outbuf[0][0][4];9'd5: outbuf_d <= outbuf[0][0][5];9'd6: outbuf_d <= outbuf[0][0][6];9'd7: outbuf_d <= outbuf[0][0][7];9'd8: outbuf_d <= outbuf[0][0][8];9'd9: outbuf_d <= outbuf[0][0][9];9'd10: outbuf_d <= outbuf[0][0][10];9'd11: outbuf_d <= outbuf[0][0][11];9'd12: outbuf_d <= outbuf[0][0][12];9'd13: outbuf_d <= outbuf[0][0][13];9'd14: outbuf_d <= outbuf[0][0][14];9'd15: outbuf_d <= outbuf[0][0][15];9'd16: outbuf_d <= outbuf[0][0][16];9'd17: outbuf_d <= outbuf[0][0][17];9'd18: outbuf_d <= outbuf[0][0][18];9'd19: outbuf_d <= outbuf[0][0][19];9'd20: outbuf_d <= outbuf[0][0][20];9'd21: outbuf_d <= outbuf[0][0][21];9'd22: outbuf_d <= outbuf[0][0][22];9'd23: outbuf_d <= outbuf[0][0][23];9'd24: outbuf_d <= outbuf[0][0][24];9'd25: outbuf_d <= outbuf[0][0][25];9'd26: outbuf_d <= outbuf[0][0][26];9'd27: outbuf_d <= outbuf[0][0][27];9'd28: outbuf_d <= outbuf[0][0][28];9'd29: outbuf_d <= outbuf[0][0][29];9'd30: outbuf_d <= outbuf[0][0][30];9'd31: outbuf_d <= outbuf[0][0][31];9'd32: outbuf_d <= outbuf[0][0][32];9'd33: outbuf_d <= outbuf[0][0][33];9'd34: outbuf_d <= outbuf[0][0][34];9'd35: outbuf_d <= outbuf[0][0][35];9'd36: outbuf_d <= outbuf[0][0][36];9'd37: outbuf_d <= outbuf[0][0][37];9'd38: outbuf_d <= outbuf[0][0][38];9'd39: outbuf_d <= outbuf[0][0][39];9'd40: outbuf_d <= outbuf[0][0][40];9'd41: outbuf_d <= outbuf[0][0][41];9'd42: outbuf_d <= outbuf[0][0][42];9'd43: outbuf_d <= outbuf[0][0][43];9'd44: outbuf_d <= outbuf[0][0][44];9'd45: outbuf_d <= outbuf[0][0][45];9'd46: outbuf_d <= outbuf[0][0][46];9'd47: outbuf_d <= outbuf[0][0][47];
    9'd64: outbuf_d <= outbuf[0][1][0];9'd65: outbuf_d <= outbuf[0][1][1];9'd66: outbuf_d <= outbuf[0][1][2];9'd67: outbuf_d <= outbuf[0][1][3];9'd68: outbuf_d <= outbuf[0][1][4];9'd69: outbuf_d <= outbuf[0][1][5];9'd70: outbuf_d <= outbuf[0][1][6];9'd71: outbuf_d <= outbuf[0][1][7];9'd72: outbuf_d <= outbuf[0][1][8];9'd73: outbuf_d <= outbuf[0][1][9];9'd74: outbuf_d <= outbuf[0][1][10];9'd75: outbuf_d <= outbuf[0][1][11];9'd76: outbuf_d <= outbuf[0][1][12];9'd77: outbuf_d <= outbuf[0][1][13];9'd78: outbuf_d <= outbuf[0][1][14];9'd79: outbuf_d <= outbuf[0][1][15];9'd80: outbuf_d <= outbuf[0][1][16];9'd81: outbuf_d <= outbuf[0][1][17];9'd82: outbuf_d <= outbuf[0][1][18];9'd83: outbuf_d <= outbuf[0][1][19];9'd84: outbuf_d <= outbuf[0][1][20];9'd85: outbuf_d <= outbuf[0][1][21];9'd86: outbuf_d <= outbuf[0][1][22];9'd87: outbuf_d <= outbuf[0][1][23];9'd88: outbuf_d <= outbuf[0][1][24];9'd89: outbuf_d <= outbuf[0][1][25];9'd90: outbuf_d <= outbuf[0][1][26];9'd91: outbuf_d <= outbuf[0][1][27];9'd92: outbuf_d <= outbuf[0][1][28];9'd93: outbuf_d <= outbuf[0][1][29];9'd94: outbuf_d <= outbuf[0][1][30];9'd95: outbuf_d <= outbuf[0][1][31];9'd96: outbuf_d <= outbuf[0][1][32];9'd97: outbuf_d <= outbuf[0][1][33];9'd98: outbuf_d <= outbuf[0][1][34];9'd99: outbuf_d <= outbuf[0][1][35];9'd100: outbuf_d <= outbuf[0][1][36];9'd101: outbuf_d <= outbuf[0][1][37];9'd102: outbuf_d <= outbuf[0][1][38];9'd103: outbuf_d <= outbuf[0][1][39];9'd104: outbuf_d <= outbuf[0][1][40];9'd105: outbuf_d <= outbuf[0][1][41];9'd106: outbuf_d <= outbuf[0][1][42];9'd107: outbuf_d <= outbuf[0][1][43];9'd108: outbuf_d <= outbuf[0][1][44];9'd109: outbuf_d <= outbuf[0][1][45];9'd110: outbuf_d <= outbuf[0][1][46];9'd111: outbuf_d <= outbuf[0][1][47];
    9'd128: outbuf_d <= outbuf[0][2][0];9'd129: outbuf_d <= outbuf[0][2][1];9'd130: outbuf_d <= outbuf[0][2][2];9'd131: outbuf_d <= outbuf[0][2][3];9'd132: outbuf_d <= outbuf[0][2][4];9'd133: outbuf_d <= outbuf[0][2][5];9'd134: outbuf_d <= outbuf[0][2][6];9'd135: outbuf_d <= outbuf[0][2][7];9'd136: outbuf_d <= outbuf[0][2][8];9'd137: outbuf_d <= outbuf[0][2][9];9'd138: outbuf_d <= outbuf[0][2][10];9'd139: outbuf_d <= outbuf[0][2][11];9'd140: outbuf_d <= outbuf[0][2][12];9'd141: outbuf_d <= outbuf[0][2][13];9'd142: outbuf_d <= outbuf[0][2][14];9'd143: outbuf_d <= outbuf[0][2][15];9'd144: outbuf_d <= outbuf[0][2][16];9'd145: outbuf_d <= outbuf[0][2][17];9'd146: outbuf_d <= outbuf[0][2][18];9'd147: outbuf_d <= outbuf[0][2][19];9'd148: outbuf_d <= outbuf[0][2][20];9'd149: outbuf_d <= outbuf[0][2][21];9'd150: outbuf_d <= outbuf[0][2][22];9'd151: outbuf_d <= outbuf[0][2][23];9'd152: outbuf_d <= outbuf[0][2][24];9'd153: outbuf_d <= outbuf[0][2][25];9'd154: outbuf_d <= outbuf[0][2][26];9'd155: outbuf_d <= outbuf[0][2][27];9'd156: outbuf_d <= outbuf[0][2][28];9'd157: outbuf_d <= outbuf[0][2][29];9'd158: outbuf_d <= outbuf[0][2][30];9'd159: outbuf_d <= outbuf[0][2][31];9'd160: outbuf_d <= outbuf[0][2][32];9'd161: outbuf_d <= outbuf[0][2][33];9'd162: outbuf_d <= outbuf[0][2][34];9'd163: outbuf_d <= outbuf[0][2][35];9'd164: outbuf_d <= outbuf[0][2][36];9'd165: outbuf_d <= outbuf[0][2][37];9'd166: outbuf_d <= outbuf[0][2][38];9'd167: outbuf_d <= outbuf[0][2][39];9'd168: outbuf_d <= outbuf[0][2][40];9'd169: outbuf_d <= outbuf[0][2][41];9'd170: outbuf_d <= outbuf[0][2][42];9'd171: outbuf_d <= outbuf[0][2][43];9'd172: outbuf_d <= outbuf[0][2][44];9'd173: outbuf_d <= outbuf[0][2][45];9'd174: outbuf_d <= outbuf[0][2][46];9'd175: outbuf_d <= outbuf[0][2][47];
    9'd256: outbuf_d <= outbuf[1][0][0];9'd257: outbuf_d <= outbuf[1][0][1];9'd258: outbuf_d <= outbuf[1][0][2];9'd259: outbuf_d <= outbuf[1][0][3];9'd260: outbuf_d <= outbuf[1][0][4];9'd261: outbuf_d <= outbuf[1][0][5];9'd262: outbuf_d <= outbuf[1][0][6];9'd263: outbuf_d <= outbuf[1][0][7];9'd264: outbuf_d <= outbuf[1][0][8];9'd265: outbuf_d <= outbuf[1][0][9];9'd266: outbuf_d <= outbuf[1][0][10];9'd267: outbuf_d <= outbuf[1][0][11];9'd268: outbuf_d <= outbuf[1][0][12];9'd269: outbuf_d <= outbuf[1][0][13];9'd270: outbuf_d <= outbuf[1][0][14];9'd271: outbuf_d <= outbuf[1][0][15];9'd272: outbuf_d <= outbuf[1][0][16];9'd273: outbuf_d <= outbuf[1][0][17];9'd274: outbuf_d <= outbuf[1][0][18];9'd275: outbuf_d <= outbuf[1][0][19];9'd276: outbuf_d <= outbuf[1][0][20];9'd277: outbuf_d <= outbuf[1][0][21];9'd278: outbuf_d <= outbuf[1][0][22];9'd279: outbuf_d <= outbuf[1][0][23];9'd280: outbuf_d <= outbuf[1][0][24];9'd281: outbuf_d <= outbuf[1][0][25];9'd282: outbuf_d <= outbuf[1][0][26];9'd283: outbuf_d <= outbuf[1][0][27];9'd284: outbuf_d <= outbuf[1][0][28];9'd285: outbuf_d <= outbuf[1][0][29];9'd286: outbuf_d <= outbuf[1][0][30];9'd287: outbuf_d <= outbuf[1][0][31];9'd288: outbuf_d <= outbuf[1][0][32];9'd289: outbuf_d <= outbuf[1][0][33];9'd290: outbuf_d <= outbuf[1][0][34];9'd291: outbuf_d <= outbuf[1][0][35];9'd292: outbuf_d <= outbuf[1][0][36];9'd293: outbuf_d <= outbuf[1][0][37];9'd294: outbuf_d <= outbuf[1][0][38];9'd295: outbuf_d <= outbuf[1][0][39];9'd296: outbuf_d <= outbuf[1][0][40];9'd297: outbuf_d <= outbuf[1][0][41];9'd298: outbuf_d <= outbuf[1][0][42];9'd299: outbuf_d <= outbuf[1][0][43];9'd300: outbuf_d <= outbuf[1][0][44];9'd301: outbuf_d <= outbuf[1][0][45];9'd302: outbuf_d <= outbuf[1][0][46];9'd303: outbuf_d <= outbuf[1][0][47];
    9'd320: outbuf_d <= outbuf[1][1][0];9'd321: outbuf_d <= outbuf[1][1][1];9'd322: outbuf_d <= outbuf[1][1][2];9'd323: outbuf_d <= outbuf[1][1][3];9'd324: outbuf_d <= outbuf[1][1][4];9'd325: outbuf_d <= outbuf[1][1][5];9'd326: outbuf_d <= outbuf[1][1][6];9'd327: outbuf_d <= outbuf[1][1][7];9'd328: outbuf_d <= outbuf[1][1][8];9'd329: outbuf_d <= outbuf[1][1][9];9'd330: outbuf_d <= outbuf[1][1][10];9'd331: outbuf_d <= outbuf[1][1][11];9'd332: outbuf_d <= outbuf[1][1][12];9'd333: outbuf_d <= outbuf[1][1][13];9'd334: outbuf_d <= outbuf[1][1][14];9'd335: outbuf_d <= outbuf[1][1][15];9'd336: outbuf_d <= outbuf[1][1][16];9'd337: outbuf_d <= outbuf[1][1][17];9'd338: outbuf_d <= outbuf[1][1][18];9'd339: outbuf_d <= outbuf[1][1][19];9'd340: outbuf_d <= outbuf[1][1][20];9'd341: outbuf_d <= outbuf[1][1][21];9'd342: outbuf_d <= outbuf[1][1][22];9'd343: outbuf_d <= outbuf[1][1][23];9'd344: outbuf_d <= outbuf[1][1][24];9'd345: outbuf_d <= outbuf[1][1][25];9'd346: outbuf_d <= outbuf[1][1][26];9'd347: outbuf_d <= outbuf[1][1][27];9'd348: outbuf_d <= outbuf[1][1][28];9'd349: outbuf_d <= outbuf[1][1][29];9'd350: outbuf_d <= outbuf[1][1][30];9'd351: outbuf_d <= outbuf[1][1][31];9'd352: outbuf_d <= outbuf[1][1][32];9'd353: outbuf_d <= outbuf[1][1][33];9'd354: outbuf_d <= outbuf[1][1][34];9'd355: outbuf_d <= outbuf[1][1][35];9'd356: outbuf_d <= outbuf[1][1][36];9'd357: outbuf_d <= outbuf[1][1][37];9'd358: outbuf_d <= outbuf[1][1][38];9'd359: outbuf_d <= outbuf[1][1][39];9'd360: outbuf_d <= outbuf[1][1][40];9'd361: outbuf_d <= outbuf[1][1][41];9'd362: outbuf_d <= outbuf[1][1][42];9'd363: outbuf_d <= outbuf[1][1][43];9'd364: outbuf_d <= outbuf[1][1][44];9'd365: outbuf_d <= outbuf[1][1][45];9'd366: outbuf_d <= outbuf[1][1][46];9'd367: outbuf_d <= outbuf[1][1][47];
    9'd384: outbuf_d <= outbuf[1][2][0];9'd385: outbuf_d <= outbuf[1][2][1];9'd386: outbuf_d <= outbuf[1][2][2];9'd387: outbuf_d <= outbuf[1][2][3];9'd388: outbuf_d <= outbuf[1][2][4];9'd389: outbuf_d <= outbuf[1][2][5];9'd390: outbuf_d <= outbuf[1][2][6];9'd391: outbuf_d <= outbuf[1][2][7];9'd392: outbuf_d <= outbuf[1][2][8];9'd393: outbuf_d <= outbuf[1][2][9];9'd394: outbuf_d <= outbuf[1][2][10];9'd395: outbuf_d <= outbuf[1][2][11];9'd396: outbuf_d <= outbuf[1][2][12];9'd397: outbuf_d <= outbuf[1][2][13];9'd398: outbuf_d <= outbuf[1][2][14];9'd399: outbuf_d <= outbuf[1][2][15];9'd400: outbuf_d <= outbuf[1][2][16];9'd401: outbuf_d <= outbuf[1][2][17];9'd402: outbuf_d <= outbuf[1][2][18];9'd403: outbuf_d <= outbuf[1][2][19];9'd404: outbuf_d <= outbuf[1][2][20];9'd405: outbuf_d <= outbuf[1][2][21];9'd406: outbuf_d <= outbuf[1][2][22];9'd407: outbuf_d <= outbuf[1][2][23];9'd408: outbuf_d <= outbuf[1][2][24];9'd409: outbuf_d <= outbuf[1][2][25];9'd410: outbuf_d <= outbuf[1][2][26];9'd411: outbuf_d <= outbuf[1][2][27];9'd412: outbuf_d <= outbuf[1][2][28];9'd413: outbuf_d <= outbuf[1][2][29];9'd414: outbuf_d <= outbuf[1][2][30];9'd415: outbuf_d <= outbuf[1][2][31];9'd416: outbuf_d <= outbuf[1][2][32];9'd417: outbuf_d <= outbuf[1][2][33];9'd418: outbuf_d <= outbuf[1][2][34];9'd419: outbuf_d <= outbuf[1][2][35];9'd420: outbuf_d <= outbuf[1][2][36];9'd421: outbuf_d <= outbuf[1][2][37];9'd422: outbuf_d <= outbuf[1][2][38];9'd423: outbuf_d <= outbuf[1][2][39];9'd424: outbuf_d <= outbuf[1][2][40];9'd425: outbuf_d <= outbuf[1][2][41];9'd426: outbuf_d <= outbuf[1][2][42];9'd427: outbuf_d <= outbuf[1][2][43];9'd428: outbuf_d <= outbuf[1][2][44];9'd429: outbuf_d <= outbuf[1][2][45];9'd430: outbuf_d <= outbuf[1][2][46];
    default: outbuf_d <= outbuf[1][2][47];
    endcase

    m_out2_d <= m_out2;
  end
end

always@(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    cs <= IDLE;
  end
  else begin
    cs <= ns;
  end
end

always@(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    x_acti <= {6{1'b1}};
    y_acti2 <= 'd0;
    for(i=0;i<5;i=i+1) begin
      for(j=0;j<50;j=j+1) begin
        acti[i][j] <= 'd0;
      end
    end

    x_w <= 'd2;
    y_w <= 'd2;
    m_w2 <= 'd1;
    for(i=0;i<2;i=i+1) begin
      for(j=0;j<3;j=j+1) begin
        for(k=0;k<3;k=k+1) begin
          filter[i][j][k] <= 'd0;
        end
      end
    end

    x_ow <= 'd2;
    m_ow2 <= 'd1;
    for(i=0;i<2;i=i+1) begin
      for(j=0;j<3;j=j+1) begin
        ow[i][j] <= 'd0;
      end
    end

    for(i=0;i<2;i=i+1) begin
      for(j=0;j<3;j=j+1) begin
        for(k=0;k<48;k=k+1) begin
            outbuf[i][j][k] <= 'd0;
        end
      end
    end
    c_acti <= 'd0;

    x_out <= {6{1'b1}};
    y_out2 <= 'd0;
    m_out2 <= 'd0;

    m_out1 <= 'd0;
    y_out1 <= 'd0;

  end
  else begin
    x_acti <= x_acti;
    y_acti2 <= y_acti2;
    for(i=0;i<5;i=i+1) begin
      for(j=0;j<50;j=j+1) begin
        acti[i][j] <= acti[i][j];
      end
    end
    
    x_w <= x_w;
    y_w <= y_w;
    m_w2 <= m_w2;
    for(i=0;i<2;i=i+1) begin
      for(j=0;j<3;j=j+1) begin
        for(k=0;k<3;k=k+1) begin
          filter[i][j][k] <= filter[i][j][k];
        end
      end
    end

    x_ow <= x_ow;
    m_ow2 <= m_ow2;
    for(i=0;i<2;i=i+1) begin
      for(j=0;j<3;j=j+1) begin
        ow[i][j] <= ow[i][j];
      end
    end

    for(i=0;i<2;i=i+1) begin
      for(j=0;j<3;j=j+1) begin
        for(k=0;k<48;k=k+1) begin
            outbuf[i][j][k] <= outbuf[i][j][k];
        end
      end
    end
    c_acti <= c_acti;

    x_out <= x_out;
    y_out2 <= y_out2;
    m_out2 <= m_out2;

    m_out1 <= m_out1;
    y_out1 <= y_out1;
    
    case(ns)
    LOAD: begin
      x_acti <= x_acti_inc;
      y_acti2 <= y_acti2_inc; //need x_acti to be 63, need reset before LOAD
      // for(i1=0;i1<5;i1=i1+1) begin
      //   for(i0=0;i0<=ifmap_w_dec;i0=i0+1) begin
      //     if(i0==ifmap_w_dec) begin
      //       if(i1==4)
      //         acti[i1][i0] <= rom_data_ri;
      //       else
      //         acti[i1][i0] <= acti[i1+1][0];
      //     end
      //     else
      //       acti[i1][i0] <= acti[i1][i0+1];
      //   end
      // end
      case(ifmap_w)
      6'd50: begin
        acti[0][0] <= acti[0][1];acti[0][1] <= acti[0][2];acti[0][2] <= acti[0][3];acti[0][3] <= acti[0][4];acti[0][4] <= acti[0][5];acti[0][5] <= acti[0][6];acti[0][6] <= acti[0][7];acti[0][7] <= acti[0][8];acti[0][8] <= acti[0][9];acti[0][9] <= acti[0][10];acti[0][10] <= acti[0][11];acti[0][11] <= acti[0][12];acti[0][12] <= acti[0][13];acti[0][13] <= acti[0][14];acti[0][14] <= acti[0][15];acti[0][15] <= acti[0][16];acti[0][16] <= acti[0][17];acti[0][17] <= acti[0][18];acti[0][18] <= acti[0][19];acti[0][19] <= acti[0][20];acti[0][20] <= acti[0][21];acti[0][21] <= acti[0][22];acti[0][22] <= acti[0][23];acti[0][23] <= acti[0][24];acti[0][24] <= acti[0][25];acti[0][25] <= acti[0][26];acti[0][26] <= acti[0][27];acti[0][27] <= acti[0][28];acti[0][28] <= acti[0][29];acti[0][29] <= acti[0][30];acti[0][30] <= acti[0][31];acti[0][31] <= acti[0][32];acti[0][32] <= acti[0][33];acti[0][33] <= acti[0][34];acti[0][34] <= acti[0][35];acti[0][35] <= acti[0][36];acti[0][36] <= acti[0][37];acti[0][37] <= acti[0][38];acti[0][38] <= acti[0][39];acti[0][39] <= acti[0][40];acti[0][40] <= acti[0][41];acti[0][41] <= acti[0][42];acti[0][42] <= acti[0][43];acti[0][43] <= acti[0][44];acti[0][44] <= acti[0][45];acti[0][45] <= acti[0][46];acti[0][46] <= acti[0][47];acti[0][47] <= acti[0][48];acti[0][48] <= acti[0][49];acti[0][49] <= acti[1][0];acti[1][0] <= acti[1][1];acti[1][1] <= acti[1][2];acti[1][2] <= acti[1][3];acti[1][3] <= acti[1][4];acti[1][4] <= acti[1][5];acti[1][5] <= acti[1][6];acti[1][6] <= acti[1][7];acti[1][7] <= acti[1][8];acti[1][8] <= acti[1][9];acti[1][9] <= acti[1][10];acti[1][10] <= acti[1][11];acti[1][11] <= acti[1][12];acti[1][12] <= acti[1][13];acti[1][13] <= acti[1][14];acti[1][14] <= acti[1][15];acti[1][15] <= acti[1][16];acti[1][16] <= acti[1][17];acti[1][17] <= acti[1][18];acti[1][18] <= acti[1][19];acti[1][19] <= acti[1][20];acti[1][20] <= acti[1][21];acti[1][21] <= acti[1][22];acti[1][22] <= acti[1][23];acti[1][23] <= acti[1][24];acti[1][24] <= acti[1][25];acti[1][25] <= acti[1][26];acti[1][26] <= acti[1][27];acti[1][27] <= acti[1][28];acti[1][28] <= acti[1][29];acti[1][29] <= acti[1][30];acti[1][30] <= acti[1][31];acti[1][31] <= acti[1][32];acti[1][32] <= acti[1][33];acti[1][33] <= acti[1][34];acti[1][34] <= acti[1][35];acti[1][35] <= acti[1][36];acti[1][36] <= acti[1][37];acti[1][37] <= acti[1][38];acti[1][38] <= acti[1][39];acti[1][39] <= acti[1][40];acti[1][40] <= acti[1][41];acti[1][41] <= acti[1][42];acti[1][42] <= acti[1][43];acti[1][43] <= acti[1][44];acti[1][44] <= acti[1][45];acti[1][45] <= acti[1][46];acti[1][46] <= acti[1][47];acti[1][47] <= acti[1][48];acti[1][48] <= acti[1][49];acti[1][49] <= acti[2][0];acti[2][0] <= acti[2][1];acti[2][1] <= acti[2][2];acti[2][2] <= acti[2][3];acti[2][3] <= acti[2][4];acti[2][4] <= acti[2][5];acti[2][5] <= acti[2][6];acti[2][6] <= acti[2][7];acti[2][7] <= acti[2][8];acti[2][8] <= acti[2][9];acti[2][9] <= acti[2][10];acti[2][10] <= acti[2][11];acti[2][11] <= acti[2][12];acti[2][12] <= acti[2][13];acti[2][13] <= acti[2][14];acti[2][14] <= acti[2][15];acti[2][15] <= acti[2][16];acti[2][16] <= acti[2][17];acti[2][17] <= acti[2][18];acti[2][18] <= acti[2][19];acti[2][19] <= acti[2][20];acti[2][20] <= acti[2][21];acti[2][21] <= acti[2][22];acti[2][22] <= acti[2][23];acti[2][23] <= acti[2][24];acti[2][24] <= acti[2][25];acti[2][25] <= acti[2][26];acti[2][26] <= acti[2][27];acti[2][27] <= acti[2][28];acti[2][28] <= acti[2][29];acti[2][29] <= acti[2][30];acti[2][30] <= acti[2][31];acti[2][31] <= acti[2][32];acti[2][32] <= acti[2][33];acti[2][33] <= acti[2][34];acti[2][34] <= acti[2][35];acti[2][35] <= acti[2][36];acti[2][36] <= acti[2][37];acti[2][37] <= acti[2][38];acti[2][38] <= acti[2][39];acti[2][39] <= acti[2][40];acti[2][40] <= acti[2][41];acti[2][41] <= acti[2][42];acti[2][42] <= acti[2][43];acti[2][43] <= acti[2][44];acti[2][44] <= acti[2][45];acti[2][45] <= acti[2][46];acti[2][46] <= acti[2][47];acti[2][47] <= acti[2][48];acti[2][48] <= acti[2][49];acti[2][49] <= acti[3][0];acti[3][0] <= acti[3][1];acti[3][1] <= acti[3][2];acti[3][2] <= acti[3][3];acti[3][3] <= acti[3][4];acti[3][4] <= acti[3][5];acti[3][5] <= acti[3][6];acti[3][6] <= acti[3][7];acti[3][7] <= acti[3][8];acti[3][8] <= acti[3][9];acti[3][9] <= acti[3][10];acti[3][10] <= acti[3][11];acti[3][11] <= acti[3][12];acti[3][12] <= acti[3][13];acti[3][13] <= acti[3][14];acti[3][14] <= acti[3][15];acti[3][15] <= acti[3][16];acti[3][16] <= acti[3][17];acti[3][17] <= acti[3][18];acti[3][18] <= acti[3][19];acti[3][19] <= acti[3][20];acti[3][20] <= acti[3][21];acti[3][21] <= acti[3][22];acti[3][22] <= acti[3][23];acti[3][23] <= acti[3][24];acti[3][24] <= acti[3][25];acti[3][25] <= acti[3][26];acti[3][26] <= acti[3][27];acti[3][27] <= acti[3][28];acti[3][28] <= acti[3][29];acti[3][29] <= acti[3][30];acti[3][30] <= acti[3][31];acti[3][31] <= acti[3][32];acti[3][32] <= acti[3][33];acti[3][33] <= acti[3][34];acti[3][34] <= acti[3][35];acti[3][35] <= acti[3][36];acti[3][36] <= acti[3][37];acti[3][37] <= acti[3][38];acti[3][38] <= acti[3][39];acti[3][39] <= acti[3][40];acti[3][40] <= acti[3][41];acti[3][41] <= acti[3][42];acti[3][42] <= acti[3][43];acti[3][43] <= acti[3][44];acti[3][44] <= acti[3][45];acti[3][45] <= acti[3][46];acti[3][46] <= acti[3][47];acti[3][47] <= acti[3][48];acti[3][48] <= acti[3][49];acti[3][49] <= acti[4][0];acti[4][0] <= acti[4][1];acti[4][1] <= acti[4][2];acti[4][2] <= acti[4][3];acti[4][3] <= acti[4][4];acti[4][4] <= acti[4][5];acti[4][5] <= acti[4][6];acti[4][6] <= acti[4][7];acti[4][7] <= acti[4][8];acti[4][8] <= acti[4][9];acti[4][9] <= acti[4][10];acti[4][10] <= acti[4][11];acti[4][11] <= acti[4][12];acti[4][12] <= acti[4][13];acti[4][13] <= acti[4][14];acti[4][14] <= acti[4][15];acti[4][15] <= acti[4][16];acti[4][16] <= acti[4][17];acti[4][17] <= acti[4][18];acti[4][18] <= acti[4][19];acti[4][19] <= acti[4][20];acti[4][20] <= acti[4][21];acti[4][21] <= acti[4][22];acti[4][22] <= acti[4][23];acti[4][23] <= acti[4][24];acti[4][24] <= acti[4][25];acti[4][25] <= acti[4][26];acti[4][26] <= acti[4][27];acti[4][27] <= acti[4][28];acti[4][28] <= acti[4][29];acti[4][29] <= acti[4][30];acti[4][30] <= acti[4][31];acti[4][31] <= acti[4][32];acti[4][32] <= acti[4][33];acti[4][33] <= acti[4][34];acti[4][34] <= acti[4][35];acti[4][35] <= acti[4][36];acti[4][36] <= acti[4][37];acti[4][37] <= acti[4][38];acti[4][38] <= acti[4][39];acti[4][39] <= acti[4][40];acti[4][40] <= acti[4][41];acti[4][41] <= acti[4][42];acti[4][42] <= acti[4][43];acti[4][43] <= acti[4][44];acti[4][44] <= acti[4][45];acti[4][45] <= acti[4][46];acti[4][46] <= acti[4][47];acti[4][47] <= acti[4][48];acti[4][48] <= acti[4][49];acti[4][49] <= rom_data_ri;
      end
      6'd24: begin
        acti[0][0] <= acti[0][1];acti[0][1] <= acti[0][2];acti[0][2] <= acti[0][3];acti[0][3] <= acti[0][4];acti[0][4] <= acti[0][5];acti[0][5] <= acti[0][6];acti[0][6] <= acti[0][7];acti[0][7] <= acti[0][8];acti[0][8] <= acti[0][9];acti[0][9] <= acti[0][10];acti[0][10] <= acti[0][11];acti[0][11] <= acti[0][12];acti[0][12] <= acti[0][13];acti[0][13] <= acti[0][14];acti[0][14] <= acti[0][15];acti[0][15] <= acti[0][16];acti[0][16] <= acti[0][17];acti[0][17] <= acti[0][18];acti[0][18] <= acti[0][19];acti[0][19] <= acti[0][20];acti[0][20] <= acti[0][21];acti[0][21] <= acti[0][22];acti[0][22] <= acti[0][23];acti[0][23] <= acti[1][0];acti[1][0] <= acti[1][1];acti[1][1] <= acti[1][2];acti[1][2] <= acti[1][3];acti[1][3] <= acti[1][4];acti[1][4] <= acti[1][5];acti[1][5] <= acti[1][6];acti[1][6] <= acti[1][7];acti[1][7] <= acti[1][8];acti[1][8] <= acti[1][9];acti[1][9] <= acti[1][10];acti[1][10] <= acti[1][11];acti[1][11] <= acti[1][12];acti[1][12] <= acti[1][13];acti[1][13] <= acti[1][14];acti[1][14] <= acti[1][15];acti[1][15] <= acti[1][16];acti[1][16] <= acti[1][17];acti[1][17] <= acti[1][18];acti[1][18] <= acti[1][19];acti[1][19] <= acti[1][20];acti[1][20] <= acti[1][21];acti[1][21] <= acti[1][22];acti[1][22] <= acti[1][23];acti[1][23] <= acti[2][0];acti[2][0] <= acti[2][1];acti[2][1] <= acti[2][2];acti[2][2] <= acti[2][3];acti[2][3] <= acti[2][4];acti[2][4] <= acti[2][5];acti[2][5] <= acti[2][6];acti[2][6] <= acti[2][7];acti[2][7] <= acti[2][8];acti[2][8] <= acti[2][9];acti[2][9] <= acti[2][10];acti[2][10] <= acti[2][11];acti[2][11] <= acti[2][12];acti[2][12] <= acti[2][13];acti[2][13] <= acti[2][14];acti[2][14] <= acti[2][15];acti[2][15] <= acti[2][16];acti[2][16] <= acti[2][17];acti[2][17] <= acti[2][18];acti[2][18] <= acti[2][19];acti[2][19] <= acti[2][20];acti[2][20] <= acti[2][21];acti[2][21] <= acti[2][22];acti[2][22] <= acti[2][23];acti[2][23] <= acti[3][0];acti[3][0] <= acti[3][1];acti[3][1] <= acti[3][2];acti[3][2] <= acti[3][3];acti[3][3] <= acti[3][4];acti[3][4] <= acti[3][5];acti[3][5] <= acti[3][6];acti[3][6] <= acti[3][7];acti[3][7] <= acti[3][8];acti[3][8] <= acti[3][9];acti[3][9] <= acti[3][10];acti[3][10] <= acti[3][11];acti[3][11] <= acti[3][12];acti[3][12] <= acti[3][13];acti[3][13] <= acti[3][14];acti[3][14] <= acti[3][15];acti[3][15] <= acti[3][16];acti[3][16] <= acti[3][17];acti[3][17] <= acti[3][18];acti[3][18] <= acti[3][19];acti[3][19] <= acti[3][20];acti[3][20] <= acti[3][21];acti[3][21] <= acti[3][22];acti[3][22] <= acti[3][23];acti[3][23] <= acti[4][0];acti[4][0] <= acti[4][1];acti[4][1] <= acti[4][2];acti[4][2] <= acti[4][3];acti[4][3] <= acti[4][4];acti[4][4] <= acti[4][5];acti[4][5] <= acti[4][6];acti[4][6] <= acti[4][7];acti[4][7] <= acti[4][8];acti[4][8] <= acti[4][9];acti[4][9] <= acti[4][10];acti[4][10] <= acti[4][11];acti[4][11] <= acti[4][12];acti[4][12] <= acti[4][13];acti[4][13] <= acti[4][14];acti[4][14] <= acti[4][15];acti[4][15] <= acti[4][16];acti[4][16] <= acti[4][17];acti[4][17] <= acti[4][18];acti[4][18] <= acti[4][19];acti[4][19] <= acti[4][20];acti[4][20] <= acti[4][21];acti[4][21] <= acti[4][22];acti[4][22] <= acti[4][23];acti[4][23] <= rom_data_ri;
      end
      default: begin
        acti[0][0] <= acti[0][1];acti[0][1] <= acti[0][2];acti[0][2] <= acti[0][3];acti[0][3] <= acti[0][4];acti[0][4] <= acti[0][5];acti[0][5] <= acti[0][6];acti[0][6] <= acti[0][7];acti[0][7] <= acti[0][8];acti[0][8] <= acti[0][9];acti[0][9] <= acti[0][10];acti[0][10] <= acti[0][11];acti[0][11] <= acti[0][12];acti[0][12] <= acti[0][13];acti[0][13] <= acti[0][14];acti[0][14] <= acti[0][15];acti[0][15] <= acti[0][16];acti[0][16] <= acti[0][17];acti[0][17] <= acti[0][18];acti[0][18] <= acti[0][19];acti[0][19] <= acti[0][20];acti[0][20] <= acti[0][21];acti[0][21] <= acti[1][0];acti[1][0] <= acti[1][1];acti[1][1] <= acti[1][2];acti[1][2] <= acti[1][3];acti[1][3] <= acti[1][4];acti[1][4] <= acti[1][5];acti[1][5] <= acti[1][6];acti[1][6] <= acti[1][7];acti[1][7] <= acti[1][8];acti[1][8] <= acti[1][9];acti[1][9] <= acti[1][10];acti[1][10] <= acti[1][11];acti[1][11] <= acti[1][12];acti[1][12] <= acti[1][13];acti[1][13] <= acti[1][14];acti[1][14] <= acti[1][15];acti[1][15] <= acti[1][16];acti[1][16] <= acti[1][17];acti[1][17] <= acti[1][18];acti[1][18] <= acti[1][19];acti[1][19] <= acti[1][20];acti[1][20] <= acti[1][21];acti[1][21] <= acti[2][0];acti[2][0] <= acti[2][1];acti[2][1] <= acti[2][2];acti[2][2] <= acti[2][3];acti[2][3] <= acti[2][4];acti[2][4] <= acti[2][5];acti[2][5] <= acti[2][6];acti[2][6] <= acti[2][7];acti[2][7] <= acti[2][8];acti[2][8] <= acti[2][9];acti[2][9] <= acti[2][10];acti[2][10] <= acti[2][11];acti[2][11] <= acti[2][12];acti[2][12] <= acti[2][13];acti[2][13] <= acti[2][14];acti[2][14] <= acti[2][15];acti[2][15] <= acti[2][16];acti[2][16] <= acti[2][17];acti[2][17] <= acti[2][18];acti[2][18] <= acti[2][19];acti[2][19] <= acti[2][20];acti[2][20] <= acti[2][21];acti[2][21] <= acti[3][0];acti[3][0] <= acti[3][1];acti[3][1] <= acti[3][2];acti[3][2] <= acti[3][3];acti[3][3] <= acti[3][4];acti[3][4] <= acti[3][5];acti[3][5] <= acti[3][6];acti[3][6] <= acti[3][7];acti[3][7] <= acti[3][8];acti[3][8] <= acti[3][9];acti[3][9] <= acti[3][10];acti[3][10] <= acti[3][11];acti[3][11] <= acti[3][12];acti[3][12] <= acti[3][13];acti[3][13] <= acti[3][14];acti[3][14] <= acti[3][15];acti[3][15] <= acti[3][16];acti[3][16] <= acti[3][17];acti[3][17] <= acti[3][18];acti[3][18] <= acti[3][19];acti[3][19] <= acti[3][20];acti[3][20] <= acti[3][21];acti[3][21] <= acti[4][0];acti[4][0] <= acti[4][1];acti[4][1] <= acti[4][2];acti[4][2] <= acti[4][3];acti[4][3] <= acti[4][4];acti[4][4] <= acti[4][5];acti[4][5] <= acti[4][6];acti[4][6] <= acti[4][7];acti[4][7] <= acti[4][8];acti[4][8] <= acti[4][9];acti[4][9] <= acti[4][10];acti[4][10] <= acti[4][11];acti[4][11] <= acti[4][12];acti[4][12] <= acti[4][13];acti[4][13] <= acti[4][14];acti[4][14] <= acti[4][15];acti[4][15] <= acti[4][16];acti[4][16] <= acti[4][17];acti[4][17] <= acti[4][18];acti[4][18] <= acti[4][19];acti[4][19] <= acti[4][20];acti[4][20] <= acti[4][21];acti[4][21] <= rom_data_ri;
      end
      endcase

      x_w <= x_w_inc;
      y_w <= y_w_inc;
      m_w2 <= m_w2_inc;
      
      if(cnt_LOAD<'d20) begin
        for(i=0;i<2;i=i+1) begin
          for(j=0;j<3;j=j+1) begin
            for(k=0;k<3;k=k+1) begin
              if(k==2) begin
                if(j==2) begin
                  if(i==1)
                    filter[i][j][k] <= rom_data_rw;
                  else
                    filter[i][j][k] <= filter[i+1][0][0];
                end
                else
                  filter[i][j][k] <= filter[i][j+1][0];
              end
              else
                filter[i][j][k] <= filter[i][j][k+1];
            end
          end
        end
      end

      x_ow <= x_ow_inc;
      m_ow2 <= m_ow2_inc;
      
      if(cnt_LOAD<'d8) begin
        for(i=0;i<2;i=i+1) begin
          for(j=0;j<3;j=j+1) begin
            if(j==2) begin
              if(i==1)
                ow[i][j] <= rom_data_row;
              else
                ow[i][j] <= ow[i+1][0];
            end
            else
              ow[i][j] <= ow[i][j+1];
          end
        end
      end
    end
    ROW_RUN: begin
      for(i=0;i<5;i=i+1) begin
        for(j=0;j<50;j=j+1) begin
          if(j==49)
            acti[i][j] <= acti[i][0];
          else
            acti[i][j] <= acti[i][j+1];
        end
      end
      
      for(i=0;i<2;i=i+1) begin
        for(j=0;j<3;j=j+1) begin
          for(k=0;k<3;k=k+1) begin
            filter[i][j][k] <= filter[i][j][k];
          end
        end
      end

      // for(i2=0;i2<2;i2=i2+1) begin
      //   for(i3=0;i3<3;i3=i3+1) begin
      //     for(i4=0;i4<=outfmap_w_dec;i4=i4+1) begin
      //       if(i4==outfmap_w_dec)
      //         outbuf[i2][i3][i4] <= outbuf[i2][i3][0] + psum[i2][i3];
      //       else
      //         outbuf[i2][i3][i4] <= outbuf[i2][i3][i4+1];
      //     end
      //   end
      // end

      case(outfmap_w)
      6'd48: begin
        outbuf[0][0][0] <= outbuf[0][0][1];outbuf[0][0][1] <= outbuf[0][0][2];outbuf[0][0][2] <= outbuf[0][0][3];outbuf[0][0][3] <= outbuf[0][0][4];outbuf[0][0][4] <= outbuf[0][0][5];outbuf[0][0][5] <= outbuf[0][0][6];outbuf[0][0][6] <= outbuf[0][0][7];outbuf[0][0][7] <= outbuf[0][0][8];outbuf[0][0][8] <= outbuf[0][0][9];outbuf[0][0][9] <= outbuf[0][0][10];outbuf[0][0][10] <= outbuf[0][0][11];outbuf[0][0][11] <= outbuf[0][0][12];outbuf[0][0][12] <= outbuf[0][0][13];outbuf[0][0][13] <= outbuf[0][0][14];outbuf[0][0][14] <= outbuf[0][0][15];outbuf[0][0][15] <= outbuf[0][0][16];outbuf[0][0][16] <= outbuf[0][0][17];outbuf[0][0][17] <= outbuf[0][0][18];outbuf[0][0][18] <= outbuf[0][0][19];outbuf[0][0][19] <= outbuf[0][0][20];outbuf[0][0][20] <= outbuf[0][0][21];outbuf[0][0][21] <= outbuf[0][0][22];outbuf[0][0][22] <= outbuf[0][0][23];outbuf[0][0][23] <= outbuf[0][0][24];outbuf[0][0][24] <= outbuf[0][0][25];outbuf[0][0][25] <= outbuf[0][0][26];outbuf[0][0][26] <= outbuf[0][0][27];outbuf[0][0][27] <= outbuf[0][0][28];outbuf[0][0][28] <= outbuf[0][0][29];outbuf[0][0][29] <= outbuf[0][0][30];outbuf[0][0][30] <= outbuf[0][0][31];outbuf[0][0][31] <= outbuf[0][0][32];outbuf[0][0][32] <= outbuf[0][0][33];outbuf[0][0][33] <= outbuf[0][0][34];outbuf[0][0][34] <= outbuf[0][0][35];outbuf[0][0][35] <= outbuf[0][0][36];outbuf[0][0][36] <= outbuf[0][0][37];outbuf[0][0][37] <= outbuf[0][0][38];outbuf[0][0][38] <= outbuf[0][0][39];outbuf[0][0][39] <= outbuf[0][0][40];outbuf[0][0][40] <= outbuf[0][0][41];outbuf[0][0][41] <= outbuf[0][0][42];outbuf[0][0][42] <= outbuf[0][0][43];outbuf[0][0][43] <= outbuf[0][0][44];outbuf[0][0][44] <= outbuf[0][0][45];outbuf[0][0][45] <= outbuf[0][0][46];outbuf[0][0][46] <= outbuf[0][0][47];outbuf[0][0][47] <= outbuf[0][0][0] + psum[0][0];outbuf[0][1][0] <= outbuf[0][1][1];outbuf[0][1][1] <= outbuf[0][1][2];outbuf[0][1][2] <= outbuf[0][1][3];outbuf[0][1][3] <= outbuf[0][1][4];outbuf[0][1][4] <= outbuf[0][1][5];outbuf[0][1][5] <= outbuf[0][1][6];outbuf[0][1][6] <= outbuf[0][1][7];outbuf[0][1][7] <= outbuf[0][1][8];outbuf[0][1][8] <= outbuf[0][1][9];outbuf[0][1][9] <= outbuf[0][1][10];outbuf[0][1][10] <= outbuf[0][1][11];outbuf[0][1][11] <= outbuf[0][1][12];outbuf[0][1][12] <= outbuf[0][1][13];outbuf[0][1][13] <= outbuf[0][1][14];outbuf[0][1][14] <= outbuf[0][1][15];outbuf[0][1][15] <= outbuf[0][1][16];outbuf[0][1][16] <= outbuf[0][1][17];outbuf[0][1][17] <= outbuf[0][1][18];outbuf[0][1][18] <= outbuf[0][1][19];outbuf[0][1][19] <= outbuf[0][1][20];outbuf[0][1][20] <= outbuf[0][1][21];outbuf[0][1][21] <= outbuf[0][1][22];outbuf[0][1][22] <= outbuf[0][1][23];outbuf[0][1][23] <= outbuf[0][1][24];outbuf[0][1][24] <= outbuf[0][1][25];outbuf[0][1][25] <= outbuf[0][1][26];outbuf[0][1][26] <= outbuf[0][1][27];outbuf[0][1][27] <= outbuf[0][1][28];outbuf[0][1][28] <= outbuf[0][1][29];outbuf[0][1][29] <= outbuf[0][1][30];outbuf[0][1][30] <= outbuf[0][1][31];outbuf[0][1][31] <= outbuf[0][1][32];outbuf[0][1][32] <= outbuf[0][1][33];outbuf[0][1][33] <= outbuf[0][1][34];outbuf[0][1][34] <= outbuf[0][1][35];outbuf[0][1][35] <= outbuf[0][1][36];outbuf[0][1][36] <= outbuf[0][1][37];outbuf[0][1][37] <= outbuf[0][1][38];outbuf[0][1][38] <= outbuf[0][1][39];outbuf[0][1][39] <= outbuf[0][1][40];outbuf[0][1][40] <= outbuf[0][1][41];outbuf[0][1][41] <= outbuf[0][1][42];outbuf[0][1][42] <= outbuf[0][1][43];outbuf[0][1][43] <= outbuf[0][1][44];outbuf[0][1][44] <= outbuf[0][1][45];outbuf[0][1][45] <= outbuf[0][1][46];outbuf[0][1][46] <= outbuf[0][1][47];outbuf[0][1][47] <= outbuf[0][1][0] + psum[0][1];outbuf[0][2][0] <= outbuf[0][2][1];outbuf[0][2][1] <= outbuf[0][2][2];outbuf[0][2][2] <= outbuf[0][2][3];outbuf[0][2][3] <= outbuf[0][2][4];outbuf[0][2][4] <= outbuf[0][2][5];outbuf[0][2][5] <= outbuf[0][2][6];outbuf[0][2][6] <= outbuf[0][2][7];outbuf[0][2][7] <= outbuf[0][2][8];outbuf[0][2][8] <= outbuf[0][2][9];outbuf[0][2][9] <= outbuf[0][2][10];outbuf[0][2][10] <= outbuf[0][2][11];outbuf[0][2][11] <= outbuf[0][2][12];outbuf[0][2][12] <= outbuf[0][2][13];outbuf[0][2][13] <= outbuf[0][2][14];outbuf[0][2][14] <= outbuf[0][2][15];outbuf[0][2][15] <= outbuf[0][2][16];outbuf[0][2][16] <= outbuf[0][2][17];outbuf[0][2][17] <= outbuf[0][2][18];outbuf[0][2][18] <= outbuf[0][2][19];outbuf[0][2][19] <= outbuf[0][2][20];outbuf[0][2][20] <= outbuf[0][2][21];outbuf[0][2][21] <= outbuf[0][2][22];outbuf[0][2][22] <= outbuf[0][2][23];outbuf[0][2][23] <= outbuf[0][2][24];outbuf[0][2][24] <= outbuf[0][2][25];outbuf[0][2][25] <= outbuf[0][2][26];outbuf[0][2][26] <= outbuf[0][2][27];outbuf[0][2][27] <= outbuf[0][2][28];outbuf[0][2][28] <= outbuf[0][2][29];outbuf[0][2][29] <= outbuf[0][2][30];outbuf[0][2][30] <= outbuf[0][2][31];outbuf[0][2][31] <= outbuf[0][2][32];outbuf[0][2][32] <= outbuf[0][2][33];outbuf[0][2][33] <= outbuf[0][2][34];outbuf[0][2][34] <= outbuf[0][2][35];outbuf[0][2][35] <= outbuf[0][2][36];outbuf[0][2][36] <= outbuf[0][2][37];outbuf[0][2][37] <= outbuf[0][2][38];outbuf[0][2][38] <= outbuf[0][2][39];outbuf[0][2][39] <= outbuf[0][2][40];outbuf[0][2][40] <= outbuf[0][2][41];outbuf[0][2][41] <= outbuf[0][2][42];outbuf[0][2][42] <= outbuf[0][2][43];outbuf[0][2][43] <= outbuf[0][2][44];outbuf[0][2][44] <= outbuf[0][2][45];outbuf[0][2][45] <= outbuf[0][2][46];outbuf[0][2][46] <= outbuf[0][2][47];outbuf[0][2][47] <= outbuf[0][2][0] + psum[0][2];outbuf[1][0][0] <= outbuf[1][0][1];outbuf[1][0][1] <= outbuf[1][0][2];outbuf[1][0][2] <= outbuf[1][0][3];outbuf[1][0][3] <= outbuf[1][0][4];outbuf[1][0][4] <= outbuf[1][0][5];outbuf[1][0][5] <= outbuf[1][0][6];outbuf[1][0][6] <= outbuf[1][0][7];outbuf[1][0][7] <= outbuf[1][0][8];outbuf[1][0][8] <= outbuf[1][0][9];outbuf[1][0][9] <= outbuf[1][0][10];outbuf[1][0][10] <= outbuf[1][0][11];outbuf[1][0][11] <= outbuf[1][0][12];outbuf[1][0][12] <= outbuf[1][0][13];outbuf[1][0][13] <= outbuf[1][0][14];outbuf[1][0][14] <= outbuf[1][0][15];outbuf[1][0][15] <= outbuf[1][0][16];outbuf[1][0][16] <= outbuf[1][0][17];outbuf[1][0][17] <= outbuf[1][0][18];outbuf[1][0][18] <= outbuf[1][0][19];outbuf[1][0][19] <= outbuf[1][0][20];outbuf[1][0][20] <= outbuf[1][0][21];outbuf[1][0][21] <= outbuf[1][0][22];outbuf[1][0][22] <= outbuf[1][0][23];outbuf[1][0][23] <= outbuf[1][0][24];outbuf[1][0][24] <= outbuf[1][0][25];outbuf[1][0][25] <= outbuf[1][0][26];outbuf[1][0][26] <= outbuf[1][0][27];outbuf[1][0][27] <= outbuf[1][0][28];outbuf[1][0][28] <= outbuf[1][0][29];outbuf[1][0][29] <= outbuf[1][0][30];outbuf[1][0][30] <= outbuf[1][0][31];outbuf[1][0][31] <= outbuf[1][0][32];outbuf[1][0][32] <= outbuf[1][0][33];outbuf[1][0][33] <= outbuf[1][0][34];outbuf[1][0][34] <= outbuf[1][0][35];outbuf[1][0][35] <= outbuf[1][0][36];outbuf[1][0][36] <= outbuf[1][0][37];outbuf[1][0][37] <= outbuf[1][0][38];outbuf[1][0][38] <= outbuf[1][0][39];outbuf[1][0][39] <= outbuf[1][0][40];outbuf[1][0][40] <= outbuf[1][0][41];outbuf[1][0][41] <= outbuf[1][0][42];outbuf[1][0][42] <= outbuf[1][0][43];outbuf[1][0][43] <= outbuf[1][0][44];outbuf[1][0][44] <= outbuf[1][0][45];outbuf[1][0][45] <= outbuf[1][0][46];outbuf[1][0][46] <= outbuf[1][0][47];outbuf[1][0][47] <= outbuf[1][0][0] + psum[1][0];outbuf[1][1][0] <= outbuf[1][1][1];outbuf[1][1][1] <= outbuf[1][1][2];outbuf[1][1][2] <= outbuf[1][1][3];outbuf[1][1][3] <= outbuf[1][1][4];outbuf[1][1][4] <= outbuf[1][1][5];outbuf[1][1][5] <= outbuf[1][1][6];outbuf[1][1][6] <= outbuf[1][1][7];outbuf[1][1][7] <= outbuf[1][1][8];outbuf[1][1][8] <= outbuf[1][1][9];outbuf[1][1][9] <= outbuf[1][1][10];outbuf[1][1][10] <= outbuf[1][1][11];outbuf[1][1][11] <= outbuf[1][1][12];outbuf[1][1][12] <= outbuf[1][1][13];outbuf[1][1][13] <= outbuf[1][1][14];outbuf[1][1][14] <= outbuf[1][1][15];outbuf[1][1][15] <= outbuf[1][1][16];outbuf[1][1][16] <= outbuf[1][1][17];outbuf[1][1][17] <= outbuf[1][1][18];outbuf[1][1][18] <= outbuf[1][1][19];outbuf[1][1][19] <= outbuf[1][1][20];outbuf[1][1][20] <= outbuf[1][1][21];outbuf[1][1][21] <= outbuf[1][1][22];outbuf[1][1][22] <= outbuf[1][1][23];outbuf[1][1][23] <= outbuf[1][1][24];outbuf[1][1][24] <= outbuf[1][1][25];outbuf[1][1][25] <= outbuf[1][1][26];outbuf[1][1][26] <= outbuf[1][1][27];outbuf[1][1][27] <= outbuf[1][1][28];outbuf[1][1][28] <= outbuf[1][1][29];outbuf[1][1][29] <= outbuf[1][1][30];outbuf[1][1][30] <= outbuf[1][1][31];outbuf[1][1][31] <= outbuf[1][1][32];outbuf[1][1][32] <= outbuf[1][1][33];outbuf[1][1][33] <= outbuf[1][1][34];outbuf[1][1][34] <= outbuf[1][1][35];outbuf[1][1][35] <= outbuf[1][1][36];outbuf[1][1][36] <= outbuf[1][1][37];outbuf[1][1][37] <= outbuf[1][1][38];outbuf[1][1][38] <= outbuf[1][1][39];outbuf[1][1][39] <= outbuf[1][1][40];outbuf[1][1][40] <= outbuf[1][1][41];outbuf[1][1][41] <= outbuf[1][1][42];outbuf[1][1][42] <= outbuf[1][1][43];outbuf[1][1][43] <= outbuf[1][1][44];outbuf[1][1][44] <= outbuf[1][1][45];outbuf[1][1][45] <= outbuf[1][1][46];outbuf[1][1][46] <= outbuf[1][1][47];outbuf[1][1][47] <= outbuf[1][1][0] + psum[1][1];outbuf[1][2][0] <= outbuf[1][2][1];outbuf[1][2][1] <= outbuf[1][2][2];outbuf[1][2][2] <= outbuf[1][2][3];outbuf[1][2][3] <= outbuf[1][2][4];outbuf[1][2][4] <= outbuf[1][2][5];outbuf[1][2][5] <= outbuf[1][2][6];outbuf[1][2][6] <= outbuf[1][2][7];outbuf[1][2][7] <= outbuf[1][2][8];outbuf[1][2][8] <= outbuf[1][2][9];outbuf[1][2][9] <= outbuf[1][2][10];outbuf[1][2][10] <= outbuf[1][2][11];outbuf[1][2][11] <= outbuf[1][2][12];outbuf[1][2][12] <= outbuf[1][2][13];outbuf[1][2][13] <= outbuf[1][2][14];outbuf[1][2][14] <= outbuf[1][2][15];outbuf[1][2][15] <= outbuf[1][2][16];outbuf[1][2][16] <= outbuf[1][2][17];outbuf[1][2][17] <= outbuf[1][2][18];outbuf[1][2][18] <= outbuf[1][2][19];outbuf[1][2][19] <= outbuf[1][2][20];outbuf[1][2][20] <= outbuf[1][2][21];outbuf[1][2][21] <= outbuf[1][2][22];outbuf[1][2][22] <= outbuf[1][2][23];outbuf[1][2][23] <= outbuf[1][2][24];outbuf[1][2][24] <= outbuf[1][2][25];outbuf[1][2][25] <= outbuf[1][2][26];outbuf[1][2][26] <= outbuf[1][2][27];outbuf[1][2][27] <= outbuf[1][2][28];outbuf[1][2][28] <= outbuf[1][2][29];outbuf[1][2][29] <= outbuf[1][2][30];outbuf[1][2][30] <= outbuf[1][2][31];outbuf[1][2][31] <= outbuf[1][2][32];outbuf[1][2][32] <= outbuf[1][2][33];outbuf[1][2][33] <= outbuf[1][2][34];outbuf[1][2][34] <= outbuf[1][2][35];outbuf[1][2][35] <= outbuf[1][2][36];outbuf[1][2][36] <= outbuf[1][2][37];outbuf[1][2][37] <= outbuf[1][2][38];outbuf[1][2][38] <= outbuf[1][2][39];outbuf[1][2][39] <= outbuf[1][2][40];outbuf[1][2][40] <= outbuf[1][2][41];outbuf[1][2][41] <= outbuf[1][2][42];outbuf[1][2][42] <= outbuf[1][2][43];outbuf[1][2][43] <= outbuf[1][2][44];outbuf[1][2][44] <= outbuf[1][2][45];outbuf[1][2][45] <= outbuf[1][2][46];outbuf[1][2][46] <= outbuf[1][2][47];outbuf[1][2][47] <= outbuf[1][2][0] + psum[1][2];
      end
      6'd22: begin
        outbuf[0][0][0] <= outbuf[0][0][1];outbuf[0][0][1] <= outbuf[0][0][2];outbuf[0][0][2] <= outbuf[0][0][3];outbuf[0][0][3] <= outbuf[0][0][4];outbuf[0][0][4] <= outbuf[0][0][5];outbuf[0][0][5] <= outbuf[0][0][6];outbuf[0][0][6] <= outbuf[0][0][7];outbuf[0][0][7] <= outbuf[0][0][8];outbuf[0][0][8] <= outbuf[0][0][9];outbuf[0][0][9] <= outbuf[0][0][10];outbuf[0][0][10] <= outbuf[0][0][11];outbuf[0][0][11] <= outbuf[0][0][12];outbuf[0][0][12] <= outbuf[0][0][13];outbuf[0][0][13] <= outbuf[0][0][14];outbuf[0][0][14] <= outbuf[0][0][15];outbuf[0][0][15] <= outbuf[0][0][16];outbuf[0][0][16] <= outbuf[0][0][17];outbuf[0][0][17] <= outbuf[0][0][18];outbuf[0][0][18] <= outbuf[0][0][19];outbuf[0][0][19] <= outbuf[0][0][20];outbuf[0][0][20] <= outbuf[0][0][21];outbuf[0][0][21] <= outbuf[0][0][0] + psum[0][0];outbuf[0][1][0] <= outbuf[0][1][1];outbuf[0][1][1] <= outbuf[0][1][2];outbuf[0][1][2] <= outbuf[0][1][3];outbuf[0][1][3] <= outbuf[0][1][4];outbuf[0][1][4] <= outbuf[0][1][5];outbuf[0][1][5] <= outbuf[0][1][6];outbuf[0][1][6] <= outbuf[0][1][7];outbuf[0][1][7] <= outbuf[0][1][8];outbuf[0][1][8] <= outbuf[0][1][9];outbuf[0][1][9] <= outbuf[0][1][10];outbuf[0][1][10] <= outbuf[0][1][11];outbuf[0][1][11] <= outbuf[0][1][12];outbuf[0][1][12] <= outbuf[0][1][13];outbuf[0][1][13] <= outbuf[0][1][14];outbuf[0][1][14] <= outbuf[0][1][15];outbuf[0][1][15] <= outbuf[0][1][16];outbuf[0][1][16] <= outbuf[0][1][17];outbuf[0][1][17] <= outbuf[0][1][18];outbuf[0][1][18] <= outbuf[0][1][19];outbuf[0][1][19] <= outbuf[0][1][20];outbuf[0][1][20] <= outbuf[0][1][21];outbuf[0][1][21] <= outbuf[0][1][0] + psum[0][1];outbuf[0][2][0] <= outbuf[0][2][1];outbuf[0][2][1] <= outbuf[0][2][2];outbuf[0][2][2] <= outbuf[0][2][3];outbuf[0][2][3] <= outbuf[0][2][4];outbuf[0][2][4] <= outbuf[0][2][5];outbuf[0][2][5] <= outbuf[0][2][6];outbuf[0][2][6] <= outbuf[0][2][7];outbuf[0][2][7] <= outbuf[0][2][8];outbuf[0][2][8] <= outbuf[0][2][9];outbuf[0][2][9] <= outbuf[0][2][10];outbuf[0][2][10] <= outbuf[0][2][11];outbuf[0][2][11] <= outbuf[0][2][12];outbuf[0][2][12] <= outbuf[0][2][13];outbuf[0][2][13] <= outbuf[0][2][14];outbuf[0][2][14] <= outbuf[0][2][15];outbuf[0][2][15] <= outbuf[0][2][16];outbuf[0][2][16] <= outbuf[0][2][17];outbuf[0][2][17] <= outbuf[0][2][18];outbuf[0][2][18] <= outbuf[0][2][19];outbuf[0][2][19] <= outbuf[0][2][20];outbuf[0][2][20] <= outbuf[0][2][21];outbuf[0][2][21] <= outbuf[0][2][0] + psum[0][2];outbuf[1][0][0] <= outbuf[1][0][1];outbuf[1][0][1] <= outbuf[1][0][2];outbuf[1][0][2] <= outbuf[1][0][3];outbuf[1][0][3] <= outbuf[1][0][4];outbuf[1][0][4] <= outbuf[1][0][5];outbuf[1][0][5] <= outbuf[1][0][6];outbuf[1][0][6] <= outbuf[1][0][7];outbuf[1][0][7] <= outbuf[1][0][8];outbuf[1][0][8] <= outbuf[1][0][9];outbuf[1][0][9] <= outbuf[1][0][10];outbuf[1][0][10] <= outbuf[1][0][11];outbuf[1][0][11] <= outbuf[1][0][12];outbuf[1][0][12] <= outbuf[1][0][13];outbuf[1][0][13] <= outbuf[1][0][14];outbuf[1][0][14] <= outbuf[1][0][15];outbuf[1][0][15] <= outbuf[1][0][16];outbuf[1][0][16] <= outbuf[1][0][17];outbuf[1][0][17] <= outbuf[1][0][18];outbuf[1][0][18] <= outbuf[1][0][19];outbuf[1][0][19] <= outbuf[1][0][20];outbuf[1][0][20] <= outbuf[1][0][21];outbuf[1][0][21] <= outbuf[1][0][0] + psum[1][0];outbuf[1][1][0] <= outbuf[1][1][1];outbuf[1][1][1] <= outbuf[1][1][2];outbuf[1][1][2] <= outbuf[1][1][3];outbuf[1][1][3] <= outbuf[1][1][4];outbuf[1][1][4] <= outbuf[1][1][5];outbuf[1][1][5] <= outbuf[1][1][6];outbuf[1][1][6] <= outbuf[1][1][7];outbuf[1][1][7] <= outbuf[1][1][8];outbuf[1][1][8] <= outbuf[1][1][9];outbuf[1][1][9] <= outbuf[1][1][10];outbuf[1][1][10] <= outbuf[1][1][11];outbuf[1][1][11] <= outbuf[1][1][12];outbuf[1][1][12] <= outbuf[1][1][13];outbuf[1][1][13] <= outbuf[1][1][14];outbuf[1][1][14] <= outbuf[1][1][15];outbuf[1][1][15] <= outbuf[1][1][16];outbuf[1][1][16] <= outbuf[1][1][17];outbuf[1][1][17] <= outbuf[1][1][18];outbuf[1][1][18] <= outbuf[1][1][19];outbuf[1][1][19] <= outbuf[1][1][20];outbuf[1][1][20] <= outbuf[1][1][21];outbuf[1][1][21] <= outbuf[1][1][0] + psum[1][1];outbuf[1][2][0] <= outbuf[1][2][1];outbuf[1][2][1] <= outbuf[1][2][2];outbuf[1][2][2] <= outbuf[1][2][3];outbuf[1][2][3] <= outbuf[1][2][4];outbuf[1][2][4] <= outbuf[1][2][5];outbuf[1][2][5] <= outbuf[1][2][6];outbuf[1][2][6] <= outbuf[1][2][7];outbuf[1][2][7] <= outbuf[1][2][8];outbuf[1][2][8] <= outbuf[1][2][9];outbuf[1][2][9] <= outbuf[1][2][10];outbuf[1][2][10] <= outbuf[1][2][11];outbuf[1][2][11] <= outbuf[1][2][12];outbuf[1][2][12] <= outbuf[1][2][13];outbuf[1][2][13] <= outbuf[1][2][14];outbuf[1][2][14] <= outbuf[1][2][15];outbuf[1][2][15] <= outbuf[1][2][16];outbuf[1][2][16] <= outbuf[1][2][17];outbuf[1][2][17] <= outbuf[1][2][18];outbuf[1][2][18] <= outbuf[1][2][19];outbuf[1][2][19] <= outbuf[1][2][20];outbuf[1][2][20] <= outbuf[1][2][21];outbuf[1][2][21] <= outbuf[1][2][0] + psum[1][2];
      end
      default: begin
        outbuf[0][0][0] <= outbuf[0][0][1];outbuf[0][0][1] <= outbuf[0][0][2];outbuf[0][0][2] <= outbuf[0][0][3];outbuf[0][0][3] <= outbuf[0][0][4];outbuf[0][0][4] <= outbuf[0][0][5];outbuf[0][0][5] <= outbuf[0][0][6];outbuf[0][0][6] <= outbuf[0][0][7];outbuf[0][0][7] <= outbuf[0][0][8];outbuf[0][0][8] <= outbuf[0][0][9];outbuf[0][0][9] <= outbuf[0][0][10];outbuf[0][0][10] <= outbuf[0][0][11];outbuf[0][0][11] <= outbuf[0][0][12];outbuf[0][0][12] <= outbuf[0][0][13];outbuf[0][0][13] <= outbuf[0][0][14];outbuf[0][0][14] <= outbuf[0][0][15];outbuf[0][0][15] <= outbuf[0][0][16];outbuf[0][0][16] <= outbuf[0][0][17];outbuf[0][0][17] <= outbuf[0][0][18];outbuf[0][0][18] <= outbuf[0][0][19];outbuf[0][0][19] <= outbuf[0][0][0] + psum[0][0];outbuf[0][1][0] <= outbuf[0][1][1];outbuf[0][1][1] <= outbuf[0][1][2];outbuf[0][1][2] <= outbuf[0][1][3];outbuf[0][1][3] <= outbuf[0][1][4];outbuf[0][1][4] <= outbuf[0][1][5];outbuf[0][1][5] <= outbuf[0][1][6];outbuf[0][1][6] <= outbuf[0][1][7];outbuf[0][1][7] <= outbuf[0][1][8];outbuf[0][1][8] <= outbuf[0][1][9];outbuf[0][1][9] <= outbuf[0][1][10];outbuf[0][1][10] <= outbuf[0][1][11];outbuf[0][1][11] <= outbuf[0][1][12];outbuf[0][1][12] <= outbuf[0][1][13];outbuf[0][1][13] <= outbuf[0][1][14];outbuf[0][1][14] <= outbuf[0][1][15];outbuf[0][1][15] <= outbuf[0][1][16];outbuf[0][1][16] <= outbuf[0][1][17];outbuf[0][1][17] <= outbuf[0][1][18];outbuf[0][1][18] <= outbuf[0][1][19];outbuf[0][1][19] <= outbuf[0][1][0] + psum[0][1];outbuf[0][2][0] <= outbuf[0][2][1];outbuf[0][2][1] <= outbuf[0][2][2];outbuf[0][2][2] <= outbuf[0][2][3];outbuf[0][2][3] <= outbuf[0][2][4];outbuf[0][2][4] <= outbuf[0][2][5];outbuf[0][2][5] <= outbuf[0][2][6];outbuf[0][2][6] <= outbuf[0][2][7];outbuf[0][2][7] <= outbuf[0][2][8];outbuf[0][2][8] <= outbuf[0][2][9];outbuf[0][2][9] <= outbuf[0][2][10];outbuf[0][2][10] <= outbuf[0][2][11];outbuf[0][2][11] <= outbuf[0][2][12];outbuf[0][2][12] <= outbuf[0][2][13];outbuf[0][2][13] <= outbuf[0][2][14];outbuf[0][2][14] <= outbuf[0][2][15];outbuf[0][2][15] <= outbuf[0][2][16];outbuf[0][2][16] <= outbuf[0][2][17];outbuf[0][2][17] <= outbuf[0][2][18];outbuf[0][2][18] <= outbuf[0][2][19];outbuf[0][2][19] <= outbuf[0][2][0] + psum[0][2];outbuf[1][0][0] <= outbuf[1][0][1];outbuf[1][0][1] <= outbuf[1][0][2];outbuf[1][0][2] <= outbuf[1][0][3];outbuf[1][0][3] <= outbuf[1][0][4];outbuf[1][0][4] <= outbuf[1][0][5];outbuf[1][0][5] <= outbuf[1][0][6];outbuf[1][0][6] <= outbuf[1][0][7];outbuf[1][0][7] <= outbuf[1][0][8];outbuf[1][0][8] <= outbuf[1][0][9];outbuf[1][0][9] <= outbuf[1][0][10];outbuf[1][0][10] <= outbuf[1][0][11];outbuf[1][0][11] <= outbuf[1][0][12];outbuf[1][0][12] <= outbuf[1][0][13];outbuf[1][0][13] <= outbuf[1][0][14];outbuf[1][0][14] <= outbuf[1][0][15];outbuf[1][0][15] <= outbuf[1][0][16];outbuf[1][0][16] <= outbuf[1][0][17];outbuf[1][0][17] <= outbuf[1][0][18];outbuf[1][0][18] <= outbuf[1][0][19];outbuf[1][0][19] <= outbuf[1][0][0] + psum[1][0];outbuf[1][1][0] <= outbuf[1][1][1];outbuf[1][1][1] <= outbuf[1][1][2];outbuf[1][1][2] <= outbuf[1][1][3];outbuf[1][1][3] <= outbuf[1][1][4];outbuf[1][1][4] <= outbuf[1][1][5];outbuf[1][1][5] <= outbuf[1][1][6];outbuf[1][1][6] <= outbuf[1][1][7];outbuf[1][1][7] <= outbuf[1][1][8];outbuf[1][1][8] <= outbuf[1][1][9];outbuf[1][1][9] <= outbuf[1][1][10];outbuf[1][1][10] <= outbuf[1][1][11];outbuf[1][1][11] <= outbuf[1][1][12];outbuf[1][1][12] <= outbuf[1][1][13];outbuf[1][1][13] <= outbuf[1][1][14];outbuf[1][1][14] <= outbuf[1][1][15];outbuf[1][1][15] <= outbuf[1][1][16];outbuf[1][1][16] <= outbuf[1][1][17];outbuf[1][1][17] <= outbuf[1][1][18];outbuf[1][1][18] <= outbuf[1][1][19];outbuf[1][1][19] <= outbuf[1][1][0] + psum[1][1];outbuf[1][2][0] <= outbuf[1][2][1];outbuf[1][2][1] <= outbuf[1][2][2];outbuf[1][2][2] <= outbuf[1][2][3];outbuf[1][2][3] <= outbuf[1][2][4];outbuf[1][2][4] <= outbuf[1][2][5];outbuf[1][2][5] <= outbuf[1][2][6];outbuf[1][2][6] <= outbuf[1][2][7];outbuf[1][2][7] <= outbuf[1][2][8];outbuf[1][2][8] <= outbuf[1][2][9];outbuf[1][2][9] <= outbuf[1][2][10];outbuf[1][2][10] <= outbuf[1][2][11];outbuf[1][2][11] <= outbuf[1][2][12];outbuf[1][2][12] <= outbuf[1][2][13];outbuf[1][2][13] <= outbuf[1][2][14];outbuf[1][2][14] <= outbuf[1][2][15];outbuf[1][2][15] <= outbuf[1][2][16];outbuf[1][2][16] <= outbuf[1][2][17];outbuf[1][2][17] <= outbuf[1][2][18];outbuf[1][2][18] <= outbuf[1][2][19];outbuf[1][2][19] <= outbuf[1][2][0] + psum[1][2];
      end
      endcase
      x_acti <= {6{1'b1}};
      y_acti2 <= 'd0;
      x_w <= 'd2;
      y_w <= 'd2;
      m_w2 <= 'd1;
      x_ow <= 'd2;
      m_ow2 <= 'd1;
    end
    NEXT_C: begin
      c_acti <= c_acti + 1'd1;
    end
    WR_OUT: begin
      x_out <= x_out_inc;
      y_out2 <= y_out2_inc;
      m_out2 <= m_out2_inc;

      c_acti <= 'd0;
    end
    NEXT_M: begin
      m_out1 <= m_out1_inc;

      for(i=0;i<2;i=i+1) begin
        for(j=0;j<3;j=j+1) begin
          for(k=0;k<48;k=k+1) begin
            outbuf[i][j][k] <= 'd0;
          end
        end
      end
      
      x_out <= {6{1'b1}};
      y_out2 <= 'd0;
      m_out2 <= 'd0;
    end
    NEXT_H: begin
      y_out1 <= y_out1_inc;

      for(i=0;i<2;i=i+1) begin
        for(j=0;j<3;j=j+1) begin
          for(k=0;k<48;k=k+1) begin
            outbuf[i][j][k] <= 'd0;
          end
        end
      end

      m_out1 <= 'd0;
      x_out <= {6{1'b1}};
      y_out2 <= 'd0;
      m_out2 <= 'd0;
    end
      
    default: begin
      x_acti <= {6{1'b1}};
      y_acti2 <= 'd0;
      for(i=0;i<5;i=i+1) begin
        for(j=0;j<50;j=j+1) begin
          acti[i][j] <= 'd0;
        end
      end

      x_w <= 'd2;
      y_w <= 'd2;
      m_w2 <= 'd1;
      for(i=0;i<2;i=i+1) begin
        for(j=0;j<3;j=j+1) begin
          for(k=0;k<3;k=k+1) begin
            filter[i][j][k] <= 'd0;
          end
        end
      end

      x_ow <= 'd2;
      m_ow2 <= 'd1;
      for(i=0;i<2;i=i+1) begin
        for(j=0;j<3;j=j+1) begin
          ow[i][j] <= 'd0;
        end
      end

      for(i=0;i<2;i=i+1) begin
        for(j=0;j<3;j=j+1) begin
          for(k=0;k<48;k=k+1) begin
              outbuf[i][j][k] <= 'd0;
          end
        end
      end
      c_acti <= 'd0;

      x_out <= {6{1'b1}};
      y_out2 <= 'd0;
      m_out2 <= 'd0;

      m_out1 <= 'd0;
      y_out1 <= 'd0;
    end
    endcase  
  end
end

always@(*) begin
  for(i=0;i<2;i=i+1)
    for(j=0;j<3;j=j+1)
      for(k=0;k<3;k=k+1)
        PE[i][j][k] = acti[j+k][0] * filter[i][j][0] + acti[j+k][1] * filter[i][j][1] + acti[j+k][2] * filter[i][j][2];
end

always@(*) begin
  for(i=0;i<2;i=i+1)
    for(j=0;j<3;j=j+1)
      psum[i][j] = PE[i][0][j] + PE[i][1][j] + PE[i][2][j];
end

always@(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    cnt_LOAD <= {8{1'b1}};
  end
  else begin
    if(ns==LOAD)
      cnt_LOAD <= cnt_LOAD + 1'd1;
    else
      cnt_LOAD <= {8{1'b1}};
  end
end

always@(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    cnt_ROW_RUN <= {6{1'b1}};
  end
  else begin
    if(ns==ROW_RUN)
      cnt_ROW_RUN <= cnt_ROW_RUN + 1'd1;
    else
      cnt_ROW_RUN <= {6{1'b1}};
  end
end

endmodule
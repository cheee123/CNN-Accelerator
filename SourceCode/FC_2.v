module FC_2(

input clk,
input rst_n,


input start_FC,
output end_FC,
//ROM read input image
output reg [11:0]rom_addr_ri,
input  [7:0]rom_data_ri,
output reg rom_en_ri, 
//ROM read weight
output reg [14:0]rom_addr_rw,
input  [7:0]rom_data_rw,
output reg rom_en_rw, 
//ROM read other_weight
output reg [8:0]rom_addr_row,
input  [31:0]rom_data_row,
output reg rom_en_row,

output reg [7:0]NN_out_male,
output reg [7:0]NN_out_female
);

reg signed [7:0] acti [0:15];
reg signed [7:0] weight [0:15];
reg signed [31:0] ow [0:35];
reg signed [31:0] outbuf [0:11];

reg [5:0] cnt;
reg [1:0] layer;
reg [14:0] bias_w;
reg [8:0] bias_ow;
reg [10:0] c_acti;
reg [6:0] c_acti1, c_acti1_inc;
reg [3:0] c_acti2, c_acti2_inc;

reg [14:0] m_out;
reg [3:0] m_out1, m_out1_inc;
reg [6:0] m_out2, m_out2_inc;
reg [3:0] m_out3, m_out3_inc;
reg signed [31:0] sum_aw;
wire signed [31:0] sum_ow [0:11];
wire signed [63:0] Msum [0:11];
wire signed [31:0] Msum_dec [0:11];
wire signed [31:0] bullshit = (layer==2'd2)? 32'd41 : -32'd128;
reg signed [31:0] amulw [15:0];


reg [3:0] ns, cs;
parameter IDLE=4'd0, RD_AW=4'd1, SUM=4'd2, NEXT_C=4'd3, NEXT_M=4'd4, RD_OW=4'd5, UPDATE=4'd6, NEXT_L=4'd7, RD_W=4'd8, DONE=4'd9, PRE_SUM=4'd10;
integer i;
assign end_FC = cs == DONE;
always@(*) begin
    case(cs)
    IDLE: ns = start_FC? RD_AW : IDLE;
    RD_AW: ns = (cnt=='d18)? PRE_SUM : RD_AW;
    PRE_SUM: ns = SUM;
    SUM: begin
        case(layer)
        2'd0: begin
            if(c_acti1==7'd99 && m_out1==4'd11)
                ns = RD_OW;
            else if(c_acti1==7'd99)
                ns = NEXT_M;
            else
                ns = NEXT_C;
        end
        2'd1: begin
            if(m_out2==4'd7)
                ns = RD_OW;
            else
                ns = NEXT_M;
        end
        default: begin
            if(m_out2==4'd1)
                ns = RD_OW;
            else
                ns = NEXT_M;
        end
        endcase
    end
    NEXT_C: ns = RD_AW;
    NEXT_M: ns = (layer==2'd0)? RD_AW : RD_W;
    RD_OW: begin
        case(layer)
        2'd0: ns = (cnt=='d38)? UPDATE : RD_OW;
        2'd1: ns = (cnt=='d26)? UPDATE : RD_OW;
        default: ns = (cnt=='d8)? UPDATE : RD_OW;
        endcase
    end
    UPDATE: ns = (layer==2'd2)? DONE : NEXT_L;
    NEXT_L: ns = RD_W;
    RD_W: begin
        case(layer)
        2'd1: ns = (cnt=='d14)? PRE_SUM : RD_W;
        default: ns = (cnt=='d10)? PRE_SUM : RD_W;
        endcase
    end
    default: ns = IDLE; //DONE
    endcase
end
always@(*) begin
    case(layer)
    2'd0: begin
        bias_w = 15'd2664;
        bias_ow = 9'd108;
        m_out = m_out1*11'd1600 + {m_out2,4'd0} + m_out3;
    end
    2'd1: begin
        bias_w = 15'd21864;
        bias_ow = 9'd144;
        m_out = m_out2*4'd12 + m_out3;
    end
    default: begin
        bias_w = 15'd21960;
        bias_ow = 9'd168;
        m_out = {m_out2,3'd0} + m_out3;
    end
    endcase
end
always@(*) begin
    c_acti1_inc = (c_acti1=='d99)? 'd0 : c_acti1 + 'd1;
    c_acti2_inc = c_acti2 + 'd1;
    
    case(layer)
    2'd0: begin
        m_out1_inc = (m_out1=='d11)? 'd0 : m_out1 + 'd1;
        m_out2_inc = (m_out2=='d99)? 'd0 : m_out2 + 'd1;
        m_out3_inc = m_out3 + 'd1;
    end
    2'd1: begin
        m_out1_inc = 'd0;
        m_out2_inc = (m_out2=='d7)? 'd0 : m_out2 + 'd1;
        m_out3_inc = (m_out3=='d11)? 'd0 : m_out3 + 'd1;
    end
    default begin
        m_out1_inc = 'd0;
        m_out2_inc = (m_out2[0])? 'd0 : m_out2 + 'd1;
        m_out3_inc = (m_out3=='d7)? 'd0 : m_out3 + 'd1;
    end
    endcase
end
always@(*) begin
    rom_addr_ri = c_acti2*7'd100 + c_acti1;
    rom_addr_rw = m_out + bias_w;
    rom_addr_row = cnt + bias_ow;
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i=0;i<16;i=i+1)
            amulw[i] <= 'd0;
    end
    else begin
        for(i=0;i<16;i=i+1)
            amulw[i] <= acti[i]*weight[i];
    end
end
always@(*) begin
    sum_aw = amulw[0] + amulw[1] + amulw[2] + amulw[3] + amulw[4] + amulw[5] + amulw[6] + amulw[7] + amulw[8] + amulw[9] + amulw[10] + amulw[11] + amulw[12] + amulw[13] + amulw[14] + amulw[15];
end
always@(*) begin
    case(cs)
    RD_AW: begin
        rom_en_ri = 'd1;
        rom_en_rw = 'd1;
        rom_en_row = 'd0;
    end
    RD_W: begin
        rom_en_ri = 'd0;
        rom_en_rw = 'd1;
        rom_en_row = 'd0;
    end
    RD_OW: begin
        rom_en_ri = 'd0;
        rom_en_rw = 'd0;
        rom_en_row = 'd1;
    end
    default: begin
        rom_en_ri = 'd0;
        rom_en_rw = 'd0;
        rom_en_row = 'd0;
    end
    endcase
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
        c_acti1 <= 'd0;
        c_acti2 <= 'd15;
        for(i=0;i<16;i=i+1) begin
            acti[i] <= 'd0;
        end
        m_out1 <= 'd0;
        m_out2 <= 'd0;
        m_out3 <= 'd15;
        for(i=0;i<16;i=i+1) begin
            weight[i] <= 'd0;
        end

        for(i=0;i<12;i=i+1) begin
            outbuf[i] <= 'd0;
        end

        for(i=0;i<36;i=i+1) begin
            ow[i] <= 'd0;
        end

        layer <= 'd0;
    end
    else begin
        c_acti1 <= c_acti1;
        c_acti2 <= c_acti2;
        for(i=0;i<16;i=i+1) begin
            acti[i] <= acti[i];
        end
        m_out1 <= m_out1;
        m_out2 <= m_out2;
        m_out3 <= m_out3;
        for(i=0;i<16;i=i+1) begin
            weight[i] <= weight[i];
        end

        for(i=0;i<12;i=i+1) begin
            outbuf[i] <= outbuf[i];
        end

        for(i=0;i<36;i=i+1) begin
            ow[i] <= ow[i];
        end

        layer <= layer;

        case(ns)
        RD_AW: begin
            c_acti2 <= c_acti2_inc;
            for(i=0;i<16;i=i+1) begin
                if(i==15)
                    acti[i] <= rom_data_ri;
                else
                    acti[i] <= acti[i+1];
            end

            m_out3 <= m_out3_inc;
            for(i=0;i<16;i=i+1) begin
                if(i==15)
                    weight[i] <= rom_data_rw;
                else
                    weight[i] <= weight[i+1];
            end
        end
        PRE_SUM: begin
            c_acti1 <= c_acti1;
            c_acti2 <= c_acti2;
            for(i=0;i<16;i=i+1) begin
                acti[i] <= acti[i];
            end
            m_out1 <= m_out1;
            m_out2 <= m_out2;
            m_out3 <= m_out3;
            for(i=0;i<16;i=i+1) begin
                weight[i] <= weight[i];
            end

            for(i=0;i<12;i=i+1) begin
                outbuf[i] <= outbuf[i];
            end

            for(i=0;i<36;i=i+1) begin
                ow[i] <= ow[i];
            end

            layer <= layer;
        end
        SUM: begin
            case(layer)
            2'd0: begin
                case(m_out1)
                4'd0: outbuf[0] <= outbuf[0] + sum_aw;
                4'd1: outbuf[1] <= outbuf[1] + sum_aw;
                4'd2: outbuf[2] <= outbuf[2] + sum_aw;
                4'd3: outbuf[3] <= outbuf[3] + sum_aw;
                4'd4: outbuf[4] <= outbuf[4] + sum_aw;
                4'd5: outbuf[5] <= outbuf[5] + sum_aw;
                4'd6: outbuf[6] <= outbuf[6] + sum_aw;
                4'd7: outbuf[7] <= outbuf[7] + sum_aw;
                4'd8: outbuf[8] <= outbuf[8] + sum_aw;
                4'd9: outbuf[9] <= outbuf[9] + sum_aw;
                4'd10: outbuf[10] <= outbuf[10] + sum_aw;
                default: outbuf[11] <= outbuf[11] + sum_aw;
                endcase
            end
            2'd1: begin
                case(m_out2)
                7'd0: outbuf[0] <= outbuf[0] + sum_aw;
                7'd1: outbuf[1] <= outbuf[1] + sum_aw;
                7'd2: outbuf[2] <= outbuf[2] + sum_aw;
                7'd3: outbuf[3] <= outbuf[3] + sum_aw;
                7'd4: outbuf[4] <= outbuf[4] + sum_aw;
                7'd5: outbuf[5] <= outbuf[5] + sum_aw;
                7'd6: outbuf[6] <= outbuf[6] + sum_aw;
                default: outbuf[7] <= outbuf[7] + sum_aw;
                endcase
            end
            default: begin
                case(m_out2)
                7'd0: outbuf[0] <= outbuf[0] + sum_aw;
                default: outbuf[1] <= outbuf[1] + sum_aw;
                endcase
            end
            endcase
        end
        NEXT_C: begin
            c_acti1 <= c_acti1_inc;
            m_out2 <= m_out2_inc;

            c_acti2 <= 'd15;
            m_out3 <= 'd15;
        end
        NEXT_M: begin
            c_acti1 <= 'd0;
            c_acti2 <= 'd15;

            case(layer)
            2'd0: begin
                m_out1 <= m_out1_inc;
                m_out2 <= 'd0;
                m_out3 <= 'd15;
            end
            2'd1: begin
                m_out1 <= 'd0;
                m_out2 <= m_out2_inc;
                m_out3 <= 'd11;
            end
            default: begin
                m_out1 <= 'd0;
                m_out2 <= m_out2_inc;
                m_out3 <= 'd7;
            end
            endcase
        end
        RD_OW: begin
            case(layer)
            2'd0: begin
                for(i=0;i<36;i=i+1) begin
                    if(i==35)
                        ow[i] <= rom_data_row;
                    else
                        ow[i] <= ow[i+1];
                end
            end
            2'd1: begin
                for(i=0;i<24;i=i+1) begin
                    if(i==23)
                        ow[i] <= rom_data_row;
                    else
                        ow[i] <= ow[i+1];
                end
            end
            default: begin
                for(i=0;i<6;i=i+1) begin
                    if(i==5)
                        ow[i] <= rom_data_row;
                    else
                        ow[i] <= ow[i+1];
                end
            end
            endcase
        end
        UPDATE: begin
            acti[0] <= (Msum_dec[0]<$signed(-32'd128))? 8'd128 : Msum_dec[0][7:0];
            acti[1] <= (Msum_dec[1]<$signed(-32'd128))? 8'd128 : Msum_dec[1][7:0];
            acti[2] <= (Msum_dec[2]<$signed(-32'd128))? 8'd128 : Msum_dec[2][7:0];
            acti[3] <= (Msum_dec[3]<$signed(-32'd128))? 8'd128 : Msum_dec[3][7:0];
            acti[4] <= (Msum_dec[4]<$signed(-32'd128))? 8'd128 : Msum_dec[4][7:0];
            acti[5] <= (Msum_dec[5]<$signed(-32'd128))? 8'd128 : Msum_dec[5][7:0];
            acti[6] <= (Msum_dec[6]<$signed(-32'd128))? 8'd128 : Msum_dec[6][7:0];
            acti[7] <= (Msum_dec[7]<$signed(-32'd128))? 8'd128 : Msum_dec[7][7:0];
            acti[8] <= (Msum_dec[8]<$signed(-32'd128))? 8'd128 : Msum_dec[8][7:0];
            acti[9] <= (Msum_dec[9]<$signed(-32'd128))? 8'd128 : Msum_dec[9][7:0];
            acti[10] <= (Msum_dec[10]<$signed(-32'd128))? 8'd128 : Msum_dec[10][7:0];
            acti[11] <= (Msum_dec[11]<$signed(-32'd128))? 8'd128 : Msum_dec[11][7:0];
        end
        NEXT_L: begin
            layer <= layer + 'd1;
            case(layer)
            2'd0: begin
                m_out2 <= 'd0;
                m_out3 <= 'd11;
                for(i=12;i<16;i=i+1) begin
                    acti[i] <= 'd0;
                end
            end
            default: begin
                m_out2 <= 'd0;
                m_out3 <= 'd7;
                for(i=8;i<16;i=i+1) begin
                    acti[i] <= 'd0;
                end
            end
            endcase

            c_acti1 <= 'd0;
            c_acti2 <= 'd0;
            m_out1 <= 'd0;
            for(i=0;i<36;i=i+1) begin
                ow[i] <= 'd0;
            end
            for(i=0;i<12;i=i+1) begin
                outbuf[i] <= 'd0;
                weight[i] <= 'd0;
            end
        end
        RD_W: begin
            m_out3 <= m_out3_inc;
            case(layer)
            2'd1: begin
                for(i=0;i<12;i=i+1) begin
                    if(i==11)
                        weight[i] <= rom_data_rw;
                    else
                        weight[i] <= weight[i+1];
                end
            end
            default: begin
                for(i=0;i<8;i=i+1) begin
                    if(i==7)
                        weight[i] <= rom_data_rw;
                    else
                        weight[i] <= weight[i+1];
                end
            end
            endcase
        end
        default: begin
            c_acti1 <= 'd0;
            c_acti2 <= 'd15;
            for(i=0;i<16;i=i+1) begin
                acti[i] <= 'd0;
            end
            m_out1 <= 'd0;
            m_out2 <= 'd0;
            m_out3 <= 'd15;
            for(i=0;i<16;i=i+1) begin
                weight[i] <= 'd0;
            end

            for(i=0;i<12;i=i+1) begin
                outbuf[i] <= 'd0;
            end

            for(i=0;i<36;i=i+1) begin
                ow[i] <= 'd0;
            end

            layer <= 'd0;
        end
        endcase
    end
end
always@(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    cnt <= 'd0;
  end
  else begin
    case(cs)
    RD_AW,RD_OW,RD_W: cnt <= cnt + 'd1;
    default: cnt <= 'd0;
    endcase
  end
end
always@(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    NN_out_female <= 'd0;
    NN_out_male <= 'd0;
  end
  else begin
    case(ns)
    DONE: begin
        NN_out_female <= acti[0];
        NN_out_male <= acti[1];
    end
    default: begin
        NN_out_female <= 'd0;
        NN_out_male <= 'd0;
    end
    endcase
  end
end
assign sum_ow[0] = outbuf[0] - ow[1] + ow[2];
assign Msum[0] = sum_ow[0] * ow[0];
assign Msum_dec[0] = Msum[0][63:32] + bullshit + {31'd0,(Msum[0][31]&&(Msum[0][30:0]))};
assign sum_ow[1] = outbuf[1] - ow[4] + ow[5];
assign Msum[1] = sum_ow[1] * ow[3];
assign Msum_dec[1] = Msum[1][63:32] + bullshit + {31'd0,(Msum[1][31]&&(Msum[1][30:0]))};
assign sum_ow[2] = outbuf[2] - ow[7] + ow[8];
assign Msum[2] = sum_ow[2] * ow[6];
assign Msum_dec[2] = Msum[2][63:32] + bullshit + {31'd0,(Msum[2][31]&&(Msum[2][30:0]))};
assign sum_ow[3] = outbuf[3] - ow[10] + ow[11];
assign Msum[3] = sum_ow[3] * ow[9];
assign Msum_dec[3] = Msum[3][63:32] + bullshit + {31'd0,(Msum[3][31]&&(Msum[3][30:0]))};
assign sum_ow[4] = outbuf[4] - ow[13] + ow[14];
assign Msum[4] = sum_ow[4] * ow[12];
assign Msum_dec[4] = Msum[4][63:32] + bullshit + {31'd0,(Msum[4][31]&&(Msum[4][30:0]))};
assign sum_ow[5] = outbuf[5] - ow[16] + ow[17];
assign Msum[5] = sum_ow[5] * ow[15];
assign Msum_dec[5] = Msum[5][63:32] + bullshit + {31'd0,(Msum[5][31]&&(Msum[5][30:0]))};
assign sum_ow[6] = outbuf[6] - ow[19] + ow[20];
assign Msum[6] = sum_ow[6] * ow[18];
assign Msum_dec[6] = Msum[6][63:32] + bullshit + {31'd0,(Msum[6][31]&&(Msum[6][30:0]))};
assign sum_ow[7] = outbuf[7] - ow[22] + ow[23];
assign Msum[7] = sum_ow[7] * ow[21];
assign Msum_dec[7] = Msum[7][63:32] + bullshit + {31'd0,(Msum[7][31]&&(Msum[7][30:0]))};
assign sum_ow[8] = outbuf[8] - ow[25] + ow[26];
assign Msum[8] = sum_ow[8] * ow[24];
assign Msum_dec[8] = Msum[8][63:32] + bullshit + {31'd0,(Msum[8][31]&&(Msum[8][30:0]))};
assign sum_ow[9] = outbuf[9] - ow[28] + ow[29];
assign Msum[9] = sum_ow[9] * ow[27];
assign Msum_dec[9] = Msum[9][63:32] + bullshit + {31'd0,(Msum[9][31]&&(Msum[9][30:0]))};
assign sum_ow[10] = outbuf[10] - ow[31] + ow[32];
assign Msum[10] = sum_ow[10] * ow[30];
assign Msum_dec[10] = Msum[10][63:32] + bullshit + {31'd0,(Msum[10][31]&&(Msum[10][30:0]))};
assign sum_ow[11] = outbuf[11] - ow[34] + ow[35];
assign Msum[11] = sum_ow[11] * ow[33];
assign Msum_dec[11] = Msum[11][63:32] + bullshit + {31'd0,(Msum[11][31]&&(Msum[11][30:0]))};
endmodule

`timescale 1ns / 1ns
module MP1
(
    input  clk,
    input  rst_n,

//RAM write
    input  start_MP1,
    input  start_MP2,
    output reg end_MP1,
    output reg end_MP2,
    output reg [15:0] ram_addr_w,
    output reg [7:0] ram_data_w,
    output reg ram_en,
    output reg ram_wea,

//RAM read
    output reg [15:0] ram_addr_r,
    input  [7:0] ram_data_r,
    output reg ram_en_r
);

parameter idle = 3'b000;
parameter read_infmap = 3'b001;
parameter compare = 3'b010;
parameter end_p = 3'b011;
parameter wait1 = 3'b100;
parameter wait2 = 3'b101;

reg [2:0] ps;
reg [6:0] cnt;
reg [7:0] cnt2;
reg [7:0] data_storage [95:0];
wire [7:0] maximum1;
wire [7:0] maximum2;

reg [1:0] layer;

integer i;

always@(posedge clk or negedge rst_n) begin
    if (!rst_n) ps <= idle;
    else begin
        case (ps)
            idle        : if (start_MP1 | start_MP2) ps <= read_infmap;
                          else                       ps <= idle;
            read_infmap : begin
                          // if (((layer == 2'd1) & (cnt == 7'd98))|(layer == 2'd2) & (cnt == 7'd42)) ps <= compare;
                          // else ps <= read_infmap;
                          if ((cnt == 7'd98)) ps <= compare;
                          else ps <= read_infmap;
            end
            compare     : begin
                          if ((layer == 2'd1) & (cnt == 7'd48) & (cnt2 == 8'd191))      ps <= end_p;
                          else if ((layer == 2'd2) & (cnt == 7'd20) & (cnt2 == 8'd159)) ps <= end_p;
                          else if ((layer == 2'd1) & (cnt == 7'd48))                    ps <= read_infmap;
                          else if ((layer == 2'd2) & (cnt == 7'd20))                    ps <= read_infmap;
                          else                                                          ps <= compare;
            end
            end_p       : ps <= wait1;
            wait1       : ps <= wait2;
            wait2       : ps <= idle;
            default     : ps <= idle;
        endcase
    end
end

always@(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    cnt <= 'd0;
    cnt2 <= 'd0;
  end
  else begin
    cnt <= cnt;
    cnt2 <= cnt2;
    case (ps)
        idle        : begin
                      cnt <= 7'd0;
                      cnt2 <= 8'd0;
        end
        read_infmap : begin
                      if ((cnt == 7'd98))      cnt <= 7'd0;
                      // else if ((layer == 2'd2) & (cnt == 7'd42)) cnt <= 7'd0;
                      else                                       cnt <= cnt + 7'd1;
        end
        compare     :begin
                      if ((layer == 2'd1) & (cnt == 7'd48))      begin
                                                                 cnt <= 7'd0;
                                                                 cnt2 <= cnt2 + 1'd1; end
                      else if ((layer == 2'd2) & (cnt == 7'd20)) begin
                                                                 cnt <= 7'd0;
                                                                 cnt2 <= cnt2 + 1'd1; end                                   
                      else                                       cnt <= cnt + 7'd2;
        end
        default     : begin
          cnt <= cnt;
          cnt2 <= cnt2;
        end
    endcase
  end
end

// idle
always@(posedge clk or negedge rst_n) begin
  if(!rst_n) layer <= 'd0;
  else begin
    if (start_MP1)      layer <= 2'd1;
    else if (start_MP2) layer <= 2'd2;
    else                layer <= 2'd0;
  end
end

// read_infmap
always@(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    ram_addr_r <= 16'd0;
    ram_en_r <= 0;
    for(i=0;i<96;i=i+1)
        data_storage[i] <= 'd0;  
  end
  else begin
    ram_addr_r <= ram_addr_r;
    ram_en_r <= ram_en_r;    
    for(i=0;i<96;i=i+1)
        data_storage[i] <= data_storage[i];  

    if (ps == idle) begin
        ram_addr_r <= 16'd0;
        ram_en_r <= 'd0;
        for(i=0;i<96;i=i+1)
          data_storage[i] <= 'd0;
    end
    else if (ps == read_infmap) begin
        ram_en_r <= 'd1;
        if ((ram_en_r) & (layer == 2'd1) & (cnt < 7'd97))      ram_addr_r <= ram_addr_r + 16'd1;
        else if ((ram_en_r) & (layer == 2'd2) & (cnt < 7'd41)) ram_addr_r <= ram_addr_r + 16'd1;
        else                                                   ram_addr_r <= ram_addr_r;

        // if (cnt > 7'd2) data_storage[cnt-7'd3] <= ram_data_r;
        for(i=0;i<96;i=i+1)
            if(i==95)
                data_storage[i] <= ram_data_r;
            else
                data_storage[i] <= data_storage[i+1];
    end
    else begin
        ram_en_r <= 'd0;
        ram_addr_r <= ram_addr_r;
        for(i=0;i<94;i=i+1)
            data_storage[i] <= data_storage[i+2];
    end
  end
end

// compare
// cmp c1(data_storage[cnt], data_storage[cnt+7'd1], data_storage[cnt+7'd48], data_storage[cnt+7'd49], maximum1);
// cmp c2(data_storage[cnt], data_storage[cnt+7'd1], data_storage[cnt+7'd20], data_storage[cnt+7'd21], maximum2);
cmp c1(data_storage[0], data_storage[1], data_storage[48], data_storage[49], maximum1);
cmp c2(data_storage[0], data_storage[1], data_storage[20], data_storage[21], maximum2);

always@(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    ram_addr_w <= 16'd0;
    ram_data_w <= 8'd0;
    ram_en <= 'd0;
    ram_wea <= 'd0;
  end
  else begin
    if (ps == idle) begin
        ram_addr_w <= 16'd0;
        ram_data_w <= 8'd0;
        ram_en <= 'd0;
        ram_wea <= 'd0;
    end    
    else if (ps == compare) begin
        ram_en <= 1;
        ram_wea <= 1;
        if (layer == 2'd1)      ram_data_w <= maximum1;
        else if (layer == 2'd2) ram_data_w <= maximum2;
        else                    ram_data_w <= ram_data_w;
        if (ram_en) ram_addr_w <= ram_addr_w + 16'd1;
        else        ram_addr_w <= ram_addr_w;
    end
    else begin
        ram_en <= 0;
        ram_wea <= 0;
        ram_addr_w <= ram_addr_w;
        ram_data_w <= ram_data_w;
    end
  end
end

// end_p
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        end_MP1 <= 0;
        end_MP2 <= 0;
    end
    else begin
      if (ps == idle) begin
          end_MP1 <= 0;
          end_MP2 <= 0;
      end
      else if (ps == end_p) begin
          if (layer == 'd1) begin
              end_MP1 <= 'd1;
              end_MP2 <= end_MP2;
          end
          else if (layer == 'd2) begin
              end_MP1 <= end_MP1;
              end_MP2 <= 'd1;
          end
          else begin
              end_MP1 <= end_MP1;
              end_MP2 <= end_MP2;end
      end
      else begin
          end_MP1 <= end_MP1;
          end_MP2 <= end_MP2;
      end
    end
end

endmodule

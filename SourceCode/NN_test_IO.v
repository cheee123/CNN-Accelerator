`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/11/19 16:47:35
// Design Name: 
// Module Name: NN_test_IO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module NN_test_IO(
  input NN_start,
  input clk,
  input rst_n,
  output NN_end,
  output [7:0]NN_out_male,
  output [7:0]NN_out_female,
  input [7:0]rdata,
  output renable,
  output [11:0]raddr
  );

parameter IDLE    = 3'b000;
parameter OP      = 3'b001;
parameter END_OP0 = 3'b100;
parameter END_OP1 = 3'b101;
parameter END_OP2 = 3'b110;

reg [31:0]NN_end_cnt;
reg [2:0]ps;

assign renable = (ps==OP);
assign raddr=12'd2499;
assign NN_end = (ps == END_OP0 || ps == END_OP1 || ps == END_OP2 );
assign NN_out_male= rdata;
assign NN_out_female= rdata+3;

always @(posedge clk) begin
  if(!rst_n) 
    ps <= IDLE;
  else begin
    case(ps)
      IDLE : begin
        if(NN_start)   ps <= OP;
        else           ps <= IDLE;
      end
      OP : begin
        if(NN_end_cnt=={24{1'b1}})  ps <= END_OP0;   
        else    ps <= OP;     
      end
      END_OP0: ps <= END_OP1;
      END_OP1: ps <= END_OP2;
      END_OP2: ps <= IDLE;
      default : begin
          // Do nothing. No other unused state.
      end
    endcase
  end
end

always @(posedge clk) begin
  if(!rst_n) 
    NN_end_cnt <= 0;
  else begin
    if(ps==OP)begin
      if(NN_end_cnt=={24{1'b1}})    NN_end_cnt<=0;
      else                          NN_end_cnt<=NN_end_cnt+1;  
    end
    else    NN_end_cnt<=NN_end_cnt;
  end  
end

endmodule

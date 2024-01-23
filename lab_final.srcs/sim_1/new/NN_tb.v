`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/29 21:52:19
// Design Name: 
// Module Name: NN_tb
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


module NN_tb();

wire end_flag;
reg [15:0]ram_addr_rtb;
wire signed [7:0]ram_data_rtb;
reg ram_en_rtb;
reg rst_n;
reg [11:0]ram_addr_wtb;
reg [7:0]ram_data_wtb;
reg ram_en_wtb;
reg ram_wea_wtb;
reg start_flag;
reg sys_clk;
wire signed [7:0] NN_out_female, NN_out_male;
wire temp_ena;
wire [15:0] temp_addra;
wire [7:0] temp_dataa;
wire temp_enb;
wire [15:0] temp_addrb;

real CLK_PER = 25;//100MHz

NN_bd_wrapper UUT
   (.end_flag(end_flag),
    .ram_addr_rtb(ram_addr_rtb),
    .ram_data_rtb(ram_data_rtb),
    .ram_en_rtb(ram_en_rtb),
    .rst_n(rst_n),
    .ram_addr_wtb(ram_addr_wtb),
    .ram_data_wtb(ram_data_wtb),
    .ram_en_wtb(ram_en_wtb),
    .ram_wea_wtb(ram_wea_wtb),
    .start_flag(start_flag),
    .sys_clk(sys_clk),
    .NN_out_female(NN_out_female),
    .NN_out_male(NN_out_male),
    .temp_ena(temp_ena),
    .temp_addra(temp_addra),
    .temp_dataa(temp_dataa),
    .temp_enb(temp_enb),
    .temp_addrb(temp_addrb)
    );
    
  
initial
begin
  #0;
  rst_n=0;
  #50;
  rst_n=1;
end

integer inimg_file,inimg_data,i;
reg signed [7:0] inimg_list[0:2500];
initial begin
  #0
  start_flag=0;
  ram_addr_wtb=0;
  ram_data_wtb=0;
  ram_en_wtb=0;
  ram_wea_wtb=0;
  
  inimg_file = $fopen("./golden_data/input_image.dat","r");
  for(i=0;i<2500;i=i+1) begin
    inimg_data = $fscanf(inimg_file,"%d", inimg_list[i]);
  end
  
  #50
  @(negedge sys_clk);
  for(i=0;i<2500;i=i+1) begin
    @(negedge sys_clk);
    ram_addr_wtb=i;
    ram_data_wtb=inimg_list[i];
    ram_en_wtb=1;
    ram_wea_wtb=1;
  end
  
  #1
  @(negedge sys_clk);
  ram_addr_wtb=0;
  ram_data_wtb=0;
  ram_en_wtb=0;
  ram_wea_wtb=0;
  @(negedge sys_clk);
  #1
  @(negedge sys_clk);
  #1
  start_flag=1;
  @(negedge sys_clk);
  #1
  @(negedge sys_clk);
  #1
  @(negedge sys_clk);
  #1
  @(negedge sys_clk);
  #1
  @(negedge sys_clk);
  #1
  start_flag=0;
  
end

parameter Data_Num=48*48*8;
parameter test_num=48*48*8;
integer golden, golden_data, m ,k;
reg signed [7:0] golden_list[0:(Data_Num-1)];
initial begin
   golden = $fopen("./golden_data/ConV1_gold.dat","r");
   for(m=0;m<Data_Num;m=m+1) begin
       golden_data = $fscanf(golden,"%d", golden_list[m]);
   end
end

initial begin
  sys_clk = 0;
  forever begin
    #(CLK_PER/2) sys_clk = (~sys_clk);
  end
end

integer end_optime,error_coef;

//  initial begin
//    error_coef=0; 
//    wait(end_flag);
//    end_optime=$time;

//    $display(" Check Coefficient ...");
//    @(negedge sys_clk)
//    $display("NN_out_female: %d; ", NN_out_female);
//    $display("NN_out_male: %d; ", NN_out_male);
  
//    $display("Complete CNN operation time : %d  ns; ",end_optime);
//    $display("total number of errors  : %d ; ",error_coef);

//    #50
//    @(negedge sys_clk);
//    for(i=0;i<2500;i=i+1) begin
//      @(negedge sys_clk);
//      ram_addr_wtb=i;
//      ram_data_wtb=inimg_list[i];
//      ram_en_wtb=1;
//      ram_wea_wtb=1;
//    end
  // #1
  // @(negedge sys_clk);
  // ram_addr_wtb=0;
  // ram_data_wtb=0;
  // ram_en_wtb=0;
  // ram_wea_wtb=0;
  // @(negedge sys_clk);
  // #1
  // @(negedge sys_clk);
  // #1
  // @(negedge sys_clk);
  // #1
  // start_flag=1;
  // @(negedge sys_clk);
  // #1
  // @(negedge sys_clk);
  // #1
  // @(negedge sys_clk);
  // #1
  // @(negedge sys_clk);
  // #1
  // @(negedge sys_clk);
  // #1
//    start_flag=0;
  
//    wait(end_flag);
//    end_optime=$time;

//    $display(" Check Coefficient ...");
//    @(negedge sys_clk)
//    $display("NN_out_female: %d; ", NN_out_female);
//    $display("NN_out_male: %d; ", NN_out_male);
  
//    $display("Complete CNN operation time : %d  ns; ",end_optime);
//    $display("total number of errors  : %d ; ",error_coef);
  
//    $finish;
//  end

initial begin
 error_coef=0; 
 wait(end_flag);
 end_optime=$time;
  @(negedge sys_clk)
  @(negedge sys_clk)
  @(negedge sys_clk)
 $display(" Check Coefficient ...");
 @(negedge sys_clk)
 $display("NN_out_female: %d; ", NN_out_female);
 $display("NN_out_male: %d; ", NN_out_male);

 repeat(10)  @(posedge sys_clk);
 for(k=0; k < test_num; k=k+1) begin
   config_read_check(k, golden_list[k]);
 end
  
 $display("Complete CNN operation time : %d  ns; ",end_optime);
 $display("total number of errors  : %d ; ",error_coef);
  
 $finish;
end

task config_read_check;
  input [15:0]        addr;
  input signed [31:0] exp_data;
  begin
      ram_en_rtb <= 0;
      @(posedge sys_clk);
      ram_en_rtb <= 1; ram_addr_rtb <= addr;
      repeat(3)@(posedge sys_clk);
      //while (!rvalid) @(posedge axis_clk);
      if( (ram_data_rtb) != (exp_data)) begin
          $display("ERROR: exp = %d, rdata = %d", exp_data, ram_data_rtb);
          error_coef <= error_coef+1;
          $display("Addr = %d", ram_addr_rtb);
          //$finish;
      end 
      else begin
          $display("OK: exp = %d, rdata = %d", exp_data, ram_data_rtb);
      end
  end
endtask

endmodule
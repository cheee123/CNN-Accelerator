`timescale 1ns / 1ns
module cmp
(
    input signed [7:0] data1,
    input signed [7:0] data2,
    input signed [7:0] data3,
    input signed [7:0] data4,

    output [7:0] maximum
);
wire signed [7:0] candi1, candi2;
assign candi1 = ($signed(data1) >= $signed(data2))? data1 : data2;
assign candi2 = ($signed(data3) >= $signed(data4))? data3 : data4;
assign maximum = ($signed(candi1) >= $signed(candi2))? candi1 : candi2;
// assign maximum = ((data1 >= data2) & (data1 >= data3) & (data1 >= data4)) ? data1 :
//                  ((data2 >= data1) & (data2 >= data3) & (data2 >= data4)) ? data2 :
//                  ((data3 >= data1) & (data3 >= data2) & (data3 >= data4)) ? data3 :
//                                                                             data4 ;
endmodule
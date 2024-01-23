
`timescale 1 ns / 1 ps

module myip_v1_0 #
       (
           // Users to add parameters here

           // User parameters ends
           // Do not modify the parameters beyond this line


           // Parameters of Axi Slave Bus Interface S00_AXI
           parameter integer C_S00_AXI_DATA_WIDTH	= 32,
           parameter integer C_S00_AXI_ADDR_WIDTH	= 4,

           // Parameters of Axi Master Bus Interface M00_AXI
           parameter  C_M00_AXI_START_DATA_VALUE	= 32'hAA000000,
           parameter  C_M00_AXI_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
           parameter integer C_M00_AXI_ADDR_WIDTH	= 32,
           parameter integer C_M00_AXI_DATA_WIDTH	= 32,
           parameter integer C_M00_AXI_TRANSACTIONS_NUM	= 4,

           // Parameters of Axi Slave Bus Interface S00_AXIS
           parameter integer C_S00_AXIS_TDATA_WIDTH	= 32,

           // Parameters of Axi Master Bus Interface M00_AXIS
           parameter integer C_M00_AXIS_TDATA_WIDTH	= 32,
           parameter integer C_M00_AXIS_START_COUNT	= 32
       )
       (
           // Users to add ports here
           input clk,
           input reset_n,
           // User ports ends
           // Do not modify the ports beyond this line


           // Ports of Axi Slave Bus Interface S00_AXI
           input wire  s00_axi_aclk,
           input wire  s00_axi_aresetn,
           input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
           input wire [2 : 0] s00_axi_awprot,
           input wire  s00_axi_awvalid,
           output wire  s00_axi_awready,
           input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
           input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
           input wire  s00_axi_wvalid,
           output wire  s00_axi_wready,
           output wire [1 : 0] s00_axi_bresp,
           output wire  s00_axi_bvalid,
           input wire  s00_axi_bready,
           input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
           input wire [2 : 0] s00_axi_arprot,
           input wire  s00_axi_arvalid,
           output wire  s00_axi_arready,
           output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
           output wire [1 : 0] s00_axi_rresp,
           output wire  s00_axi_rvalid,
           input wire  s00_axi_rready,

           // Ports of Axi Slave Bus Interface S00_AXIS
           input wire  s00_axis_aclk,
           input wire  s00_axis_aresetn,
           output wire  s00_axis_tready,
           input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
           input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tkeep,
           input wire  s00_axis_tlast,
           input wire  s00_axis_tvalid,

           // Ports of Axi Master Bus Interface M00_AXIS
           input wire  m00_axis_aclk,
           input wire  m00_axis_aresetn,
           output wire  m00_axis_tvalid,
           output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
           output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tkeep,
           output wire  m00_axis_tlast,
           input wire  m00_axis_tready,
           
           //
           input [7:0]NN_out_male,
           input [7:0]NN_out_female,           
           input NN_end,
           output NN_start,
           
           // BRAM
           output wire [11:0]NN_addra,
           output wire [7:0]NN_dina,
           output wire [0:0]NN_en,
           output wire [0:0]NN_wea
       );

wire [C_S00_AXI_DATA_WIDTH-1:0] AXI_Lite_input0;
wire [C_S00_AXI_DATA_WIDTH-1:0] AXI_Lite_input1;
wire [C_S00_AXI_DATA_WIDTH-1:0] AXI_Lite_input2;
wire [C_S00_AXI_DATA_WIDTH-1:0] AXI_Lite_input3;


// Instantiation of Axi Bus Interface S00_AXI
myip_v1_0_S00_AXI # (
                      .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
                      .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
                  ) myip_v1_0_S00_AXI_inst (
                      .AXI_Lite_input0(AXI_Lite_input0),
                      .AXI_Lite_input1(AXI_Lite_input1),
                      .AXI_Lite_input2(AXI_Lite_input2),
                      .AXI_Lite_input3(AXI_Lite_input3),

                      .S_AXI_ACLK(s00_axi_aclk),
                      .S_AXI_ARESETN(s00_axi_aresetn),
                      .S_AXI_AWADDR(s00_axi_awaddr),
                      .S_AXI_AWPROT(s00_axi_awprot),
                      .S_AXI_AWVALID(s00_axi_awvalid),
                      .S_AXI_AWREADY(s00_axi_awready),
                      .S_AXI_WDATA(s00_axi_wdata),
                      .S_AXI_WSTRB(s00_axi_wstrb),
                      .S_AXI_WVALID(s00_axi_wvalid),
                      .S_AXI_WREADY(s00_axi_wready),
                      .S_AXI_BRESP(s00_axi_bresp),
                      .S_AXI_BVALID(s00_axi_bvalid),
                      .S_AXI_BREADY(s00_axi_bready),
                      .S_AXI_ARADDR(s00_axi_araddr),
                      .S_AXI_ARPROT(s00_axi_arprot),
                      .S_AXI_ARVALID(s00_axi_arvalid),
                      .S_AXI_ARREADY(s00_axi_arready),
                      .S_AXI_RDATA(s00_axi_rdata),
                      .S_AXI_RRESP(s00_axi_rresp),
                      .S_AXI_RVALID(s00_axi_rvalid),
                      .S_AXI_RREADY(s00_axi_rready)
                  );

wire rx_ready;
wire rx_valid;
wire rx_last;
wire [C_S00_AXIS_TDATA_WIDTH-1:0] rx_data;
wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] rx_keep;
// Instantiation of Axi Bus Interface S00_AXIS
myip_v1_0_S00_AXIS # (
                       .C_S_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH)
                   ) myip_v1_0_S00_AXIS_inst (
                       .rx_ready(rx_ready),
                       .rx_valid(rx_valid),
                       .rx_last(rx_last),
                       .rx_data(rx_data),
                       .rx_keep(rx_keep),

                       .S_AXIS_ACLK(s00_axis_aclk),
                       .S_AXIS_ARESETN(s00_axis_aresetn),
                       .S_AXIS_TREADY(s00_axis_tready),
                       .S_AXIS_TDATA(s00_axis_tdata),
                       .S_AXIS_TKEEP(s00_axis_tkeep),
                       .S_AXIS_TLAST(s00_axis_tlast),
                       .S_AXIS_TVALID(s00_axis_tvalid)
                   );

wire tx_ready;
wire tx_valid;
wire tx_last;
wire [C_M00_AXIS_TDATA_WIDTH-1:0] tx_data;
wire [C_M00_AXIS_TDATA_WIDTH/8-1:0] tx_keep;
// Instantiation of Axi Bus Interface M00_AXIS
myip_v1_0_M00_AXIS # (
                       .C_M_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH),
                       .C_M_START_COUNT(C_M00_AXIS_START_COUNT)
                   ) myip_v1_0_M00_AXIS_inst (
                       .tx_ready(tx_ready),
                       .tx_valid(tx_valid),
                       .tx_last(tx_last),
                       .tx_data(tx_data),
                       .tx_keep(tx_keep),

                       .M_AXIS_ACLK(m00_axis_aclk),
                       .M_AXIS_ARESETN(m00_axis_aresetn),
                       .M_AXIS_TVALID(m00_axis_tvalid),
                       .M_AXIS_TDATA(m00_axis_tdata),
                       .M_AXIS_TKEEP(m00_axis_tkeep),
                       .M_AXIS_TLAST(m00_axis_tlast),
                       .M_AXIS_TREADY(m00_axis_tready)
                   );

// Add user logic here
connect #(
                 .C_S00_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
                 .C_S00_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH),
                 .C_M00_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH)
             )   connect_test_inst (
                 .clk(clk),
                 .reset_n(reset_n),
                 //AXI Lite Slave
                 .AXI_Lite_input0(AXI_Lite_input0),
                 .AXI_Lite_input1(AXI_Lite_input1),
                 .AXI_Lite_input2(AXI_Lite_input2),
                 .AXI_Lite_input3(AXI_Lite_input3),
                 //AXIS Slave
                 .rx_ready(rx_ready),
                 .rx_valid(rx_valid),
                 .rx_last(rx_last),
                 .rx_data(rx_data),
                 .rx_keep(rx_keep),
                 //AXIS Master
                 .tx_ready(tx_ready),
                 .tx_valid(tx_valid),
                 .tx_last(tx_last),
                 .tx_data(tx_data),
                 .tx_keep(tx_keep),
                 //
                 .NN_out_male(NN_out_male),
                 .NN_out_female(NN_out_female),           
                 .NN_end(NN_end),
                 .NN_start(NN_start),
                 //
                 .NN_addra(NN_addra),    
                 .NN_dina(NN_dina),
                 .NN_en(NN_en),
                 .NN_wea(NN_wea)
             );
// User logic ends

endmodule

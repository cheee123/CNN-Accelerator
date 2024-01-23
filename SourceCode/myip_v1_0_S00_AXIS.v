
`timescale 1 ns / 1 ps

module myip_v1_0_S00_AXIS #
       (
           // Users to add parameters here

           // User parameters ends
           // Do not modify the parameters beyond this line

           // AXI4Stream sink: Data Width
           parameter integer C_S_AXIS_TDATA_WIDTH	= 32
       )
       (
           // Users to add ports here
           input rx_ready,
           output reg rx_valid,
           output reg rx_last,
           output reg [C_S_AXIS_TDATA_WIDTH-1 : 0] rx_data,
           output reg [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] rx_keep,
           // User ports ends
           // Do not modify the ports beyond this line

           // AXI4Stream sink: Clock
           input wire  S_AXIS_ACLK,
           // AXI4Stream sink: Reset
           input wire  S_AXIS_ARESETN,
           // Ready to accept data in
           output wire  S_AXIS_TREADY,
           // Data in
           input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
           // Keep
           input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TKEEP,
           // Indicates boundary of last packet
           input wire  S_AXIS_TLAST,
           // Data is in valid
           input wire  S_AXIS_TVALID
       );

// input stream data S_AXIS_TDATA
wire  	axis_tready;
// I/O Connections assignments

assign S_AXIS_TREADY	= axis_tready;

// Add user logic here
assign axis_tready = rx_ready;

always @(posedge S_AXIS_ACLK) begin
    if(!S_AXIS_ARESETN) begin
        rx_valid <= 1'b0;
    end
    else if(axis_tready) begin
        rx_valid <= S_AXIS_TVALID;
    end
end

always @(posedge S_AXIS_ACLK) begin
    if(!S_AXIS_ARESETN) begin
        rx_last <= 1'b0;
    end
    else if (S_AXIS_TVALID && axis_tready) begin
        rx_last <= S_AXIS_TLAST;
    end
end

always @(posedge S_AXIS_ACLK) begin
    if(!S_AXIS_ARESETN) begin
        rx_data <= {C_S_AXIS_TDATA_WIDTH{1'b0}};
    end
    else if (S_AXIS_TVALID && axis_tready) begin
        rx_data <= S_AXIS_TDATA;
    end
end

always @(posedge S_AXIS_ACLK) begin
    if(!S_AXIS_ARESETN) begin
        rx_keep <= {C_S_AXIS_TDATA_WIDTH/8{1'b1}};
    end
    else if(S_AXIS_TVALID && axis_tready) begin
        rx_keep <= S_AXIS_TKEEP;
    end
end
// User logic ends

endmodule

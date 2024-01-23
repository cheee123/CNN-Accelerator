
`timescale 1 ns / 1 ps

module myip_v1_0_M00_AXIS #
       (
           // Users to add parameters here

           // User parameters ends
           // Do not modify the parameters beyond this line

           // Width of S_AXIS address bus. The slave accepts the read and write addresses of width C_M_AXIS_TDATA_WIDTH.
           parameter integer C_M_AXIS_TDATA_WIDTH	= 32,
           // Start count is the number of clock cycles the master will wait before initiating/issuing any transaction.
           parameter integer C_M_START_COUNT	= 32
       )
       (
           // Users to add ports here
           output reg tx_ready,
           input tx_valid,
           input tx_last,
           input [C_M_AXIS_TDATA_WIDTH-1:0] tx_data,
           input [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] tx_keep,
           // User ports ends
           // Do not modify the ports beyond this line

           // Global ports
           input wire  M_AXIS_ACLK,
           //
           input wire  M_AXIS_ARESETN,
           // Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted.
           output wire  M_AXIS_TVALID,
           // TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
           output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] M_AXIS_TDATA,
           // TKEEP
           output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TKEEP,
           // TLAST indicates the boundary of a packet.
           output wire  M_AXIS_TLAST,
           // TREADY indicates that the slave can accept a transfer in the current cycle.
           input wire  M_AXIS_TREADY
       );
// Total number of output data
localparam NUMBER_OF_OUTPUT_WORDS = 8;

// function called clogb2 that returns an integer which has the
// value of the ceiling of the log base 2.
function integer clogb2 (input integer bit_depth);
    begin
        for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
            bit_depth = bit_depth >> 1;
    end
endfunction

// WAIT_COUNT_BITS is the width of the wait counter.
localparam integer WAIT_COUNT_BITS = clogb2(C_M_START_COUNT-1);

// bit_num gives the minimum number of bits needed to address 'depth' size of FIFO.
localparam bit_num  = clogb2(NUMBER_OF_OUTPUT_WORDS);

// AXI Stream internal signals
//streaming data valid
wire  	axis_tvalid;
//streaming data valid delayed by one clock cycle
reg  	axis_tvalid_delay;
//Last of the streaming data
wire  	axis_tlast;
//Last of the streaming data delayed by one clock cycle
reg  	axis_tlast_delay;
//FIFO implementation signals
reg [C_M_AXIS_TDATA_WIDTH-1 : 0] 	stream_data_out;
wire  	tx_en;
//The master has issued all the streaming data stored in FIFO
reg  	tx_done;

wire [C_M_AXIS_TDATA_WIDTH/8-1:0] axis_tkeep;
reg [C_M_AXIS_TDATA_WIDTH/8-1:0] axis_tkeep_delay;


// I/O Connections assignments

assign M_AXIS_TVALID	= axis_tvalid_delay;
assign M_AXIS_TDATA	= stream_data_out;
assign M_AXIS_TLAST	= axis_tlast_delay;
assign M_AXIS_TKEEP	= axis_tkeep_delay;

//tvalid generation
//axis_tvalid is asserted when the control state machine's state is SEND_STREAM and
//number of output streaming data is less than the NUMBER_OF_OUTPUT_WORDS.
assign axis_tvalid = tx_valid;

// AXI tlast generation
// axis_tlast is asserted number of output streaming data is NUMBER_OF_OUTPUT_WORDS-1
// (0 to NUMBER_OF_OUTPUT_WORDS-1)
assign axis_tlast = tx_last;

assign axis_tkeep = tx_keep;


// Delay the axis_tvalid and axis_tlast signal by one clock cycle
// to match the latency of M_AXIS_TDATA
always @(posedge M_AXIS_ACLK) begin
    if (!M_AXIS_ARESETN) begin
        axis_tvalid_delay <= 1'b0;
        axis_tlast_delay <= 1'b0;
        axis_tkeep_delay <= {C_M_AXIS_TDATA_WIDTH/8{1'b1}};
    end
    else if(M_AXIS_TREADY) begin
        axis_tvalid_delay <= axis_tvalid;
        axis_tlast_delay <= axis_tlast;
        axis_tkeep_delay <= axis_tkeep;
    end
end

//FIFO read enable generation

assign tx_en = M_AXIS_TREADY && axis_tvalid;

integer byte_index;
// Streaming output data is read from FIFO
always @( posedge M_AXIS_ACLK ) begin
    for (byte_index=0; byte_index<(C_M_AXIS_TDATA_WIDTH/8); byte_index=byte_index+1) begin
        if(!M_AXIS_ARESETN) begin
            stream_data_out[byte_index*8 +: 8] <= 0;
        end
        else if (tx_en) begin
            if(tx_keep[byte_index])
                stream_data_out[byte_index*8 +: 8] <= tx_data[byte_index*8 +: 8];
            else
                stream_data_out[byte_index*8 +: 8] <= 8'd0;
        end
    end
end

// Add user logic here
always@(posedge M_AXIS_ACLK) begin
    if(!M_AXIS_ARESETN) begin
        tx_done <= 1'b0;
    end
    else
        if (tx_last) begin
            tx_done <= 1'b1;
        end
        else begin
            tx_done <= 1'b0;
        end
end

always@(*) begin
    tx_ready = M_AXIS_TREADY;
end
// User logic ends

endmodule

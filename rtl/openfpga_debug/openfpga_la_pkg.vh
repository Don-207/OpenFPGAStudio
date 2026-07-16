`ifndef OPENFPGA_LA_PKG_VH
`define OPENFPGA_LA_PKG_VH

`define OFD_TYPE_LA_CAPTURE_HEADER      8'h40
`define OFD_TYPE_LA_SAMPLE_DATA         8'h41
`define OFD_TYPE_LA_CAPTURE_STATUS      8'h42
`define OFD_TYPE_LA_TRIGGER_EVENT       8'h43
`define OFD_TYPE_LA_CHANNEL_MANIFEST    8'h44
`define OFD_TYPE_LA_CFG_REQ             8'h45
`define OFD_TYPE_LA_CFG_RESP            8'h46

`define OFD_LA_LEN_CAPTURE_HEADER       8'd24
`define OFD_LA_LEN_SAMPLE_DATA          8'd32
`define OFD_LA_LEN_CAPTURE_STATUS       8'd20
`define OFD_LA_LEN_TRIGGER_EVENT        8'd20

`define OFD_LA_STATE_IDLE               3'd0
`define OFD_LA_STATE_ARMED              3'd1
`define OFD_LA_STATE_CAPTURING          3'd2
`define OFD_LA_STATE_DONE               3'd3
`define OFD_LA_STATE_READOUT            3'd4
`define OFD_LA_STATE_ERROR              3'd5

`define OFD_LA_FLAG_VALID               16'h0001
`define OFD_LA_FLAG_TRIGGERED           16'h0002
`define OFD_LA_FLAG_FORCED              16'h0004
`define OFD_LA_FLAG_OVERFLOW            16'h0008
`define OFD_LA_FLAG_PARTIAL             16'h0010

`define OFD_LA_ERROR_NONE               8'd0
`define OFD_LA_ERROR_CONFIG             8'd1
`define OFD_LA_ERROR_BUSY               8'd2
`define OFD_LA_ERROR_READOUT            8'd3

`define OFD_LA_TRIGGER_DISABLED         4'd0
`define OFD_LA_TRIGGER_LEVEL            4'd1
`define OFD_LA_TRIGGER_EDGE_RISING      4'd2
`define OFD_LA_TRIGGER_EDGE_FALLING     4'd3
`define OFD_LA_TRIGGER_MASK_MATCH       4'd4

`define OFD_LA_SAMPLE_WIDTH_BITS        16'd32
`define OFD_LA_SAMPLE_BYTES             8'd4
`define OFD_LA_CHANNEL_COUNT            16'd32
`define OFD_LA_MAX_SAMPLE_DEPTH         16'd128
`define OFD_LA_SAMPLE_DATA_BYTES        8'd20
`define OFD_LA_SAMPLES_PER_CHUNK        8'd5
`define OFD_LA_VERSION_VALUE            32'h00010000
`define OFD_LA_ID_VALUE                 32'h4F464C41

`define OFD_MON_ADDR_LA_ID              16'h0060
`define OFD_MON_ADDR_LA_VERSION         16'h0064
`define OFD_MON_ADDR_LA_CONTROL         16'h0068
`define OFD_MON_ADDR_LA_STATUS          16'h006C
`define OFD_MON_ADDR_LA_SAMPLE_DIVISOR  16'h0070
`define OFD_MON_ADDR_LA_CAPTURE_DEPTH   16'h0074
`define OFD_MON_ADDR_LA_PRETRIGGER_DEPTH 16'h0078
`define OFD_MON_ADDR_LA_TRIGGER_MODE    16'h007C
`define OFD_MON_ADDR_LA_TRIGGER_CHANNEL 16'h0080
`define OFD_MON_ADDR_LA_TRIGGER_VALUE   16'h0084
`define OFD_MON_ADDR_LA_TRIGGER_MASK    16'h0088
`define OFD_MON_ADDR_LA_COMMAND         16'h008C
`define OFD_MON_ADDR_LA_CAPTURE_ID      16'h0090
`define OFD_MON_ADDR_LA_CHANNEL_MASK    16'h0094

`endif

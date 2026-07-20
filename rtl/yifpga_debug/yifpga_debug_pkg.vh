`ifndef OPENFPGA_DEBUG_PKG_VH
`define OPENFPGA_DEBUG_PKG_VH

`define OFD_SOF                 8'hA5
`define OFD_VERSION             8'h01
`define OFD_MAX_PAYLOAD_BYTES   8'd32

`define OFD_TYPE_HEARTBEAT      8'h01
`define OFD_TYPE_DEBUG_PRINT    8'h02
`define OFD_TYPE_EVENT          8'h03
`define OFD_TYPE_WATCH          8'h04
`define OFD_TYPE_STATUS         8'h05

`define OFD_LEVEL_DEBUG         8'd0
`define OFD_LEVEL_INFO          8'd1
`define OFD_LEVEL_WARNING       8'd2
`define OFD_LEVEL_ERROR         8'd3

`endif


`timescale 1ns / 1ps

`include "yifpga_trace_pkg.vh"

module yifpga_trace_adapter (
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] timestamp,

    input  wire        span_begin_valid,
    input  wire [15:0] span_begin_trace_id,
    input  wire [15:0] span_begin_instance_id,
    input  wire [31:0] span_begin_arg0,

    input  wire        span_end_valid,
    input  wire [15:0] span_end_trace_id,
    input  wire [15:0] span_end_instance_id,
    input  wire [7:0]  span_end_status,
    input  wire [31:0] span_end_arg0,

    input  wire        mark_valid,
    input  wire [15:0] mark_trace_id,
    input  wire [7:0]  mark_level,
    input  wire [31:0] mark_arg0,

    input  wire        value_valid,
    input  wire [15:0] value_trace_id,
    input  wire [15:0] value_id,
    input  wire [31:0] value_data,

    input  wire        drop_valid,
    input  wire [15:0] drop_trace_id,
    input  wire [31:0] drop_count,

    output wire        trace_ready,
    output wire        trace_accepted,
    output wire        trace_dropped,

    output reg         msg_valid,
    output reg  [7:0]  msg_type,
    output reg  [7:0]  payload_len,
    output reg  [255:0] payload_flat,
    input  wire        msg_ready
);

wire [2:0] input_count;
reg        incoming_valid;
reg [7:0]  incoming_type;
reg [7:0]  incoming_len;
reg [255:0] incoming_payload;

assign input_count = {2'b0, span_begin_valid} + {2'b0, span_end_valid} +
                     {2'b0, mark_valid} + {2'b0, value_valid} +
                     {2'b0, drop_valid};
assign trace_ready = (!msg_valid || msg_ready) && (input_count <= 3'd1);
assign trace_accepted = msg_valid && msg_ready;
assign trace_dropped = (input_count > 3'd1) ||
                       ((input_count != 3'd0) && msg_valid && !msg_ready);

always @(*) begin
    incoming_valid = 1'b0;
    incoming_type = 8'd0;
    incoming_len = 8'd0;
    incoming_payload = 256'd0;

    if (span_begin_valid) begin
        incoming_valid = 1'b1;
        incoming_type = `OFD_TYPE_TRACE_SPAN_BEGIN;
        incoming_len = `OFD_TRACE_LEN_SPAN_BEGIN;
        incoming_payload[31:0] = timestamp;
        incoming_payload[47:32] = span_begin_trace_id;
        incoming_payload[63:48] = span_begin_instance_id;
        incoming_payload[95:64] = span_begin_arg0;
    end else if (span_end_valid) begin
        incoming_valid = 1'b1;
        incoming_type = `OFD_TYPE_TRACE_SPAN_END;
        incoming_len = `OFD_TRACE_LEN_SPAN_END;
        incoming_payload[31:0] = timestamp;
        incoming_payload[47:32] = span_end_trace_id;
        incoming_payload[63:48] = span_end_instance_id;
        incoming_payload[71:64] = span_end_status;
        incoming_payload[103:72] = span_end_arg0;
    end else if (mark_valid) begin
        incoming_valid = 1'b1;
        incoming_type = `OFD_TYPE_TRACE_MARK;
        incoming_len = `OFD_TRACE_LEN_MARK;
        incoming_payload[31:0] = timestamp;
        incoming_payload[47:32] = mark_trace_id;
        incoming_payload[55:48] = mark_level;
        incoming_payload[87:56] = mark_arg0;
    end else if (value_valid) begin
        incoming_valid = 1'b1;
        incoming_type = `OFD_TYPE_TRACE_VALUE;
        incoming_len = `OFD_TRACE_LEN_VALUE;
        incoming_payload[31:0] = timestamp;
        incoming_payload[47:32] = value_trace_id;
        incoming_payload[63:48] = value_id;
        incoming_payload[95:64] = value_data;
    end else if (drop_valid) begin
        incoming_valid = 1'b1;
        incoming_type = `OFD_TYPE_TRACE_DROP;
        incoming_len = `OFD_TRACE_LEN_DROP;
        incoming_payload[31:0] = timestamp;
        incoming_payload[47:32] = drop_trace_id;
        incoming_payload[79:48] = drop_count;
    end
end

always @(posedge clk) begin
    if (rst) begin
        msg_valid <= 1'b0;
        msg_type <= 8'd0;
        payload_len <= 8'd0;
        payload_flat <= 256'd0;
    end else if (!msg_valid || msg_ready) begin
        msg_valid <= incoming_valid;
        if (incoming_valid) begin
            msg_type <= incoming_type;
            payload_len <= incoming_len;
            payload_flat <= incoming_payload;
        end
    end
end

endmodule

// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged.
module openfpga_trace_adapter (
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] timestamp,

    input  wire        span_begin_valid,
    input  wire [15:0] span_begin_trace_id,
    input  wire [15:0] span_begin_instance_id,
    input  wire [31:0] span_begin_arg0,

    input  wire        span_end_valid,
    input  wire [15:0] span_end_trace_id,
    input  wire [15:0] span_end_instance_id,
    input  wire [7:0]  span_end_status,
    input  wire [31:0] span_end_arg0,

    input  wire        mark_valid,
    input  wire [15:0] mark_trace_id,
    input  wire [7:0]  mark_level,
    input  wire [31:0] mark_arg0,

    input  wire        value_valid,
    input  wire [15:0] value_trace_id,
    input  wire [15:0] value_id,
    input  wire [31:0] value_data,

    input  wire        drop_valid,
    input  wire [15:0] drop_trace_id,
    input  wire [31:0] drop_count,

    output wire        trace_ready,
    output wire        trace_accepted,
    output wire        trace_dropped,

    output wire         msg_valid,
    output wire  [7:0]  msg_type,
    output wire  [7:0]  payload_len,
    output wire  [255:0] payload_flat,
    input  wire        msg_ready
);
yifpga_trace_adapter u_yifpga_compat (
    .clk(clk),
    .rst(rst),
    .timestamp(timestamp),
    .span_begin_valid(span_begin_valid),
    .span_begin_trace_id(span_begin_trace_id),
    .span_begin_instance_id(span_begin_instance_id),
    .span_begin_arg0(span_begin_arg0),
    .span_end_valid(span_end_valid),
    .span_end_trace_id(span_end_trace_id),
    .span_end_instance_id(span_end_instance_id),
    .span_end_status(span_end_status),
    .span_end_arg0(span_end_arg0),
    .mark_valid(mark_valid),
    .mark_trace_id(mark_trace_id),
    .mark_level(mark_level),
    .mark_arg0(mark_arg0),
    .value_valid(value_valid),
    .value_trace_id(value_trace_id),
    .value_id(value_id),
    .value_data(value_data),
    .drop_valid(drop_valid),
    .drop_trace_id(drop_trace_id),
    .drop_count(drop_count),
    .trace_ready(trace_ready),
    .trace_accepted(trace_accepted),
    .trace_dropped(trace_dropped),
    .msg_valid(msg_valid),
    .msg_type(msg_type),
    .payload_len(payload_len),
    .payload_flat(payload_flat),
    .msg_ready(msg_ready)
);
endmodule

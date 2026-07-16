`timescale 1ns / 1ps

`include "openfpga_trace_pkg.vh"

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

    output reg         msg_valid,
    output reg  [7:0]  msg_type,
    output reg  [7:0]  payload_len,
    output reg  [255:0] payload_flat,
    input  wire        msg_ready
);

wire [2:0] input_count;

assign input_count = {2'b0, span_begin_valid} + {2'b0, span_end_valid} +
                     {2'b0, mark_valid} + {2'b0, value_valid} +
                     {2'b0, drop_valid};
assign trace_ready = msg_ready && (input_count <= 3'd1);
assign trace_accepted = msg_valid && msg_ready;
assign trace_dropped = (input_count != 3'd0) &&
                       (!trace_accepted || (input_count > {2'b0, trace_accepted}));

always @(*) begin
    msg_valid = 1'b0;
    msg_type = 8'd0;
    payload_len = 8'd0;
    payload_flat = 256'd0;

    if (span_begin_valid) begin
        msg_valid = 1'b1;
        msg_type = `OFD_TYPE_TRACE_SPAN_BEGIN;
        payload_len = `OFD_TRACE_LEN_SPAN_BEGIN;
        payload_flat[31:0] = timestamp;
        payload_flat[47:32] = span_begin_trace_id;
        payload_flat[63:48] = span_begin_instance_id;
        payload_flat[95:64] = span_begin_arg0;
    end else if (span_end_valid) begin
        msg_valid = 1'b1;
        msg_type = `OFD_TYPE_TRACE_SPAN_END;
        payload_len = `OFD_TRACE_LEN_SPAN_END;
        payload_flat[31:0] = timestamp;
        payload_flat[47:32] = span_end_trace_id;
        payload_flat[63:48] = span_end_instance_id;
        payload_flat[71:64] = span_end_status;
        payload_flat[103:72] = span_end_arg0;
    end else if (mark_valid) begin
        msg_valid = 1'b1;
        msg_type = `OFD_TYPE_TRACE_MARK;
        payload_len = `OFD_TRACE_LEN_MARK;
        payload_flat[31:0] = timestamp;
        payload_flat[47:32] = mark_trace_id;
        payload_flat[55:48] = mark_level;
        payload_flat[87:56] = mark_arg0;
    end else if (value_valid) begin
        msg_valid = 1'b1;
        msg_type = `OFD_TYPE_TRACE_VALUE;
        payload_len = `OFD_TRACE_LEN_VALUE;
        payload_flat[31:0] = timestamp;
        payload_flat[47:32] = value_trace_id;
        payload_flat[63:48] = value_id;
        payload_flat[95:64] = value_data;
    end else if (drop_valid) begin
        msg_valid = 1'b1;
        msg_type = `OFD_TYPE_TRACE_DROP;
        payload_len = `OFD_TRACE_LEN_DROP;
        payload_flat[31:0] = timestamp;
        payload_flat[47:32] = drop_trace_id;
        payload_flat[79:48] = drop_count;
    end
end

endmodule

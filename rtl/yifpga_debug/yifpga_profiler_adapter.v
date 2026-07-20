`timescale 1ns / 1ps

`include "yifpga_profiler_pkg.vh"

module yifpga_profiler_adapter (
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] timestamp,

    input  wire        snapshot_valid,
    output wire        snapshot_ready,
    input  wire [15:0] snapshot_metric_id,
    input  wire [15:0] snapshot_flags,
    input  wire [31:0] snapshot_sample_cycles,
    input  wire [31:0] snapshot_value0,
    input  wire [31:0] snapshot_value1,
    input  wire [31:0] snapshot_value2,
    input  wire [31:0] snapshot_value3,
    input  wire [15:0] snapshot_overflow_count,

    input  wire        alert_valid,
    output wire        alert_ready,
    input  wire [15:0] alert_metric_id,
    input  wire [7:0]  alert_level,
    input  wire [7:0]  alert_code,
    input  wire [31:0] alert_arg0,
    input  wire [31:0] alert_arg1,

    output reg         msg_valid,
    input  wire        msg_ready,
    output reg  [7:0]  msg_type,
    output reg  [7:0]  payload_len,
    output reg  [255:0] payload_flat
);

wire can_accept = !msg_valid || msg_ready;

assign alert_ready = can_accept;
assign snapshot_ready = can_accept && !alert_valid;

always @(posedge clk) begin
    if (rst) begin
        msg_valid <= 1'b0;
        msg_type <= 8'd0;
        payload_len <= 8'd0;
        payload_flat <= 256'd0;
    end else begin
        if (msg_valid && msg_ready) begin
            msg_valid <= 1'b0;
        end

        if (alert_valid && alert_ready) begin
            msg_valid <= 1'b1;
            msg_type <= `OFD_TYPE_PROFILER_ALERT;
            payload_len <= `OFD_PROFILER_LEN_ALERT;
            payload_flat <= 256'd0;
            payload_flat[31:0] <= timestamp;
            payload_flat[47:32] <= alert_metric_id;
            payload_flat[55:48] <= alert_level;
            payload_flat[63:56] <= alert_code;
            payload_flat[95:64] <= alert_arg0;
            payload_flat[127:96] <= alert_arg1;
        end else if (snapshot_valid && snapshot_ready) begin
            msg_valid <= 1'b1;
            msg_type <= `OFD_TYPE_PROFILER_SNAPSHOT;
            payload_len <= `OFD_PROFILER_LEN_SNAPSHOT;
            payload_flat <= 256'd0;
            payload_flat[31:0] <= timestamp;
            payload_flat[47:32] <= snapshot_metric_id;
            payload_flat[63:48] <= snapshot_flags;
            payload_flat[95:64] <= snapshot_sample_cycles;
            payload_flat[127:96] <= snapshot_value0;
            payload_flat[159:128] <= snapshot_value1;
            payload_flat[191:160] <= snapshot_value2;
            payload_flat[223:192] <= snapshot_value3;
            payload_flat[239:224] <= snapshot_overflow_count;
            payload_flat[255:240] <= 16'd0;
        end
    end
end

endmodule

// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged.
module openfpga_profiler_adapter (
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] timestamp,

    input  wire        snapshot_valid,
    output wire        snapshot_ready,
    input  wire [15:0] snapshot_metric_id,
    input  wire [15:0] snapshot_flags,
    input  wire [31:0] snapshot_sample_cycles,
    input  wire [31:0] snapshot_value0,
    input  wire [31:0] snapshot_value1,
    input  wire [31:0] snapshot_value2,
    input  wire [31:0] snapshot_value3,
    input  wire [15:0] snapshot_overflow_count,

    input  wire        alert_valid,
    output wire        alert_ready,
    input  wire [15:0] alert_metric_id,
    input  wire [7:0]  alert_level,
    input  wire [7:0]  alert_code,
    input  wire [31:0] alert_arg0,
    input  wire [31:0] alert_arg1,

    output wire         msg_valid,
    input  wire        msg_ready,
    output wire  [7:0]  msg_type,
    output wire  [7:0]  payload_len,
    output wire  [255:0] payload_flat
);
yifpga_profiler_adapter u_yifpga_compat (
    .clk(clk),
    .rst(rst),
    .timestamp(timestamp),
    .snapshot_valid(snapshot_valid),
    .snapshot_ready(snapshot_ready),
    .snapshot_metric_id(snapshot_metric_id),
    .snapshot_flags(snapshot_flags),
    .snapshot_sample_cycles(snapshot_sample_cycles),
    .snapshot_value0(snapshot_value0),
    .snapshot_value1(snapshot_value1),
    .snapshot_value2(snapshot_value2),
    .snapshot_value3(snapshot_value3),
    .snapshot_overflow_count(snapshot_overflow_count),
    .alert_valid(alert_valid),
    .alert_ready(alert_ready),
    .alert_metric_id(alert_metric_id),
    .alert_level(alert_level),
    .alert_code(alert_code),
    .alert_arg0(alert_arg0),
    .alert_arg1(alert_arg1),
    .msg_valid(msg_valid),
    .msg_ready(msg_ready),
    .msg_type(msg_type),
    .payload_len(payload_len),
    .payload_flat(payload_flat)
);
endmodule

`timescale 1ns / 1ps

`include "openfpga_debug_pkg.vh"
`include "openfpga_trace_pkg.vh"

module yifpga_trace_dma_probe #(
    parameter ENABLE = 1
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        start_valid,
    input  wire        done_valid,
    input  wire        error_valid,
    input  wire        timeout_valid,
    input  wire [15:0] desc_id,
    input  wire [31:0] arg0,

    output reg         span_begin_valid,
    output reg  [15:0] span_begin_trace_id,
    output reg  [15:0] span_begin_instance_id,
    output reg  [31:0] span_begin_arg0,

    output reg         span_end_valid,
    output reg  [15:0] span_end_trace_id,
    output reg  [15:0] span_end_instance_id,
    output reg  [7:0]  span_end_status,
    output reg  [31:0] span_end_arg0,

    output reg         mark_valid,
    output reg  [15:0] mark_trace_id,
    output reg  [7:0]  mark_level,
    output reg  [31:0] mark_arg0
);

always @(posedge clk) begin
    if (rst) begin
        span_begin_valid <= 1'b0;
        span_end_valid <= 1'b0;
        mark_valid <= 1'b0;
        span_begin_trace_id <= `OFD_TRACE_ID_DMA;
        span_begin_instance_id <= 16'd0;
        span_begin_arg0 <= 32'd0;
        span_end_trace_id <= `OFD_TRACE_ID_DMA;
        span_end_instance_id <= 16'd0;
        span_end_status <= `OFD_TRACE_STATUS_OK;
        span_end_arg0 <= 32'd0;
        mark_trace_id <= `OFD_TRACE_ID_DMA;
        mark_level <= `OFD_LEVEL_INFO;
        mark_arg0 <= 32'd0;
    end else begin
        span_begin_valid <= 1'b0;
        span_end_valid <= 1'b0;
        mark_valid <= 1'b0;

        if (ENABLE != 0) begin
            if (start_valid) begin
                span_begin_valid <= 1'b1;
                span_begin_trace_id <= `OFD_TRACE_ID_DMA;
                span_begin_instance_id <= desc_id;
                span_begin_arg0 <= arg0;
            end else if (timeout_valid) begin
                span_end_valid <= 1'b1;
                span_end_trace_id <= `OFD_TRACE_ID_DMA;
                span_end_instance_id <= desc_id;
                span_end_status <= `OFD_TRACE_STATUS_TIMEOUT;
                span_end_arg0 <= arg0;
            end else if (error_valid) begin
                span_end_valid <= 1'b1;
                span_end_trace_id <= `OFD_TRACE_ID_DMA;
                span_end_instance_id <= desc_id;
                span_end_status <= `OFD_TRACE_STATUS_ERROR;
                span_end_arg0 <= arg0;
            end else if (done_valid) begin
                span_end_valid <= 1'b1;
                span_end_trace_id <= `OFD_TRACE_ID_DMA;
                span_end_instance_id <= desc_id;
                span_end_status <= `OFD_TRACE_STATUS_OK;
                span_end_arg0 <= arg0;
            end
        end
    end
end

endmodule

// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged.
module openfpga_trace_dma_probe #(
    parameter ENABLE = 1
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        start_valid,
    input  wire        done_valid,
    input  wire        error_valid,
    input  wire        timeout_valid,
    input  wire [15:0] desc_id,
    input  wire [31:0] arg0,

    output wire         span_begin_valid,
    output wire  [15:0] span_begin_trace_id,
    output wire  [15:0] span_begin_instance_id,
    output wire  [31:0] span_begin_arg0,

    output wire         span_end_valid,
    output wire  [15:0] span_end_trace_id,
    output wire  [15:0] span_end_instance_id,
    output wire  [7:0]  span_end_status,
    output wire  [31:0] span_end_arg0,

    output wire         mark_valid,
    output wire  [15:0] mark_trace_id,
    output wire  [7:0]  mark_level,
    output wire  [31:0] mark_arg0
);
yifpga_trace_dma_probe #(
    .ENABLE(ENABLE)
) u_yifpga_compat (
    .clk(clk),
    .rst(rst),
    .start_valid(start_valid),
    .done_valid(done_valid),
    .error_valid(error_valid),
    .timeout_valid(timeout_valid),
    .desc_id(desc_id),
    .arg0(arg0),
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
    .mark_arg0(mark_arg0)
);
endmodule

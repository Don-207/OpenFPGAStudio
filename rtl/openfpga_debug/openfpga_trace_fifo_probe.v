`timescale 1ns / 1ps

`include "openfpga_debug_pkg.vh"
`include "openfpga_trace_pkg.vh"

module yifpga_trace_fifo_probe #(
    parameter ENABLE = 1,
    parameter VALUE_ID = 16'h0001
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        sample_valid,
    input  wire        almost_full,
    input  wire        overflow_valid,
    input  wire [31:0] level,

    output reg         mark_valid,
    output reg  [15:0] mark_trace_id,
    output reg  [7:0]  mark_level,
    output reg  [31:0] mark_arg0,

    output reg         value_valid,
    output reg  [15:0] value_trace_id,
    output reg  [15:0] value_id,
    output reg  [31:0] value_data
);

reg almost_full_d;

always @(posedge clk) begin
    if (rst) begin
        almost_full_d <= 1'b0;
        mark_valid <= 1'b0;
        mark_trace_id <= `OFD_TRACE_ID_FIFO;
        mark_level <= `OFD_LEVEL_WARNING;
        mark_arg0 <= 32'd0;
        value_valid <= 1'b0;
        value_trace_id <= `OFD_TRACE_ID_FIFO;
        value_id <= VALUE_ID;
        value_data <= 32'd0;
    end else begin
        almost_full_d <= almost_full;
        mark_valid <= 1'b0;
        value_valid <= 1'b0;

        if (ENABLE != 0) begin
            if (overflow_valid) begin
                mark_valid <= 1'b1;
                mark_trace_id <= `OFD_TRACE_ID_FIFO;
                mark_level <= `OFD_LEVEL_ERROR;
                mark_arg0 <= level;
            end else if (almost_full && !almost_full_d) begin
                mark_valid <= 1'b1;
                mark_trace_id <= `OFD_TRACE_ID_FIFO;
                mark_level <= `OFD_LEVEL_WARNING;
                mark_arg0 <= level;
            end

            if (sample_valid) begin
                value_valid <= 1'b1;
                value_trace_id <= `OFD_TRACE_ID_FIFO;
                value_id <= VALUE_ID;
                value_data <= level;
            end
        end
    end
end

endmodule

// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged.
module openfpga_trace_fifo_probe #(
    parameter ENABLE = 1,
    parameter VALUE_ID = 16'h0001
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        sample_valid,
    input  wire        almost_full,
    input  wire        overflow_valid,
    input  wire [31:0] level,

    output wire         mark_valid,
    output wire  [15:0] mark_trace_id,
    output wire  [7:0]  mark_level,
    output wire  [31:0] mark_arg0,

    output wire         value_valid,
    output wire  [15:0] value_trace_id,
    output wire  [15:0] value_id,
    output wire  [31:0] value_data
);
yifpga_trace_fifo_probe #(
    .ENABLE(ENABLE),
    .VALUE_ID(VALUE_ID)
) u_yifpga_compat (
    .clk(clk),
    .rst(rst),
    .sample_valid(sample_valid),
    .almost_full(almost_full),
    .overflow_valid(overflow_valid),
    .level(level),
    .mark_valid(mark_valid),
    .mark_trace_id(mark_trace_id),
    .mark_level(mark_level),
    .mark_arg0(mark_arg0),
    .value_valid(value_valid),
    .value_trace_id(value_trace_id),
    .value_id(value_id),
    .value_data(value_data)
);
endmodule

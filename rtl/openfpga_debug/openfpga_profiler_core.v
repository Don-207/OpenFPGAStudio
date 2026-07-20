`timescale 1ns / 1ps

`include "openfpga_profiler_pkg.vh"
`include "openfpga_debug_pkg.vh"

module yifpga_profiler_core #(
    parameter DEFAULT_SAMPLE_PERIOD = `OFD_PROFILER_DEFAULT_SAMPLE_PERIOD
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        enable,
    input  wire        clear_pulse,
    input  wire [31:0] sample_period,
    input  wire [31:0] metric_mask,

    input  wire        metric_valid,
    output wire        metric_ready,
    input  wire [15:0] metric_id,
    input  wire [31:0] metric_value0,
    input  wire [31:0] metric_value1,
    input  wire [31:0] metric_value2,
    input  wire [31:0] metric_value3,
    input  wire        metric_overflow,

    output reg         snapshot_valid,
    input  wire        snapshot_ready,
    output reg  [15:0] snapshot_metric_id,
    output reg  [15:0] snapshot_flags,
    output reg  [31:0] snapshot_sample_cycles,
    output reg  [31:0] snapshot_value0,
    output reg  [31:0] snapshot_value1,
    output reg  [31:0] snapshot_value2,
    output reg  [31:0] snapshot_value3,
    output reg  [15:0] snapshot_overflow_count,

    output reg         alert_valid,
    input  wire        alert_ready,
    output reg  [15:0] alert_metric_id,
    output reg  [7:0]  alert_level,
    output reg  [7:0]  alert_code,
    output reg  [31:0] alert_arg0,
    output reg  [31:0] alert_arg1
);

wire [31:0] effective_sample_period =
    (sample_period == 32'd0) ? DEFAULT_SAMPLE_PERIOD : sample_period;
wire [4:0] metric_mask_index =
    (metric_id == `OFD_PROFILER_METRIC_AXIS_DEMO_THROUGHPUT) ? 5'd1 :
    (metric_id == `OFD_PROFILER_METRIC_FIFO_DEMO_LEVEL) ? 5'd2 :
    (metric_id == `OFD_PROFILER_METRIC_DEMO_LATENCY) ? 5'd3 :
    (metric_id == `OFD_PROFILER_METRIC_FRAME_RATE) ? 5'd4 :
    metric_id[4:0];
wire metric_enabled = metric_mask[metric_mask_index];
wire accept_metric = metric_valid && metric_ready && metric_enabled;
wire counter_clear;
wire [31:0] counter_value0;
wire [31:0] counter_value1;
wire [31:0] counter_value2;
wire [31:0] counter_value3;
wire counter_sat0;
wire counter_sat1;
wire counter_sat2;
wire counter_sat3;
wire counter_overflow0;
wire counter_overflow1;
wire counter_overflow2;
wire counter_overflow3;
wire any_saturated = counter_sat0 || counter_sat1 || counter_sat2 || counter_sat3;
wire any_counter_overflow = counter_overflow0 || counter_overflow1 || counter_overflow2 || counter_overflow3;
wire snapshot_can_capture = !snapshot_valid || snapshot_ready;
wire alert_can_capture = !alert_valid || alert_ready;
wire sample_due;

reg [31:0] sample_counter = 32'd0;
reg [15:0] active_metric_id = `OFD_PROFILER_METRIC_AXIS_DEMO_THROUGHPUT;
reg [15:0] overflow_count = 16'd0;
reg        window_has_data = 1'b0;
reg        clear_counters_next = 1'b0;

assign metric_ready = enable && snapshot_can_capture && alert_can_capture;
assign sample_due = enable && (sample_counter >= (effective_sample_period - 32'd1));
assign counter_clear = rst || clear_pulse || clear_counters_next;

yifpga_profiler_counter u_counter0 (
    .clk(clk),
    .rst(rst),
    .clear(counter_clear),
    .add_valid(accept_metric),
    .add_value(metric_value0),
    .value(counter_value0),
    .saturated(counter_sat0),
    .overflow_pulse(counter_overflow0)
);

yifpga_profiler_counter u_counter1 (
    .clk(clk),
    .rst(rst),
    .clear(counter_clear),
    .add_valid(accept_metric),
    .add_value(metric_value1),
    .value(counter_value1),
    .saturated(counter_sat1),
    .overflow_pulse(counter_overflow1)
);

yifpga_profiler_counter u_counter2 (
    .clk(clk),
    .rst(rst),
    .clear(counter_clear),
    .add_valid(accept_metric),
    .add_value(metric_value2),
    .value(counter_value2),
    .saturated(counter_sat2),
    .overflow_pulse(counter_overflow2)
);

yifpga_profiler_counter u_counter3 (
    .clk(clk),
    .rst(rst),
    .clear(counter_clear),
    .add_valid(accept_metric),
    .add_value(metric_value3),
    .value(counter_value3),
    .saturated(counter_sat3),
    .overflow_pulse(counter_overflow3)
);

always @(posedge clk) begin
    if (rst) begin
        sample_counter <= 32'd0;
        snapshot_valid <= 1'b0;
        snapshot_metric_id <= `OFD_PROFILER_METRIC_AXIS_DEMO_THROUGHPUT;
        snapshot_flags <= 16'd0;
        snapshot_sample_cycles <= 32'd0;
        snapshot_value0 <= 32'd0;
        snapshot_value1 <= 32'd0;
        snapshot_value2 <= 32'd0;
        snapshot_value3 <= 32'd0;
        snapshot_overflow_count <= 16'd0;
        alert_valid <= 1'b0;
        alert_metric_id <= 16'd0;
        alert_level <= `OFD_LEVEL_WARNING;
        alert_code <= 8'd0;
        alert_arg0 <= 32'd0;
        alert_arg1 <= 32'd0;
        active_metric_id <= `OFD_PROFILER_METRIC_AXIS_DEMO_THROUGHPUT;
        overflow_count <= 16'd0;
        window_has_data <= 1'b0;
        clear_counters_next <= 1'b0;
    end else begin
        clear_counters_next <= 1'b0;

        if (snapshot_valid && snapshot_ready) begin
            snapshot_valid <= 1'b0;
        end
        if (alert_valid && alert_ready) begin
            alert_valid <= 1'b0;
        end

        if (!enable || clear_pulse) begin
            sample_counter <= 32'd0;
            overflow_count <= 16'd0;
            window_has_data <= 1'b0;
        end else begin
            if (accept_metric) begin
                active_metric_id <= metric_id;
                window_has_data <= 1'b1;
                if (metric_overflow && overflow_count != 16'hFFFF) begin
                    overflow_count <= overflow_count + 16'd1;
                end
                if (metric_overflow && alert_can_capture) begin
                    alert_valid <= 1'b1;
                    alert_metric_id <= metric_id;
                    alert_level <= `OFD_LEVEL_WARNING;
                    alert_code <= `OFD_PROFILER_ALERT_OVERFLOW;
                    alert_arg0 <= metric_value0;
                    alert_arg1 <= {16'd0, overflow_count + 16'd1};
                end
            end

            if (any_counter_overflow && overflow_count != 16'hFFFF) begin
                overflow_count <= overflow_count + 16'd1;
            end

            if (sample_due && snapshot_can_capture) begin
                snapshot_valid <= 1'b1;
                snapshot_metric_id <= active_metric_id;
                snapshot_flags <= `OFD_PROFILER_FLAG_VALID |
                                  `OFD_PROFILER_FLAG_WINDOW_RESET |
                                  ((any_saturated || (overflow_count != 16'd0)) ? `OFD_PROFILER_FLAG_SATURATED : 16'd0) |
                                  ((overflow_count != 16'd0) ? `OFD_PROFILER_FLAG_ALERT : 16'd0);
                snapshot_sample_cycles <= effective_sample_period;
                snapshot_value0 <= counter_value0 + (accept_metric ? metric_value0 : 32'd0);
                snapshot_value1 <= counter_value1 + (accept_metric ? metric_value1 : 32'd0);
                snapshot_value2 <= counter_value2 + (accept_metric ? metric_value2 : 32'd0);
                snapshot_value3 <= counter_value3 + (accept_metric ? metric_value3 : 32'd0);
                snapshot_overflow_count <= overflow_count;
                sample_counter <= 32'd0;
                overflow_count <= 16'd0;
                window_has_data <= 1'b0;
                clear_counters_next <= 1'b1;
            end else if (window_has_data || accept_metric) begin
                sample_counter <= sample_counter + 32'd1;
            end
        end
    end
end

endmodule

// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged.
module openfpga_profiler_core #(
    parameter DEFAULT_SAMPLE_PERIOD = `OFD_PROFILER_DEFAULT_SAMPLE_PERIOD
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        enable,
    input  wire        clear_pulse,
    input  wire [31:0] sample_period,
    input  wire [31:0] metric_mask,

    input  wire        metric_valid,
    output wire        metric_ready,
    input  wire [15:0] metric_id,
    input  wire [31:0] metric_value0,
    input  wire [31:0] metric_value1,
    input  wire [31:0] metric_value2,
    input  wire [31:0] metric_value3,
    input  wire        metric_overflow,

    output wire         snapshot_valid,
    input  wire        snapshot_ready,
    output wire  [15:0] snapshot_metric_id,
    output wire  [15:0] snapshot_flags,
    output wire  [31:0] snapshot_sample_cycles,
    output wire  [31:0] snapshot_value0,
    output wire  [31:0] snapshot_value1,
    output wire  [31:0] snapshot_value2,
    output wire  [31:0] snapshot_value3,
    output wire  [15:0] snapshot_overflow_count,

    output wire         alert_valid,
    input  wire        alert_ready,
    output wire  [15:0] alert_metric_id,
    output wire  [7:0]  alert_level,
    output wire  [7:0]  alert_code,
    output wire  [31:0] alert_arg0,
    output wire  [31:0] alert_arg1
);
yifpga_profiler_core #(
    .DEFAULT_SAMPLE_PERIOD(DEFAULT_SAMPLE_PERIOD)
) u_yifpga_compat (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .clear_pulse(clear_pulse),
    .sample_period(sample_period),
    .metric_mask(metric_mask),
    .metric_valid(metric_valid),
    .metric_ready(metric_ready),
    .metric_id(metric_id),
    .metric_value0(metric_value0),
    .metric_value1(metric_value1),
    .metric_value2(metric_value2),
    .metric_value3(metric_value3),
    .metric_overflow(metric_overflow),
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
    .alert_arg1(alert_arg1)
);
endmodule

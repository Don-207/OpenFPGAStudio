`timescale 1ns / 1ps

`include "yifpga_debug_pkg.vh"
`include "yifpga_trace_pkg.vh"

module yifpga_trace_irq_probe #(
    parameter ENABLE = 1
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        irq_level,
    input  wire [31:0] irq_arg0,

    output reg         mark_valid,
    output reg  [15:0] mark_trace_id,
    output reg  [7:0]  mark_level,
    output reg  [31:0] mark_arg0
);

reg irq_level_d;

always @(posedge clk) begin
    if (rst) begin
        irq_level_d <= 1'b0;
        mark_valid <= 1'b0;
        mark_trace_id <= `OFD_TRACE_ID_IRQ;
        mark_level <= `OFD_LEVEL_INFO;
        mark_arg0 <= 32'd0;
    end else begin
        irq_level_d <= irq_level;
        mark_valid <= 1'b0;

        if (ENABLE != 0) begin
            if (irq_level && !irq_level_d) begin
                mark_valid <= 1'b1;
                mark_trace_id <= `OFD_TRACE_ID_IRQ;
                mark_level <= `OFD_LEVEL_INFO;
                mark_arg0 <= irq_arg0;
            end else if (!irq_level && irq_level_d) begin
                mark_valid <= 1'b1;
                mark_trace_id <= `OFD_TRACE_ID_IRQ;
                mark_level <= `OFD_LEVEL_DEBUG;
                mark_arg0 <= irq_arg0;
            end
        end
    end
end

endmodule

// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged.
module openfpga_trace_irq_probe #(
    parameter ENABLE = 1
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        irq_level,
    input  wire [31:0] irq_arg0,

    output wire         mark_valid,
    output wire  [15:0] mark_trace_id,
    output wire  [7:0]  mark_level,
    output wire  [31:0] mark_arg0
);
yifpga_trace_irq_probe #(
    .ENABLE(ENABLE)
) u_yifpga_compat (
    .clk(clk),
    .rst(rst),
    .irq_level(irq_level),
    .irq_arg0(irq_arg0),
    .mark_valid(mark_valid),
    .mark_trace_id(mark_trace_id),
    .mark_level(mark_level),
    .mark_arg0(mark_arg0)
);
endmodule

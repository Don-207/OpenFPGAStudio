`timescale 1ns / 1ps

module yifpga_debug_timestamp (
    input  wire        clk,
    input  wire        rst,
    output reg  [31:0] timestamp
);

always @(posedge clk) begin
    if (rst) begin
        timestamp <= 32'd0;
    end else begin
        timestamp <= timestamp + 32'd1;
    end
end

endmodule

// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged.
module openfpga_debug_timestamp (
    input  wire        clk,
    input  wire        rst,
    output wire  [31:0] timestamp
);
yifpga_debug_timestamp u_yifpga_compat (
    .clk(clk),
    .rst(rst),
    .timestamp(timestamp)
);
endmodule

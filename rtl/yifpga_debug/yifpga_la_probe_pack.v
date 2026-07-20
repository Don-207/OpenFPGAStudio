`timescale 1ns / 1ps

module yifpga_la_probe_pack (
    input  wire [31:0] probe_bits,
    output wire [31:0] sample_bus
);

assign sample_bus = probe_bits;

endmodule

// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged.
module openfpga_la_probe_pack (
    input  wire [31:0] probe_bits,
    output wire [31:0] sample_bus
);
yifpga_la_probe_pack u_yifpga_compat (
    .probe_bits(probe_bits),
    .sample_bus(sample_bus)
);
endmodule

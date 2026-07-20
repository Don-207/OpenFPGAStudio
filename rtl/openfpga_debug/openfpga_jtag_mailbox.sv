`timescale 1ns/1ps
module yifpga_jtag_mailbox #(
    parameter int ADDR_WIDTH = 12,
    parameter logic [31:0] BUILD_ID = 32'd0
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        header_req,
    input  logic [5:0]  header_addr,
    output logic [7:0]  header_data,
    output logic        header_valid,
    input  logic        payload_req,
    output logic [7:0]  payload_data,
    output logic        payload_valid,
    input  logic        payload_ready,
    input  logic        payload_commit,
    input  logic        payload_abort,
    input  logic [31:0] session_id,
    input  logic [31:0] write_count,
    input  logic [31:0] read_count,
    input  logic [ADDR_WIDTH:0] available_bytes,
    input  logic [31:0] overflow_count,
    input  logic [31:0] dropped_bytes,
    input  logic [7:0]  ring_data,
    input  logic        ring_valid,
    output logic        ring_ready,
    output logic        ring_commit,
    output logic        ring_abort
);

localparam logic [31:0] MAGIC = 32'h544a_464f; // bytes: 4f 46 4a 54, "OFJT"
localparam logic [15:0] VERSION = 16'h0001;
localparam logic [15:0] CAPS = 16'h000f;
localparam logic [31:0] BUFFER_SIZE = (32'd1 << ADDR_WIDTH);
logic [319:0] header_live;
logic [319:0] header_snapshot;

always_comb begin
    header_live = {BUILD_ID, dropped_bytes, overflow_count,
                   {{(31-ADDR_WIDTH){1'b0}}, available_bytes},
                   read_count, write_count, BUFFER_SIZE, session_id,
                   CAPS, VERSION, MAGIC};
end

// While no Header response is active, continually prepare a coherent snapshot.
// The CAPTURE edge is the final update; header_req then stays asserted for the
// whole response scan, keeping all 40 bytes stable despite CDC counter changes.
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        header_snapshot <= '0;
    else if (!header_req)
        header_snapshot <= header_live;
end

always_comb begin
    header_data = header_snapshot[header_addr*8 +: 8];
    header_valid = header_req && (header_addr < 6'd40);
    payload_data = ring_data;
    payload_valid = payload_req && ring_valid;
    ring_ready = payload_req && payload_ready;
    ring_commit = payload_commit;
    ring_abort = payload_abort;
end

endmodule

// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged.
module openfpga_jtag_mailbox #(
    parameter int ADDR_WIDTH = 12,
    parameter logic [31:0] BUILD_ID = 32'd0
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        header_req,
    input  logic [5:0]  header_addr,
    output wire [7:0]  header_data,
    output wire        header_valid,
    input  logic        payload_req,
    output wire [7:0]  payload_data,
    output wire        payload_valid,
    input  logic        payload_ready,
    input  logic        payload_commit,
    input  logic        payload_abort,
    input  logic [31:0] session_id,
    input  logic [31:0] write_count,
    input  logic [31:0] read_count,
    input  logic [ADDR_WIDTH:0] available_bytes,
    input  logic [31:0] overflow_count,
    input  logic [31:0] dropped_bytes,
    input  logic [7:0]  ring_data,
    input  logic        ring_valid,
    output wire        ring_ready,
    output wire        ring_commit,
    output wire        ring_abort
);
yifpga_jtag_mailbox #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .BUILD_ID(BUILD_ID)
) u_yifpga_compat (
    .clk(clk),
    .rst_n(rst_n),
    .header_req(header_req),
    .header_addr(header_addr),
    .header_data(header_data),
    .header_valid(header_valid),
    .payload_req(payload_req),
    .payload_data(payload_data),
    .payload_valid(payload_valid),
    .payload_ready(payload_ready),
    .payload_commit(payload_commit),
    .payload_abort(payload_abort),
    .session_id(session_id),
    .write_count(write_count),
    .read_count(read_count),
    .available_bytes(available_bytes),
    .overflow_count(overflow_count),
    .dropped_bytes(dropped_bytes),
    .ring_data(ring_data),
    .ring_valid(ring_valid),
    .ring_ready(ring_ready),
    .ring_commit(ring_commit),
    .ring_abort(ring_abort)
);
endmodule

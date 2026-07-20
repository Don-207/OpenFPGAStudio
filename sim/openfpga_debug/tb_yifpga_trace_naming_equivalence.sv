`timescale 1ns/1ps
`include "openfpga_trace_pkg.vh"

module tb_yifpga_trace_naming_equivalence;
logic clk = 0, rst = 1, msg_ready = 1;
logic [31:0] timestamp = 0;
logic span_begin_valid = 0, span_end_valid = 0, mark_valid = 0;
logic value_valid = 0, drop_valid = 0;
logic [15:0] span_begin_trace_id = 0, span_begin_instance_id = 0;
logic [31:0] span_begin_arg0 = 0;
logic [15:0] span_end_trace_id = 0, span_end_instance_id = 0;
logic [7:0] span_end_status = 0;
logic [31:0] span_end_arg0 = 0;
logic [15:0] mark_trace_id = 0;
logic [7:0] mark_level = 0;
logic [31:0] mark_arg0 = 0;
logic [15:0] value_trace_id = 0, value_id = 0;
logic [31:0] value_data = 0;
logic [15:0] drop_trace_id = 0;
logic [31:0] drop_count = 0;
wire new_trace_ready, new_trace_accepted, new_trace_dropped, new_msg_valid;
wire [7:0] new_msg_type, new_payload_len;
wire [255:0] new_payload_flat;
wire old_trace_ready, old_trace_accepted, old_trace_dropped, old_msg_valid;
wire [7:0] old_msg_type, old_payload_len;
wire [255:0] old_payload_flat;
integer errors = 0;

always #5 clk = ~clk;

yifpga_trace_adapter canonical (.*,
    .trace_ready(new_trace_ready), .trace_accepted(new_trace_accepted),
    .trace_dropped(new_trace_dropped), .msg_valid(new_msg_valid),
    .msg_type(new_msg_type), .payload_len(new_payload_len),
    .payload_flat(new_payload_flat));
openfpga_trace_adapter legacy (.*,
    .trace_ready(old_trace_ready), .trace_accepted(old_trace_accepted),
    .trace_dropped(old_trace_dropped), .msg_valid(old_msg_valid),
    .msg_type(old_msg_type), .payload_len(old_payload_len),
    .payload_flat(old_payload_flat));

task compare_outputs;
begin
    #1;
    if ({new_trace_ready, new_trace_accepted, new_trace_dropped, new_msg_valid,
         new_msg_type, new_payload_len, new_payload_flat} !==
        {old_trace_ready, old_trace_accepted, old_trace_dropped, old_msg_valid,
         old_msg_type, old_payload_len, old_payload_flat}) errors++;
end
endtask

initial begin
    repeat (3) @(posedge clk); rst = 0;
    repeat (2) begin @(posedge clk); compare_outputs(); end
    for (integer i = 0; i < 64; i++) begin
        @(negedge clk);
        timestamp = i * 17; msg_ready = i[0];
        span_begin_valid = (i % 7) == 0; span_end_valid = (i % 7) == 1;
        mark_valid = (i % 7) == 2; value_valid = (i % 7) == 3;
        drop_valid = (i % 7) == 4;
        span_begin_trace_id = i; span_begin_instance_id = i + 1; span_begin_arg0 = i * 3;
        span_end_trace_id = i + 2; span_end_instance_id = i + 3;
        span_end_status = i; span_end_arg0 = i * 5;
        mark_trace_id = i + 4; mark_level = i; mark_arg0 = i * 7;
        value_trace_id = i + 5; value_id = i + 6; value_data = i * 11;
        drop_trace_id = i + 7; drop_count = i * 13;
        @(posedge clk); compare_outputs();
    end
    if (errors) $display("FAIL: Trace naming equivalence %0d mismatches", errors);
    else $display("PASS: Trace old/new module outputs are cycle-equivalent");
    $finish;
end
endmodule

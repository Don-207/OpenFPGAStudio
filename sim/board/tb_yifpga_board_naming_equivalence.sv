`timescale 1ns/1ps
module tb_yifpga_board_naming_equivalence;
localparam CLK_FREQ_HZ = 10000000;
logic clk_p = 0, reset_n = 0, demo_trigger = 0, uart_rx = 1;
wire clk_n = ~clk_p;
wire new_uart_tx, new_led0, new_led1, old_uart_tx, old_led0, old_led1;
integer errors = 0;
always #5 clk_p = ~clk_p;

yifpga_debug_board_demo #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ), .UART_BAUD(1000000), .BUFFER_ADDR_WIDTH(3),
    .HEARTBEAT_INTERVAL_TICKS(1000), .EVENT_INTERVAL_TICKS(400),
    .WATCH_INTERVAL_TICKS(700), .PRINT_INTERVAL_TICKS(900),
    .STATUS_INTERVAL_TICKS(600), .TRACE_SCENARIO_INTERVAL_TICKS(500),
    .LED_HOLD_TICKS(10), .ENABLE_JTAG(0)
) canonical (.*,.uart_tx(new_uart_tx), .led0(new_led0), .led1(new_led1));
openfpga_debug_board_demo #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ), .UART_BAUD(1000000), .BUFFER_ADDR_WIDTH(3),
    .HEARTBEAT_INTERVAL_TICKS(1000), .EVENT_INTERVAL_TICKS(400),
    .WATCH_INTERVAL_TICKS(700), .PRINT_INTERVAL_TICKS(900),
    .STATUS_INTERVAL_TICKS(600), .TRACE_SCENARIO_INTERVAL_TICKS(500),
    .LED_HOLD_TICKS(10), .ENABLE_JTAG(0)
) legacy (.*,.uart_tx(old_uart_tx), .led0(old_led0), .led1(old_led1));

initial begin
    repeat (5) @(posedge clk_p); reset_n = 1;
    for (integer i = 0; i < 20000; i++) begin
        @(negedge clk_p);
        demo_trigger = (i % 997) == 0;
        uart_rx = (i % 1237) != 0;
        #1;
        if ({new_uart_tx, new_led0, new_led1} !== {old_uart_tx, old_led0, old_led1})
            errors++;
    end
    if (errors) $display("FAIL: Board naming equivalence %0d mismatches", errors);
    else $display("PASS: Board old/new module outputs are cycle-equivalent");
    $finish;
end
endmodule

# M16 板级 Demo 与第三阶段发布实施计划

## 目标

- 板级 demo 接入 UART RX、Command Parser、Monitor Core 和 response adapter。
- Viewer 能在线读取 `MONITOR_ID/MONITOR_VERSION`，写 `LED_CONTROL/DEMO_PERIOD/CLEAR_COUNTERS`。
- 补齐仿真、Vivado elaboration、使用说明、验证记录和发布 checklist。

## 实现

- `rtl/board/openfpga_debug_board_demo.v`
  - 新增 `uart_rx` 端口。
  - 接入 `openfpga_debug_uart_rx`、`openfpga_debug_command_parser`、`openfpga_monitor_core`、`openfpga_monitor_adapter`。
  - `LED_CONTROL[1:0]` 直接影响 `led0/led1`。
  - `DEMO_PERIOD` 影响 Event/Trace demo 节奏。
  - `CLEAR_COUNTERS` 清除 demo 计数器和序号。
- `sim/board/tb_openfpga_debug_board_monitor.v`
  - 从 UART RX 注入 Monitor read/write request。
  - 从 UART TX 读取 response frame，检查 ID、LED 写入和 RO 写拒绝。
- `prj/scripts/check_openfpga_monitor_m16_elab.tcl`
  - 检查完整 board demo RTL elaboration。

## 注意

当前 `prj/constraints/openfpga_debug_board_demo.xdc` 已补充 `uart_rx` 引脚约束，板级验证时需要确认 PC TX 到 FPGA RX 的线缆方向和共地。

## 验收

```powershell
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_trace_pkg.vh rtl\openfpga_debug\openfpga_monitor_pkg.vh rtl\openfpga_debug\*.v rtl\board\openfpga_debug_board_demo.v sim\board\tb_openfpga_debug_board_monitor.v
xelab tb_openfpga_debug_board_monitor -s tb_openfpga_debug_board_monitor_sim
xsim tb_openfpga_debug_board_monitor_sim -runall
```

期望输出：

```text
PASS: OpenFPGA Monitor M16 board UART RX to response path checks passed
```

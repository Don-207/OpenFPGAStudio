# M13 UART RX 与 Command Parser 实施计划

## 目标

- 新增 `openfpga_debug_uart_rx`，把 PC TX 的 UART bit stream 转成字节流。
- 新增 `openfpga_debug_command_parser`，复用 Debug Protocol v1 帧格式解析 `MONITOR_READ_REQ` 和 `MONITOR_WRITE_REQ`。
- 对 SOF 重同步、版本、长度、checksum、width 和 unsupported type 做显式保护。

## 实现

- `rtl/openfpga_debug/openfpga_debug_uart_rx.v`
  - 使用双触发同步输入 RX。
  - 按 `CLK_FREQ_HZ / BAUD` 采样 start/data/stop。
  - 输出单周期 `data_valid` 和 `frame_error`。
- `rtl/openfpga_debug/openfpga_debug_command_parser.v`
  - 状态机解析 `SOF + VER + TYPE + LEN + PAYLOAD + CHECKSUM`。
  - READ payload 固定为 5 字节，WRITE payload 固定为 13 字节。
  - 输出 `monitor_req_seq/addr/write/width/wdata/wmask`，并用 `monitor_req_ready` 做反压。
- `sim/openfpga_debug/tb_openfpga_debug_command_parser.v`
  - 通过 UART bit stream 注入 read/write request。
  - 覆盖 checksum 错误不产生请求、reset 清空 pending。
- `prj/scripts/check_openfpga_monitor_m13_elab.tcl`
  - Vivado RTL elaboration 检查。

## 验收

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_monitor_pkg.vh rtl\openfpga_debug\openfpga_debug_uart_rx.v rtl\openfpga_debug\openfpga_debug_command_parser.v sim\openfpga_debug\tb_openfpga_debug_command_parser.v
xelab tb_openfpga_debug_command_parser -s tb_openfpga_debug_command_parser_sim
xsim tb_openfpga_debug_command_parser_sim -runall
```

期望输出：

```text
PASS: OpenFPGA Monitor M13 UART RX command parser checks passed
```

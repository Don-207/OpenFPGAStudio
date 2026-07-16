# M14 RTL Monitor Core 与寄存器窗口实施计划

## 目标

- 新增 Monitor 常量包、Core、寄存器窗口和 response adapter。
- 支持 RO、RW、W1C、TRIGGER 四类寄存器语义。
- 生成 `MONITOR_READ_RESP` 和 `MONITOR_WRITE_RESP`，并通过现有 Debug Core TX path 发送。

## 实现

- `rtl/openfpga_debug/openfpga_monitor_pkg.vh`
  - 定义 Monitor type、status、地址和固定 ID/version。
- `rtl/openfpga_debug/openfpga_monitor_reg_bank.v`
  - 暴露 `MONITOR_ID`、`MONITOR_VERSION`、`CONTROL`、`LED_CONTROL`、`DEMO_PERIOD`、`COUNTER0`、`CLEAR_COUNTERS`、`ERROR_STATUS`。
  - `DEMO_PERIOD` 禁止写 0。
  - `CLEAR_COUNTERS` 输出单周期 pulse。
- `rtl/openfpga_debug/openfpga_monitor_core.v`
  - 保存请求上下文，把寄存器窗口响应补齐为带 seq/addr/width 的 Monitor response。
- `rtl/openfpga_debug/openfpga_monitor_adapter.v`
  - 按协议打包 read/write response payload。
- `rtl/openfpga_debug/openfpga_debug_core.v`
  - 增加 `monitor_msg_*` 注入口，复用 ring buffer、packetizer 和 UART TX。
- `sim/openfpga_debug/tb_openfpga_monitor_core.v`
  - 覆盖 RO/RW/mask/W1C/TRIGGER/BAD_ADDR/BAD_VALUE。

## 验收

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_monitor_pkg.vh rtl\openfpga_debug\openfpga_monitor_reg_bank.v rtl\openfpga_debug\openfpga_monitor_core.v sim\openfpga_debug\tb_openfpga_monitor_core.v
xelab tb_openfpga_monitor_core -s tb_openfpga_monitor_core_sim
xsim tb_openfpga_monitor_core_sim -runall
```

期望输出：

```text
PASS: OpenFPGA Monitor M14 core register checks passed
```

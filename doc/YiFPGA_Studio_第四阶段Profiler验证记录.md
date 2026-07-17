# OpenFPGA Studio 第四阶段 Profiler 验证记录

## M21 Board Demo

已实现：

- Board demo 接入 `openfpga_profiler_core`、`openfpga_profiler_adapter` 和四类典型 probe。
- Profiler 帧通过现有 Debug Core UART TX path 输出，与 Debug、Trace、Monitor 帧共存。
- Monitor register map 增加 `0x0040..0x005C` Profiler 控制与状态寄存器。
- Web Viewer Profiler 控制地址已对齐 M21 register map。
- 新增 `tb_openfpga_debug_board_profiler.v` 覆盖 enable、sample period、mask、clear、alert 和多类型帧共存。
- 新增 Vivado RTL elaboration 脚本 `prj/scripts/check_openfpga_profiler_m21_elab.tcl`。

## 已执行

2026-07-02 已执行：

- `python tools\viewer\protocol_parser_test.py`
  - `PASS: OpenFPGA Debug Protocol parser test vectors passed`
- `python tools\viewer\web\run_perf_test.py`
  - 通过，`checksumErrors=0`、`profilerSnapshots=4`、`profilerAlerts=1`、`profilerMalformed=1`
- M18 Profiler Core XSim
  - `PASS: OpenFPGA Profiler M18 core snapshot checks passed`
- M19 Profiler Probes XSim
  - `PASS: OpenFPGA Profiler M19 probe checks passed`
- Monitor Core XSim
  - `PASS: OpenFPGA Monitor M14 core register checks passed`
- M21 Board Demo XSim
  - `PASS: OpenFPGA Profiler M21 board demo checks passed`
- M21 Vivado RTL elaboration
  - `PASS: OpenFPGA Profiler M21 board demo Vivado RTL elaboration completed`
- M21 bitstream build
  - `prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo.bit`
  - Bitstream timestamp: `2026-07-02 13:56:53`
- M21 board serial validation on `COM7`
  - Monitor: `PASS: OpenFPGA Monitor board validation passed`
  - Profiler: `PASS: OpenFPGA Profiler board validation passed`
  - Observed `PROFILER_ID=0x4F465034`, `PROFILER_VERSION=0x00010000`, four profiler snapshot metrics, and one profiler alert.
  - `PROFILER_STATUS` read after high-rate profiler traffic may timeout because snapshot/alert frames can saturate the shared UART path; the validator treats that final read as advisory after required snapshots and alert have been observed.

```powershell
python tools\viewer\protocol_parser_test.py
python tools\viewer\web\run_perf_test.py
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_trace_pkg.vh rtl\openfpga_debug\openfpga_monitor_pkg.vh rtl\openfpga_debug\openfpga_profiler_pkg.vh rtl\openfpga_debug\openfpga_debug_timestamp.v rtl\openfpga_debug\openfpga_debug_ring_buffer.v rtl\openfpga_debug\openfpga_debug_packetizer.v rtl\openfpga_debug\openfpga_debug_uart_tx.v rtl\openfpga_debug\openfpga_debug_uart_rx.v rtl\openfpga_debug\openfpga_debug_command_parser.v rtl\openfpga_debug\openfpga_trace_adapter.v rtl\openfpga_debug\openfpga_trace_dma_probe.v rtl\openfpga_debug\openfpga_trace_frame_probe.v rtl\openfpga_debug\openfpga_trace_fifo_probe.v rtl\openfpga_debug\openfpga_trace_irq_probe.v rtl\openfpga_debug\openfpga_monitor_reg_bank.v rtl\openfpga_debug\openfpga_monitor_core.v rtl\openfpga_debug\openfpga_monitor_adapter.v rtl\openfpga_debug\openfpga_profiler_counter.v rtl\openfpga_debug\openfpga_profiler_core.v rtl\openfpga_debug\openfpga_profiler_adapter.v rtl\openfpga_debug\openfpga_profiler_axis_probe.v rtl\openfpga_debug\openfpga_profiler_fifo_probe.v rtl\openfpga_debug\openfpga_profiler_frame_probe.v rtl\openfpga_debug\openfpga_profiler_latency.v rtl\openfpga_debug\openfpga_debug_core.v rtl\openfpga_debug\openfpga_debug_top.v rtl\board\openfpga_debug_board_demo.v sim\board\tb_openfpga_debug_board_profiler.v
xelab tb_openfpga_debug_board_profiler -s tb_openfpga_debug_board_profiler_sim
xsim tb_openfpga_debug_board_profiler_sim -runall
```

Vivado RTL elaboration 已执行：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_profiler_m21_elab.tcl
```

## 2026-07-16 v1.0 WP3复核

### 回归与缺陷修复

- `just profiler-check`覆盖Parser、Viewer压力、M18 Core、M19 Probe、M21 Board Demo和Vivado elaboration；各项通过。
- Viewer压力回归共处理11,194帧，checksum、sync、unknown均为0，Profiler snapshot、alert和malformed路径均有覆盖。
- 首次在旧候选镜像执行1800秒长稳时，虽然checksum和设备drop均为0，但FIFO metric `0x0101`的`overflow_count`增长并饱和到65,535，因此该次结果判为FAIL，未沿用历史板级PASS。
- 定位到`openfpga_profiler_fifo_probe`在FIFO level不变时仍每拍发出当前gauge，Profiler Core因而重复累计同一值。修复后只在level变化、读写或overflow/underflow事件发生时发出metric，并增加稳定level不得重复发出的M19断言。
- 修复后的M19 Probe和M21 Board Demo XSim通过。

### 当前候选构建与下载

| 项目 | 结果 |
| --- | --- |
| Vivado/器件 | Vivado 2024.2 / `xcku5p-ffvb676-2-i` |
| 配置 | M36 UART+JTAG+ILA，USER2，1个BSCANE2，1个ILA |
| 实现 | WNS `+3.522 ns`，TNS `0`，未布线网络`0`，DRC `0 error` |
| bitstream | 15,431,260 bytes，SHA-256 `3c4e1fd154802784340e68d2b69544b4ce2c7bde7a36b3ab3d935dc0432539de` |
| LTX | 13,686 bytes，SHA-256 `019c53da47cee5fb7cecfc429efe703e9b07c038e9534a906d47e44cca115622` |
| 下载 | `Digilent/210512180081` / `xcku5p_0`，startup HIGH，枚举1个ILA |

### Ubuntu串口板级验收

环境：CH340 `/dev/ttyUSB1`，115200 baud。验收脚本读取并保存原始control/period/mask/threshold，设置有界采样窗口，结束后逐项恢复。

```text
just profiler-soak /dev/ttyUSB1 115200 120
just profiler-soak /dev/ttyUSB1 115200 1800
```

| 时长 | snapshots | alerts | status | checksum | 设备drop | overflow峰值 | 结果 |
| ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 120秒 | 483 | 121 | 6,000 | 0 | 0 | Throughput 0，FIFO 0，Latency 1，Frame 0 | PASS |
| 1800秒 | 7,203 | 1,801 | 90,000 | 0 | 0 | Throughput 0，FIFO 0，Latency 1，Frame 0 | PASS |

`Latency=1`来自board demo刻意产生的延迟/超时事件，未增长到饱和值；FIFO修复后峰值保持0。两次测试均覆盖metric `0x0001/0x0101/0x0201/0x0301`，并成功恢复测试前Profiler配置。

## Windows Edge人工视觉签署

2026-07-16在Windows Microsoft Edge `150.0.4078.65`正式版本（64位）完成当前候选的Profiler页面人工观察：

- 页面累计99 snapshots、49 alerts、0 malformed。
- Throughput、FIFO、Latency和Frame Rate四类指标均显示实时值、窗口、flags和history。
- Throughput趋势图正常绘制，alert面板持续显示FIFO/Latency演示告警。
- `Period=100000`下FIFO/Latency卡片出现`SATURATED/ALERT`，对应board demo刻意产生的窗口事件；该视觉状态不代表Debug Core丢帧。正式1800秒门禁中设备drop为0、FIFO overflow计数峰值为0。
- Enable、Disable、Apply Period、Clear、Read Status和Diagnose控制入口均正常渲染。

结论：Windows Edge人工视觉签署PASS。第四阶段Profiler验证无剩余PENDING项。

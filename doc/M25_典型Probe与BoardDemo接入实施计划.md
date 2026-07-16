# M25 典型 Probe 与 Board Demo 接入实施计划

M25 目标是把 M23 的 Logic Analyzer Core 接入现有 board demo，用 Debug、Trace、Monitor、Profiler 和 demo 内部状态形成一组代表性 probe，并完成仿真和 Vivado elaboration 验收。

## 1. 目标

- board demo 接入 LA core，采样覆盖 Debug/Trace/Monitor/Profiler 的代表性信号。
- Monitor register map 接入 LA 配置窗口。
- Debug Core TX path 接入 LA adapter 输出，并与既有 Debug/Trace/Monitor/Profiler 帧共存。
- Viewer 能通过 UART 链路 arm capture、触发、读取 chunk 并显示波形。
- 补齐 board demo XSim 和 Vivado elaboration。

## 2. 修改文件

```text
rtl/board/
  openfpga_debug_board_demo.v

sim/board/
  tb_openfpga_debug_board_la.v

prj/scripts/
  check_openfpga_la_m25_elab.tcl

doc/
  OpenFPGA_LogicAnalyzer_使用说明.md
  M25_典型Probe与BoardDemo接入实施计划.md
```

根据实际接入点，可能还需要修改：

```text
rtl/openfpga_debug/
  openfpga_debug_core.v
  openfpga_monitor_*.v
```

## 3. P0 通道定义

| 通道 | 名称 | 来源 |
| --- | --- | --- |
| `0` | `uart_tx_busy` | UART TX 状态 |
| `1` | `uart_rx_valid` | UART RX byte valid |
| `2` | `debug_tx_valid` | Debug Core TX 入队 |
| `3` | `debug_tx_ready` | Debug Core TX backpressure |
| `4` | `trace_valid` | Trace adapter 输出 |
| `5` | `monitor_resp_valid` | Monitor response |
| `6` | `profiler_snapshot_valid` | Profiler snapshot |
| `7` | `demo_frame_tick` | board demo frame event |
| `15:8` | `debug_buffer_used_lsb` | buffer used 低 8 bit |
| `23:16` | `demo_fifo_level_lsb` | demo FIFO level 低 8 bit |
| `31:24` | `la_state_debug` | LA/系统状态摘要 |

P0 固定 32 bit sample。跨时钟域信号必须在进入 LA core 前同步到 sample clock。

## 4. Monitor Register Map 接入

在 Profiler 后续空间追加：

| 地址 | 名称 | 属性 | 验收 |
| --- | --- | --- | --- |
| `0x0060` | `LA_ID` | RO | 能读到 `0x4F464C41` 或文档固定值 |
| `0x0064` | `LA_VERSION` | RO | 能读到 LA 版本 |
| `0x0068` | `LA_CONTROL` | RW | enable/auto_readout/trigger_enable 生效 |
| `0x006C` | `LA_STATUS` | RO/W1C | state/done/overflow/config_error/readout_busy 可见 |
| `0x0070` | `LA_SAMPLE_DIVISOR` | RW | 采样间隔变化 |
| `0x0074` | `LA_CAPTURE_DEPTH` | RW | 捕获 sample 数变化 |
| `0x0078` | `LA_PRETRIGGER_DEPTH` | RW | 触发点位置变化 |
| `0x007C` | `LA_TRIGGER_MODE` | RW | edge/level/mask 生效 |
| `0x0080` | `LA_TRIGGER_CHANNEL` | RW | 触发通道选择生效 |
| `0x0084` | `LA_TRIGGER_VALUE` | RW | 触发比较值生效 |
| `0x0088` | `LA_TRIGGER_MASK` | RW | mask match 生效 |
| `0x008C` | `LA_COMMAND` | TRIGGER | arm/stop/clear/force_trigger/start_readout 产生单周期脉冲 |
| `0x0090` | `LA_CAPTURE_ID` | RO | capture 完成后递增 |
| `0x0094` | `LA_CHANNEL_MASK` | RW | P0 可选 |

## 5. TX Path 仲裁

LA adapter 输出接入现有 Debug Core TX path 时，需要确认：

- LA readout 不饿死 Monitor response。
- Debug/Trace/Monitor/Profiler/LA 帧 type 保持独立。
- `msg_valid/msg_ready` backpressure 不丢帧。
- LA chunk readout 可暂停或由状态位显示 busy。
- UART 带宽不足时，Viewer 能看到 readout 进度和 dropped/overflow 统计。

建议 P0 仲裁优先级：

```text
Monitor response > Debug critical/status > Trace/Profiler > LA readout chunk
```

`LA_TRIGGER_EVENT` 和 `LA_CAPTURE_HEADER` 可高于普通 sample chunk。

## 6. 仿真

`tb_openfpga_debug_board_la.v` 覆盖：

- 读取 `LA_ID/LA_VERSION`。
- 写 LA 配置寄存器后读回一致。
- 写 `LA_COMMAND.arm` 后状态进入 ARMED。
- 触发 `debug_tx_valid` 或 `demo_frame_tick` 后产生 capture done。
- `start_readout` 后 UART TX path 输出 header、trigger event、data chunk 和 status。
- force trigger 能在无自然 trigger 时完成捕获。
- clear 后状态回到 IDLE。
- Debug/Trace/Monitor/Profiler/LA 帧共存，checksum 正确。

## 7. Vivado Elaboration

新增：

```text
vivado -mode batch -source prj/scripts/check_openfpga_la_m25_elab.tcl
```

期望：

```text
PASS: OpenFPGA Logic Analyzer M25 board demo Vivado RTL elaboration completed
```

## 8. 验收命令

```text
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\*.vh rtl\openfpga_debug\*.v rtl\board\openfpga_debug_board_demo.v sim\board\tb_openfpga_debug_board_la.v
xelab tb_openfpga_debug_board_la -s tb_openfpga_debug_board_la_sim
xsim tb_openfpga_debug_board_la_sim -runall
```

期望输出：

```text
PASS: OpenFPGA Logic Analyzer M25 board demo checks passed
```

Vivado elaboration：

```text
vivado -mode batch -source prj/scripts/check_openfpga_la_m25_elab.tcl
```

期望输出：

```text
PASS: OpenFPGA Logic Analyzer M25 board demo Vivado RTL elaboration completed
```

## 9. 使用说明

`doc/OpenFPGA_LogicAnalyzer_使用说明.md` 至少包含：

- LA P0 能力边界。
- Monitor register map。
- P0 通道 manifest。
- 典型 trigger 配置示例。
- Viewer arm/readout/export 操作流程。
- UART 带宽和 capture depth 建议。
- 与厂商 ILA 的关系和限制。

## 10. 留给 M26

- 生成并下载包含 LA 的 board demo bitstream。
- 完成真实串口链路板级验收。
- 连续运行 Debug/Trace/Monitor/Profiler/LA 共存长稳。
- 完成验证记录和发布 checklist。
## 11. 验收记录

截至 2026-07-06，M25 RTL board demo 接入已完成：

- `openfpga_debug_board_demo` 已实例化 `openfpga_la_probe_pack`、`openfpga_la_core` 和 `openfpga_la_adapter`。
- P0 32-bit probe 已接入 UART TX/RX、Debug TX、Trace、Monitor response、Profiler snapshot、demo frame tick、buffer used、demo FIFO level 和 LA state 摘要。
- Monitor register map 已扩展 `0x0060..0x0094`，支持 LA ID/version/config/status/command/capture_id/channel_mask。
- Debug TX path 已增加 LA readout 消息源；Monitor response 最高优先级，LA finite readout 优先于连续 Trace/Profiler，避免 capture readout starvation。
- 新增 `sim/board/tb_openfpga_debug_board_la.v`，覆盖 UART Monitor 配置、arm、force trigger、start readout、LA header/trigger/data/status 帧、clear。
- 新增 `prj/scripts/check_openfpga_la_m25_elab.tcl`，用于 Vivado RTL elaboration 检查。
- 新增 `doc/OpenFPGA_LogicAnalyzer_使用说明.md`。

已运行并通过：

```text
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug ... rtl\board\openfpga_debug_board_demo.v sim\board\tb_openfpga_debug_board_la.v
xelab tb_openfpga_debug_board_la -s tb_openfpga_debug_board_la_sim
xsim tb_openfpga_debug_board_la_sim -runall
PASS: OpenFPGA Logic Analyzer M25 board demo checks passed
```

回归已运行并通过：

```text
xsim tb_openfpga_debug_board_profiler_sim -runall
PASS: OpenFPGA Profiler M21 board demo checks passed

xsim tb_openfpga_la_core_sim -runall
PASS: OpenFPGA Logic Analyzer M23 core capture checks passed
```

Vivado elaboration 命令已准备，但尚未在本次实现中自动运行：

```text
vivado -mode batch -source prj/scripts/check_openfpga_la_m25_elab.tcl
```

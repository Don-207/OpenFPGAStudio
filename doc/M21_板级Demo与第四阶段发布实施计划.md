# M21 板级 Demo 与第四阶段发布实施计划

M21 是第四阶段 Profiler 的集成和发布里程碑。目标是在现有 board demo 中接入 Profiler Core 和典型 probe，并完成从仿真到板级长稳的验收闭环。

## 1. 目标

- 板级 demo 接入 Profiler Core、adapter 和典型 probe。
- Viewer 能观察 frame rate、FIFO level、throughput、latency 和 alert。
- Monitor 能控制 Profiler enable、sample period、clear 和 metric mask。
- 补齐 XSim、Vivado elaboration、使用说明、验证记录和发布 checklist。

## 2. 修改文件

```text
rtl/board/
  openfpga_debug_board_demo.v

sim/board/
  tb_openfpga_debug_board_profiler.v

prj/scripts/
  check_openfpga_profiler_m21_elab.tcl

doc/
  YiFPGA_Profiler_使用说明.md
  YiFPGA_Studio_第四阶段Profiler验证记录.md
  YiFPGA_Studio_第四阶段Profiler发布Checklist.md
```

## 3. Demo 指标

| metric_id | 名称 | 来源 |
| --- | --- | --- |
| `0x0001` | `AXIS_DEMO_THROUGHPUT` | demo 内部有效数据节拍 |
| `0x0101` | `FIFO_DEMO_LEVEL` | 模拟 FIFO level 或现有 buffer used |
| `0x0201` | `DEMO_LATENCY` | start/end demo 事务 |
| `0x0301` | `FRAME_RATE` | demo frame_done 周期 |

Alert 示例：

- FIFO level 超过阈值。
- Latency 超过阈值。
- Profiler snapshot drop 或 overflow。

## 4. Monitor Register Map 接入

在现有 Monitor map 后追加：

| 地址 | 名称 | 属性 | 验收 |
| --- | --- | --- | --- |
| `0x0040` | `PROFILER_ID` | RO | 能读到固定 ID |
| `0x0044` | `PROFILER_VERSION` | RO | 能读到版本 |
| `0x0048` | `PROFILER_CONTROL` | RW | enable 生效 |
| `0x004C` | `PROFILER_SAMPLE_PERIOD` | RW | snapshot 频率变化 |
| `0x0050` | `PROFILER_CLEAR` | TRIGGER | 统计清零 |
| `0x0054` | `PROFILER_STATUS` | RO/W1C | overflow/drop 可见且可清 |
| `0x0058` | `PROFILER_METRIC_MASK0` | RW | 可启停部分 metric |
| `0x005C` | `PROFILER_ALERT_THRESHOLD0` | RW | demo alert 阈值变化 |

## 5. 仿真

`tb_openfpga_debug_board_profiler.v` 覆盖：

- Profiler enable 后 UART TX 输出 snapshot。
- 调整 sample period 后 snapshot 间隔变化。
- 写 clear 后统计窗口清零。
- metric mask 禁用指定 metric 后不再上报。
- threshold 降低后产生 alert。
- Debug/Trace/Monitor/Profiler 帧在同一 TX path 中共存。

## 6. Vivado Elaboration

新增：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_profiler_m21_elab.tcl
```

期望：

```text
PASS: OpenFPGA Profiler M21 board demo Vivado RTL elaboration completed
```

## 7. 板级验收

1. 生成并下载包含 Profiler 的 bitstream。
2. 打开 Web Viewer，连接 UART。
3. 在 Monitor 视图读取 `PROFILER_ID/PROFILER_VERSION`。
4. 写 `PROFILER_CONTROL.enable = 1`。
5. 切换到 Profiler 视图，确认四类 demo metric 持续更新。
6. 修改 `PROFILER_SAMPLE_PERIOD`，确认 snapshot 频率随之变化。
7. 写 `PROFILER_CLEAR`，确认 counters 和趋势重新开始。
8. 降低 alert threshold，确认 Viewer 显示 alert。
9. 连续运行 30 分钟，确认 checksum error、drop、overflow 不持续增长。

## 8. 发布 Checklist

第四阶段发布前至少确认：

- [ ] `YiFPGA_Debug_Protocol_v1.md` 已补齐 Profiler 类型和 payload。
- [ ] Parser 回归测试通过。
- [ ] M18 Profiler Core XSim 通过。
- [ ] M19 Probe XSim 通过。
- [ ] M21 Board Demo XSim 通过。
- [ ] M21 Vivado elaboration 通过。
- [ ] Web Viewer Profiler 无硬件样例通过。
- [ ] JSONL/CSV 导出包含 Profiler 数据。
- [ ] Profiler 使用说明完成。
- [ ] 验证记录完成。
- [ ] Bitstream 构建完成。
- [ ] 板级 30 分钟长稳通过。

## 9. 验收命令

```powershell
python tools\viewer\protocol_parser_test.py
python tools\viewer\web\run_perf_test.py
```

```powershell
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_trace_pkg.vh rtl\openfpga_debug\openfpga_monitor_pkg.vh rtl\openfpga_debug\openfpga_profiler_pkg.vh rtl\openfpga_debug\*.v rtl\board\openfpga_debug_board_demo.v sim\board\tb_openfpga_debug_board_profiler.v
xelab tb_openfpga_debug_board_profiler -s tb_openfpga_debug_board_profiler_sim
xsim tb_openfpga_debug_board_profiler_sim -runall
```

期望输出：

```text
PASS: OpenFPGA Profiler M21 board demo checks passed
```

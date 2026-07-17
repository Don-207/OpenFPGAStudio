# OpenFPGA Studio 第四阶段 Profiler 实施计划

## 1. 阶段目标

根据 `YiFPGA_Studio_发展规划.docx`，第四阶段定位为 `OpenFPGA Profiler`：

- DDR、PCIe、AXI、FIFO、Latency、Frame Rate 统计。
- 将已有 Debug、Trace、Monitor 能力扩展为可长期运行的性能画像工具。
- 让开发者在不中断 bitstream 的情况下看到吞吐、拥塞、延迟、帧率和异常计数的趋势。

第四阶段承接前三阶段：Debug Core 提供基础上报链路，Trace 提供时间线事件，Monitor 提供受控读写和配置能力。Profiler 的核心目标不是捕获每一拍波形，而是把高频硬件行为压缩成低带宽、可解释、可长期观察的指标流。

## 2. 阶段边界

必须完成：

- 定义 Profiler 协议扩展，使用 `0x30..0x3F` 类型空间。
- 增加通用 `Profiler Core`，支持计数器、周期快照、峰值/谷值、最小/最大/平均延迟和溢出统计。
- 提供典型 probe：AXI Stream/FIFO、Frame Rate、Latency，DDR/PCIe 先以接口适配模板和文档约束落地。
- Web Viewer 增加 Profiler 视图，支持指标卡、趋势图、吞吐/延迟统计表、异常高亮和 JSONL/CSV 导出。
- 与 Monitor 联动，允许通过安全寄存器配置采样周期、清零计数器和启停 profiler。
- 提供板级 demo，能在现有 UART 带宽下稳定展示 frame rate、FIFO level、throughput 和 latency 示例。
- 增加 parser 回归、RTL 仿真、Vivado elaboration 和板级验收清单。

暂不完成：

- 连续波形采样、复杂触发捕获和采样深度管理，此项属于第五阶段 Open Logic Analyzer。
- AI 自动诊断和瓶颈根因推理，此项属于第六阶段 AI Debug。
- 完整 DDR 控制器、PCIe Endpoint 或 AXI interconnect IP 集成。第四阶段只提供 probe/adapter 和 demo 级统计入口。
- 任意地址性能采样或不受控总线窥探。Profiler 只观察显式接入的信号和计数窗口。
- 高带宽实时曲线全量传输。P0 采用周期摘要和限流上报，保证 UART 链路可用。

## 3. 总体架构

```text
User Logic / Bus / FIFO / Frame Path
    |
    | event, byte_count, level, start/end, error
    v
Profiler Probes
    |
    | metric update
    v
OpenFPGA Profiler Core
    |
    | periodic snapshot / alert / clear
    v
Debug Core TX path
    |
    | PROFILER_SNAPSHOT / PROFILER_ALERT
    v
Web Viewer Profiler View
    |
    | optional config/clear
    v
Monitor Register Map
```

模块边界：

- `Profiler Probe`：贴近被观察接口，产生计数、延迟、level、帧完成等低成本事件。
- `Profiler Core`：聚合指标，按窗口生成 snapshot，维护 min/max/sum/count/overflow。
- `Profiler Adapter`：把 snapshot 和 alert 打包成 Debug Protocol v1 帧。
- `Monitor Config`：复用第三阶段 Monitor，暴露 enable、sample_period、clear、drop_policy 等安全寄存器。
- `Viewer Profiler Model`：维护指标定义、最新值、历史窗口、阈值、单位和导出记录。

## 4. 协议扩展建议

沿用 Debug Protocol v1 帧格式：

```text
SOF + VER + TYPE + LEN + PAYLOAD + CHECKSUM
```

Profiler 第一版优先使用 FPGA 到 PC 的周期快照；PC 到 FPGA 的配置继续通过 Monitor 完成，避免新增并行控制面。

### 4.1 类型分配

| Type | 方向 | 名称 | 说明 |
| --- | --- | --- | --- |
| `0x30` | FPGA -> PC | `PROFILER_SNAPSHOT` | 周期指标快照 |
| `0x31` | FPGA -> PC | `PROFILER_ALERT` | 阈值、溢出、拥塞等异常 |
| `0x32` | FPGA -> PC | `PROFILER_COUNTER` | 单计数器低频更新，P0 可选 |
| `0x33` | FPGA -> PC | `PROFILER_LATENCY` | 延迟统计快照，P0 可并入 snapshot |
| `0x34` | FPGA -> PC | `PROFILER_DISCOVER` | 指标 manifest 摘要，P1 |
| `0x35` | PC -> FPGA | `PROFILER_CFG_REQ` | Profiler 专用配置，P1，P0 由 Monitor 替代 |
| `0x36` | FPGA -> PC | `PROFILER_CFG_RESP` | Profiler 配置响应，P1 |
| `0x37..0x3F` | 双向 | 保留 | 后续扩展 |

### 4.2 PROFILER_SNAPSHOT

P0 建议固定 32 字节 payload，正好适配当前 `LEN <= 32` 限制：

```text
u32 timestamp
u16 metric_id
u16 flags
u32 sample_cycles
u32 value0
u32 value1
u32 value2
u32 value3
u16 overflow_count
u16 reserved
```

字段含义由 `metric_id` 决定：

| metric_id 范围 | 类型 | value0 | value1 | value2 | value3 |
| --- | --- | --- | --- | --- | --- |
| `0x0001..0x00FF` | Throughput | bytes/words | beats | active_cycles | stall_cycles |
| `0x0100..0x01FF` | FIFO | current_level | max_level | min_level | overflow/underflow |
| `0x0200..0x02FF` | Latency | count | min | max | avg |
| `0x0300..0x03FF` | Frame Rate | frame_count | dropped_frames | min_interval | max_interval |
| `0x0400..0x04FF` | PCIe | posted_bytes | completion_bytes | retry/error | backpressure |
| `0x0500..0x05FF` | DDR | read_bytes | write_bytes | busy_cycles | stall_cycles |

`flags` 建议：

| Bit | 名称 | 说明 |
| --- | --- | --- |
| `0` | `VALID` | 当前 snapshot 有效 |
| `1` | `SATURATED` | 计数器发生饱和 |
| `2` | `WINDOW_RESET` | 本帧之后窗口已清零 |
| `3` | `PARTIAL` | 窗口未满但被提前上报 |
| `4` | `ALERT` | 同窗口存在异常 |

### 4.3 PROFILER_ALERT

```text
u32 timestamp
u16 metric_id
u8  level
u8  code
u32 arg0
u32 arg1
```

长度：16 字节。

`level` 复用 EVENT 的 Debug/Info/Warning/Error。`code` 建议：

| Code | 名称 | 说明 |
| --- | --- | --- |
| `1` | `THRESHOLD_HIGH` | 指标超过上限 |
| `2` | `THRESHOLD_LOW` | 指标低于下限 |
| `3` | `OVERFLOW` | 统计计数器溢出或饱和 |
| `4` | `UNDERFLOW` | FIFO 或流控下溢 |
| `5` | `TIMEOUT` | 延迟超过窗口上限 |
| `6` | `DROP` | Profiler 或 Debug Core 丢弃统计帧 |

## 5. RTL 实施计划

建议新增：

```text
rtl/openfpga_debug/
  openfpga_profiler_pkg.vh
  openfpga_profiler_core.v
  openfpga_profiler_counter.v
  openfpga_profiler_latency.v
  openfpga_profiler_fifo_probe.v
  openfpga_profiler_frame_probe.v
  openfpga_profiler_axis_probe.v
  openfpga_profiler_adapter.v
```

职责：

- `openfpga_profiler_pkg.vh`：Profiler type、metric_id、flags、alert code、默认窗口参数。
- `openfpga_profiler_counter.v`：通用饱和计数、清零、快照寄存器。
- `openfpga_profiler_latency.v`：start/end 事件匹配，统计 count/min/max/sum/avg。
- `openfpga_profiler_fifo_probe.v`：采集 FIFO level、almost_full、overflow、underflow。
- `openfpga_profiler_frame_probe.v`：采集 frame count、drop、帧间隔和帧率。
- `openfpga_profiler_axis_probe.v`：采集 AXI Stream valid/ready、beat、byte、stall、active cycles。
- `openfpga_profiler_core.v`：统一 sample tick、snapshot 仲裁、alert 生成和 clear 控制。
- `openfpga_profiler_adapter.v`：打包 `PROFILER_SNAPSHOT/ALERT` 并注入 Debug Core TX path。

实现原则：

- 所有计数器同步复位，清零由 Monitor 触发单周期 pulse。
- 高速接口 probe 只输出事件和计数，不直接参与 UART 打包。
- 跨时钟域的 probe 必须先用同步计数快照或 async FIFO 汇聚到 Debug Core 时钟域。
- 延迟统计 P0 支持单 outstanding 或显式 `tag` 限制；多 outstanding 事务放到 P1。
- 计数器溢出必须可见，不能静默回绕。

## 6. Monitor 配置窗口

第四阶段复用 Monitor 增加 Profiler 控制寄存器：

| 地址 | 名称 | 属性 | 说明 |
| --- | --- | --- | --- |
| `0x0040` | `PROFILER_ID` | RO | 固定标识，例如 `0x4F465034` |
| `0x0044` | `PROFILER_VERSION` | RO | Profiler 版本 |
| `0x0048` | `PROFILER_CONTROL` | RW | enable、auto_clear、alert_enable |
| `0x004C` | `PROFILER_SAMPLE_PERIOD` | RW | snapshot 周期，单位为 Debug Core clock cycle |
| `0x0050` | `PROFILER_CLEAR` | TRIGGER | 清零所有统计窗口 |
| `0x0054` | `PROFILER_STATUS` | RO/W1C | overflow、drop、busy、cdc_error |
| `0x0058` | `PROFILER_METRIC_MASK0` | RW | 启用 metric_id 低位组 |
| `0x005C` | `PROFILER_ALERT_THRESHOLD0` | RW | demo 阈值或默认告警阈值 |

P0 可以把这些寄存器放入现有 board demo register bank；P1 再拆出独立 profiler register bank。

## 7. Viewer 实施计划

Web Viewer 新增 `Profiler` 视图：

- 指标总览：吞吐、FIFO level、latency、frame rate、drop/overflow。
- 趋势图：按 metric_id 保留最近 N 个 snapshot，显示 value0..value3。
- 统计表：显示单位、当前值、min/max/avg、窗口周期、更新时间。
- Alert 面板：显示阈值、溢出、下溢、timeout、drop。
- 控制区：复用 Monitor 命令读写 `PROFILER_CONTROL/SAMPLE_PERIOD/CLEAR`。
- 导出：JSONL 增加 `profiler_snapshot`、`profiler_alert`，CSV 支持按 metric 导出。
- `Inject Sample` 增加 Profiler 示例，覆盖 throughput、FIFO、latency、frame rate 和 alert。

UI 原则：

- 工程工具优先，保持密集、可扫描，不做营销式展示。
- 单位必须明确：B/s、beats/s、cycles、frames/s、level、count。
- 在 UART 低带宽场景下默认只显示最近窗口，长历史通过导出保存。
- Alert 不阻塞实时数据流，失败配置通过 Monitor 错误路径显示。

## 8. 里程碑拆分

### M17：Profiler 协议与指标模型

目标：

- 固化 `0x30..0x3F` Profiler 类型空间。
- 更新协议文档，定义 `PROFILER_SNAPSHOT/ALERT` payload。
- Web Viewer 增加 Profiler parser、metric model 和测试钩子。
- 增加 parser 回归测试向量。

交付物：

- `doc/YiFPGA_Debug_Protocol_v1.md` Profiler 扩展章节。
- `tools/viewer/protocol_parser_test.py` Profiler 测试向量。
- `tools/viewer/web/app.js` Profiler parser/model。
- `doc/M17_Profiler_协议与指标模型实施计划.md`

### M18：RTL Profiler Core 与计数窗口

目标：

- 新增 Profiler 常量包、通用计数器、核心聚合模块和 adapter。
- 支持周期 snapshot、手动 clear、overflow 标记和 alert 输出。
- 提供核心 RTL 仿真。

交付物：

- `rtl/openfpga_debug/openfpga_profiler_pkg.vh`
- `rtl/openfpga_debug/openfpga_profiler_counter.v`
- `rtl/openfpga_debug/openfpga_profiler_core.v`
- `rtl/openfpga_debug/openfpga_profiler_adapter.v`
- `sim/openfpga_debug/tb_openfpga_profiler_core.v`

### M19：典型 Profiler Probe

目标：

- 新增 AXI Stream/FIFO/Frame/Latency probe。
- 覆盖 valid/ready stall、FIFO level 峰值、帧率、drop 和单 outstanding latency。
- 给 DDR/PCIe 提供接入模板和注意事项。

交付物：

- `rtl/openfpga_debug/openfpga_profiler_axis_probe.v`
- `rtl/openfpga_debug/openfpga_profiler_fifo_probe.v`
- `rtl/openfpga_debug/openfpga_profiler_frame_probe.v`
- `rtl/openfpga_debug/openfpga_profiler_latency.v`
- `sim/openfpga_debug/tb_openfpga_profiler_probes.v`
- `doc/YiFPGA_Profiler_Probe接入说明.md`

### M20：Profiler Viewer 视图

目标：

- Web Viewer 新增 Profiler 标签页。
- 支持指标卡、趋势图、统计表、alert 列表、配置/清零入口和导出。
- 保持 Log/Trace/Monitor 视图不回退。

交付物：

- `tools/viewer/web/index.html`
- `tools/viewer/web/app.js`
- `tools/viewer/web/styles.css`
- `doc/YiFPGA_Web_Viewer_使用说明.md` Profiler 章节。
- `doc/M20_Profiler_Viewer实施计划.md`

### M21：板级 Demo 与第四阶段发布

目标：

- board demo 接入 Profiler Core 和典型 probe。
- Viewer 能观察 frame rate、FIFO level、throughput、latency 和 alert 示例。
- 完成 parser、XSim、Vivado elaboration、bitstream、板级长稳和文档整理。

交付物：

- `rtl/board/openfpga_debug_board_demo.v` Profiler 接入。
- `sim/board/tb_openfpga_debug_board_profiler.v`
- `prj/scripts/check_openfpga_profiler_m21_elab.tcl`
- `doc/YiFPGA_Profiler_使用说明.md`
- `doc/YiFPGA_Studio_第四阶段Profiler验证记录.md`
- `doc/YiFPGA_Studio_第四阶段Profiler发布Checklist.md`
- `doc/M21_板级Demo与第四阶段发布实施计划.md`

## 9. 验收场景

### 9.1 无硬件验收

打开 `tools/viewer/web/index.html` 后点击 `Inject Sample`：

- Profiler 视图出现吞吐、FIFO、Latency、Frame Rate 指标。
- 趋势图能按时间追加 snapshot。
- Alert 面板能显示 overflow、threshold、timeout 示例。
- JSONL 导出包含 `profiler_snapshot` 和 `profiler_alert`。
- Monitor 控制区能生成 sample period、clear、enable 对应命令帧。

### 9.2 RTL 仿真验收

建议新增：

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_profiler_pkg.vh rtl\openfpga_debug\openfpga_profiler_counter.v rtl\openfpga_debug\openfpga_profiler_core.v rtl\openfpga_debug\openfpga_profiler_adapter.v sim\openfpga_debug\tb_openfpga_profiler_core.v
xelab tb_openfpga_profiler_core -s tb_openfpga_profiler_core_sim
xsim tb_openfpga_profiler_core_sim -runall
```

Probe：

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_profiler_pkg.vh rtl\openfpga_debug\openfpga_profiler_axis_probe.v rtl\openfpga_debug\openfpga_profiler_fifo_probe.v rtl\openfpga_debug\openfpga_profiler_frame_probe.v rtl\openfpga_debug\openfpga_profiler_latency.v sim\openfpga_debug\tb_openfpga_profiler_probes.v
xelab tb_openfpga_profiler_probes -s tb_openfpga_profiler_probes_sim
xsim tb_openfpga_profiler_probes_sim -runall
```

### 9.3 Vivado Elaboration

建议新增：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_profiler_m21_elab.tcl
```

期望：

```text
PASS: OpenFPGA Profiler M21 board demo Vivado RTL elaboration completed
```

### 9.4 板级验收

使用 Chrome 或 Edge 打开 Web Viewer：

1. 下载包含 Profiler 的 board demo bitstream。
2. 连接 FPGA UART TX/RX，并选择与 RTL 一致的 baud rate。
3. 在 Monitor 视图读取 `PROFILER_ID/PROFILER_VERSION`。
4. 写 `PROFILER_CONTROL.enable = 1`。
5. 设置 `PROFILER_SAMPLE_PERIOD`，观察 Profiler snapshot 频率变化。
6. 观察 Frame Rate、FIFO level、Throughput、Latency 指标持续更新。
7. 触发 demo 阈值或 overflow 场景，确认 Alert 可见。
8. 写 `PROFILER_CLEAR`，确认统计窗口清零。
9. 连续运行 30 分钟，确认 Debug/Trace/Monitor/Profiler 四类流量共存，checksum error 和 drop 不持续增长。

## 10. 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| UART 带宽不足 | Profiler snapshot 挤占 Debug/Trace/Monitor | 默认低频窗口、metric mask、drop 可见、优先保证控制响应 |
| 指标语义不统一 | Viewer 显示难以解释 | 先固化 metric_id、单位、value 字段含义和 manifest |
| 高速接口跨时钟域 | 统计不稳定或亚稳态 | probe 在源时钟域计数，快照用同步握手或 async FIFO 汇聚 |
| 计数器溢出 | 性能数据失真 | 使用饱和计数和 overflow flag，Viewer 高亮 |
| 延迟统计多 outstanding 复杂 | P0 范围膨胀 | P0 只做单 outstanding 或显式 tag 限制，多事务放 P1 |
| Profiler 和 Trace 重叠 | 功能边界混乱 | Trace 记录事务时间线，Profiler 输出窗口化统计摘要 |
| DDR/PCIe 依赖 vendor IP | 难以一次性完成 | 第四阶段先交付 probe 模板和 demo 指标，真实 IP 接入作为 P1 |

## 11. 推荐优先级

建议按 `M17 -> M18 -> M19 -> M20 -> M21` 推进：

1. 先固化协议和指标模型，避免 RTL、Viewer、文档对 `metric_id/value` 理解不一致。
2. 再实现 Profiler Core，先证明周期快照、清零和溢出路径可靠。
3. 然后补典型 probe，把吞吐、FIFO、帧率和延迟四类指标做成可复用模块。
4. 接着做 Viewer，让无硬件样例先跑通展示、导出和错误显示。
5. 最后接入 board demo，完成仿真、elaboration、bitstream 和板级长稳验收。

这样第四阶段可以在现有 UART 调试链路上稳妥扩展性能画像能力，同时为后续 PCIe/Ethernet 高带宽传输和 AI Debug 积累结构化指标数据。

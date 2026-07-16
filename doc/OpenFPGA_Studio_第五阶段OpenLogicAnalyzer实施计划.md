# OpenFPGA Studio 第五阶段 Open Logic Analyzer 实施计划

## 1. 阶段目标

根据 `OpenFPGA_Studio_发展规划.docx`，第五阶段定位为 `Open Logic Analyzer`：

- 提供统一逻辑分析接口，减少对 Vivado ILA、SignalTap 等厂商工具的绑定。
- 在现有 Debug、Trace、Monitor、Profiler 能力之上，增加可触发、可缓冲、可回放的波形级采样能力。
- 让开发者在不重新切换厂商逻辑分析工具的情况下，完成常见信号捕获、触发定位、波形查看和导出。

第五阶段不是要一次替代所有厂商 ILA 功能，而是先交付一个跨厂商、低资源、可嵌入 board demo 的 P0 版本：支持有限通道、有限深度、单时钟域优先、基本触发和 Web Viewer 波形展示。

## 2. 阶段边界

必须完成：

- 定义 Logic Analyzer 协议扩展，使用 Debug Protocol v1 中已预留的 `0x40..0x4F` 类型空间。
- 新增通用 `Logic Analyzer Core`，支持信号打包、采样使能、预触发/后触发采样、环形采样缓冲和捕获状态机。
- 提供基础 trigger engine，支持边沿、等值、掩码匹配、简单多条件 AND/OR。
- 通过 Monitor 暴露配置寄存器：enable、sample divisor、trigger mode、trigger value/mask、capture depth、pre-trigger depth、arm、stop、clear、status。
- Web Viewer 新增 `Analyzer` 或 `Logic` 视图，支持通道列表、数字波形、触发位置、缩放/平移、游标测量、VCD/JSONL 导出。
- board demo 接入一组代表性信号：UART TX/RX 状态、Debug Core buffer、Trace/Monitor/Profiler valid、demo FIFO level 低位、frame tick 等。
- 增加 parser 回归、RTL 仿真、Viewer 无硬件样例、Vivado elaboration 和板级验收记录。

暂不完成：

- 高速全带宽连续流式波形上传。P0 采用捕获后分片读取，避免占满 UART。
- 多时钟域自动合并波形。P0 单 LA core 对应单采样时钟；跨域信号需要先同步或在 P1 增加多 core。
- 任意层级信号自动发现。P0 使用显式 probe port 和静态 channel manifest。
- 压缩波形、复杂状态机触发、跨触发组序列匹配。此类能力放到 P1/P2。
- 替代厂商在线 JTAG ILA 的全部交互体验。第五阶段优先建立开放协议、RTL core 和 Viewer 闭环。
- AI 自动分析波形根因。此项属于第六阶段 AI Debug。

## 3. 总体架构

```text
User Logic / Debug Core / Board Demo Signals
    |
    | sample_bus, channel_manifest
    v
OpenFPGA Logic Analyzer Core
    |
    | trigger / circular buffer / capture window
    v
Analyzer Readout Adapter
    |
    | chunked waveform frames
    v
Debug Core TX path
    |
    | LA_HEADER / LA_DATA / LA_STATUS / LA_TRIGGER
    v
Web Viewer Logic Analyzer View
    ^
    | arm / config / readback
    |
Monitor Register Map
```

模块边界：

- `LA Probe`：把离散信号、状态位、计数器低位打包为固定宽度 `sample_bus`。
- `LA Core`：维护采样时钟、trigger 判断、环形缓冲、捕获状态、触发点索引和读出地址。
- `LA Adapter`：把 captured samples 分片打包为 Debug Protocol v1 帧，并注入现有 TX path。
- `Monitor Config`：负责配置 trigger、depth、sample divisor、arm/stop/clear 和 readout 请求。
- `Viewer LA Model`：维护 capture metadata、channel manifest、sample chunks、触发点、游标、导出记录。

## 4. 协议扩展建议

沿用 Debug Protocol v1 帧格式：

```text
SOF + VER + TYPE + LEN + PAYLOAD + CHECKSUM
```

P0 设计原则：

- PC 到 FPGA 的控制仍复用 Monitor request/response，不新增第二套控制面。
- FPGA 到 PC 的波形数据使用 `0x40..0x4F` 类型空间。
- 单帧 payload 仍遵守 `LEN <= 32`，大 capture 通过 chunk 分片上传。
- Viewer 必须支持乱序防护和丢帧可见，但 P0 可以要求同一次 capture 的 chunk 顺序发送。

### 4.1 类型分配

| Type | 方向 | 名称 | 说明 |
| --- | --- | --- | --- |
| `0x40` | FPGA -> PC | `LA_CAPTURE_HEADER` | 一次捕获的元信息 |
| `0x41` | FPGA -> PC | `LA_SAMPLE_DATA` | 分片 sample 数据 |
| `0x42` | FPGA -> PC | `LA_CAPTURE_STATUS` | 捕获状态、错误和进度 |
| `0x43` | FPGA -> PC | `LA_TRIGGER_EVENT` | 触发命中事件 |
| `0x44` | FPGA -> PC | `LA_CHANNEL_MANIFEST` | 通道定义摘要，P0 可选 |
| `0x45` | PC -> FPGA | `LA_CFG_REQ` | 专用配置请求，预留，P0 由 Monitor 替代 |
| `0x46` | FPGA -> PC | `LA_CFG_RESP` | 专用配置响应，预留 |
| `0x47..0x4F` | 双向 | 保留 | 后续压缩、序列触发、多 core 扩展 |

### 4.2 LA_CAPTURE_HEADER

建议固定 24 字节 payload：

```text
u32 capture_id
u32 timestamp
u16 sample_width_bits
u16 sample_count
u16 trigger_index
u16 flags
u32 sample_period_cycles
u16 channel_count
u16 reserved
```

`flags` 建议：

| Bit | 名称 | 说明 |
| --- | --- | --- |
| `0` | `VALID` | 本次捕获有效 |
| `1` | `TRIGGERED` | 已命中 trigger |
| `2` | `FORCED` | 由 stop/force 结束 |
| `3` | `OVERFLOW` | capture 或 readout 发生溢出 |
| `4` | `PARTIAL` | 未采满即结束 |

### 4.3 LA_SAMPLE_DATA

P0 建议单帧 32 字节 payload：

```text
u32 capture_id
u16 chunk_index
u16 first_sample_index
u8  sample_bytes
u8  sample_count
u16 flags
u8  data[20]
```

说明：

- `sample_bytes` 是单个 sample 打包后的字节数，P0 建议支持 1、2、4。
- `data` 小端紧凑排列，不足 20 字节的尾帧补 0。
- 当 `sample_width_bits > 32` 时，P0 可拒绝配置；P1 再支持宽 sample 多帧拼接。

### 4.4 LA_CAPTURE_STATUS

```text
u32 timestamp
u32 capture_id
u8  state
u8  error
u16 samples_written
u16 chunks_sent
u16 chunks_total
u32 status_flags
```

`state` 建议：

| 值 | 名称 | 说明 |
| --- | --- | --- |
| `0` | `IDLE` | 未使能 |
| `1` | `ARMED` | 等待 trigger |
| `2` | `CAPTURING` | 已触发或正在填充窗口 |
| `3` | `DONE` | 捕获完成，可读出 |
| `4` | `READOUT` | 正在上传分片 |
| `5` | `ERROR` | 配置或运行错误 |

### 4.5 LA_TRIGGER_EVENT

```text
u32 timestamp
u32 capture_id
u16 trigger_index
u16 trigger_channel
u32 sample_value
u32 trigger_value
```

长度 20 字节。P0 若 trigger 是多条件组合，`trigger_channel` 可填第一个命中条件的通道号，完整条件通过配置寄存器和 Viewer manifest 解释。

## 5. RTL 实施计划

建议新增：

```text
rtl/openfpga_debug/
  openfpga_la_pkg.vh
  openfpga_la_probe_pack.v
  openfpga_la_trigger.v
  openfpga_la_core.v
  openfpga_la_adapter.v
```

职责：

- `openfpga_la_pkg.vh`：LA type、状态、flags、错误码、默认深度、寄存器地址和 trigger 模式。
- `openfpga_la_probe_pack.v`：把多个 1-bit/多 bit 信号组合为固定宽度 sample。
- `openfpga_la_trigger.v`：实现 edge、level、mask match 和简单 AND/OR 条件。
- `openfpga_la_core.v`：实现采样分频、环形 buffer、预触发窗口、后触发计数、capture_id 和状态机。
- `openfpga_la_adapter.v`：读取 buffer，生成 header/status/trigger/data chunk，并接入 Debug Core TX path。

实现原则：

- P0 默认 sample width 不超过 32 bit，sample depth 建议从 64/128 起步，避免资源和 UART 上传时间失控。
- sample buffer 优先使用寄存器数组，P1 再提供 BRAM 版本。
- trigger 和采样逻辑与 readout 解耦；readout 慢不能影响下一次 arm 的状态可见性。
- `arm`、`stop`、`clear` 由 Monitor 寄存器产生单周期 pulse。
- 所有计数器饱和或显式标记 overflow，不静默回绕。
- 跨时钟域信号必须在进入 LA core 前同步；文档要明确 sample clock 和被采样信号的关系。

## 6. Monitor 配置窗口

第五阶段复用 Monitor 增加 Logic Analyzer 控制寄存器。建议地址从 Profiler 后续空间之后开始：

| 地址 | 名称 | 属性 | 说明 |
| --- | --- | --- | --- |
| `0x0060` | `LA_ID` | RO | 固定标识，例如 `0x4F464C41` |
| `0x0064` | `LA_VERSION` | RO | Logic Analyzer 版本 |
| `0x0068` | `LA_CONTROL` | RW | enable、auto_readout、trigger_enable |
| `0x006C` | `LA_STATUS` | RO/W1C | state、done、overflow、config_error、readout_busy |
| `0x0070` | `LA_SAMPLE_DIVISOR` | RW | 每 N 个 Debug Core clock 采 1 次 |
| `0x0074` | `LA_CAPTURE_DEPTH` | RW | 本次捕获 sample 数，不能超过实现上限 |
| `0x0078` | `LA_PRETRIGGER_DEPTH` | RW | trigger 前保留 sample 数 |
| `0x007C` | `LA_TRIGGER_MODE` | RW | edge、level、mask、AND/OR |
| `0x0080` | `LA_TRIGGER_CHANNEL` | RW | 触发通道或通道组 |
| `0x0084` | `LA_TRIGGER_VALUE` | RW | 触发比较值 |
| `0x0088` | `LA_TRIGGER_MASK` | RW | 触发比较 mask |
| `0x008C` | `LA_COMMAND` | TRIGGER | arm、stop、clear、force_trigger、start_readout |
| `0x0090` | `LA_CAPTURE_ID` | RO | 当前或最近一次 capture id |
| `0x0094` | `LA_CHANNEL_MASK` | RW | P0 可选，控制哪些通道显示或参与 trigger |

P0 可以固定 channel manifest，只允许修改 trigger 和深度；P1 再加入动态通道描述和多组 trigger。

## 7. Viewer 实施计划

Web Viewer 新增 Logic Analyzer 视图：

- Capture 控制区：arm、stop、force trigger、clear、start readout。
- 配置区：sample divisor、capture depth、pre-trigger depth、trigger channel、trigger mode、value、mask。
- 波形区：数字波形轨道、触发线、时间刻度、缩放、平移。
- 通道列表：名称、bit index、当前游标值、显示开关、颜色。
- 游标测量：cursor A/B、delta samples、delta cycles、按 sample period 换算时间。
- 状态区：capture_id、state、samples、chunks、overflow、dropped frames、parser malformed。
- 导出：VCD、JSONL；CSV 可选，仅导出 sample index 和 packed value。
- `Inject Sample` 增加 LA 示例，覆盖 header、data chunks、trigger event 和 malformed chunk。

UI 原则：

- 工程工具优先，波形区域要密集、可扫描，避免营销式大卡片。
- 默认显示有限样本，上传完成前可先显示进度，不阻塞 Debug/Trace/Monitor/Profiler 视图。
- 所有配置失败通过 Monitor errors 和 LA status 同时可见。
- 波形数据和现有日志导出共存，JSONL 中新增 `la_capture_header`、`la_sample`、`la_status`、`la_trigger_event`。

## 8. 里程碑拆分

### M22：Logic Analyzer 协议与捕获模型

目标：

- 固化 `0x40..0x4F` Logic Analyzer 类型空间。
- 更新协议文档，定义 header、sample data、status、trigger event payload。
- Web Viewer parser 增加 LA frame 解码、capture model 和测试钩子。
- 增加 parser 回归测试向量，覆盖分片、乱序/缺片提示、malformed 长度。

交付物：

- `doc/OpenFPGA_Debug_Protocol_v1.md` Logic Analyzer 扩展章节。
- `tools/viewer/protocol_parser_test.py` LA 测试向量。
- `tools/viewer/web/app.js` LA parser/model。
- `doc/M22_LogicAnalyzer_协议与捕获模型实施计划.md`

### M23：RTL Logic Analyzer Core

目标：

- 新增 LA 常量包、probe pack、trigger engine、capture core 和 adapter。
- 支持 sample divisor、pre-trigger、post-trigger、ring buffer、capture_id、status 和 chunk readout。
- 提供核心 RTL 仿真，覆盖 arm、trigger、force trigger、clear、overflow 和 readout。

交付物：

- `rtl/openfpga_debug/openfpga_la_pkg.vh`
- `rtl/openfpga_debug/openfpga_la_probe_pack.v`
- `rtl/openfpga_debug/openfpga_la_trigger.v`
- `rtl/openfpga_debug/openfpga_la_core.v`
- `rtl/openfpga_debug/openfpga_la_adapter.v`
- `sim/openfpga_debug/tb_openfpga_la_core.v`

### M24：Logic Analyzer Viewer 视图

目标：

- Web Viewer 新增 Logic Analyzer 标签页。
- 支持数字波形绘制、通道列表、trigger marker、游标、缩放和平移。
- 支持 Monitor 配置和控制 LA capture。
- 支持 VCD/JSONL 导出和无硬件注入样例。

交付物：

- `tools/viewer/web/index.html`
- `tools/viewer/web/app.js`
- `tools/viewer/web/styles.css`
- `doc/OpenFPGA_Web_Viewer_使用说明.md` Logic Analyzer 章节。
- `doc/M24_LogicAnalyzer_Viewer实施计划.md`

### M25：典型 Probe 与 Board Demo 接入

目标：

- board demo 接入 LA core，采样一组覆盖 Debug/Trace/Monitor/Profiler 的代表性信号。
- Monitor register map 接入 LA 配置窗口。
- Viewer 能 arm capture、触发、读取 chunk 并显示波形。
- 补齐 board demo XSim 和 Vivado elaboration。

建议 P0 通道：

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

交付物：

- `rtl/board/openfpga_debug_board_demo.v` LA 接入。
- `sim/board/tb_openfpga_debug_board_la.v`
- `prj/scripts/check_openfpga_la_m25_elab.tcl`
- `doc/OpenFPGA_LogicAnalyzer_使用说明.md`
- `doc/M25_典型Probe与BoardDemo接入实施计划.md`

### M26：板级验证与第五阶段发布

目标：

- 生成并下载包含 LA 的 board demo bitstream。
- 在真实串口链路上完成 arm、trigger、readout、waveform display、export 验收。
- 连续运行 Debug/Trace/Monitor/Profiler/Logic Analyzer 共存场景，确认控制响应和数据上传稳定。
- 完成验证记录、发布 checklist 和使用说明。

交付物：

- `doc/OpenFPGA_Studio_第五阶段OpenLogicAnalyzer验证记录.md`
- `doc/OpenFPGA_Studio_第五阶段OpenLogicAnalyzer发布Checklist.md`
- `doc/M26_板级验证与第五阶段发布实施计划.md`

## 9. 验收场景

### 9.1 无硬件验收

打开 `tools/viewer/web/index.html` 后点击 `Inject Sample`：

- Logic Analyzer 视图出现一次 capture。
- Header 显示 capture_id、sample width、sample count、trigger index。
- 波形区显示多通道数字波形，trigger marker 位于预期位置。
- 游标 A/B 可以测量 sample delta 和 cycle delta。
- JSONL 导出包含 LA header、sample、status 和 trigger event。
- VCD 导出可被 GTKWave 或其他 VCD 工具打开。
- 注入错误长度或缺失 chunk 时，malformed/missing 计数增加且 UI 不崩溃。

### 9.2 RTL 仿真验收

建议新增：

```powershell
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_la_pkg.vh rtl\openfpga_debug\openfpga_la_probe_pack.v rtl\openfpga_debug\openfpga_la_trigger.v rtl\openfpga_debug\openfpga_la_core.v rtl\openfpga_debug\openfpga_la_adapter.v sim\openfpga_debug\tb_openfpga_la_core.v
xelab tb_openfpga_la_core -s tb_openfpga_la_core_sim
xsim tb_openfpga_la_core_sim -runall
```

期望输出：

```text
PASS: OpenFPGA Logic Analyzer M23 core capture checks passed
```

Board demo：

```powershell
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\*.vh rtl\openfpga_debug\*.v rtl\board\openfpga_debug_board_demo.v sim\board\tb_openfpga_debug_board_la.v
xelab tb_openfpga_debug_board_la -s tb_openfpga_debug_board_la_sim
xsim tb_openfpga_debug_board_la_sim -runall
```

期望输出：

```text
PASS: OpenFPGA Logic Analyzer M25 board demo checks passed
```

### 9.3 Vivado Elaboration

建议新增：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_la_m25_elab.tcl
```

期望输出：

```text
PASS: OpenFPGA Logic Analyzer M25 board demo Vivado RTL elaboration completed
```

### 9.4 板级验收

使用 Chrome 或 Edge 打开 Web Viewer：

1. 下载包含 Logic Analyzer 的 board demo bitstream。
2. 连接 FPGA UART TX/RX，并选择与 RTL 一致的 baud rate。
3. 在 Monitor 视图读取 `LA_ID/LA_VERSION`。
4. 设置 `LA_SAMPLE_DIVISOR`、`LA_CAPTURE_DEPTH`、`LA_PRETRIGGER_DEPTH`。
5. 配置 trigger channel/value/mask，例如捕获 `debug_tx_valid` 上升沿。
6. 写 `LA_COMMAND.arm`，确认 `LA_STATUS.state = ARMED`。
7. 触发 demo 事件，确认 `LA_TRIGGER_EVENT` 和 capture done。
8. 写 `LA_COMMAND.start_readout` 或启用 auto_readout，等待 chunks 上传完成。
9. 切换到 Logic Analyzer 视图，确认波形、触发线和通道名正确。
10. 导出 VCD/JSONL，确认文件包含本次 capture。
11. 连续运行 30 分钟，确认 Debug/Trace/Monitor/Profiler/LA 共存，checksum error、drop、overflow 不持续增长。

## 10. 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| UART 带宽不足 | 波形上传慢，挤占其他调试数据 | 捕获后分片读出、默认小深度、readout 可停止、状态和 drop 可见 |
| 资源占用过高 | board demo 难以收敛或小 FPGA 不适用 | P0 限制 32 bit x 128 samples，先用寄存器数组，BRAM 作为 P1 |
| 跨时钟域采样不可靠 | 波形误导调试判断 | P0 明确单采样时钟，跨域信号先同步，多 core 放到 P1 |
| trigger 复杂度膨胀 | RTL 和 UI 范围失控 | P0 只做 edge、level、mask、简单 AND/OR，序列触发后移 |
| chunk 缺失或乱序 | Viewer 波形错误 | capture_id、chunk_index、sample index 全部校验，缺片显式标红 |
| 与 Trace 边界混淆 | 功能重复、使用心智混乱 | Trace 记录事件时间线，LA 捕获位级波形窗口 |
| 与厂商 ILA 预期差距大 | 用户误以为 P0 要替代完整 ILA | 文档明确 P0 是开放轻量 LA，厂商深度调试仍可并行使用 |

## 11. 推荐优先级

建议按 `M22 -> M23 -> M24 -> M25 -> M26` 推进：

1. 先固化协议和 capture model，避免 RTL、Viewer、文档对 chunk、trigger index、sample width 理解不一致。
2. 再实现 LA Core，先证明 arm、trigger、pre-trigger、readout 和 clear 路径可靠。
3. 然后做 Viewer 波形视图，让无硬件样例先跑通显示、游标和导出。
4. 接着接入 board demo，用 Debug/Trace/Monitor/Profiler 的真实内部信号验证工具价值。
5. 最后完成 bitstream、板级长稳、使用说明、验证记录和发布 checklist。

这样第五阶段可以在现有 UART 调试链路上建立开放逻辑分析闭环，为后续 USB/Ethernet/PCIe 高带宽传输、深采样缓存和第六阶段 AI Debug 波形分析打基础。

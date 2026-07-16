# M23 RTL Logic Analyzer Core 实施计划

M23 目标是在 RTL 侧建立第五阶段的通用 Logic Analyzer 核心。它先提供采样、触发、环形缓冲、捕获窗口和分片读出能力，不绑定具体 board demo probe；board demo 接入放到 M25。

## 1. 目标

- 新增 LA 常量包、probe pack、trigger engine、capture core 和 adapter。
- 支持 sample divisor、pre-trigger、post-trigger、ring buffer、capture_id、status 和 chunk readout。
- 通过现有 Debug Core TX path 发送 `LA_CAPTURE_HEADER`、`LA_SAMPLE_DATA`、`LA_CAPTURE_STATUS` 和 `LA_TRIGGER_EVENT`。
- 提供核心 RTL 仿真，覆盖 arm、trigger、force trigger、clear、overflow 和 readout。

## 2. 新增文件

```text
rtl/openfpga_debug/
  openfpga_la_pkg.vh
  openfpga_la_probe_pack.v
  openfpga_la_trigger.v
  openfpga_la_core.v
  openfpga_la_adapter.v

sim/openfpga_debug/
  tb_openfpga_la_core.v

prj/scripts/
  check_openfpga_la_m23_elab.tcl
  build_openfpga_la_m23_bitstream.tcl
```

## 3. 模块职责

### openfpga_la_pkg.vh

- 定义 LA type：`0x40..0x46`。
- 定义 capture state、flags、error code、trigger mode 和默认参数。
- 定义 Monitor register address：`0x0060..0x0094`。
- 定义 P0 最大 sample width、sample depth 和 payload 长度。

### openfpga_la_probe_pack.v

- 把离散 1-bit 信号和多 bit 状态打包为固定宽度 `sample_bus`。
- P0 默认输出 32 bit sample。
- 保持纯组合逻辑，具体跨时钟同步由上游完成。

### openfpga_la_trigger.v

- 支持 disabled、level、edge rising、edge falling、mask match。
- 支持简单 AND/OR 条件组合，P0 可限制为同一 32 bit sample 上的 mask/value 组合。
- 输出 trigger hit、hit channel 和 trigger sample value。

### openfpga_la_core.v

- 根据 `sample_divisor` 产生 sample enable。
- 维护环形 buffer、写指针、已写 sample 数、trigger index 和 post-trigger 计数。
- 支持 arm、stop、clear、force_trigger 和 start_readout 控制脉冲。
- 输出 captured sample 读口、状态、错误、overflow 和 capture metadata。

### openfpga_la_adapter.v

- 读取 core capture metadata 和 sample buffer。
- 打包 M22 定义的 header/status/trigger/data chunk payload。
- 输出 `la_msg_valid/type/len/payload`，由 Debug Core TX path 仲裁发送。
- 支持 backpressure，`msg_valid` 被保持到 `msg_ready`。

## 4. 接口建议

Core 配置输入：

```verilog
input  wire        clk,
input  wire        rst,
input  wire        enable,
input  wire        arm_pulse,
input  wire        stop_pulse,
input  wire        clear_pulse,
input  wire        force_trigger_pulse,
input  wire [15:0] sample_divisor,
input  wire [15:0] capture_depth,
input  wire [15:0] pretrigger_depth,
input  wire [3:0]  trigger_mode,
input  wire [4:0]  trigger_channel,
input  wire [31:0] trigger_value,
input  wire [31:0] trigger_mask,
input  wire [31:0] sample_bus
```

Core 状态和读出输出：

```verilog
output wire [2:0]  state,
output wire [15:0] samples_written,
output wire [15:0] trigger_index,
output wire [31:0] capture_id,
output wire        done,
output wire        overflow,

input  wire        read_req,
input  wire [15:0] read_index,
output wire [31:0] read_sample,
output wire        read_valid
```

P0 可以把 buffer 做成寄存器数组：

```verilog
parameter SAMPLE_WIDTH = 32;
parameter SAMPLE_DEPTH = 128;
```

## 5. 状态机

建议状态：

| 状态 | 说明 |
| --- | --- |
| `IDLE` | 未使能或 clear 后空闲 |
| `ARMED` | 已 arm，持续采集 pre-trigger 窗口并等待 trigger |
| `CAPTURING` | trigger 命中或 force 后，继续采集 post-trigger |
| `DONE` | 捕获完成，可读出 |
| `READOUT` | adapter 正在发送 header/status/data chunks |
| `ERROR` | 配置非法或运行错误 |

关键规则：

- `capture_depth` 不能超过 `SAMPLE_DEPTH`，非法配置进入 config error。
- `pretrigger_depth < capture_depth`，否则进入 config error 或饱和到 `capture_depth - 1`。
- `sample_divisor == 0` 按 1 处理或进入 config error，二选一并在文档固定。
- 计数器饱和或显式设置 overflow，不静默回绕。
- readout 慢不能破坏已完成 capture 的 sample 顺序。

## 6. Monitor 联动

M23 先准备寄存器接口信号，实际接入 board demo 在 M25 完成：

- `LA_CONTROL.enable`
- `LA_CONTROL.auto_readout`
- `LA_CONTROL.trigger_enable`
- `LA_SAMPLE_DIVISOR`
- `LA_CAPTURE_DEPTH`
- `LA_PRETRIGGER_DEPTH`
- `LA_TRIGGER_MODE`
- `LA_TRIGGER_CHANNEL`
- `LA_TRIGGER_VALUE`
- `LA_TRIGGER_MASK`
- `LA_COMMAND.arm/stop/clear/force_trigger/start_readout`
- `LA_STATUS.state/done/overflow/config_error/readout_busy`

## 7. 仿真覆盖

`tb_openfpga_la_core.v` 覆盖：

- enable 为 0 时 arm 不启动捕获。
- arm 后进入 ARMED，并保留 pre-trigger sample。
- level/mask trigger 命中后进入 CAPTURING。
- edge trigger 只在边沿产生一次 hit。
- force_trigger 在无自然 trigger 时完成捕获并设置 FORCED flag。
- clear 后回到 IDLE，capture 状态和 overflow 清零。
- capture_depth 超过实现上限时设置 config error。
- readout 按 header、trigger event、data chunks、status 顺序生成合法 payload。
- msg_ready 拉低时 adapter 保持当前帧，不跳帧。

## 8. 验收

```text
xvlog -d OPENFPGA_DEBUG_SIM -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_la_pkg.vh rtl\openfpga_debug\openfpga_la_probe_pack.v rtl\openfpga_debug\openfpga_la_trigger.v rtl\openfpga_debug\openfpga_la_core.v rtl\openfpga_debug\openfpga_la_adapter.v sim\openfpga_debug\tb_openfpga_la_core.v
xelab tb_openfpga_la_core -s tb_openfpga_la_core_sim
xsim tb_openfpga_la_core_sim -runall
```

期望输出：

```text
PASS: OpenFPGA Logic Analyzer M23 core capture checks passed
```

Vivado RTL elaboration 检查：

```text
vivado -mode batch -source prj/scripts/check_openfpga_la_m23_elab.tcl
```

期望输出：

```text
PASS: OpenFPGA Logic Analyzer M23 core and adapter Vivado RTL elaboration completed
```

M23 兼容 board demo bitstream 构建脚本：

```text
vivado -mode batch -source prj/scripts/build_openfpga_la_m23_bitstream.tcl
```

输出文件：

```text
prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_m23.bit
prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_m23_timing_summary_routed.rpt
prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_m23_route_status.rpt
prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_m23_drc_routed.rpt
prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_m23_utilization_routed.rpt
```

说明：M23 只交付通用 LA RTL core/adapter，暂不实例化到 `openfpga_debug_board_demo`；board demo 接入放到 M25。因此 M23 bitstream 脚本用于确认加入 LA RTL 后现有 board demo 仍可构建，不能代表 bitstream 已包含 LA 硬件。

## 9. 当前实现与验证记录

截至 2026-07-03，M23 已完成以下内容：

- 已新增 `openfpga_la_pkg.vh`、`openfpga_la_probe_pack.v`、`openfpga_la_trigger.v`、`openfpga_la_core.v`、`openfpga_la_adapter.v` 和 `tb_openfpga_la_core.v`。
- `openfpga_la_core` 已实现 sample divisor、pre-trigger ring buffer、post-trigger capture、capture_id、force trigger、clear、config error、readout metadata 和 sample 读口。
- `openfpga_la_adapter` 已按 M22 payload 生成 `LA_CAPTURE_HEADER`、`LA_TRIGGER_EVENT`、`LA_SAMPLE_DATA` 和 `LA_CAPTURE_STATUS`，并支持 `msg_valid/msg_ready` backpressure。
- `sample_divisor == 0` 按 1 处理；`capture_depth == 0`、`capture_depth > SAMPLE_DEPTH` 或 `pretrigger_depth >= capture_depth` 进入 config error。
- P0 sample width 为 32 bit，默认 sample depth 为 128，sample data chunk 每帧最多携带 5 个 32 bit sample。

已通过仿真：

```text
xvlog ...
xelab tb_openfpga_la_core -s tb_openfpga_la_core_sim
xsim tb_openfpga_la_core_sim -runall
PASS: OpenFPGA Logic Analyzer M23 core capture checks passed
```

仿真覆盖项包括 disabled arm、mask trigger、edge trigger、force trigger、clear、非法 depth、sample readback、adapter header/trigger/data/status 顺序和 backpressure 保持。

已通过 Vivado RTL elaboration：

```text
vivado -mode batch -source prj/scripts/check_openfpga_la_m23_elab.tcl
```

检查结果：

```text
openfpga_la_core:    0 Warnings, 0 Critical Warnings, 0 Errors
openfpga_la_adapter: 0 Warnings, 0 Critical Warnings, 0 Errors
PASS: OpenFPGA Logic Analyzer M23 core and adapter Vivado RTL elaboration completed
```

已生成 M23 兼容 bitstream 和报告：

```text
openfpga_debug_board_demo_m23.bit
openfpga_debug_board_demo_m23_timing_summary_routed.rpt
openfpga_debug_board_demo_m23_route_status.rpt
openfpga_debug_board_demo_m23_drc_routed.rpt
openfpga_debug_board_demo_m23_utilization_routed.rpt
```

检查结果：

- Bitgen completed successfully。
- Route status：0 routing errors，所有 routable nets fully routed。
- DRC：0 Errors，1 个 `RTSTAT-10 No routable loads` warning，来源为 `dbg_hub/u_ila_monitor` 相关内部 net，非 LA。
- Timing 未收敛：`WNS = -14.430 ns`、`TNS = -160.586 ns`、22 个 failing endpoints。
- 最差 setup path 位于 `u_latency_profiler_probe/complete_count_reg[16] -> u_latency_profiler_probe/metric_value3_reg[0]`，不是 M23 LA core/adapter 路径。

结论：M23 LA RTL 本体已通过仿真和 Vivado RTL elaboration；当前 board demo bitstream 可生成，但因既有 profiler latency probe 长组合路径存在 timing violation，不作为 timing-clean 版本发布。M25 接入 LA 到 board demo 前，应单独处理或隔离该 profiler timing 问题。

## 10. 留给 M24

- Web Viewer 完整 Logic Analyzer 标签页。
- 数字波形渲染、通道列表、游标、缩放和平移。
- VCD/JSONL 导出和无硬件注入样例。

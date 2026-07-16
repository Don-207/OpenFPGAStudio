# M18 RTL Profiler Core 与计数窗口实施计划

M18 目标是在 RTL 侧建立第四阶段的通用统计核心。它不绑定具体 AXI/FIFO/Frame 信号，而是先提供可复用的计数窗口、快照、清零、溢出和上报机制。

## 1. 目标

- 新增 Profiler 常量包、通用计数器、Profiler Core 和 adapter。
- 支持周期 snapshot、手动 clear、enable、metric mask 和 overflow 标记。
- 生成 `PROFILER_SNAPSHOT` 和 `PROFILER_ALERT`。
- 通过现有 Debug Core TX path 发送 Profiler 消息。
- 增加核心 RTL 仿真。

## 2. 新增文件

```text
rtl/openfpga_debug/
  openfpga_profiler_pkg.vh
  openfpga_profiler_counter.v
  openfpga_profiler_core.v
  openfpga_profiler_adapter.v

sim/openfpga_debug/
  tb_openfpga_profiler_core.v
```

## 3. 模块职责

### openfpga_profiler_pkg.vh

- 定义 Profiler type：`0x30..0x31`。
- 定义 metric_id 范围、flags、alert code。
- 定义默认 `SAMPLE_PERIOD`、最大 payload 长度和版本号。

### openfpga_profiler_counter.v

- 提供通用饱和计数器。
- 支持 increment、add、clear、snapshot。
- 输出 overflow/saturated。

### openfpga_profiler_core.v

- 输入一组抽象 metric update 信号。
- 根据 sample tick 生成 snapshot。
- 仲裁多个 metric 的上报顺序。
- 支持 `enable`、`metric_mask`、`clear_pulse`、`sample_period`。
- 发生 overflow 或阈值事件时生成 alert。

### openfpga_profiler_adapter.v

- 把 core 输出字段打包为 Debug Protocol payload。
- 输出 `profiler_msg_valid/type/len/payload`。
- 接入 Debug Core TX path 的新增注入口。

## 4. 接口建议

Core 输入：

```verilog
input  wire        clk,
input  wire        rst,
input  wire        enable,
input  wire        clear_pulse,
input  wire [31:0] sample_period,
input  wire [31:0] metric_mask,

input  wire        metric_valid,
input  wire [15:0] metric_id,
input  wire [31:0] metric_value0,
input  wire [31:0] metric_value1,
input  wire [31:0] metric_value2,
input  wire [31:0] metric_value3,
input  wire        metric_overflow
```

Core 输出：

```verilog
output wire        snapshot_valid,
output wire [15:0] snapshot_metric_id,
output wire [15:0] snapshot_flags,
output wire [31:0] snapshot_sample_cycles,
output wire [31:0] snapshot_value0,
output wire [31:0] snapshot_value1,
output wire [31:0] snapshot_value2,
output wire [31:0] snapshot_value3,
output wire [15:0] snapshot_overflow_count,
input  wire        snapshot_ready
```

P0 如果 metric 数量固定，也可以使用多路静态输入，避免做复杂事件总线。

## 5. Monitor 联动

M18 建议只把配置接口准备好，实际寄存器接入在 M21 完成：

- `PROFILER_CONTROL.enable`
- `PROFILER_CONTROL.auto_clear`
- `PROFILER_SAMPLE_PERIOD`
- `PROFILER_CLEAR`
- `PROFILER_STATUS.overflow`
- `PROFILER_METRIC_MASK0`

## 6. 仿真覆盖

`tb_openfpga_profiler_core.v` 覆盖：

- enable 为 0 时不产生 snapshot。
- enable 为 1 且 sample_period 到达时产生 snapshot。
- clear_pulse 后计数窗口清零。
- metric_mask 禁用的 metric 不上报。
- 计数器饱和后设置 `SATURATED` 和 overflow_count。
- snapshot_ready 拉低时 core 保持有效数据，不丢失当前 snapshot。
- alert 生成后 payload 字段正确。

## 7. 验收

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_profiler_pkg.vh rtl\openfpga_debug\openfpga_profiler_counter.v rtl\openfpga_debug\openfpga_profiler_core.v rtl\openfpga_debug\openfpga_profiler_adapter.v sim\openfpga_debug\tb_openfpga_profiler_core.v
xelab tb_openfpga_profiler_core -s tb_openfpga_profiler_core_sim
xsim tb_openfpga_profiler_core_sim -runall
```

期望输出：

```text
PASS: OpenFPGA Profiler M18 core snapshot checks passed
```

## 8. 当前实现状态

- 已新增 `openfpga_profiler_pkg.vh`，定义 Profiler type、payload length、flags、alert code、P0 metric_id 和默认 sample period。
- 已新增 `openfpga_profiler_counter.v`，提供通用饱和加法计数器和 overflow pulse。
- 已新增 `openfpga_profiler_core.v`，支持 enable、clear、sample_period、metric_mask、窗口累计、snapshot backpressure、overflow_count 和 overflow alert。
- 已新增 `openfpga_profiler_adapter.v`，按 M17 协议打包 `PROFILER_SNAPSHOT` 32 字节 payload 和 `PROFILER_ALERT` 16 字节 payload。
- 已新增 `tb_openfpga_profiler_core.v`，覆盖 disabled、周期 snapshot、clear、metric_mask、snapshot backpressure、overflow alert 和 adapter payload。
- 默认 `xsim.dir/work` 在当前环境存在写入/锁定问题，本次验证使用 `sim_work/m18` 独立仿真目录完成。

已通过：

```text
PASS: OpenFPGA Profiler M18 core snapshot checks passed
```

## 9. 留给 M19

- 接入具体 AXI Stream/FIFO/Frame/Latency probe。
- 将 probe 事件转换为 M18 core 可消费的 metric update。
- 补充 probe 级仿真。

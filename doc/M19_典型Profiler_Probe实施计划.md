# M19 典型 Profiler Probe 实施计划

M19 在 M18 的通用 Profiler Core 之上补齐第一批可复用 probe。目标是覆盖第四阶段最核心的性能观察对象：吞吐、FIFO、延迟和帧率。

## 1. 目标

- 新增 AXI Stream throughput/stall probe。
- 新增 FIFO level/overflow/underflow probe。
- 新增 Frame Rate/drop/inter-frame interval probe。
- 新增单 outstanding Latency probe。
- 提供 DDR/PCIe 接入模板和注意事项。
- 增加 probe RTL 仿真。

## 2. 新增文件

```text
rtl/openfpga_debug/
  openfpga_profiler_axis_probe.v
  openfpga_profiler_fifo_probe.v
  openfpga_profiler_frame_probe.v
  openfpga_profiler_latency.v

sim/openfpga_debug/
  tb_openfpga_profiler_probes.v

doc/
  OpenFPGA_Profiler_Probe接入说明.md
```

## 3. Probe 定义

### AXI Stream Probe

输入：

```verilog
input wire        axis_valid,
input wire        axis_ready,
input wire [N:0]  axis_keep,
input wire        axis_last
```

统计：

- `value0`：窗口内 bytes 或 words。
- `value1`：handshake beat 数。
- `value2`：active cycles，`valid || ready`。
- `value3`：stall cycles，`valid && !ready` 或 `ready && !valid` 可配置。

### FIFO Probe

输入：

```verilog
input wire [LEVEL_WIDTH-1:0] fifo_level,
input wire                   fifo_wr_en,
input wire                   fifo_rd_en,
input wire                   fifo_full,
input wire                   fifo_empty,
input wire                   fifo_overflow,
input wire                   fifo_underflow
```

统计：

- `value0`：当前 level。
- `value1`：窗口最大 level。
- `value2`：窗口最小 level。
- `value3`：overflow/underflow 计数打包。

### Frame Probe

输入：

```verilog
input wire frame_start,
input wire frame_done,
input wire frame_drop,
input wire frame_error
```

统计：

- `value0`：窗口完成帧数。
- `value1`：drop/error 帧数。
- `value2`：最小帧间隔。
- `value3`：最大帧间隔。

### Latency Probe

P0 支持单 outstanding：

```verilog
input wire start_valid,
input wire end_valid,
input wire timeout_clear
```

统计：

- `value0`：完成事务数。
- `value1`：最小 latency。
- `value2`：最大 latency。
- `value3`：平均 latency。

若 `start_valid` 在前一个事务未结束时再次到来，P0 返回 busy/overflow 计数，不尝试多事务匹配。

## 4. DDR/PCIe 接入模板

DDR 和 PCIe P0 不强制集成 vendor IP，但文档必须给出接入点：

- DDR：read/write command accepted、data beat、busy、stall、error。
- PCIe：posted write bytes、completion bytes、request pending、retry/error、backpressure。
- CDC：高速域先本地计数，Debug Core 域只读取 snapshot。
- 宽总线 byte 统计必须参数化，例如 `DATA_WIDTH/8`。

## 5. 仿真覆盖

`tb_openfpga_profiler_probes.v` 覆盖：

- AXI Stream 连续传输、valid stall、ready stall、不同 keep mask。
- FIFO level 上升下降、最大/最小 level、overflow/underflow。
- Frame done/drop/error、帧间隔 min/max。
- Latency 正常 start/end、timeout、重复 start busy。
- clear 后窗口统计归零。

## 6. 验收

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_profiler_pkg.vh rtl\openfpga_debug\openfpga_profiler_axis_probe.v rtl\openfpga_debug\openfpga_profiler_fifo_probe.v rtl\openfpga_debug\openfpga_profiler_frame_probe.v rtl\openfpga_debug\openfpga_profiler_latency.v sim\openfpga_debug\tb_openfpga_profiler_probes.v
xelab tb_openfpga_profiler_probes -s tb_openfpga_profiler_probes_sim
xsim tb_openfpga_profiler_probes_sim -runall
```

期望输出：

```text
PASS: OpenFPGA Profiler M19 probe checks passed
```

## 7. 留给 M20

- Viewer 使用 M17 metric model 展示 M19 指标。
- 增加 `Inject Sample`，覆盖每类 probe 的典型 snapshot 和 alert。

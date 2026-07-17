# M9 RTL Trace Adapter 实施计划

## 1. 目标

M9 承接 M7 的 Trace 协议定义和 M8 的 Viewer 时间轴，实现 FPGA 侧 Trace 消息封装层：

- 新增 Trace 常量包，固化 `0x10..0x14` 类型、payload 长度、status 和常用 `trace_id`。
- 新增 `openfpga_trace_adapter`，把 begin/end/mark/value/drop API 转换为 Debug Protocol v1 消息。
- payload 使用 little-endian 位布局，可直接接入现有 ring buffer 或 packetizer。
- 增加 RTL testbench，覆盖 payload 编码、握手、背压和同周期多输入优先级。

M9 不实现 DMA/Frame/FIFO/IRQ 业务 probe，也不改板级 demo 行为；这些放在 M10。

## 2. 文件交付

| 文件 | 内容 |
| --- | --- |
| `rtl/openfpga_debug/openfpga_trace_pkg.vh` | Trace type、payload length、status、常用 trace_id 常量 |
| `rtl/openfpga_debug/openfpga_trace_adapter.v` | Trace API 到 Debug Protocol payload 的适配器 |
| `sim/openfpga_debug/tb_openfpga_trace_adapter.v` | Adapter payload 和握手仿真 |
| `prj/scripts/check_openfpga_trace_m9_elab.tcl` | Vivado RTL elaboration 检查脚本 |

## 3. Adapter 接口约定

Adapter 输入由五类单周期脉冲组成：

- `span_begin_valid`
- `span_end_valid`
- `mark_valid`
- `value_valid`
- `drop_valid`

输出复用 Debug Core 内部消息接口：

```text
msg_valid
msg_type
payload_len
payload_flat
msg_ready
```

`trace_ready` 表示当前周期没有多输入竞争且下游可接收。`trace_accepted` 表示优先级选中的消息已被下游接受。`trace_dropped` 表示本周期存在未被接受的 Trace 脉冲，包括背压或同周期多输入竞争。

优先级为：

```text
span_begin > span_end > mark > value > drop
```

## 4. Payload 编码

Adapter 严格按 `YiFPGA_Debug_Protocol_v1.md` 编码：

- `TRACE_SPAN_BEGIN`：`timestamp, trace_id, instance_id, arg0`
- `TRACE_SPAN_END`：`timestamp, trace_id, instance_id, status, arg0`
- `TRACE_MARK`：`timestamp, trace_id, level, arg0`
- `TRACE_VALUE`：`timestamp, trace_id, value_id, value`
- `TRACE_DROP`：`timestamp, trace_id, drop_count`

`payload_flat[7:0]` 是 payload 第 0 字节，因此现有 packetizer 会按 little-endian 发送多字节字段。

## 5. 验收

协议 parser 回归：

```powershell
python tools\viewer\protocol_parser_test.py
```

Vivado elaboration：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_trace_m9_elab.tcl
```

Trace Adapter testbench 可在 Vivado/XSim 中把 `sim/openfpga_debug/tb_openfpga_trace_adapter.v` 与 `rtl/openfpga_debug/openfpga_trace_adapter.v` 一起编译运行，期望输出：

```text
PASS: OpenFPGA Trace Adapter payload and handshake checks passed
```

## 6. 留给 M10

- 增加 DMA/Frame/FIFO/IRQ probe。
- 在 probe 内部做必要的边沿检测、实例号生成和低频 value 采样。
- 把 adapter 输出接入 Debug Core 的发送队列，板级 demo 产生可在 M8 Viewer 中观察的 Trace 时间轴。

# M10 典型 Probe 与 Demo 实施计划

## 1. 目标

M10 承接 M9 的 `openfpga_trace_adapter`，补齐可直接放进用户逻辑或板级 demo 的典型 Trace probe：

- DMA probe：把 descriptor start/done/error/timeout 转成 span begin/end。
- Frame probe：把 frame start/end/drop 转成 frame span 和 warning mark。
- FIFO probe：把低频 level sample 转成 value，把 almost_full/overflow 转成 mark。
- IRQ probe：把 interrupt assert/clear 边沿转成 mark。
- 板级 demo 周期性产生 `frame -> dma -> fifo -> irq -> dma end -> frame end`，并插入一个 DMA timeout 场景，Web Viewer 可直接看到完整 Trace 时间线。

M10 不引入复杂性能统计，也不替代 ILA 波形采样；它只提供过程级、事件级观测。

## 2. 交付文件

| 文件 | 内容 |
| --- | --- |
| `rtl/openfpga_debug/openfpga_trace_dma_probe.v` | DMA span begin/end probe |
| `rtl/openfpga_debug/openfpga_trace_frame_probe.v` | Frame span/mark probe |
| `rtl/openfpga_debug/openfpga_trace_fifo_probe.v` | FIFO value/mark probe |
| `rtl/openfpga_debug/openfpga_trace_irq_probe.v` | IRQ edge mark probe |
| `rtl/openfpga_debug/openfpga_debug_core.v` | 接入 Trace adapter 到现有 ring buffer/packetizer |
| `rtl/openfpga_debug/openfpga_debug_top.v` | 向上暴露 Trace API 输入 |
| `rtl/board/openfpga_debug_board_demo.v` | 产生可观察的 M10 Trace demo 流 |
| `sim/board/tb_openfpga_debug_board_demo.v` | 验证 board demo 输出 Trace 帧 |
| `prj/scripts/check_openfpga_trace_m10_elab.tcl` | Vivado RTL elaboration 验收脚本 |

## 3. Probe 接口原则

- Probe 只做边沿检测、状态到 Trace 字段的映射，不持有复杂业务状态。
- 每个 probe 都输出 M9 adapter 的 begin/end/mark/value 字段子集，便于用户逻辑用优先级 mux 汇聚。
- `ENABLE` 参数用于综合裁剪。
- FIFO value 保持低频 sample，由上层决定采样节奏，避免 UART 带宽被高频 level 占满。

## 4. Demo 过程

板级 demo 内置循环 Trace 剧本：

1. Frame span begin。
2. DMA span begin。
3. FIFO level value sample。
4. FIFO almost_full warning mark。
5. IRQ assert mark。
6. IRQ clear mark。
7. DMA span end OK。
8. Frame span end OK。
9. 额外插入一个 DMA begin + timeout end，用于验证 Viewer 的 problem 高亮。

标准 heartbeat/event/watch/print/status 帧继续保留，Trace 帧作为同一 Debug Protocol v1 流中的 `0x10..0x14` 消息输出。

## 5. 验收

无硬件 parser 回归：

```powershell
python tools\viewer\protocol_parser_test.py
```

板级 demo 仿真期望看到 debug 帧和 trace 帧：

```text
PASS: OpenFPGA Debug board demo emitted debug and trace frames
```

Vivado elaboration：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_trace_m10_elab.tcl
```

期望：

```text
PASS: OpenFPGA Trace M10 probe and demo Vivado RTL elaboration completed
```

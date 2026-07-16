# OpenFPGA Studio 第二阶段 Trace 发布 Checklist

## 文档

- [ ] `doc/OpenFPGA_Debug_Protocol_v1.md` 包含 `0x10..0x14` Trace 消息定义。
- [ ] `doc/OpenFPGA_Trace_使用说明.md` 覆盖 RTL 接入、Viewer 使用和验收命令。
- [ ] `doc/OpenFPGA_Web_Viewer_使用说明.md` 描述 Trace 视图、Inject Sample 和 JSONL 导出。
- [ ] `doc/OpenFPGA_Studio_第二阶段Trace验证记录.md` 记录本次发布的命令、环境和结果。
- [ ] `README.md` 有 Trace 能力、仿真命令和文档入口。

## RTL

- [ ] `openfpga_trace_pkg.vh` 的类型、长度、status、trace_id 与协议文档一致。
- [ ] `openfpga_trace_adapter.v` payload 使用 little-endian 布局。
- [ ] `openfpga_debug_core.v` 正确接入 Trace adapter，且原有 Debug 消息不回退。
- [ ] `openfpga_debug_top.v` 向用户逻辑暴露 Trace API。
- [ ] DMA、Frame、FIFO、IRQ probe 均带 `ENABLE` 参数。
- [ ] 板级 demo 输出 debug 帧和 trace 帧。

## Viewer

- [ ] parser 能解析 `TRACE_SPAN_BEGIN/END/MARK/VALUE/DROP`。
- [ ] begin/end 能合成 span，未匹配 end 保留为 orphan。
- [ ] Trace 视图显示 lane、span、mark、Latest Values 和 details。
- [ ] 过滤器可按 lane、problem/status、时间范围筛选。
- [ ] `Inject Sample` 覆盖 Frame、DMA、FIFO、Interrupt、timeout、drop。
- [ ] JSONL 导出包含 Trace 记录。

## 回归

- [ ] `python tools\viewer\protocol_parser_test.py`
- [ ] `python tools\viewer\web\run_perf_test.py`
- [ ] `xsim tb_openfpga_trace_adapter_sim -runall`
- [ ] `xsim tb_openfpga_debug_board_demo_m10_sim -runall`
- [ ] `vivado -mode batch -source prj/scripts/check_openfpga_trace_m10_elab.tcl`

## 板级

- [ ] 使用最新 RTL 生成 bitstream。
- [ ] Web Viewer 能连接板卡串口。
- [ ] Log/Watch/Events/Status 继续更新。
- [ ] Trace 视图能看到 Frame、DMA、FIFO、Interrupt 泳道。
- [ ] DMA timeout 或 error 高亮可见。
- [ ] 连续运行 30 分钟后 checksum error 不持续增长。
- [ ] `drop_count` 为 0，或已记录并解释增长原因。

## 发布边界

- [ ] 第二阶段只发布 Trace，不承诺寄存器读写和在线控制。
- [ ] Monitor 入口留给第三阶段，不把双向协议混入本次发布。
- [ ] Profiler/Logic Analyzer/AI Debug 仍保持后续阶段规划。

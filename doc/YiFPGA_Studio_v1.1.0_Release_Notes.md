# YiFPGA Studio v1.1.0 Release Notes

## 发布定位

v1.1.0 是 OpenFPGA Studio 迁移为 YiFPGA Studio 后的首个 minor 版本。该版本将
YiFPGA 名称设为新的 canonical 入口，同时保留 v1 协议、schema 和旧代码入口的
兼容性。本次迁移不更改 wire format、JTAG Mailbox ABI、Monitor 寄存器语义、
build ID 或历史证据格式。

## 主要变更

- 产品、README、Web Viewer 和当前使用说明统一使用 `YiFPGA Studio`。
- JavaScript 主入口切换为 `YiFPGA*`，Python Bridge 主入口切换为
  `tools/jtag/yifpga_jtag_bridge.py`。
- RTL module、仿真目录、Tcl、约束、Vivado 工程和新 runs 路径切换为
  `yifpga_*` / `YiFPGAStudio.*`。
- normal、performance 和 JTAG-only+ILA 三个候选镜像通过 Vivado 2024.2
  构建、时序、DRC/CDC、下载和板级闭环。
- performance+ILA 在 10 MHz TCK、1,024 B block 下的 30 分钟长稳吞吐为
  `232,687.952 B/s`，3 次客户端重连成功，drop/overflow 为 0。
- JTAG Bridge 将每个 mailbox block 合并为一次 worker 调度，降低 Host
  调度开销，不改变 header/read/commit 事务语义。

## 兼容性与弃用计划

- Debug Protocol v1、`openfpga.*` schema、`openfpga-diagnosis-v1` 和 `OFD_*` 保持兼容。
- `OpenFPGA*` JavaScript 全局与 `openfpga_jtag_bridge.py` 作为 deprecated alias/wrapper
  保留，至少覆盖 v1.1.x 和 v1.2.x；最早只能在 v1.3.0 评估移除。
- 旧 Tcl 脚本名保留 source wrapper；当前版本不删除旧入口。
- `openfpga_*` RTL wrapper、`OPENFPGA_*` 宏 alias、Protocol v1 和 schema v1
  不在 minor 版本中移除；任何移除必须进入 major 版本评审并提前预告。
- 历史 `OpenFPGAStudio.runs`、capture、snapshot、JSONL、VCD 和哈希证据保持原样。

## 升级示例

```text
tools/jtag/openfpga_jtag_bridge.py  -> tools/jtag/yifpga_jtag_bridge.py
OpenFPGAViewerModel                -> YiFPGAViewerModel
openfpga_debug_core                -> yifpga_debug_core
OPENFPGA_DEBUG_SIM                 -> YIFPGA_DEBUG_SIM
prj/OpenFPGAStudio.xpr             -> prj/YiFPGAStudio.xpr
```

旧入口在兼容期内仍可使用；新集成应立即使用右侧 canonical 名称。

## 验证摘要

- `just release-check`：通过。
- RTL 新旧命名等价仿真：通过。
- M36 五组综合矩阵与三个 ILA 实现候选：通过。
- normal JTAG 功能冒烟、performance 30 分钟长稳、JTAG-only Monitor/Profiler/LA
  闭环：通过。
- 详细参数、产物 SHA-256 和告警判读见
  [`YiFPGA_品牌与代码兼容迁移计划.md`](YiFPGA_品牌与代码兼容迁移计划.md)。

## 已知限制

- v1.1.0 只签署 Xilinx `xcku5p-ffvb676-2-i` 参考实现。
- Direct FT232H backend 与 Vivado Hardware Manager 不能同时独占同一 cable；
  在 Bridge 和 ILA 操作间需先释放 FTDI。
- Mailbox v1 单次 block 上限为 1,024 B；2 KiB/4 KiB 需新 ABI capability。
- normal 镜像用于功能流，不承担 100 KB/s 持续性能承诺；性能门槛仅由
  performance 镜像签署。

## 回退

- Host 集成可临时切回 deprecated `OpenFPGA*` / `openfpga_*` 兼容入口。
- RTL 集成可使用 `openfpga_*` wrapper，其内部仍转发到同一 `yifpga_*`
  canonical 实现。
- Vivado 迁移失败时使用已签署的 `YiFPGAStudio.xpr` 和 v1.0 历史产物；
  不改写历史 runs 或哈希证据。

## 发布前剩余项

- 从候选提交执行干净 clone 离线门禁。
- 确认 tag 策略。截至 2026-07-20，GitHub 远端无 tag，因此不得将计划中的
  “已有 v1.0.0 tag”当作既成事实。
- push 候选提交，创建经确认的 tag 和 GitHub Release。

# YiFPGA Studio 品牌迁移与兼容说明

`OpenFPGA Studio` 自 2026-07-17 起迁移为 `YiFPGA Studio`。本次变更首先更新用户可见
品牌，不改变 Debug Protocol v1、JTAG Mailbox、Monitor 寄存器、消息 payload、build ID
或诊断 schema v1。

## 当前名称

- 产品名称：`YiFPGA Studio`
- 简称：`YiFPGA`
- 当前 RTL、仿真、Tcl 和 Vivado 工程入口已迁移到 YiFPGA 路径；旧 Tcl 名称保留兼容 wrapper。
- 既有品牌文档文件名已统一迁移为 `YiFPGA*`，仓库内链接和自动验证脚本已同步更新。

## 兼容承诺

- `openfpga.*` schema、`openfpga-diagnosis-v1` 和 `OFD_*` 是 v1 ABI，保持不变。
- `YiFPGA*` JavaScript 全局已成为 canonical；`OpenFPGA*` 作为同一对象的兼容别名保留。
- JTAG Bridge canonical 入口为 `yifpga_jtag_bridge.py`；旧 `openfpga_jtag_bridge.py` wrapper
  继续可用并提示弃用。RTL 入口仍留待后续工作包迁移。
- Viewer 继续导入旧 capture、JSONL、VCD、CSV 和 snapshot；解析不依赖文件名。
- Viewer 新导出的 VCD、CSV 和 JSONL 默认使用 `yifpga-` 前缀。
- 历史验证文档文件名可使用新品牌；其中记录的产物路径、hash、Git tag 和已发布附件不重命名。

旧 Host 入口至少保留到首个 YiFPGA 正式版本之后的一个 minor release；RTL wrapper、
Protocol v1 和 schema v1 的移除必须另行进入 major 版本评审，并提前在 Release Notes 预告。

完整边界和后续工作包见
[`YiFPGA_品牌与代码兼容迁移计划.md`](YiFPGA_品牌与代码兼容迁移计划.md)。

# Vivado 工程迁移说明

旧工程入口 `OpenFPGAStudio.xpr` 已迁移为 `YiFPGAStudio.xpr`。请从仓库根目录打开：

```text
vivado prj/YiFPGAStudio.xpr
```

历史 `OpenFPGAStudio.runs`、已归档 bitstream、LTX、DCP、报告和 hash 不重命名、不重新生成。
新工程构建应写入 `YiFPGAStudio.runs`。旧 RTL module 与 Tcl 入口仍按品牌迁移计划保留兼容
wrapper，但新工程文件清单只引用 `rtl/yifpga_debug`、`yifpga_*` 源文件和
`prj/constraints/yifpga_debug_board_demo.xdc`。

迁移本身不代表新工程已经完成综合、实现、DRC、CDC、时序或板级签署；这些步骤仍由用户
显式执行并保存报告。

# YiFPGA 品牌与代码兼容迁移计划

## 1. 目标

将产品品牌从 `OpenFPGA Studio` 迁移为 `YiFPGA Studio`，并逐步将源码标识、文件路径、
构建入口和导出名称迁移到 `YiFPGA/yifpga/YIFPGA` 命名空间，同时保持 v1.0 已冻结协议、
板级镜像、诊断数据、脚本调用和历史验证证据可复现。

本迁移不改变产品功能，不借品牌迁移修改协议语义、硬件寄存器、JTAG Mailbox ABI、
消息类型或板级时序。任何功能变更必须进入独立工作包和评审。

## 2. 命名规范

| 对象 | 规范名称 | 示例 |
| --- | --- | --- |
| 产品品牌 | `YiFPGA Studio` | Viewer 标题、README、发布页 |
| 简称 | `YiFPGA` | 文档正文、CLI 描述 |
| 仓库/工程 | `YiFPGAStudio` | GitHub repository、Vivado project |
| 文件与目录前缀 | `yifpga_` | `yifpga_debug_core.v` |
| RTL module 前缀 | `yifpga_` | `yifpga_debug_core` |
| C/Verilog宏前缀 | `YIFPGA_` | `YIFPGA_DEBUG_SIM` |
| JavaScript全局 | `YiFPGA*` | `YiFPGADiagnosticSnapshot` |
| 导出文件前缀 | `yifpga-` | `yifpga-la-*.vcd` |
| Python package/module | `yifpga_` | `yifpga_jtag_bridge.py` |

`YiFPGA` 的大小写视为品牌规范，不使用 `YIFPGA Studio`、`YiFpga` 或 `yifpga Studio`。

## 3. 冻结的兼容边界

### 3.1 v1.x 内不得改变

- Debug Protocol v1 wire format：SOF、version、type、length、payload和checksum。
- Monitor寄存器地址、访问权限、状态码和命令语义。
- Logic Analyzer、Profiler和Trace的消息类型及payload布局。
- JTAG Mailbox header、opcode、USER chain、session、commit和计数语义。
- 已发布build ID及其对应bitstream含义。
- `schema_version: 1` 数据结构和字段语义。
- 已归档capture、JSONL、VCD、CSV、bitstream、LTX和报告的hash。

### 3.2 v1.x 保留的旧标识

以下标识属于兼容ABI，不因品牌改名立即删除：

- `openfpga.diagnostic_snapshot`
- `openfpga.diagnostic_findings`
- `openfpga.ai_debug_report`
- `openfpga.ai_debug_board_run`
- `openfpga.ai_debug_board_qualification`
- `openfpga-diagnosis-v1`
- RTL协议常量前缀 `OFD_*`
- Bridge protocol的字段名、版本号和`stable_id`格式

新代码必须继续读取这些值。是否引入 `yifpga.*` schema 只能通过新的schema major version
单独设计；不能只替换字符串而继续声明version 1。

### 3.3 历史证据保护

历史文档文件名经用户于 2026-07-17 明确授权，统一使用 `YiFPGA*`，并通过 Git rename 保留
版本追溯。以下证据正文及产物仍保持原样，不做机械改名：

- 已完成阶段的验证记录中出现的真实命令、路径、工程名和产物名。
- `prj/YiFPGAStudio.runs/...` 等证据路径。
- 既有bitstream、LTX、DCP、CSV、JSONL和VCD文件名及hash。
- Git tag、commit message、PR正文和已发布release附件。

历史文档可更新标题和文件名，也可在顶部增加“现品牌为YiFPGA Studio”的说明，但不得
改写当时的命令、工程路径、产物名、结果和hash。

## 4. 迁移原则

1. 品牌展示先于内部标识迁移。
2. 读取端先兼容新旧名称，写出端再切换新名称。
3. 公共RTL module先提供兼容wrapper，再迁移内部实例。
4. 路径迁移必须使用Git rename并同步所有显式文件清单。
5. 每个阶段保持可独立回退，不提交品牌和功能混合改动。
6. 所有旧名称删除必须经过至少一个兼容发布周期。
7. Vivado综合、实现、bitstream生成和烧录由用户执行；自动迁移不得隐式启动厂商构建。

## 5. 工作包

### YF.WP0：名称与资产冻结

状态（2026-07-17）：**已完成**。文字名称与扫描基线已冻结，品牌与Copyright主体确认为
用户本人（公开标识`Don-207`），许可证为MIT，目标产品市场为FPGA调试；域名经用户决议
延期且不阻塞后续工作包。详见
[`YF_WP0_YiFPGA名称与资产冻结记录.md`](YF_WP0_YiFPGA名称与资产冻结记录.md)。

- 确认`YiFPGA`、`YiFPGA Studio`、仓库名和目标域名的最终拼写。
- 完成GitHub、常用搜索引擎、软件包注册表、域名和目标市场商标初筛。
- 确认品牌所有者、许可证、Copyright主体和中文名称。
- 确认logo、favicon、主色和字标是否本轮迁移；未确认时只迁移文字品牌。
- 生成全仓名称清单，分类为品牌、源码标识、协议ABI、历史证据和生成物。

交付物：名称决议、资产清单、保留标识清单和迁移基线提交。

停止条件：品牌拼写或法律使用边界未冻结。

### YF.WP1：品牌展示迁移

状态（2026-07-17）：**已完成**。README、Viewer、当前使用说明和Viewer新导出文件名前缀
已迁移；代码ABI、旧入口、工程路径及历史证据保持不变。`just parser-test`、`just m27-check`
至`just m30-check`均通过。

- 更新README首页、Viewer标题、页面说明、帮助文本和当前使用说明为`YiFPGA Studio`。
- 首次出现时写明`YiFPGA Studio（原OpenFPGA Studio）`。
- 所有品牌文档文件名使用`YiFPGA_*`；历史文档通过Git rename迁移，正文证据保持原样。
- 新导出文件默认使用`yifpga-*`前缀。
- Viewer仍能导入旧`openfpga-*`文件，文件内容解析不依赖文件名。
- 增加品牌迁移说明，列出旧名称支持周期。

本阶段不改RTL module、Python import、JavaScript全局、schema、Tcl入口和Vivado工程。

门禁：`just parser-test`、`just viewer-test`、`just m27-check`至`just m30-check`。

### YF.WP2：Host软件双命名兼容

状态（2026-07-20）：**已完成**。Viewer 已以 `YiFPGA*` 全局作为 canonical 名称，旧
`OpenFPGA*` 全局继续指向同一对象；JTAG Bridge 已以 `yifpga_jtag_bridge.py` 作为 canonical
入口，旧脚本保留轻量 wrapper 和弃用提示。冻结 schema、fixture 与 Bridge protocol 保持
不变。新旧入口恒等测试及 `just release-check` 均通过。

- 新增`YiFPGA*` JavaScript全局，同时将`OpenFPGA*`保留为同一对象的deprecated alias。
- 新增`yifpga_*` Python入口；旧`openfpga_*`脚本保留轻量wrapper并打印一次弃用提示。
- CLI帮助、日志和用户可见错误使用新品牌，协议字段和fixture保持不变。
- 导出器写出`yifpga-*`文件名，导入器继续接受任意文件名及旧schema。
- 测试必须同时覆盖旧入口和新入口，且结果逐字节或语义等价。
- 不复制两套Parser、诊断规则或业务模型；alias必须指向同一实现。

兼容周期：旧Host入口至少保留至首个YiFPGA正式版本后的一个minor release。

门禁：`just release-check`及新旧入口等价测试。

### YF.WP3：RTL标识兼容迁移

状态（2026-07-20）：**已完成**。36 个通用、板级及 Xilinx 适配 module
已迁移为单一 `yifpga_*` canonical 实现，旧 `openfpga_*` module 保留端口和参数默认值不变的
轻量 wrapper；RTL 内部实例已切换新名称。`YIFPGA_DEBUG_SIM` 已成为 canonical 构建宏，旧
`OPENFPGA_DEBUG_SIM` 继续映射为兼容 alias。现有 Debug Core、Trace、Profiler、Logic
Analyzer、board demo 和 JTAG 用例均通过 `xvlog` 分析与 `xelab` 静态展开，Xilinx 适配源码
也通过 `xvlog` 分析。Debug Core、Profiler 和 Logic Analyzer 行为用例通过；新增 Trace 与
board demo 新旧顶层逐周期等价仿真并通过。提交 `46acb9a` 的独立基线复验确认 Trace Adapter
原有 27 项断言、board demo 原有 1 项 LED activity 断言以及 JTAG transport 原有 2 项断言在
迁移前已同样失败，均不属于 WP3 回归，后续应以独立功能修复处理。`just release-check` 与
`git diff --check` 通过。未运行综合、实现、bitstream 生成或板级操作。

- 新核心module采用`yifpga_*`名称。
- 对外公开的旧`openfpga_*`module保留wrapper，端口名、参数默认值和时序行为不变。
- 先迁移内部实例到新module，再迁移下游示例；不得同时维护两份功能RTL。
- `OFD_*`协议常量在v1.x继续作为canonical ABI名称。
- 可新增`YIFPGA_*`构建宏，并将`OPENFPGA_*`映射为兼容alias。
- 对旧顶层和新顶层输入相同fixture，输出必须逐字节一致。
- 记录资源、时序和CDC差异；纯wrapper不得引入逻辑资源。

建议过渡结构：

```text
openfpga_debug_core (deprecated wrapper)
                |
                +--> yifpga_debug_core (single implementation)
```

门禁：现有RTL仿真、新旧顶层等价仿真、elaboration文件清单检查。Vivado门禁由用户单独执行。

### YF.WP4：路径、脚本与Vivado工程迁移

状态（2026-07-20）：**代码迁移与用户侧 Vivado 构建完成，板级功能复验进行中**。RTL 与仿真目录已迁移为 `rtl/yifpga_debug`、
`sim/yifpga_debug`，源码、测试、板级、Xilinx 适配、约束和 Tcl 文件名已切换 `yifpga_*`；
`YiFPGAStudio.xpr`、justfile、当前文档及显式文件清单已同步。24 个旧 Tcl 名称保留轻量
source wrapper，并提供旧工程只读迁移说明。Debug Core、RTL 新旧命名等价和
`just release-check` 离线门禁均通过；旧 Tcl wrapper 生成检查通过。用户于 2026-07-20
完成 `just m36-matrix`：UART、JTAG、UART_AND_JTAG、JTAG-disabled 与 JTAG-performance
五组综合配置全部生成 manifest，BSCANE2 数量分别符合 0/1 裁剪预期，CDC 均报告
`All paths are Safely Timed`，时钟交互均为 `Clean/Timed`，综合 WNS 为正。尚待用户侧完成
实现、DRC、最终时序、bitstream、LTX 与板级验证；本次审查未继续运行实现、bitstream 生成或烧录。

用户同日完成 normal `just m36-ila-bitstream`：设计 fully routed，11,374 个 routable nets
全部完成路由且 routing errors 为 0；WNS `2.907 ns`、TNS `0`、WHS `0.013 ns`、THS `0`，
全部用户时序约束满足。DRC 无 error，保留 3 项 dbg_hub `PDCN-1569` warning 和 1 项 dbg_hub
`RTSTAT-10` warning；CDC 为 9 项 `CDC-3` info、2 项 `CDC-9` info 和 4 项 dbg_hub
`CDC-15` warning。manifest 记录 BSCANE2=1、ILA=1，BIT/LTX 均存在。产物 SHA-256：

- BIT：`9206240d7ce929697be61186cc8bd5890b2a391c9dfa110260123e5c3edbfac5`
- LTX：`019c53da47cee5fb7cecfc429efe703e9b07c038e9534a906d47e44cca115622`

尚待 performance+ILA、JTAG-only+ILA 实现及三个候选镜像的板级验证。

用户同日完成 `just m36-perf-ila-bitstream`：performance 配置为 UART=0、JTAG=1、
JTAG_PERF_MODE=1，manifest 记录 BSCANE2=1、ILA=1。设计 fully routed，8,350 个 routable
nets 全部完成路由且 routing errors 为 0；WNS `3.770 ns`、TNS `0`、WHS `0.017 ns`、THS
`0`，全部用户时序约束满足。DRC/CDC warning 类型和数量与 normal ILA 镜像一致，均位于
Vivado dbg_hub。BIT/LTX 均存在，产物 SHA-256：

- BIT：`8228603cc930ee3e6646eaead9bc5c3260192358717d06b2e59bbbe53306c25d`
- LTX：`019c53da47cee5fb7cecfc429efe703e9b07c038e9534a906d47e44cca115622`

尚待 JTAG-only+ILA 实现及三个候选镜像的板级验证。

用户同日完成 `just m36-jtag-only-ila-bitstream`：JTAG-only 配置为 UART=0、JTAG=1、
JTAG_PERF_MODE=0、JTAG_ONLY_MODE=1，manifest 记录 BSCANE2=1、ILA=1。设计 fully routed，
11,086 个 routable nets 全部完成路由且 routing errors 为 0；WNS `3.003 ns`、TNS `0`、
WHS `0.013 ns`、THS `0`，全部用户时序约束满足。DRC/CDC warning 类型和数量与另外两个
ILA 镜像一致，均位于 Vivado dbg_hub。BIT/LTX 均存在，产物 SHA-256：

- BIT：`8eb320cd5e2693c488205665afcc4b5939229880c05aa97d62b6691b2a77ddc5`
- LTX：`019c53da47cee5fb7cecfc429efe703e9b07c038e9534a906d47e44cca115622`

至此 normal、performance 和 JTAG-only 三个 YiFPGA ILA 候选均完成实现、路由、DRC、CDC、
时序和产物核验。用户同日执行 `just m36-program 'Digilent/210512180081'`
下载 normal 镜像：Vivado 报告 startup status `HIGH`，目标设备为 `xcku5p_0`，
且刷新后精确枚举 1 个 ILA core，脚本输出 `PASS`。这确认 normal 产物可成功
加载且 probes 可被 Vivado Hardware Manager 识别。随后执行
`just m36-ila-capture 'Digilent/210512180081'`：ILA 在预期的 index 512 触发，
生成 1,024 个样本的 `m36_ila_capture.csv`，未发现缺样或多重触发行，文件
SHA-256 为 `6d631f887d30b716beabc632dc9e46a06104528fe50e97667c1636eb20fa9fc0`。
本次为 UART RX 空闲电平立即触发，64-bit probe 全窗口保持
`0x2a04000000000000`，因此证明 ILA 触发、上传和 CSV 导出链路正常，
不单独证明业务数据活动。normal Bridge 随后以 6 MHz TCK、1,024 B block
运行 60.051 s 功能冒烟：接收 53,122 B（`884.610 B/s`），2 个 HELLO 对应
1 次客户端重连，`buffer_used=0`、`slow_clients=0`，且 drop/overflow 历史计数
在窗口内未增长（首尾均为 370,931）。CSV SHA-256 为
`1e17d8c92ece9c4570d62862918eba288a8d9745f223368fbeaaec60dc9e635b`。该结果按
`--min-rate 0` 仅签署 normal 功能链路；100 KB/s 性能门槛仍由 performance 镜像
单独验证。用户同日执行
`just m36-perf-program 'Digilent/210512180081'` 下载 performance 镜像：
Vivado 报告 startup status `HIGH`，目标设备为 `xcku5p_0`，刷新后精确枚举
1 个 ILA core，脚本输出 `PASS`。尚待 performance 数据链路/性能和 JTAG-only
候选镜像板级验证及最终签署。

- `rtl/openfpga_debug`迁移为`rtl/yifpga_debug`。
- `sim/openfpga_debug`迁移为`sim/yifpga_debug`。
- Tcl、Python和约束文件新增`yifpga_*`canonical名称。
- 旧脚本保留wrapper，转发参数时不得使用字符串拼接执行未校验命令。
- 新Vivado工程使用`YiFPGAStudio.xpr`，旧工程保留只读迁移说明或短期兼容入口。
- 更新justfile、README、CI和所有显式RTL文件清单。
- `.gitignore`同时覆盖新旧Vivado生成目录。
- 不重命名或重新生成历史runs；新构建写入`YiFPGAStudio.runs`。

厂商构建由用户执行，建议验证配置：UART、JTAG、UART_AND_JTAG、JTAG disabled、
JTAG-only+ILA和performance+ILA。

门禁：离线回归全部通过；用户提供新工程的综合、实现、DRC、CDC、时序、bitstream和板级结果。

### YF.WP5：仓库与发布迁移

状态（2026-07-17）：**部分完成**。GitHub 仓库已从 `Don-207/OpenFPGAStudio` 重命名为
`Don-207/YiFPGAStudio`，本地 `origin` 已同步；外部链接、发布版本和干净clone验收仍待执行。

- GitHub仓库重命名为`YiFPGAStudio`，确认旧URL重定向可用。
- 更新clone URL、badge、issue/PR模板、release链接和外部文档。
- 发布迁移版本，Release Notes明确旧名称、兼容入口和删除时间表。
- 标签保持已有`v1.0.0`不变；品牌迁移使用新的版本标签。
- 对干净clone执行README快速开始和全部离线门禁。
- 抽查旧capture、旧snapshot、旧脚本入口和旧RTL wrapper。

完成后，新文档和新代码不得再引入未列入allowlist的`OpenFPGA/openfpga`标识。

## 6. 兼容矩阵

| 使用方 | 旧输入 | 新输入 | 迁移期行为 | 最终策略 |
| --- | --- | --- | --- | --- |
| Debug Protocol v1 | OpenFPGA命名文档 | YiFPGA命名文档 | wire完全相同 | v1永久兼容 |
| Diagnostic Snapshot | `openfpga.*` schema | 暂不新增 | 继续读写旧schema | 新major另行设计 |
| JavaScript API | `OpenFPGA*` | `YiFPGA*` | 两者指向同一实现 | 旧名延后移除 |
| Python CLI | `openfpga_*` | `yifpga_*` | 旧入口wrapper | 至少保留一个minor |
| RTL module | `openfpga_*` | `yifpga_*` | 旧module wrapper | 发布弃用周期后评估 |
| 构建宏 | `OPENFPGA_*` | `YIFPGA_*` | 宏alias | 旧宏延后移除 |
| 导出文件 | `openfpga-*` | `yifpga-*` | 读旧写新 | 文件内容决定格式 |
| Vivado工程 | `OpenFPGAStudio` | `YiFPGAStudio` | 历史工程不改 | 新构建只用新名 |

## 7. 自动检查

新增品牌检查脚本，将`OpenFPGA/openfpga`命中按路径和类别输出：

- `allowed_abi`：冻结schema、协议常量和兼容alias。
- `allowed_history`：历史验证记录、hash和真实旧路径。
- `pending_migration`：当前工作包允许存在的旧源码标识。
- `violation`：新文件或已迁移区域重新引入旧品牌。

检查脚本不得简单要求全仓零命中。目标是allowlist可审计、数量单调下降且ABI/历史证据不被误改。

每个工作包至少执行：

```text
git diff --check
just release-check
```

涉及RTL时追加当前全部硬件无关仿真；涉及Vivado时只准备用户执行的精确命令和预期产物，
不得由默认门禁隐式启动综合、实现或烧录。

## 8. 版本与弃用策略

- `v1.0.x`：可更新用户可见品牌，但不删除任何旧ABI或入口。
- 首个YiFPGA minor版本：新名称成为canonical，旧入口标记deprecated。
- 下一个minor版本：根据使用反馈决定是否继续保留旧Host入口。
- RTL wrapper、Protocol v1和schema v1的移除必须进入major版本评审。
- 任何删除都必须在前一版本Release Notes中预告，并提供迁移示例。

不建议将纯品牌迁移直接标记为`v2.0`；major版本应保留给真实不兼容协议或API变化。

## 9. 回滚策略

- 每个工作包使用独立分支和独立PR，不跨工作包压缩为一个巨型提交。
- 品牌展示可通过revert WP1恢复，不影响协议和RTL。
- Host alias迁移失败时恢复旧入口为canonical，新入口保留实验状态。
- RTL迁移失败时切回旧module实现，不修改wire format或板级约束。
- Vivado工程迁移失败时继续使用已签署的`YiFPGAStudio.xpr`和v1.0产物。
- 仓库改名最后执行；在此前所有源码和文档变化都可独立回退。

禁止通过覆盖、删除或重新生成历史证据完成回滚。

## 10. 完成定义

全部满足后，YiFPGA迁移才可标记完成：

- 产品、README、Viewer、当前使用说明和新Release统一使用`YiFPGA Studio`。
- 新旧Host入口等价测试通过。
- 旧RTL wrapper与新RTL canonical实现等价，所有仿真通过。
- Protocol v1、Mailbox ABI、Monitor寄存器和schema v1无语义变化。
- 旧capture、snapshot、JSONL和VCD可以继续导入。
- 新Vivado工程由用户完成所有候选配置构建和板级复验。
- 历史证据路径和hash未被改写。
- 品牌检查仅剩明确allowlist命中。
- 干净clone可按新README完成离线门禁和用户侧构建流程。
- Release Notes记录旧名称、兼容期限、限制和回退方法。

## 11. 推荐执行顺序

1. 完成YF.WP0名称、法律和资产冻结。
2. 合入YF.WP1品牌展示，不改代码ABI。
3. 合入YF.WP2 Host双命名兼容。
4. 合入YF.WP3 RTL wrapper和canonical标识。
5. 合入YF.WP4路径、脚本和Vivado工程迁移。
6. 完成用户侧构建、板级复验和干净clone验证。
7. 最后执行YF.WP5仓库改名与迁移版本发布。

不建议在v1.0正式标签前进行WP3至WP5；应先保留当前已签署候选的可复现基线，再在后续
minor版本开始内部标识迁移。

# OpenFPGA Studio 第三阶段 Monitor 实施计划

## 1. 阶段目标

根据 `YiFPGA_Studio_发展规划.docx`，第三阶段定位为 `OpenFPGA Monitor`：

- 寄存器浏览。
- 变量监视。
- 在线修改。

第三阶段承接第一阶段 Debug Core 和第二阶段 Trace，在保持现有 FPGA 到 PC 日志/Trace 链路稳定的基础上，补齐 PC 到 FPGA 的控制通道。核心目标是让开发者能在不中断 bitstream 运行的情况下查看内部寄存器、修改可控变量、触发安全命令，并把读写行为同步记录到 Viewer 和 Debug Protocol 中。

第三阶段不是性能分析器，也不是逻辑分析器；它关注的是“当前状态是什么”和“能否安全地改一个受控值”。

## 2. 阶段边界

必须完成：

- 定义 Monitor 协议扩展，使用 `0x20..0x2F` 保留类型空间。
- 增加 PC 到 FPGA 的命令帧接收路径，第一版以 UART RX 为目标。
- RTL 侧提供 `Monitor Register Map`，支持只读、读写、写一清零、触发型寄存器。
- Web Viewer 增加 Monitor 视图，支持寄存器列表、单次读、周期轮询、写入确认和错误显示。
- 提供板级 demo，暴露若干安全寄存器，例如 LED 控制、demo 参数、计数器、清零触发。
- 增加 parser/command encoder 回归测试和 RTL 命令路径仿真。

暂不完成：

- DDR、PCIe、AXI 吞吐率和延迟统计，此项属于第四阶段 Profiler。
- 连续波形采样和触发捕获，此项属于第五阶段 Open Logic Analyzer。
- AI 自动诊断，此项属于第六阶段 AI Debug。
- 不受控地写用户任意地址。第三阶段只写显式导出的 Monitor map。
- 复杂事务总线桥，例如完整 AXI-Lite master。第一版优先做小型本地寄存器窗口。

## 3. 总体架构

```text
Web Viewer Monitor View
    |
    | MONITOR_READ_REQ / MONITOR_WRITE_REQ / MONITOR_POLL_CFG
    v
Debug Protocol v1 command frames
    |
    | UART RX byte stream
    v
OpenFPGA Command RX + Parser
    |
    | monitor_req_valid / monitor_req_ready
    v
OpenFPGA Monitor Core
    |
    | register map read/write/trigger
    v
FPGA User Logic
    |
    | MONITOR_READ_RESP / MONITOR_WRITE_RESP / MONITOR_EVENT
    v
Existing Debug Core TX path
    |
    v
Web Viewer
```

模块边界：

- `Command RX`：接收 PC 发来的协议帧，完成 SOF/LEN/checksum 校验和命令分发。
- `Monitor Core`：维护寄存器 map，执行读写权限检查，输出响应或错误码。
- `Debug Core TX`：继续复用现有 packetizer/ring buffer/UART TX，发送 Monitor response、日志、Trace 和状态。
- `Viewer Monitor Model`：维护寄存器定义、最新值、pending 命令、错误状态和轮询任务。
- `User Logic Adapter`：把用户模块中的状态、控制位和触发命令映射成受控寄存器。

## 4. 协议扩展建议

沿用 Debug Protocol v1 帧格式，新增 Monitor 消息类型。第三阶段开始协议从单向上报扩展为双向命令/响应，但帧格式保持不变：

```text
SOF + VER + TYPE + LEN + PAYLOAD + CHECKSUM
```

### 4.1 类型分配

| Type | 方向 | 名称 | 说明 |
| --- | --- | --- | --- |
| `0x20` | PC -> FPGA | `MONITOR_READ_REQ` | 读取一个寄存器 |
| `0x21` | FPGA -> PC | `MONITOR_READ_RESP` | 读响应 |
| `0x22` | PC -> FPGA | `MONITOR_WRITE_REQ` | 写一个寄存器 |
| `0x23` | FPGA -> PC | `MONITOR_WRITE_RESP` | 写响应 |
| `0x24` | PC -> FPGA | `MONITOR_BURST_READ_REQ` | 连续读，第一版可选 |
| `0x25` | FPGA -> PC | `MONITOR_BURST_READ_RESP` | 连续读响应，第一版可选 |
| `0x26` | PC -> FPGA | `MONITOR_POLL_CFG` | 设置或取消轮询，第一版可由 Viewer 本地定时读替代 |
| `0x27` | FPGA -> PC | `MONITOR_EVENT` | Monitor 侧状态变化、拒绝写入或触发完成 |
| `0x28` | PC -> FPGA | `MONITOR_DISCOVER_REQ` | 查询寄存器 map 摘要，第一版可选 |
| `0x29` | FPGA -> PC | `MONITOR_DISCOVER_RESP` | 寄存器 map 摘要响应，第一版可选 |
| `0x2A..0x2F` | 双向 | 保留 | 后续扩展 |

第一版 P0 建议只实现 `READ_REQ/RESP` 和 `WRITE_REQ/RESP`，其余类型先进入协议文档和 Viewer model 预留。

### 4.2 公共字段

Monitor 命令建议包含 `seq` 字段，用于 Viewer 匹配响应和超时重试。

错误码建议：

| Code | 名称 | 说明 |
| --- | --- | --- |
| `0` | `OK` | 成功 |
| `1` | `BAD_ADDR` | 地址不存在 |
| `2` | `DENIED` | 权限不允许 |
| `3` | `BUSY` | Monitor core 忙或目标暂不可访问 |
| `4` | `BAD_LEN` | 长度或对齐错误 |
| `5` | `BAD_VALUE` | 写入值非法 |
| `6` | `TIMEOUT` | 内部访问超时 |

### 4.3 MONITOR_READ_REQ

```text
u16 seq
u16 addr
u8  width
```

- `addr` 是 Monitor register map 的逻辑地址，不是 FPGA 物理地址。
- `width` 第一版支持 `1/2/4` 字节，P0 可先固定为 `4`。

### 4.4 MONITOR_READ_RESP

```text
u32 timestamp
u16 seq
u16 addr
u8  status
u8  width
u32 value
```

长度：14 字节。即使 `width < 4`，`value` 也用 32 bit 承载。

### 4.5 MONITOR_WRITE_REQ

```text
u16 seq
u16 addr
u8  width
u32 value
u32 mask
```

- `mask` 支持位级修改。`new_value = (old_value & ~mask) | (value & mask)`。
- 对触发型寄存器，`mask` 可固定为 `0xFFFFFFFF`。

### 4.6 MONITOR_WRITE_RESP

```text
u32 timestamp
u16 seq
u16 addr
u8  status
u32 old_value
u32 new_value
```

长度：17 字节。若 `status != OK`，`old_value/new_value` 可返回 0 或当前实际值。

## 5. RTL 实施计划

### 5.1 新增模块

建议新增：

```text
rtl/openfpga_debug/
  openfpga_monitor_pkg.vh
  openfpga_debug_uart_rx.v
  openfpga_debug_command_parser.v
  openfpga_monitor_core.v
  openfpga_monitor_reg_bank.v
  openfpga_monitor_adapter.v
```

职责：

- `openfpga_monitor_pkg.vh`：Monitor type、status、权限、寄存器属性常量。
- `openfpga_debug_uart_rx.v`：UART RX 字节接收，参数与 TX 共用 `CLK_FREQ_HZ/UART_BAUD`。
- `openfpga_debug_command_parser.v`：复用 Debug Protocol 帧格式，解析 PC 命令帧并输出 Monitor request。
- `openfpga_monitor_core.v`：执行地址译码、权限检查、mask write、触发寄存器语义和响应生成。
- `openfpga_monitor_reg_bank.v`：示例寄存器窗口，用于 board demo 和仿真。
- `openfpga_monitor_adapter.v`：把 Monitor response 封装成 Debug Core TX 消息接口。

### 5.2 顶层接口建议

`openfpga_debug_top` 在第三阶段新增：

```verilog
input  wire        uart_rx,

output wire        monitor_req_valid,
output wire [15:0] monitor_req_addr,
output wire        monitor_req_write,
output wire [31:0] monitor_req_wdata,
output wire [31:0] monitor_req_wmask,
input  wire        monitor_req_ready,

input  wire        monitor_resp_valid,
input  wire [7:0]  monitor_resp_status,
input  wire [31:0] monitor_resp_rdata
```

P0 可以先把 Monitor Core 内置在 Debug Top 内部，P1 再把用户寄存器总线向外暴露。

### 5.3 寄存器属性

每个 Monitor register 至少定义：

| 字段 | 说明 |
| --- | --- |
| `addr` | 16 bit 逻辑地址 |
| `name` | Viewer 显示名，可由 JSON manifest 提供 |
| `width` | 1/2/4 字节 |
| `access` | RO/RW/W1C/TRIGGER |
| `reset_value` | 复位值 |
| `mask` | 可写 bit mask |
| `description` | 文档说明 |

示例地址规划：

| 地址 | 名称 | 属性 | 说明 |
| --- | --- | --- | --- |
| `0x0000` | `MONITOR_ID` | RO | 固定标识，例如 `0x4F464D30` |
| `0x0004` | `MONITOR_VERSION` | RO | Monitor core 版本 |
| `0x0008` | `CONTROL` | RW | demo 控制位 |
| `0x000C` | `LED_CONTROL` | RW | 板级 LED 控制 |
| `0x0010` | `DEMO_PERIOD` | RW | demo Trace/Event 周期参数 |
| `0x0014` | `COUNTER0` | RO | 自增计数器 |
| `0x0018` | `CLEAR_COUNTERS` | TRIGGER | 写 1 触发清零 |
| `0x001C` | `ERROR_STATUS` | W1C | 写 1 清对应错误位 |

### 5.4 安全策略

- 默认只导出显式声明的寄存器，不支持任意地址穿透。
- 写请求必须经过 `access` 和 `mask` 检查。
- 对可能影响链路稳定的参数增加范围限制，例如 `DEMO_PERIOD` 不允许写成 0。
- 触发型寄存器必须单周期脉冲化，避免命令重放导致持续动作。
- Viewer 必须显示写入前后的值和响应状态。
- Debug Core 在命令风暴下应保持 TX 日志/Trace 不被永久饿死，可对 RX 命令限速或返回 `BUSY`。

## 6. Viewer 实施计划

### 6.1 数据模型

在 `tools/viewer/web/app.js` 中新增 Monitor 状态：

```text
state.monitor = {
  registers: [],
  values: new Map(),
  pending: new Map(),
  seq: 1,
  pollEnabled: false,
  pollIntervalMs: 500,
  errors: []
}
```

寄存器定义第一版可写在 Viewer 静态 manifest：

```json
[
  {"addr": 0, "name": "MONITOR_ID", "access": "RO", "width": 4},
  {"addr": 12, "name": "LED_CONTROL", "access": "RW", "width": 4}
]
```

后续再由 `MONITOR_DISCOVER_REQ/RESP` 动态发现。

### 6.2 视图能力

Web Viewer 新增 `Monitor` 视图：

- 寄存器表格：地址、名称、权限、当前值、更新时间、状态。
- 单次读：选中或点击寄存器读取。
- 单次写：对 RW/W1C/TRIGGER 寄存器弹出写入确认。
- Mask 写：支持输入 value 和 mask。
- 周期轮询：按 manifest 中的 watch/poll 标记定时读取。
- 错误面板：显示超时、拒绝、非法地址、checksum 错误。
- 导出 JSONL：加入 `monitor_read`、`monitor_write`、`monitor_error`。

### 6.3 交互原则

- 写入操作必须有明确按钮和确认，不做输入框失焦自动写。
- RO 寄存器不显示写入控件。
- TRIGGER 寄存器使用动作按钮，例如 `Clear Counters`，不让用户误以为它保存状态。
- pending 请求要有超时，避免串口断开后 UI 一直等待。
- 写失败时保持旧值，并显示 FPGA 返回的 status。

## 7. 里程碑拆分

### M12：Monitor 协议与命令模型

目标：

- 固化 `0x20..0x2F` Monitor 消息类型。
- 更新协议文档，定义 read/write request/response payload。
- Web Viewer 增加命令 encoder、response parser 和 seq/pending model。
- 增加 parser/encoder 回归测试。

交付物：

- `doc/YiFPGA_Debug_Protocol_v1.md` Monitor 扩展章节。
- `tools/viewer/protocol_parser_test.py` Monitor 测试向量。
- `tools/viewer/web/app.js` Monitor parser/encoder model。
- `doc/M12_Monitor_协议与命令模型实施计划.md`

当前实现状态：

- 已补齐协议文档中的 Monitor 类型、状态码、read/write payload、parser 行为和示例帧。
- 已在 Web Viewer 中加入 Monitor 静态 register manifest、命令 encoder、response parser、`seq`/pending/timeout model 和 JSONL 记录。
- 已在 parser 回归测试中覆盖 read/write 编码、OK 响应、未知 `seq`、错误 `status` 和 timeout。

验收：

- 无硬件测试能构造 `READ_REQ/WRITE_REQ` 字节帧。
- 注入 `READ_RESP/WRITE_RESP` 后 Viewer 能匹配 seq 并更新寄存器状态。
- 未知 seq、错误 status、超时路径都有测试。

### M13：UART RX 与 Command Parser

目标：

- 新增 UART RX RTL。
- 新增 Debug Protocol command parser。
- 支持 PC 到 FPGA 的 Monitor request 解包。
- 覆盖 SOF 重同步、checksum 错误、半帧等待、非法 LEN。

交付物：

- `rtl/openfpga_debug/openfpga_debug_uart_rx.v`
- `rtl/openfpga_debug/openfpga_debug_command_parser.v`
- `sim/openfpga_debug/tb_openfpga_debug_command_parser.v`
- `prj/scripts/check_openfpga_monitor_m13_elab.tcl`

验收：

- XSim 输入 UART RX bit stream 后输出正确 Monitor request。
- checksum 错误不会产生写请求。
- parser reset 后状态清零。

当前实现状态：

- 已新增 `openfpga_debug_uart_rx.v` 和 `openfpga_debug_command_parser.v`。
- 已新增 `tb_openfpga_debug_command_parser.v`，覆盖 read/write、checksum 错误和 reset。
- 已新增 `check_openfpga_monitor_m13_elab.tcl`，Vivado RTL elaboration 已通过。

### M14：RTL Monitor Core 与寄存器窗口

目标：

- 新增 Monitor Core 和示例 register bank。
- 支持 RO/RW/W1C/TRIGGER 属性。
- 支持 read/write response 生成并接入现有 Debug Core TX path。
- 增加访问权限、mask write、非法地址和 busy 测试。

交付物：

- `rtl/openfpga_debug/openfpga_monitor_pkg.vh`
- `rtl/openfpga_debug/openfpga_monitor_core.v`
- `rtl/openfpga_debug/openfpga_monitor_reg_bank.v`
- `rtl/openfpga_debug/openfpga_monitor_adapter.v`
- `sim/openfpga_debug/tb_openfpga_monitor_core.v`

验收：

- 读 RO/RW 寄存器返回正确值。
- 写 RW 寄存器按 mask 修改。
- 写 RO 返回 `DENIED`。
- 写 W1C 清除指定 bit。
- 写 TRIGGER 产生单周期动作。

当前实现状态：

- 已新增 `openfpga_monitor_pkg.vh`、`openfpga_monitor_core.v`、`openfpga_monitor_reg_bank.v` 和 `openfpga_monitor_adapter.v`。
- 已在 Debug Core 增加 Monitor response 注入口，复用现有 ring buffer、packetizer 和 UART TX。
- 已新增 `tb_openfpga_monitor_core.v`，覆盖 RO/RW/mask/W1C/TRIGGER/BAD_ADDR/BAD_VALUE，XSim 已通过。

### M15：Monitor Viewer 视图

目标：

- Web Viewer 增加 Monitor 视图入口。
- 支持寄存器表、读、写、触发按钮、轮询和错误显示。
- 支持 JSONL 导出 Monitor 操作记录。
- 保持 Log/Trace/Status 视图不回退。

交付物：

- `tools/viewer/web/index.html`
- `tools/viewer/web/app.js`
- `tools/viewer/web/styles.css`
- `doc/YiFPGA_Web_Viewer_使用说明.md` Monitor 章节。
- `doc/M15_Monitor_Viewer实施计划.md`

验收：

- `Inject Sample` 或测试钩子能展示 Monitor read/write 响应。
- 写请求能生成正确帧。
- 错误响应和超时可见。
- 周期轮询不会造成 UI 卡顿。

当前实现状态：

- Web Viewer 已新增 Monitor 面板、寄存器表、Read/Write/Trigger、轮询和错误列表。
- `Inject Sample` 已加入 Monitor read/write response，JSONL 导出包含 Monitor history/error。
- `YiFPGA_Web_Viewer_使用说明.md` 已补充 Monitor 章节。

### M16：板级 Demo 与第三阶段发布

目标：

- 板级 demo 接入 UART RX 和 Monitor register bank。
- Viewer 能在线控制安全 demo 寄存器，例如 LED、demo 频率、计数器清零。
- 完成无硬件、仿真、Vivado elaboration、板级四类验收。
- 整理第三阶段使用说明和验证记录。

交付物：

- `rtl/board/openfpga_debug_board_demo.v` Monitor 接入。
- `sim/board/tb_openfpga_debug_board_monitor.v`
- `prj/scripts/check_openfpga_monitor_m16_elab.tcl`
- `doc/YiFPGA_Monitor_使用说明.md`
- `doc/YiFPGA_Studio_第三阶段Monitor验证记录.md`
- `doc/YiFPGA_Studio_第三阶段Monitor发布Checklist.md`

验收：

- Web Viewer 读到 `MONITOR_ID/MONITOR_VERSION`。
- 写 `LED_CONTROL` 后板级 LED 行为变化。
- 写 `DEMO_PERIOD` 后 Trace/Event 周期变化，且无异常丢包。
- 写 `CLEAR_COUNTERS` 后计数器清零。
- 长稳 30 分钟，checksum error 不持续增长，非法写入能被拒绝并记录。

当前实现状态：

- `openfpga_debug_board_demo.v` 已接入 UART RX、Command Parser、Monitor Core 和 response adapter。
- 已新增 `tb_openfpga_debug_board_monitor.v`，覆盖 UART RX 到 Monitor response 的板级路径，XSim 已通过。
- 已新增 `check_openfpga_monitor_m16_elab.tcl`，Vivado RTL elaboration 已通过。
- 已新增 Monitor 使用说明、验证记录和发布 checklist。
- `uart_rx` 引脚约束已补充到板级 XDC，后续进入 bitstream 构建和板级长稳验证。

## 8. 验收场景

### 8.1 无硬件验收

打开 `tools/viewer/web/index.html` 后点击 `Inject Sample` 或 Monitor 测试入口：

- Monitor 视图出现寄存器表。
- 注入 `READ_RESP` 后对应寄存器值更新。
- 注入 `WRITE_RESP OK` 后显示 old/new value。
- 注入 `DENIED/BAD_ADDR` 后错误面板显示。
- JSONL 导出包含 Monitor 操作。

### 8.2 RTL 仿真验收

建议新增：

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_monitor_pkg.vh rtl\openfpga_debug\openfpga_debug_uart_rx.v rtl\openfpga_debug\openfpga_debug_command_parser.v sim\openfpga_debug\tb_openfpga_debug_command_parser.v
xelab tb_openfpga_debug_command_parser -s tb_openfpga_debug_command_parser_sim
xsim tb_openfpga_debug_command_parser_sim -runall
```

Monitor Core：

```powershell
xvlog -i rtl\openfpga_debug rtl\openfpga_debug\openfpga_monitor_pkg.vh rtl\openfpga_debug\openfpga_monitor_core.v rtl\openfpga_debug\openfpga_monitor_reg_bank.v sim\openfpga_debug\tb_openfpga_monitor_core.v
xelab tb_openfpga_monitor_core -s tb_openfpga_monitor_core_sim
xsim tb_openfpga_monitor_core_sim -runall
```

### 8.3 Vivado Elaboration

建议新增：

```powershell
vivado -mode batch -source prj/scripts/check_openfpga_monitor_m16_elab.tcl
```

期望：

```text
PASS: OpenFPGA Monitor M16 board demo Vivado RTL elaboration completed
```

### 8.4 板级验收

使用 Chrome 或 Edge 打开 Web Viewer：

1. 下载包含 Monitor 的 board demo bitstream。
2. 连接 FPGA `uart_tx` 到 PC RX，并连接 PC TX 到 FPGA `uart_rx`。
3. 选择与 RTL 一致的 baud rate。
4. 在 Monitor 视图读取 `MONITOR_ID` 和 `MONITOR_VERSION`。
5. 写 `LED_CONTROL`，确认板级 LED 行为变化。
6. 写 `DEMO_PERIOD`，确认 Event/Trace 周期变化。
7. 写非法地址和 RO 寄存器，确认 Viewer 显示错误且 FPGA 状态稳定。
8. 连续运行 30 分钟，确认 Debug/Trace/Monitor 三类流量共存。

## 9. 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| 双向 UART 接线或波特率错误 | Monitor 无响应或 checksum error | Viewer 明确显示 pending 超时；文档强调 TX/RX 交叉和共地 |
| 命令帧误触发写入 | FPGA 状态被意外修改 | checksum、seq、access、mask 四层检查；写操作需 Viewer 确认 |
| RX 命令风暴挤占 TX 日志/Trace | 原有观测能力下降 | RX 限速、返回 BUSY、TX 优先级保留 Debug/Trace |
| 写入值非法 | demo 或用户逻辑异常 | 每个 RW 寄存器配置合法 mask/range，非法返回 BAD_VALUE |
| 与 Profiler 范围混淆 | 第三阶段范围膨胀 | Monitor 只读写状态和控制，不做吞吐率/延迟统计 |
| 寄存器 map 文档和 RTL 不一致 | Viewer 显示错误 | P0 使用共享 manifest，P1 支持 discover 或生成脚本 |

## 10. 推荐优先级

建议按 `M12 -> M13 -> M14 -> M15 -> M16` 推进：

1. 先固化 Monitor 协议和 Viewer 命令模型，避免 RTL 和上位机对 read/write payload 理解不一致。
2. 再做 UART RX 和 command parser，先把 PC 到 FPGA 的字节链路打通。
3. 然后实现 Monitor Core 和本地 register bank，优先确保权限、mask、触发语义可靠。
4. 最后做 Viewer 交互和板级 demo，把 LED、周期参数、计数器清零作为第一批可见效果。

这样第三阶段可以在不破坏现有 Debug/Trace 单向观测链路的前提下，逐步引入在线控制能力。

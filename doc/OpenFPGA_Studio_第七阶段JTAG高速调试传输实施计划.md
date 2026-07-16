# OpenFPGA Studio 第七阶段 JTAG 高速调试传输实施计划

## 1. 阶段目标

第七阶段定位为 `JTAG High-Speed Debug Transport`，承接前六阶段已经形成的 Debug Protocol、Debug/Trace/Monitor/Profiler/Logic Analyzer 数据模型和 AI Debug 诊断能力。

本阶段的目标是在不占用用户 UART 引脚的情况下，通过 FPGA 原生 JTAG USER chain 输出 OpenFPGA Debug Protocol 数据，并采用类似 RTT 的“目标端高速写缓冲、主机端批量读取”方式提升有效吞吐。Viewer、Parser 和 AI Debug 不感知底层使用 UART 还是 JTAG。

P0 优先支持当前 Xilinx Vivado/7-Series board demo，完成 FPGA 到主机的只读高速输出、常驻 Host Bridge、Web Viewer 接入、与 UART/ILA 共存及板级吞吐验收。P1 再扩展 JTAG 双向命令和 Intel Virtual JTAG。

## 2. 阶段边界

### 2.1 必须完成

- 定义与厂商无关的 byte-stream Transport 接口和构建期 Transport 选择方式。
- 实现 UART、JTAG、UART_AND_JTAG 三种输出模式。
- 实现每路独立缓冲和非阻塞分发；JTAG 未连接或堵塞不能拖死 UART、Debug Core或用户逻辑。
- 实现 Debug Core 时钟域到 JTAG 时钟域的可靠 CDC。
- 实现 Xilinx BSCANE2/BSCANE3 vendor adapter，分配独立 USER chain。
- 实现 RTT 风格 BRAM 环形缓冲或批量 mailbox，避免 Tcl/Host 逐字节访问。
- 实现常驻 Python Host Bridge，完成 target 枚举、用户选择、批量读取、断线恢复和本地 socket 输出。
- Web Viewer 增加 JTAG Bridge 连接入口，复用现有 Debug Protocol Parser。
- 验证与 Vivado ILA/debug hub 的 BSCAN 资源和运行共存。
- 测量有效吞吐、延迟、CPU 占用、丢帧和重连恢复，不以理论 TCK 代替实际数据。
- 完成 RTL 仿真、Vivado elaboration、综合/实现记录、板级长稳、使用说明和发布 checklist。

### 2.2 P0 暂不完成

- 通过 JTAG 写 Monitor 寄存器、arm Logic Analyzer 或执行其他硬件控制。
- 自动下载 bitstream、自动选择多目标 JTAG 链中的器件或 cable。
- 绕过厂商驱动实现完整 USB-JTAG cable 协议栈。
- 保证 JTAG 在所有 cable、TCK、Vivado 版本和主机环境下达到固定吞吐。
- Intel Virtual JTAG、Lattice USER JTAG 和其他厂商适配器。
- 替代 Vivado Hardware Manager、ILA 或设备编程功能。
- 连续无损传输任意带宽的 Logic Analyzer 波形；数据源仍需服从缓冲和 drop policy。

### 2.3 P0 性能目标

阶段目标采用实测分级，不承诺由理论 TCK 直接换算的速率：

| 等级 | 有效吞吐 | 定位 |
| --- | ---: | --- |
| 最低发布门槛 | `>= 100 KB/s` | 明显高于 115200 UART，满足 Debug/Trace/Profiler |
| 推荐目标 | `>= 500 KB/s` | 支持更顺畅的 LA capture 和诊断快照 |
| 优化目标 | `1–2 MB/s` | 接近常见 RTT 式使用体验 |

若受 Vivado Tcl/Hardware Manager API 限制未达到最低门槛，阶段保持候选状态，并优先优化批量事务和 Host Bridge，而不是盲目提高 TCK。

## 3. 总体架构

```text
Debug / Trace / Monitor Response / Profiler / LA Readout
                         |
                         v
              Debug Protocol Packetizer
                         |
                  byte valid/ready
                         v
                 Transport Router
                    /          \
                   v            v
              UART TX FIFO   JTAG BRAM Ring Buffer
                                  |
                       Async CDC / Mailbox Control
                                  |
                       Xilinx BSCAN USER Adapter
                                  |
                         JTAG Cable / hw_server
                                  |
                         Python Host Bridge
                                  |
                        Local WebSocket/TCP
                                  |
                           Web Viewer Parser
                                  |
               Debug/Trace/Monitor/Profiler/LA/AI Debug
```

分层原则：

- `Packetizer` 只生成 Debug Protocol v1 字节流，不包含 JTAG 状态。
- `Transport Router` 只负责按构建配置分发和独立 drop 统计。
- `JTAG Buffer` 负责数据保存、读写指针、批量读取和 overflow。
- `Vendor Adapter` 只封装 BSCAN 原语、USER instruction 和 TAP 侧移位语义。
- `Host Bridge` 只负责 JTAG 数据搬运和本地连接，不重复实现业务 Parser。
- `Viewer` 复用现有串口输入后的统一 byte-stream/Parser 入口。

## 4. RTT 风格缓冲与传输模型

### 4.1 为什么使用 BRAM mailbox

逐字节执行 Vivado Tcl 或 Hardware Manager 操作会让主机调用开销远大于 JTAG 移位时间。P0 使用 FPGA 侧 BRAM 环形缓冲，让 Debug Core 连续写入，Host Bridge 按 256 B–4 KB 的块读取。

```text
Producer write pointer ---> [ BRAM ring buffer ] <--- Host read pointer
       FPGA clock                                      JTAG clock
```

建议默认参数：

- 缓冲深度：16 KB，可配置为 4/8/16/32/64 KB。
- Host 单次最大读取：1 KB，协商范围 256 B–4 KB。
- 数据宽度：内部 8 bit byte stream；BRAM 可按 32 bit 聚合存储。
- 指针：单调递增逻辑指针，地址取低位；跨域同步使用 Gray code 或异步 FIFO等价结构。
- overflow policy：默认 drop newest，并增加饱和计数；可选 drop oldest 仅作为 P1。

### 4.2 Mailbox 状态

JTAG control/status header 建议包含：

```text
u32 magic              // "OFJT"
u16 transport_version
u16 capabilities
u32 session_id
u32 buffer_size
u32 write_count
u32 read_count
u32 available_bytes
u32 overflow_count
u32 dropped_bytes
u32 build_id
```

说明：

- Mailbox header 是 JTAG Transport 内部协议，不替代 Debug Protocol v1。
- payload 中保存完整、未经重编码的 Debug Protocol 帧。
- `session_id` 在 FPGA reset 或 Transport reset 后变化，Host 据此丢弃旧半帧状态。
- Host 更新 `read_count` 前必须完成对应 block 读取，避免覆盖尚未消费的数据。
- 所有计数器的回绕语义必须在设计说明和仿真中固定。

### 4.3 背压和双输出

`UART_AND_JTAG` 不使用一个公共 ready 同时等待两路：

- Packetizer 数据分别写入 UART FIFO 与 JTAG buffer。
- 某一路满时只增加该路 drop/overflow。
- 高优先级 Status/Error 可预留独立空间；P0 可先采用统一 drop policy，但必须可见。
- JTAG cable 未连接时不得形成全局 backpressure。
- Transport 统计进入现有 Status/Viewer，但不得造成递归日志风暴。

## 5. RTL 实施计划

建议新增：

```text
rtl/openfpga_debug/
  openfpga_transport_router.v
  openfpga_jtag_ring_buffer.v
  openfpga_jtag_mailbox.v
  openfpga_jtag_transport.v

rtl/vendor/xilinx/
  openfpga_jtag_bscan_xilinx.v

sim/openfpga_debug/
  tb_openfpga_transport_router.v
  tb_openfpga_jtag_ring_buffer.v
  tb_openfpga_jtag_transport.v
```

若项目后续允许 SystemVerilog，新模块优先使用 `.sv`；若需要与当前 Verilog-2001/XSim/Vivado 2020.2 文件列表保持一致，可在本阶段继续使用 `.v`，但必须记录原因。

实现要求：

- 顶层只实例化和连接，不把 TAP FSM、mailbox 或缓冲状态机写入 board top。
- BSCANE2/BSCANE3 只存在于 Xilinx adapter，通用模块不得直接实例化厂商原语。
- Debug clock、DRCK/TCK 域复位分别同步释放。
- 多 bit 指针不能逐 bit 直接同步；使用 async FIFO、Gray pointer 或握手快照。
- USER chain 编号集中定义并支持参数覆盖，禁止散落硬编码。
- 增加 transport version、capabilities、overflow 和 dropped counters。
- JTAG Transport 可通过参数完全裁剪，关闭后不占用 BSCAN/BRAM。
- 不为 JTAG 新增外部引脚约束，使用器件专用 JTAG 管脚。

## 6. Xilinx BSCAN 与 ILA 共存

当前工程已经使用 Vivado ILA/debug hub，因此第七阶段必须把“可以综合”与“可以同时使用”分开验收。

P0 规则：

- 为 OpenFPGA Transport 使用独立 USER chain，具体编号由器件和现有 debug hub 占用情况确定。
- 生成设计前通过 Tcl 报告 BSCANE2/BSCANE3、debug hub 和 USER chain 使用情况。
- 不修改生成目录中的 dbg_hub/IP netlist；所有设置通过源 RTL、IP/Tcl 和工程脚本完成。
- 分别验证仅 JTAG Transport、仅 ILA、JTAG Transport+ILA 三种构建。
- 板级同时打开 ILA 和 Host Bridge，确认两者可枚举、触发和读取。
- 如果器件或工具链无法稳定共存，允许构建期互斥，但必须在发布说明中明确，不得静默占用同一 chain。

## 7. Host Bridge 实施计划

建议新增：

```text
tools/jtag/
  openfpga_jtag_bridge.py
  jtag_backend.py
  xilinx_hw_server_backend.py
  bridge_protocol.py
  test_jtag_bridge.py

prj/scripts/
  openfpga_jtag_discover.tcl
  openfpga_jtag_read.tcl
```

Host Bridge 职责：

- 枚举 cable、target、device、USER chain 和 mailbox capability。
- 多 cable 或多 device 时列出目标并要求用户选择，不自动猜测。
- 常驻连接并批量读取 available data。
- 通过本地 WebSocket/TCP 输出原始 Debug Protocol 字节。
- 提供 connect/disconnect/reconnect、timeout、cancel 和退出清理。
- 显示读取块数、有效字节、吞吐、overflow、drop、session reset 和错误。
- 可选保存 raw binary，便于脱离 Viewer 复盘。

工程约束：

- Python 使用 `subprocess.run([...], shell=False, check=True)` 调用 Tcl/厂商工具。
- Tcl 负责 Vivado Hardware Manager/JTAG 事务；Python 不拼接未经校验的 Tcl 命令字符串。
- 凭据不是本阶段需求；本地 socket 默认只监听 loopback。
- Host Bridge 与 Viewer 之间增加轻量握手，包含 bridge version、transport、target 和状态，不修改 FPGA Debug Protocol payload。
- 必须提供 `--self-test`，无需 JTAG hardware 即可验证 mailbox、分块、重连和 socket framing。

若 Vivado Hardware Manager Tcl 无法实现持续高效 block read，则评估顺序为：

1. 减少命令次数并扩大单次 shift/read block。
2. 使用常驻 Vivado/XSDB session，避免每次启动进程。
3. 评估 XVC 或厂商正式 API。
4. 最后才评估 cable-specific libusb 后端；不得在 P0 无限制扩大范围。

## 8. Viewer 接入

Web Viewer 增加 JTAG Bridge 连接选项：

- 地址默认 `127.0.0.1` 和固定/可配置端口。
- 显示 bridge version、cable、device、USER chain、session id 和连接状态。
- 显示当前/平均吞吐、buffer used、overflow、dropped bytes 和 reconnect count。
- JTAG 字节进入与 Serial 相同的 Parser，不维护第二套 Debug/Trace/Profiler/LA 模型。
- 连接断开时保留已接收记录，重新连接后依据 session id 和 SOF 恢复。
- 禁止同时把 UART 与 JTAG 的同一份双输出数据无标识合并进一个会话；用户可选择单源，或在 P1 增加去重策略。

第六阶段 AI Debug 只消费 Viewer 中已经解析的数据，因此无需修改 AI Provider 或诊断 schema。可在 snapshot `target` 中记录 `transport = jtag` 和 bridge 统计，供链路健康规则使用。

## 9. 里程碑拆分

### M32：Transport 抽象与 JTAG Mailbox 协议

目标：

- 固化 byte-stream Transport 接口、构建模式和非阻塞 fan-out。
- 定义 JTAG mailbox header、session、指针、批量读取和 overflow 语义。
- 固化性能测试方法和 P0 吞吐门槛。
- 完成设计说明、数据结构 fixture 和无硬件模型。

交付物：

- `doc/OpenFPGA_JTAG_Transport_设计说明.md`
- `doc/M32_Transport抽象与JTAGMailbox协议实施计划.md`
- Host mailbox model/test fixture。

### M33：JTAG Ring Buffer、CDC 与 Xilinx BSCAN RTL

目标：

- 实现 Transport Router、BRAM ring buffer、mailbox 和 Xilinx adapter。
- 覆盖 UART/JTAG/双输出、满/空/回绕、停读/慢读、reset/session 和 CDC。
- 支持参数关闭 JTAG 功能。
- 完成 XSim 和 Vivado elaboration。

交付物：

- `rtl/openfpga_debug/openfpga_transport_router.v`
- `rtl/openfpga_debug/openfpga_jtag_ring_buffer.v`
- `rtl/openfpga_debug/openfpga_jtag_mailbox.v`
- `rtl/openfpga_debug/openfpga_jtag_transport.v`
- `rtl/vendor/xilinx/openfpga_jtag_bscan_xilinx.v`
- `sim/openfpga_debug/tb_openfpga_jtag_transport.v`
- `doc/M33_JTAG_RTL与XilinxBSCAN实施计划.md`

### M34：常驻 Host Bridge 与批量读取

目标：

- 实现 Python Host Bridge、自测试和 Xilinx backend。
- 支持目标枚举与显式选择、常驻 session、批量读取和本地 socket。
- 支持断线重连、session reset、raw capture 和性能统计。
- 使用 Mock backend 完成无硬件回归。

交付物：

- `tools/jtag/openfpga_jtag_bridge.py`
- `tools/jtag/xilinx_hw_server_backend.py`
- `tools/jtag/test_jtag_bridge.py`
- `prj/scripts/openfpga_jtag_discover.tcl`
- `prj/scripts/openfpga_jtag_read.tcl`
- `doc/M34_JTAG_HostBridge实施计划.md`

### M35：Viewer 接入与 RTT 风格性能优化

目标：

- Viewer 增加 JTAG Bridge 连接、状态和统计。
- JTAG 与 Serial 复用同一个 Parser 和业务模型。
- 调整 block size、polling、BRAM depth 和 socket batching。
- 在真实或可重复环境中达到最低 `100 KB/s`，冲刺 `500 KB/s–2 MB/s`。
- 验证 Debug/Trace/Profiler/LA/AI Debug 全链路。

交付物：

- `tools/viewer/web/index.html`
- `tools/viewer/web/app.js`
- `tools/viewer/web/styles.css`
- `doc/OpenFPGA_JTAG_Transport_使用说明.md`
- `doc/M35_Viewer接入与JTAG性能优化实施计划.md`

### M36：ILA 共存、板级长稳与第七阶段发布

目标：

- 完成 UART、JTAG、双输出和 JTAG关闭四种构建/运行模式验收。
- 完成 JTAG Transport 与 ILA/debug hub 共存验证。
- 完成吞吐、延迟、CPU、drop、overflow、断线恢复和 30 分钟长稳记录。
- 完成验证记录、已知限制、发布 checklist 和版本收口。

交付物：

- `doc/OpenFPGA_Studio_第七阶段JTAG高速调试传输验证记录.md`
- `doc/OpenFPGA_Studio_第七阶段JTAG高速调试传输发布Checklist.md`
- `doc/M36_ILA共存与第七阶段发布实施计划.md`

## 10. 验收计划

### 10.1 无硬件 Host 回归

```text
python tools/jtag/openfpga_jtag_bridge.py --self-test
python tools/jtag/test_jtag_bridge.py
python tools/viewer/protocol_parser_test.py
```

覆盖：

- mailbox header 和版本校验。
- block 边界、环形回绕、空读、短读和超大请求拒绝。
- session reset、断线、迟到 block 和重复 block。
- socket 客户端连接/断开、慢客户端和 raw capture。
- UART 与 JTAG 的同一测试向量产生等价 Parser 记录。

### 10.2 RTL 仿真

至少覆盖：

- Debug clock 到 JTAG clock 的 CDC 数据完整性和顺序。
- ring buffer 满/空、指针回绕、overflow 和饱和计数。
- Host 不读取、慢速读取、突发读取和恢复读取。
- UART、JTAG、UART_AND_JTAG 三种模式。
- JTAG 满时 UART 继续输出，UART 满时 JTAG 继续输出。
- reset/session 变化后 Host 从合法帧边界恢复。
- 参数关闭 JTAG 后相关逻辑被裁剪且 UART 行为不变。

### 10.3 Vivado 检查

- RTL elaboration 通过。
- CDC 报告中 JTAG/Debug 跨域结构符合设计，未出现未约束多 bit 直连。
- 综合报告记录 BRAM、LUT、FF、BUFG和BSCANE2/BSCANE3资源。
- 实现满足当前工程时序约束，不为掩盖 CDC 添加无依据 false path。
- 报告 USER chain 和 debug hub/ILA 资源占用。

按照项目 FPGA 工作流，综合、实现、bitstream 生成和板级下载前必须由用户确认具体命令。

### 10.4 板级功能验收

1. 下载包含 JTAG Transport 的 board demo bitstream。
2. 启动 Host Bridge，枚举并显式选择 cable、device 和 USER chain。
3. Viewer 连接本地 bridge，确认 mailbox magic、version、session 和 build id。
4. 只连接 JTAG，确认 HEARTBEAT、Debug、Trace 和 Profiler 持续进入 Viewer。
5. 触发一次 LA capture/readout，确认波形完整并可导出 VCD/JSONL。
6. 生成一次 AI Debug snapshot，确认 transport health 和原始证据完整。
7. 停止 Host Bridge 后继续运行 FPGA，再连接并确认 overflow/drop 符合设计。
8. 拔插 cable 或关闭 hw_server，恢复后确认新 session/帧边界处理正确。
9. 打开 Vivado ILA，同时运行 Host Bridge，确认两者可用且不抢占 USER chain。
10. 切换 UART_AND_JTAG，比较两路 Parser 记录和 transport 统计。

### 10.5 性能与长稳

分别测试 256 B、512 B、1 KB、2 KB、4 KB block，以及可用的 TCK 设置：

| Block | TCK | 有效吞吐 | P50/P99 延迟 | Host CPU | FPGA drop | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 256 B |  |  |  |  |  |  |
| 512 B |  |  |  |  |  |  |
| 1 KB |  |  |  |  |  |  |
| 2 KB |  |  |  |  |  |  |
| 4 KB |  |  |  |  |  |  |

选择稳定配置连续运行 30 分钟：

- Debug/Trace/Profiler 持续输出。
- 周期性读取 LA capture。
- Host Bridge 和 Viewer 无死锁、无持续内存增长。
- overflow/drop 不持续增长；若数据源超过通道能力，计数准确且 UI 可见。
- ILA 可在长稳期间触发和读取。
- 断线重连至少 3 次均可恢复。

## 11. 发布完成判据

满足以下条件后，第七阶段 P0 可发布：

- M32–M35 交付物全部落地，文档与实现一致。
- JTAG disabled 时前六阶段功能和 UART 行为无回归。
- JTAG-only 模式完成 Debug/Trace/Profiler/LA/AI Debug 数据闭环。
- UART_AND_JTAG 任一路堵塞不会拖死另一条链路。
- CDC、ring buffer、mailbox 和 Host Bridge 自动测试通过。
- Vivado elaboration、综合、实现和时序检查通过。
- 与当前 ILA/debug hub 完成实际共存验证，或明确记录构建期互斥限制。
- 板级有效吞吐达到 `100 KB/s` 最低门槛，并记录推荐配置和瓶颈。
- 30 分钟长稳与至少 3 次断线重连通过。
- 多 JTAG target 场景要求用户选择，未发生自动选错器件。

## 12. 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| Vivado Tcl 调用开销大 | TCK 高但有效吞吐低 | 常驻 session、BRAM mailbox、批量读取、减少 host round-trip |
| JTAG 与 ILA/debug hub 抢占 BSCAN | 构建失败或硬件冲突 | 独立 USER chain、资源报告、三种共存构建与板级验证 |
| JTAG CDC 错误 | 丢字节、重复帧或亚稳态 | async FIFO/Gray pointer、复位同步、CDC报告和慢读/停读仿真 |
| 未连接 JTAG 反压主链路 | UART和用户逻辑被拖死 | 独立缓冲、非阻塞 fan-out、每路独立 drop 统计 |
| BRAM 缓冲仍然溢出 | 长时间停读后丢数据 | 可配置深度、可见 overflow、优先级/drop policy、Host及时批量读取 |
| 多 cable/device 自动选错 | 操作错误硬件 | 枚举后显式选择，保存用户选择但每次验证 target identity |
| 浏览器无法直接访问 cable | Web Viewer 无法连接 JTAG | Python loopback Host Bridge，统一 socket/Parser 入口 |
| 厂商 API 绑定 | 跨厂商迁移困难 | 通用 Transport 与 vendor backend 分层，Intel VJTAG作为P1 |
| 双输出产生重复记录 | Viewer 时间线和诊断重复 | P0 单会话选择单数据源；双输出用于独立对比，不自动合并 |
| 追求峰值导致不稳定 | 长稳丢帧或高 CPU | 以持续有效吞吐和P99延迟验收，不以瞬时峰值发布 |

## 13. 推荐推进顺序

建议按 `M32 -> M33 -> M34 -> M35 -> M36` 推进：

1. 先固定 Transport 和 mailbox 语义，避免 RTL、Tcl、Python 和 Viewer 对指针/块读取理解不一致。
2. 再实现 ring buffer、CDC 和 Xilinx BSCAN，用仿真证明未连接、慢读和回绕都不会拖死主链路。
3. 然后实现常驻 Host Bridge，以 Mock backend 固化目标选择、批量读取、重连和本地 socket。
4. 接入 Viewer 后进行 RTT 风格性能优化，以实际吞吐、延迟和 CPU 数据选择 block/TCK/缓冲配置。
5. 最后完成 ILA 共存、板级长稳、断线恢复和发布收口。

这样，第七阶段可以把 JTAG 建设为独立、可关闭、可测量的高速调试 Transport，而不是让厂商原语和 Host 工具侵入 Debug Core 或第六阶段 AI Debug。后续双向 Monitor/LA 控制和 Intel Virtual JTAG 可以在稳定的 P0 数据面上继续扩展。

# M32：Transport 抽象与 JTAG Mailbox 协议实施计划

## 1. 里程碑目标

在修改 RTL 和 Viewer 前冻结 JTAG 数据面的跨层契约，使 RTL、Tcl、Python Host Bridge 和 Viewer 对缓冲区、指针、会话及异常处理采用同一语义。

本里程碑只完成协议、模型和测试夹具，不接入真实 BSCAN，不以板级吞吐作为完成条件。

## 2. 前置条件与边界

- 复用 Debug Protocol v1 帧，不重新编码 payload。
- Transport 只承载 byte stream，不理解 Debug、Trace、Profiler 或 LA 业务。
- P0 为 FPGA 到 Host 的单向批量传输；反向 Monitor/LA 控制留到 P1。
- 默认 16 KB 缓冲区，允许配置 4/8/16/32/64 KB；默认最大块读取 1 KB。
- 溢出策略固定为 `drop newest`，并提供可见的 overflow/drop 计数。

## 3. 工作包

### WP1：冻结 Transport 接口

- 定义 `valid/ready/data` byte-stream 输入及 UART、JTAG、双输出、JTAG 关闭四种构建模式。
- 双输出采用两路独立缓冲和独立丢弃计数，任一路不得向另一条链路传播背压。
- 明确复位值、时钟域、参数范围及裁剪行为。

### WP2：冻结 Mailbox ABI

- 定义 magic、transport version、capabilities、session id、buffer size、读写计数、可用字节、overflow/drop 和 build id。
- 固定字段宽度、字节序、对齐、偏移和未知 capability 的兼容规则。
- 使用单调递增逻辑计数；地址只取低位；明确 32 位回绕时的模运算规则。
- Host 只有在成功读取完整数据块后才能提交 `read_count`。

### WP3：定义事务和异常状态机

- 规定 discover、attach、header read、block read、commit、idle poll、disconnect 和 reconnect 顺序。
- session 变化时丢弃 Host 侧未完成块，从下一合法 Debug Protocol SOF 恢复。
- 定义空读、短读、越界请求、版本不兼容、magic 错误、重复块和迟到块行为。

### WP4：建立无硬件参考模型

- 建立 Host mailbox model 和可复用二进制 fixture。
- 覆盖无回绕、跨尾回绕、满/空、溢出、计数回绕和 session reset。
- fixture 同时供 Python、RTL testbench 与 Viewer parser 使用，避免各层自造样本。

### WP5：冻结性能测量方法

- 定义有效吞吐、P50/P99 延迟、Host CPU、drop/overflow 的计算口径。
- 固定 256 B、512 B、1 KB、2 KB、4 KB 块大小测试矩阵。
- P0 发布最低门槛为持续有效吞吐 100 KB/s；500 KB/s–1 MB/s 作为冲刺目标，不作为 M32 完成条件。

## 4. 验证与验收

- 协议文档中的所有字段都有偏移、宽度、访问方向、复位值和版本语义。
- 参考模型对边界、回绕、溢出、reset/session 和非法请求测试全部通过。
- 同一 fixture 经 mailbox model 解包后与原始 Debug Protocol 字节逐字节一致。
- RTL、Host Bridge 和 Viewer 的后续任务均能仅引用本协议，不需要补充隐含约定。
- 评审关闭所有“待定”项后才允许进入 M33/M34 实现。

## 5. 交付物

- `doc/YiFPGA_JTAG_Transport_设计说明.md`
- 本实施计划
- Host mailbox model、二进制 fixture 与离线测试

## 6. 退出与回退条件

若 Vivado Hardware Manager 无法支持约定的批量事务，优先调整 Host backend 的事务组合，不改变 Debug Protocol payload；任何 Mailbox ABI 变更必须提升 transport version 并同步 fixture。

## 7. 实施结果

- [x] Transport 接口、构建模式与双输出非阻塞规则已冻结。
- [x] Mailbox v1 ABI、能力位、模计数、session 与异常语义已形成设计说明。
- [x] 已提供无硬件 Python reference model 和共享 Debug Protocol fixture。
- [x] 已覆盖 Header、回绕、满/空、drop newest、完整读后提交、非法请求及 session reset。
- [x] `just m32-check` 已作为 M32 离线验收入口。

M32 不包含 RTL、Vivado elaboration、综合或板级验证；这些工作从 M33 开始。

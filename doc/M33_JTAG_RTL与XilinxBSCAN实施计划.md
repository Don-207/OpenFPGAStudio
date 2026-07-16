# M33：JTAG RTL 与 Xilinx BSCAN 实施计划

## 1. 里程碑目标

实现可参数裁剪的 Transport Router、BRAM ring buffer、Mailbox、CDC 和 Xilinx BSCAN 适配层，并以 RTL 仿真及 Vivado elaboration 证明数据完整性和结构正确性。

## 2. 前置条件

- M32 Mailbox ABI、计数回绕、session 和 overflow 语义已经冻结。
- 已确认目标器件系列、Vivado 版本、当前 debug hub/ILA 用法和可用 USER chain。
- 不修改生成目录中的 debug hub/IP netlist，不新增外部 JTAG 引脚约束。

## 3. 实现顺序

### WP1：Transport Router

- 接入现有 Packetizer byte stream。
- 实现 UART、JTAG、`UART_AND_JTAG` 和 JTAG disabled 四种模式。
- 两路输出各自判满和计数，未连接 JTAG 时 UART 与业务逻辑继续运行。

### WP2：Ring Buffer 与 CDC

- 使用真双口 BRAM 或等价结构分隔 Debug clock 与 JTAG clock。
- 多 bit 指针采用 Gray code、异步 FIFO 或握手快照，禁止逐 bit 直接同步。
- 各时钟域复位同步释放；明确异步复位断言和 session 更新顺序。
- 实现满、空、尾部回绕、`drop newest`、饱和统计和可配置深度。

### WP3：Mailbox 与事务引擎

- 按 M32 ABI 暴露 header 和批量读取窗口。
- 保证 payload 块读完成后才接受 Host read-count commit。
- 对空读、超长请求、非法地址和 reset 中事务给出确定响应。

### WP4：Xilinx BSCAN Adapter

- 仅在 vendor adapter 中实例化 BSCANE2/BSCANE3。
- USER chain 集中参数化，通用 Transport 不依赖厂商原语。
- 对 CAPTURE、SHIFT、UPDATE、SEL、TCK/TDI/TDO 的时序关系编写模块头说明和断言。

### WP5：集成与裁剪

- 顶层只实例化和连线，不放置 TAP、Mailbox 或缓冲状态机。
- JTAG 关闭时裁剪 BSCAN/BRAM，且现有 UART 行为和时序接口不变。
- 增加 transport version、capabilities、build/session 和错误统计观测点。

## 4. 仿真矩阵

- 满、空、非回绕及跨尾回绕。
- Host 不读、慢读、突发读、暂停后恢复。
- Debug clock/JTAG clock 采用互质周期并随机化相位及复位释放。
- 数据源持续快于读取端时，验证保留数据顺序及精确 drop 计数。
- UART 满不阻塞 JTAG，JTAG 满不阻塞 UART。
- 事务中 reset 后 session 改变，Host 从合法帧边界恢复。
- 参数关闭 JTAG 后 UART 输出与基准向量逐字节一致。

## 5. 验收门禁

- XSim 回归全部通过，无丢失、重复或乱序字节。
- Vivado RTL elaboration 通过，未出现 latch、多驱动或位宽警告。
- CDC 结构审查无未保护的多 bit 跨域；不以无依据 false path 掩盖问题。
- BSCAN 原语仅存在于 Xilinx adapter，USER chain 无散落硬编码。
- 代码评审通过后停止；综合、实现、bitstream 和上板必须另行获得用户确认。

## 6. 交付物

- `rtl/openfpga_debug/openfpga_transport_router.sv`
- `rtl/openfpga_debug/openfpga_jtag_ring_buffer.sv`
- `rtl/openfpga_debug/openfpga_jtag_mailbox.sv`
- `rtl/openfpga_debug/openfpga_jtag_transport.sv`
- `rtl/vendor/xilinx/openfpga_jtag_bscan_xilinx.sv`
- `sim/openfpga_debug/tb_openfpga_jtag_transport.sv`
- 本实施计划及仿真记录

## 7. 退出与回退条件

若目标器件无法稳定实现 ILA 与所选 USER chain，共存问题记录到 M36；M33 仍须保证 JTAG-only elaboration 正确。若 BRAM 双口语义无法满足时钟关系，回退为经过验证的异步 FIFO，不接受裸多 bit CDC。

## 8. 实施状态

- [x] SystemVerilog Transport Router，UART/JTAG 独立接收与丢弃统计。
- [x] 双时钟 Ring Buffer，数据指针及 Header 统计均通过 Gray CDC。
- [x] Mailbox v1 Header 与 payload 抽象读接口。
- [x] 通用 Transport 集成与 UltraScale `BSCANE2` 厂商适配层隔离。
- [x] XSim 覆盖异步时钟、顺序读取、满缓冲、drop newest、Header magic 和 Router 独立阻塞。
- [ ] Vivado RTL elaboration 与 CDC 报告（执行前需要用户确认）。
- [ ] Packetizer/Board Demo 实际接入（与构建模式和 USER chain 决策一并进入后续集成）。

`session_id` 是 Transport 顶层输入，必须由不随 Transport 数据面一起清零的板级 session 管理器提供；每次 FPGA/Transport reset 后生成新的非零值。

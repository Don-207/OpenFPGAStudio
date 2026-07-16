# M34：JTAG Host Bridge 实施计划

## 1. 里程碑目标

实现常驻 Python Host Bridge、可替换 backend、Xilinx Hardware Manager backend 和本地 socket 输出，以批量方式将 Mailbox 中的原始 Debug Protocol 字节稳定送入 Viewer。

## 2. 前置条件与边界

- M32 Mailbox ABI 已冻结，M33 提供 RTL 或等价 Mock 模型。
- P0 默认只监听 loopback，不实现认证和远程访问。
- Tcl 负责 Vivado Hardware Manager/JTAG 操作；Python 负责生命周期、协议、统计和 socket。
- Python 调用外部工具采用参数数组和 `shell=False`，不拼接未校验 Tcl 命令。

## 3. 实现顺序

### WP1：Bridge 分层

- `jtag_backend.py` 定义 enumerate、open、read header、read block、commit 和 close 接口。
- `bridge_protocol.py` 定义 Bridge/Viewer 握手和 socket framing，不修改 FPGA payload。
- 主程序管理目标、pump loop、统计、取消、退出清理和 raw capture。

### WP2：Mock Backend 与自测试

- 模拟正常流、回绕、短读、慢读、溢出、断线和 session reset。
- `--self-test` 不依赖 Vivado、JTAG cable 或硬件。
- 用 M32 fixture 验证读取、commit、socket 分帧和重连的字节等价性。

### WP3：目标枚举与选择

- 枚举 cable、target、device、USER chain、magic/version/capabilities/build id。
- 多 cable 或多 device 时列出稳定身份并要求显式选择，不自动猜测。
- 重连时复核 target identity，禁止仅按临时索引盲目恢复。

### WP4：Xilinx 常驻 Backend

- Tcl 脚本封装 discover 和 block read，维持常驻 Vivado/XSDB 会话。
- 优先减少命令往返并扩大单次 shift/read；记录实际块长和耗时。
- 将 Tcl 错误映射为结构化 backend 错误，Python 实施有限退避重连。

### WP5：本地 Socket 与可观测性

- 握手包含 bridge version、transport、target 和当前 session。
- 暴露块数、有效字节、吞吐、overflow/drop、重连次数和最近错误。
- 慢 socket 客户端不得无限占用内存；采用有界队列和明确丢弃/断开策略。
- raw capture 保存原始 payload，并附带独立元数据便于回放。

## 4. 自动化测试

- header 版本、能力位、块边界、回绕、空读、短读和超大请求。
- 重复块、迟到块、commit 失败、session reset 和断线恢复。
- 客户端连接/断开、慢客户端、有界队列、取消和进程退出清理。
- 多目标时必须显式选择，错误 target identity 必须拒绝重连。
- 运行数千次 Mock block 后输出字节与 fixture 完全一致。

## 5. 性能调优次序

1. 减少 Tcl 命令次数并增大 block。
2. 保持 Vivado/XSDB session 常驻。
3. 评估 XVC 或厂商正式 API。
4. cable-specific/libusb backend 仅作为独立 P1 决策，不扩入 M34 P0。

## 6. 验收门禁

- `--self-test` 和 Host 单元/集成测试全部通过。
- Mock 环境支持连续运行、断线至少 3 次恢复，内存无持续增长。
- 多目标场景不会自动连接到未选择设备。
- Xilinx backend 能读取真实或受控 Mailbox；硬件验证须另行获得用户确认。
- Bridge 退出后无残留子进程、监听端口或未关闭 capture 文件。

## 7. 交付物

- `tools/jtag/openfpga_jtag_bridge.py`
- `tools/jtag/jtag_backend.py`
- `tools/jtag/xilinx_hw_server_backend.py`
- `tools/jtag/bridge_protocol.py`
- `tools/jtag/test_jtag_bridge.py`
- `prj/scripts/openfpga_jtag_discover.tcl`
- `prj/scripts/openfpga_jtag_read.tcl`
- 本实施计划与测试记录

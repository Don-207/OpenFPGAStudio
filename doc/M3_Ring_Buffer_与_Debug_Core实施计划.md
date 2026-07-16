# M3 Ring Buffer 与 Debug Core 实施计划

## 1. 目标

M3 将 M2 的直通发送链路升级为带缓冲的 Debug Core：

- `event`、`watch`、`debug_print` 三类输入先进入 ring buffer。
- `packetizer` 只从 ring buffer 顺序取包，UART 忙时不直接丢弃新消息。
- 每个消息在进入队列前附加 32-bit timestamp。
- 统计 `buffer_used`、`packet_count`、`drop_count`，便于 Viewer 和板级调试判断是否丢包。

第一版 ring buffer 采用 drop-new 策略：缓冲满且无法同时出队时，新的输入消息丢弃并累加 `drop_count`。

## 2. RTL 变更

### 2.1 `openfpga_debug_ring_buffer.v`

新增按整包存储的环形缓冲：

- 每个 entry 保存 `type + len + payload[255:0]`。
- `ADDR_WIDTH` 配置缓冲深度，默认 core 使用 16 entries。
- 提供 `wr_valid/wr_ready` 和 `rd_valid/rd_ready` 两组握手。
- 支持满缓冲时同周期读写，减少 UART 发送临界点上的无谓丢包。
- 输出 `used_count` 作为当前队列占用。

### 2.2 `openfpga_debug_core.v`

Core 改为两段结构：

1. 输入仲裁与封包 payload 生成。
2. ring buffer 出队后送入 `openfpga_debug_packetizer`，再由 UART TX 发送。

输入优先级保持 M2 行为：

```text
event > watch > debug_print
```

如果同一周期有多个输入，只接收最高优先级消息，其余计入 `drop_count`。

### 2.3 `openfpga_debug_top.v`

新增参数与状态输出：

- `BUFFER_ADDR_WIDTH`
- `buffer_used`

原有 `drop_count`、`packet_count` 保持。

## 3. 验收仿真

新增 `sim/openfpga_debug/tb_openfpga_debug_m3.v`，覆盖：

- 空缓冲启动后连续写入 Event、Watch、Debug Print。
- UART 输出顺序与写入顺序一致。
- 小深度缓冲下连续写入 8 个 Event，验证满缓冲 drop-new 策略。
- `packet_count` 只统计成功入队消息。
- `drop_count` 统计缓冲满和同周期低优先级输入丢弃。
- 发送完成后 `buffer_used` 回到 0。

## 4. 验收命令

```powershell
xvlog rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_debug_timestamp.v rtl\openfpga_debug\openfpga_debug_ring_buffer.v rtl\openfpga_debug\openfpga_debug_packetizer.v rtl\openfpga_debug\openfpga_debug_uart_tx.v rtl\openfpga_debug\openfpga_debug_core.v rtl\openfpga_debug\openfpga_debug_top.v sim\openfpga_debug\tb_openfpga_debug_m3.v
xelab tb_openfpga_debug_m3 -s tb_openfpga_debug_m3_sim
xsim tb_openfpga_debug_m3_sim -runall
```

期望结果：

```text
PASS: OpenFPGA Debug M3 ring buffer ordering and overflow checks passed
```

## 5. 留给 M4/M5 的事项

- M4 Viewer 可直接显示 `buffer_used/drop_count/packet_count`，并在 drop count 增长时提示用户 UART 带宽不足。
- M5 板级 demo 可根据 `buffer_used` 调低事件上报频率，或提高 UART baud rate。
- 自动 heartbeat/status 生成策略仍留给后续里程碑，M3 先保证核心队列和三类消息稳定闭环。

# M2 UART TX 与协议解析闭环实施计划

## 1. M2 目标

M2 的目标是把 M1 的协议和工程骨架推进到可仿真验证的单向闭环：

- FPGA 端可以把调试消息打包成 OpenFPGA Debug Protocol v1 帧。
- FPGA 端可以通过 UART TX 输出 8N1 串口波形。
- PC/Web Viewer 已有 parser 能解析同一协议格式的字节流。
- 仿真中可以从 UART 波形反采样出字节，并与预期协议帧逐字节比对。

M2 仍不实现 ring buffer。消息在 UART 忙或 packetizer 忙时会被丢弃并计入 `drop_count`，M3 再用 ring buffer 改善连续写入能力。

## 2. 本次实现范围

### 2.1 Packetizer

文件：`rtl/openfpga_debug/openfpga_debug_packetizer.v`

已实现：

- 帧格式：`SOF, VER, TYPE, LEN, PAYLOAD, CHECKSUM`
- `SOF = 0xA5`
- `VER = 0x01`
- payload 最大 32 字节
- checksum 使用 `VER ^ TYPE ^ LEN ^ PAYLOAD bytes`
- `msg_valid/msg_ready` 输入握手
- `out_valid/out_ready` 字节流输出握手

### 2.2 UART TX

文件：`rtl/openfpga_debug/openfpga_debug_uart_tx.v`

已实现：

- 参数化 `CLK_FREQ_HZ` 和 `BAUD`
- 8N1 发送格式：1 start bit，8 data bits LSB first，1 stop bit
- `data_valid/data_ready` 输入握手
- `tx` 空闲为高电平
- `busy` 标识正在发送

### 2.3 Debug Core 直通闭环

文件：`rtl/openfpga_debug/openfpga_debug_core.v`

已实现：

- 将 `event_valid/event_id/event_level/event_arg0` 打包为 `EVENT` 帧
- 将 `watch_valid/watch_id/watch_value` 打包为 `WATCH` 帧
- 将 `print_valid/print_id/print_arg0/print_arg1` 打包为 `DEBUG_PRINT` 帧
- 消息优先级：Event > Watch > Debug Print
- 成功接受消息时递增 `packet_count`
- 无法接受或同周期低优先级消息被覆盖时递增 `drop_count`

## 3. 验收测试

### 3.1 RTL UART 闭环仿真

文件：`sim/openfpga_debug/tb_openfpga_debug_protocol.v`

测试内容：

- 产生一个 `EVENT` 消息。
- 等待 UART TX 波形。
- 按配置波特率从 `uart_tx` 反采样出字节。
- 校验 16 字节完整协议帧：

```text
A5 01 03 0B 0B 00 00 00 01 10 01 78 56 34 12 1A
```

其中：

- `A5` 是 SOF。
- `01` 是协议版本。
- `03` 是 EVENT 类型。
- `0B` 是 payload 长度。
- payload 为 `timestamp=0x0000000B, event_id=0x1001, level=1, arg0=0x12345678`。
- `1A` 是 XOR checksum。

已通过命令：

```powershell
xvlog rtl\openfpga_debug\openfpga_debug_pkg.vh rtl\openfpga_debug\openfpga_debug_timestamp.v rtl\openfpga_debug\openfpga_debug_packetizer.v rtl\openfpga_debug\openfpga_debug_uart_tx.v rtl\openfpga_debug\openfpga_debug_core.v rtl\openfpga_debug\openfpga_debug_top.v sim\openfpga_debug\tb_openfpga_debug_protocol.v
xelab tb_openfpga_debug_protocol -s tb_openfpga_debug_protocol_sim
xsim tb_openfpga_debug_protocol_sim -runall
```

仿真结果：

```text
PASS: OpenFPGA Debug Protocol M2 UART frame matched expected bytes
```

### 3.2 Parser 最小测试程序

文件：`tools/viewer/protocol_parser_test.py`

测试内容：

- 正常 `EVENT` 帧解析。
- 半帧输入后等待后续字节。
- checksum 错误计数。
- SOF 前垃圾字节重同步。
- 未知 type 计数。

已通过命令：

```powershell
python tools\viewer\protocol_parser_test.py
```

测试结果：

```text
PASS: OpenFPGA Debug Protocol parser test vectors passed
```

## 4. M2 完成定义

M2 可认为完成，当以下条件同时满足：

- Packetizer 可以输出符合 Debug Protocol v1 的帧字节。
- UART TX 可以发送完整 8N1 字节流。
- Debug Core 可以把至少一种真实输入消息送到 UART。
- 仿真能够校验 UART 反采样字节与预期协议帧一致。
- Web Viewer parser 保持与协议文档一致，可继续用于注入样例和真实串口接收。

## 5. 留给 M3 的事项

- 加入 ring buffer，避免 UART 忙时直接丢消息。
- 加入 status/heartbeat 自动产生策略。
- 覆盖多消息连续写入、buffer 满、drop 统计和 packet 顺序。
- 扩展仿真，分别覆盖 `DEBUG_PRINT`、`WATCH`、`STATUS` 和错误帧恢复。

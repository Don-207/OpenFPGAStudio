# M12 Monitor 协议与命令模型实施计划

M12 是第三阶段 Monitor 的起点，目标是先把 PC 和 FPGA 对 read/write 命令的字节级理解固定下来，并在 Web Viewer 中落地可测试的命令模型。M12 不实现 UART RX RTL、Monitor Core 或完整 UI，这些分别放到 M13、M14 和 M15。

## 1. 目标

- 固化 Debug Protocol v1 中 `0x20..0x2F` Monitor 类型空间。
- 定义 `MONITOR_READ_REQ/RESP` 和 `MONITOR_WRITE_REQ/RESP` 的 payload 布局。
- 在 Viewer 中增加 Monitor command encoder、response parser、`seq`/pending/timeout 状态模型。
- 增加无硬件 parser/encoder 回归测试，覆盖正常响应、未知 `seq`、错误 `status` 和 timeout。

## 2. 协议范围

M12 正式启用：

| Type | 方向 | 名称 | M12 状态 |
| --- | --- | --- | --- |
| `0x20` | PC -> FPGA | `MONITOR_READ_REQ` | 定义并编码 |
| `0x21` | FPGA -> PC | `MONITOR_READ_RESP` | 定义并解析 |
| `0x22` | PC -> FPGA | `MONITOR_WRITE_REQ` | 定义并编码 |
| `0x23` | FPGA -> PC | `MONITOR_WRITE_RESP` | 定义并解析 |

M12 仅预留：

| Type | 名称 | 后续里程碑 |
| --- | --- | --- |
| `0x24/0x25` | Burst read | M15 或之后 |
| `0x26` | Poll config | M15 或之后，P0 先由 Viewer 本地定时读替代 |
| `0x27` | Monitor event | M14/M16 |
| `0x28/0x29` | Discover | P1 动态 register map |

## 3. Viewer 命令模型

`tools/viewer/web/app.js` 新增 Monitor 状态：

```text
monitor = {
  registers,
  values,
  pending,
  seq,
  pollEnabled,
  pollIntervalMs,
  errors,
  history
}
```

核心行为：

- `encodeMonitorRead(addr, width)` 生成 `MONITOR_READ_REQ` 帧，并登记 pending。
- `encodeMonitorWrite(addr, value, mask, width)` 生成 `MONITOR_WRITE_REQ` 帧，并登记 pending。
- `MONITOR_READ_RESP` 按 `seq` 匹配 pending；`status == OK` 时更新 register value。
- `MONITOR_WRITE_RESP` 按 `seq` 匹配 pending；`status == OK` 时使用 `new_value` 更新 register value。
- 未知 `seq`、非 OK `status` 和 timeout 进入 `monitor.errors`。
- JSONL 导出包含 Monitor history 和 Monitor error 记录。

## 4. 测试向量

`tools/viewer/protocol_parser_test.py` 增加 M12 向量：

- 构造 `READ_REQ`：`addr = 0x000C`，`width = 4`。
- 构造 `WRITE_REQ`：`addr = 0x000C`，`value = 0x00000005`，`mask = 0x0000000F`。
- 注入 `READ_RESP OK`，确认 pending 清除并更新寄存器值。
- 注入 `WRITE_RESP OK`，确认 pending 清除并更新寄存器值。
- 注入未知 `seq` 响应，确认进入错误记录。
- 注入 `DENIED` 写响应，确认进入错误记录且不按成功写处理。
- 人工触发 timeout，确认 pending 清除并记录 `TIMEOUT`。

## 5. 交付物

| 文件 | 内容 |
| --- | --- |
| `doc/OpenFPGA_Debug_Protocol_v1.md` | Monitor 类型、payload、状态码、parser 行为和示例帧 |
| `tools/viewer/protocol_parser_test.py` | Monitor parser/encoder 回归测试 |
| `tools/viewer/web/app.js` | Monitor encoder/parser/pending/timeout model |
| `doc/M12_Monitor_协议与命令模型实施计划.md` | 本实施计划 |

## 6. 验收

运行：

```powershell
python tools\viewer\protocol_parser_test.py
```

期望：

```text
PASS: OpenFPGA Debug Protocol parser test vectors passed
```

浏览器侧可通过 `window.openfpgaViewerTest` 验证：

```javascript
const api = window.openfpgaViewerTest;
api.clearAll();
const read = api.encodeMonitorRead(0x000C, 4);
const write = api.encodeMonitorWrite(0x000C, 5, 0x0F, 4);
```

`read.bytes` 和 `write.bytes` 应为合法 Debug Protocol v1 帧；后续 M15 会把这些能力接入可见 Monitor 视图。

## 7. 留给 M13

- 实现 `openfpga_debug_uart_rx.v`。
- 实现 `openfpga_debug_command_parser.v`。
- 将 `MONITOR_READ_REQ/WRITE_REQ` 从 UART RX 字节流解析成 RTL request 信号。
- 用 XSim 覆盖 SOF 重同步、checksum 错误、非法长度和半帧等待。

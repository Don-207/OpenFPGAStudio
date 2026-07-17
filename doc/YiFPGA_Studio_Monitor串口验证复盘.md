# OpenFPGA Studio Monitor 串口验证复盘

## 1. 背景

本次问题出现在 OpenFPGA Debug board demo 的 Monitor 双向串口验证中。

现象是 `tools/viewer/monitor_validate.ps1` 在 COM4 上等待第一条 `MONITOR_READ_RESP` 超时，表面看起来像 FPGA 没有收到 PC 发来的 UART RX 命令，或者没有返回响应。

后续通过串口原始帧抓取和 ILA 分层验证确认：硬件串口链路、UART RX、命令解析、Monitor response 生成路径都是通的，真正问题在 PC 侧 PowerShell 验证脚本。

## 2. 关键信息

| 项目 | 内容 |
| --- | --- |
| FPGA 器件 | `xcku5p-ffvb676-2-i` |
| 顶层 | `openfpga_debug_board_demo` |
| 串口 | `COM4` |
| UART | `115200 8N1` |
| ILA bitstream | `prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_ila.bit` |
| ILA probes | `prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_ila.ltx` |
| 验证脚本 | `tools/viewer/monitor_validate.ps1` |

## 3. 误导性现象

失败命令：

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\monitor_validate.ps1 -Port COM4 -Baud 115200 -TimeoutMs 2000
```

表面错误：

```text
Timed out waiting for Monitor response seq=16640 type=0x21
```

这个错误最初被误判为板端 UART RX 或 Monitor response 路径异常。

## 4. 证据链

### 4.1 FPGA 到 PC 的 TX 正常

`serial_validate.ps1` 在 COM4 上可以持续收到 FPGA 主动输出帧：

```text
frames_total=823
DEBUG_PRINT=24
EVENT=5
WATCH=496
STATUS=249
checksum_errors=0
unknown_frames=0
last_drop_count=0
```

说明 FPGA 到 PC 的 UART TX 链路正常，协议帧校验也正常。

### 4.2 ILA 看到 PC 到 FPGA 的 RX 输入

ILA probe 位图中：

| bit | 信号 |
| --- | --- |
| 50 | `uart_rx` |
| 51 | `monitor_byte_valid` |
| 52 | `monitor_uart_frame_error` |
| 56 | `monitor_req_valid` |
| 58 | `monitor_resp_valid` |
| 60 | `monitor_msg_valid` |

ILA 触发结果：

- `uart_rx` 出现低电平起始位。
- `monitor_byte_valid` 触发，首字节为 `0xA5`。
- `monitor_req_valid` 触发，说明 command parser 已经完整解析 Monitor 请求。
- `monitor_resp_valid` 和 `monitor_msg_valid` 出现，说明 Monitor core 和 response adapter 已经生成响应。

结论：PC 发出的 Monitor read request 已经进入 FPGA，并成功走到响应生成阶段。

### 4.3 PC 原始串口探针收到响应帧

使用原始探针发送一条 `READ ID(seq=0x4100)`，收到：

```text
FRAME type=0x21 len=14 checksum_ok=True
payload=CA 33 EC E6 00 41 00 00 00 04 30 4D 46 4F
```

解析：

| 字段 | 值 |
| --- | --- |
| type | `0x21`，`MONITOR_READ_RESP` |
| seq | `00 41`，小端，即 `0x4100` |
| addr | `00 00` |
| status | `00`，OK |
| width | `04` |
| value | `30 4D 46 4F`，小端，即 `0x4F464D30` |

结论：PC 侧实际收到了正确响应帧，验证脚本却把它当成不匹配而继续等待，最终报 timeout。

## 5. 根因

根因在 `tools/viewer/monitor_validate.ps1` 的 PowerShell 二进制解析细节。

### 5.1 `[byte] -shl 8` 被截断

原先类似逻辑：

```powershell
$Payload[($Offset + 1)] -shl 8
```

如果 `$Payload[...]` 是 `[byte]`，PowerShell 可能按 byte 结果截断，导致：

```text
0x41 << 8 => 0x00
```

因此响应 payload 中的 seq `00 41` 被错误解成 `0`，而不是 `0x4100`。

修复方式：

```powershell
([uint32]$Payload[($Offset + 1)]) -shl 8
```

### 5.2 数组索引表达式必须加括号

建议写法：

```powershell
$Payload[($Offset + 1)]
$raw[(4 + $i)]
```

避免表达式解析歧义。

### 5.3 `$VERSION` 被 `$version` 覆盖

PowerShell 变量名大小写不敏感。

原脚本中协议版本变量 `$VERSION = 0x01`，后续又使用 `$version = Invoke-Read ...` 保存 Monitor version 读结果，导致 `$VERSION` 被覆盖成 hashtable，后续组帧失败。

修复方式：将读结果变量改为 `$versionRead`。

### 5.4 `0xFFFFFFFF` 类型问题

PowerShell 中 `0xFFFFFFFF` 可能被当成 `-1`，传给 `[uint32]` 参数会失败。

修复方式：

```powershell
$allOnes = [uint32]::MaxValue
```

## 6. 已采取修复

`tools/viewer/monitor_validate.ps1` 已修复：

- `Read-U16` 和 `Read-U32` 对每个 byte 先转 `[uint32]` 再移位。
- Monitor version 读结果改名为 `$versionRead`，避免覆盖协议 `$VERSION`。
- write mask 使用 `[uint32]::MaxValue`。
- 增加 `-TraceFrames`，可打印等待函数看到的帧类型和 payload。
- 增加 `-SelfTest`，可离线验证协议编解码。
- 每次打开串口前自动静默执行 self-test，脚本自身坏掉时先失败，不再误导为硬件问题。

自检命令：

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\monitor_validate.ps1 -SelfTest
```

预期结果：

```text
PASS: monitor_validate self-test passed
```

板级验证命令：

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\monitor_validate.ps1 -Port COM4 -Baud 115200 -TimeoutMs 2000
```

已验证通过时输出：

```text
MONITOR_ID=0x4F464D30 status=OK
MONITOR_VERSION=0x00010000 status=OK
LED_CONTROL_WRITE ... status=OK
LED_CONTROL_READ value=0x00000003 status=OK
DEMO_PERIOD_WRITE ... status=OK
CLEAR_COUNTERS_WRITE status=OK
RO_WRITE_MONITOR_ID status=DENIED
PASS: OpenFPGA Monitor board validation passed
```

## 7. 推荐排查顺序

以后遇到类似串口双向验证失败，按以下顺序处理。

### 7.1 先验证工具

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\monitor_validate.ps1 -SelfTest
```

如果 self-test 不通过，不允许进入板级结论。

### 7.2 验证 FPGA 到 PC 的 TX

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\serial_validate.ps1 -Port COM4 -Baud 115200 -DurationSec 5
```

重点看：

- `frames_total`
- `checksum_errors`
- `sync_drops`
- `unknown_frames`
- `last_drop_count`

### 7.3 抓 PC 侧原始响应帧

如果 Monitor validate 报 timeout，先抓原始帧，不要立刻怀疑 RTL。

可使用：

```powershell
powershell -ExecutionPolicy Bypass -File tools\viewer\monitor_raw_probe.ps1 -Port COM4 -Baud 115200 -DurationMs 3000
```

重点看是否存在：

```text
FRAME type=0x21
FRAME type=0x23
```

以及 payload 中 seq 是否匹配请求。

### 7.4 再用 ILA 分层定位

如果 PC 原始侧也没有响应，再用 ILA 分层：

| 层级 | 观测点 |
| --- | --- |
| 物理输入 | `uart_rx` 是否变化 |
| UART RX | `monitor_byte_valid` 是否出现 |
| 帧解析 | `monitor_parser_state` 是否推进 |
| 请求生成 | `monitor_req_valid` 是否出现 |
| 响应生成 | `monitor_resp_valid` 是否出现 |
| 消息打包 | `monitor_msg_valid` 是否出现 |
| TX 忙状态 | `busy` 是否长期卡住 |

只有定位到某一层确实不动，再怀疑对应 RTL、约束、连线或波特率。

## 8. 验证脚本编写规则

后续 PowerShell 脚本处理二进制协议时必须遵守：

- 移位前显式转 `[uint32]` 或更宽整数。
- 数组索引表达式使用括号，例如 `$buf[($i + 1)]`。
- 协议常量变量名避免与业务结果变量重名。
- `0xFFFFFFFF` 使用 `[uint32]::MaxValue`。
- 所有协议编码/解码函数必须有离线 self-test。
- 板级脚本在打开硬件资源前先跑 self-test。
- timeout 前最好能输出已收到但未匹配的帧类型、seq 和 payload。

## 9. 核心结论

这次不是 FPGA 串口接收失败，而是 PC 验证脚本把正确响应解析成不匹配，最终误报 timeout。

以后板级问题排查要坚持：

```text
先证明验证工具可信，再怀疑硬件。
先抓原始字节，再判断业务协议。
先用 ILA 定位层级，再修改 RTL。
```

# OpenFPGA Studio 第三阶段 Monitor 发布 Checklist

## RTL

- [x] UART RX 字节接收。
- [x] Command Parser 解析 read/write request。
- [x] Monitor register bank 支持 RO/RW/W1C/TRIGGER。
- [x] Monitor response 复用 Debug Core TX path。
- [x] Board demo 接入 Monitor。

## Viewer

- [x] Monitor 寄存器表。
- [x] Read/Write/Trigger 操作。
- [x] Pending timeout 和错误显示。
- [x] JSONL 导出 Monitor history/error。
- [x] `Inject Sample` 覆盖 Monitor 示例。

## 验证

- [x] Viewer parser 回归。
- [x] M13 XSim。
- [x] M14 XSim。
- [x] M16 XSim。
- [x] M13 Vivado elaboration。
- [x] M16 Vivado elaboration。
- [x] 补充 `uart_rx` XDC。
- [x] Bitstream 构建。
- [ ] 板级 30 分钟长稳。

# M15 Monitor Viewer 实施计划

## 目标

- 在 Web Viewer 中增加 Monitor 面板。
- 支持寄存器表、单次读、写入确认、trigger、周期轮询和错误显示。
- JSONL 导出包含 Monitor read/write/error/history。

## 实现

- `tools/viewer/web/index.html`
  - 新增 Monitor section，包含寄存器表、轮询控制和错误侧栏。
- `tools/viewer/web/app.js`
  - 复用 M12 的 encoder/parser/pending model。
  - 新增 Web Serial write path，通过 `port.writable.getWriter()` 发送命令帧。
  - 写 RW/W1C 寄存器前使用 `confirm()` 确认。
  - TRIGGER 寄存器以动作按钮写入 `1`。
  - `Inject Sample` 注入 Monitor read/write response，支持无硬件验收。
- `tools/viewer/web/styles.css`
  - 沿用现有工程面板风格，新增紧凑表格、pending 行和错误列表样式。
- `doc/YiFPGA_Web_Viewer_使用说明.md`
  - 补充 Monitor 操作说明。

## 验收

- 打开 `tools/viewer/web/index.html`，点击 `Inject Sample`。
- Monitor 表格能显示 `LED_CONTROL` 和 `DEMO_PERIOD` 示例响应。
- 未连接串口时点击 Read/Write 会显示 `DISCONNECTED` 错误。
- 连接支持 Web Serial 的浏览器后，Read/Write 生成 `0x20/0x22` 命令帧。

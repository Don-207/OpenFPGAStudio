# OpenFPGA Studio 第五阶段 Open Logic Analyzer 验证记录

## 实现状态

M22–M25 已完成协议、RTL Core、Viewer 和 board demo 接入。M26 新增统一回归入口、LA 串口验证器、发布 bitstream 入口和安全的 JTAG target 选择。

## 发布信息

| 项目 | 内容 |
| --- | --- |
| FPGA part | `xcku5p-ffvb676-2-i` |
| Board | JTAG target `Digilent/210512180081`，FPGA `xcku5p_0`；板卡商品型号/版本待补 |
| Vivado version | `2020.2`（RTL elaboration） |
| Bitstream path | `prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_m26.bit`（15431260 bytes，2026-07-10 17:02:51） |
| Build command | `just la-bitstream` |
| Commit id | 当前目录未识别为 Git 工作树，待在仓库根目录填写 |
| UART | `COM8`，`115200 8N1` |
| LA depth/divisor | 验证器默认 `64 / 4` |

## 自动回归

短回归入口：

```text
just m26-check
```

单项命令可通过 `just --list` 查看。Vivado elaboration 和 bitstream 构建是独立确认门，不包含在短回归中。

| 检查项 | 命令 | 状态/证据 |
| --- | --- | --- |
| Parser | `just parser-test` | PASS：`OpenFPGA Debug Protocol parser test vectors passed` |
| Viewer 无硬件样例 | `just viewer-test` | PASS：11192 frames，checksumErrors=0，LA capture=1，LA channels=11 |
| LA 验证器离线自测 | `just la-validator-self-test` | PASS：`OpenFPGA Logic Analyzer validator self-test passed` |
| M23 Core XSim | `just la-core-sim` | PASS：`OpenFPGA Logic Analyzer M23 core capture checks passed` |
| M25 Board XSim | `just la-board-sim` | PASS：`OpenFPGA Logic Analyzer M25 board demo checks passed` |
| M25 RTL elaboration | `just la-elab` | PASS：0 warnings，0 critical warnings，0 errors |
| M26 bitstream | `just la-bitstream` | PASS：WNS +3.945 ns，TNS 0，0 failing endpoints |

## Bitstream 构建核验

2026-07-10 手动执行 `just la-bitstream`，成功生成：

```text
prj/OpenFPGAStudio.runs/impl_1/openfpga_debug_board_demo_m26.bit
size: 15431260 bytes
timestamp: 2026-07-10 16:45:22
```

实现报告结论：

- Route：11446/11446 routable nets fully routed，0 routing errors。
- Setup timing：未闭合，WNS `-14.194 ns`、TNS `-155.050 ns`、21 failing endpoints。
- Hold/Pulse width：无违例。
- Setup 违例集中在 `u_latency_profiler_probe` 的 `complete_count` 到 `metric_value3` 路径；RTL 对应可变 32-bit 除法 `next_latency_sum / next_complete_count`，最差路径 181 级逻辑。
- DRC：1 个 `RTSTAT-10 No routable loads` warning，涉及 Vivado `dbg_hub/u_ila_monitor` 内部网络；无 routing error。

上述结果对应 16:45 的首次镜像；该镜像仅完成写出但未满足 M26 发布时序门槛，现已被后续修复后镜像替代。

## Timing 修复

2026-07-10 已将 `openfpga_profiler_latency` 的单周期可变 32-bit 除法替换为 32 周期 restoring divider：

- 平均值仍为精确整数 `floor(latency_sum / complete_count)`，协议字段不变。
- 完成事件的 `metric_valid` 延迟 32 个 `sys_clk` 周期；board demo 既有 pending 机制负责接收。
- 除法期间锁存 numerator、divisor 和 metric values，阻止新测量覆盖在途结果。
- 单周期关键路径由最高 181 级组合除法缩短为 33-bit 比较/减法。

修复后已通过：

- `PASS: OpenFPGA Profiler M19 probe checks passed`
- `PASS: OpenFPGA Profiler M21 board demo checks passed`
- `PASS: OpenFPGA Logic Analyzer M25 board demo checks passed`

以下重新实现结果用于确认修复后的 timing closure；前述负 WNS/TNS 仅保留为问题定位记录。

### 修复后重新实现结果

2026-07-10 17:02 完成重新实现：

- Bitstream：`openfpga_debug_board_demo_m26.bit`，15431260 bytes。
- SHA-256：`D3E4774B2ED70631CE8D97D2AF5B18DE73A73094CD3D68EAB8FBE424B3D4299C`。
- Setup：WNS `+3.945 ns`，TNS `0.000 ns`，0 failing endpoints。
- Hold：WHS `+0.011 ns`，THS `0.000 ns`，0 failing endpoints。
- Pulse width：WPWS `+4.458 ns`，TPWS `0.000 ns`，0 failing endpoints。
- Route：10466/10466 routable nets fully routed，0 routing errors。
- DRC：保留 1 个 Vivado `dbg_hub/u_ila_monitor` 内部网络的 `RTSTAT-10 No routable loads` warning；不涉及用户 RTL 路由错误。

结论：Profiler 除法时序阻塞已消除，新 M26 bitstream 满足现有用户时序约束，可进入下载和板级验收阶段。

## 板级验收

下载和串口验证均属于硬件操作，执行前确认 JTAG target、串口和板卡状态。

```text
just la-program "*JTAG目标序列号*"
just la-board-validate COM7 115200
```

验证器覆盖 LA ID/version、配置读回、arm、force trigger、done、readout、header/data/status 帧、capture_id 递增和 clear。Viewer 波形显示及 VCD/JSONL 文件内容仍需人工验收并在下表签字。

| 日期 | Board/串口 | arm/trigger/readout | Viewer | VCD | JSONL | 结论/证据 |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-10 | `xcku5p_0` / COM8 | PASS，capture_id=4 | 待人工确认 | 待人工确认 | 待人工确认 | header=1，trigger=1，data=13，status=1，checksum=0 |

### 自动板级验证记录

- JTAG target：`localhost:3121/xilinx_tcf/Digilent/210512180081`。
- 下载结果：`PASS: Programmed xcku5p_0 with .../openfpga_debug_board_demo_m26.bit`，startup status HIGH。
- 串口命令：`python tools/viewer/logic_analyzer_validate.py --port COM8 --baud 115200`。
- 串口结果：`PASS: OpenFPGA Logic Analyzer board validation passed`。
- 观测：`LA_VERSION=0x00010000`，`capture_id=4`，header/data/status/trigger=`1/13/1/1`，checksum errors=`0`。
- 首次诊断暴露验证器会在 Monitor response 后丢弃同批后续帧；已修复为处理完整 decoded batch 后返回，离线自测与真实链路复测均通过。

## 30 分钟共存长稳

| 时间 | checksum error | dropped frames | LA overflow | malformed | capture_id | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 0 min |  |  |  |  |  |  |
| 5 min |  |  |  |  |  |  |
| 10 min |  |  |  |  |  |  |
| 15 min |  |  |  |  |  |  |
| 20 min |  |  |  |  |  |  |
| 25 min |  |  |  |  |  |  |
| 30 min |  |  |  |  |  |  |

当前板级验收与长稳尚未执行，不应标记 M26 发布完成。

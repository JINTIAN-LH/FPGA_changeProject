# 通信协议接口控制文档 (ICD)（统一架构版）

文档编号：FPGA-QT-01-002  
版本：V1.2  
日期：2026-05-30

## 1. 这份文档的作用

一句话：所有收发双方都必须按这份文档“逐字节一致”。

如果代码与本文档冲突，以本文档为准。

## 2. 通信基础参数

| 项目 | 值 |
|---|---|
| 传输协议 | UDP over IPv4 |
| 字节序 | Big-Endian（大端） |
| 上位机 IP | 192.168.1.100 |
| FPGA IP | 192.168.1.101 |
| 上位机接收端口 | 5000 |
| FPGA 接收端口 | 5001 |
| 应用层校验 | CRC32 |

## 3. 上行帧（上位机 -> FPGA）

总长度：48 字节

| 偏移 | 长度 | 字段 | 说明 |
|---|---:|---|---|
| 0 | 2 | frame_header | 固定 0xAA55 |
| 2 | 2 | frame_len | 固定 0x0030（48） |
| 4 | 8 | stock_code | 8 字节代码，如 000858SZ |
| 12 | 4 | timestamp | uint32 秒级时间戳 |
| 16 | 4 | open | float32 |
| 20 | 4 | high | float32 |
| 24 | 4 | low | float32 |
| 28 | 4 | close | float32 |
| 32 | 4 | volume | uint32 |
| 36 | 8 | reserved | 预留，当前填 0 |
| 44 | 4 | crc32 | 对 [0..43] 计算 CRC32 |

## 4. 下行帧（FPGA -> 上位机）

总长度：44 字节

| 偏移 | 长度 | 字段 | 说明 |
|---|---:|---|---|
| 0 | 2 | frame_header | 固定 0x55AA |
| 2 | 2 | frame_len | 固定 0x002C（44） |
| 4 | 8 | stock_code | 回显上行代码 |
| 12 | 4 | timestamp | 回显上行时间 |
| 16 | 4 | ma5 | float32 |
| 20 | 4 | ma10 | float32 |
| 24 | 4 | rsi6 | float32 |
| 28 | 4 | rsi14 | float32 |
| 32 | 1 | trade_signal | 0/1/2 |
| 33 | 1 | signal_strength | 0-100 |
| 34 | 6 | reserved | 预留，当前填 0 |
| 40 | 4 | crc32 | 对 [0..39] 计算 CRC32 |

## 5. 调试信号（FPGA内部）

`frame_reject_reason` 约定：

- 0: none
- 1: header error
- 2: length error
- 3: crc error
- 4: size error

说明：这是板内调试信号，不在 UDP 帧中透传。

## 6. 异常处理规则

| 场景 | 行为 |
|---|---|
| header 错误 | 丢包，不回包 |
| length 错误 | 丢包，不回包 |
| crc 错误 | 丢包，不回包 |
| 上位机超时 | 上位机重试（最多 3 次） |

## 7. 小白验收步骤

1. 跑协议单测（Python）
2. 跑异常注入（mock）
3. 跑 Vivado batch 仿真（tb_top + tb_system_mixed）

## 8. 变更规则

任意协议字段变更，必须同步更新：

1. 本 ICD
2. 数据字典
3. Python 协议实现
4. FPGA 协议实现
5. 对应测试

## 9. 当前实现对应

1. Python 协议实现：`host_side/app/fpga_protocol.py`
2. FPGA 协议核：`fpga_side/rtl/src/m1_protocol_core.v`
3. 协议相关 TB：`fpga_side/rtl/tb/tb_top.v`（模块名 `tb_m1_protocol_core`）

说明：若实现与本文档冲突，以本文档为准并立即修正实现。

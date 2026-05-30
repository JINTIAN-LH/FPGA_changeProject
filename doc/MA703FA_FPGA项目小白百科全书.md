# MA703FA FPGA 项目小白百科全书（实战版）

## 0. 这份文档给谁看

给第一次接触本项目的同学。
你不需要先懂全部 FPGA，只要按步骤走，就能跑通“上位机回归 + FPGA仿真”。

## 1. 先记住这三件事

1. 目录已经分为 `host_side` 和 `fpga_side`。
2. 协议是本项目唯一硬约束：上行 48B、下行 44B、大端、CRC32。
3. 先跑通测试再改代码。

## 2. 本项目在做什么

本项目目标：上位机发送行情数据给 FPGA，FPGA 处理后回传结果。

当前阶段：

- 上位机链路可完整运行
- FPGA M1/M1.1 协议链路可仿真通过
- Vivado batch 流程已打通

## 3. 目录结构（小白版）

```text
.
├─ host_side/
│  ├─ app/      # Python 主代码
│  ├─ tests/    # Python 测试
│  └─ data/     # 示例输出
├─ fpga_side/
│  ├─ rtl/      # Verilog 和 testbench
│  ├─ scripts/  # Vivado 批处理脚本
│  └─ logs/     # Vivado 日志
└─ doc/         # 文档
```

## 4. 一小时上手流程

### 4.1 上位机回归

```powershell
$env:PYTHONPATH="host_side/app"
python -m unittest -v host_side/tests/test_protocol.py host_side/tests/test_validator.py host_side/tests/test_udp_transport.py host_side/tests/test_run_all_protocol.py host_side/tests/test_contract_snapshot.py host_side/tests/test_mock_fpga_behavior.py
```

### 4.2 FPGA 仿真回归

```powershell
$env:Path="C:\vivado2019\Vivado\2019.1\bin;" + $env:Path
vivado -mode batch -source fpga_side/scripts/vivado/run_xsim.tcl
```

### 4.3 端到端 mock 联调

```powershell
$env:PYTHONPATH="host_side/app"
python host_side/app/e2e_runner.py --code 000858 --start-mock --limit 20
```

## 5. 关键协议（必须理解）

### 上行帧（上位机 -> FPGA）

- 长度：48 字节
- 帧头：0xAA55
- 尾部：CRC32（最后 4 字节）

### 下行帧（FPGA -> 上位机）

- 长度：44 字节
- 帧头：0x55AA
- 尾部：CRC32（最后 4 字节）

## 6. M1.1 当前能力

- FPGA 可解析上行帧：header / length / crc
- 回包支持可配置占位：MA5 / MA10 / RSI
- 输出拒绝原因：
  - 1: header
  - 2: length
  - 3: crc
  - 4: size

## 7. 阶段性里程碑（截至 2026-05-30）

### 已完成

1. 目录重构（host/fpga 分离）
2. Python 回归 12/12 通过
3. `tb_top`、`tb_system_mixed` 仿真通过
4. 文档体系同步到新目录

### 待完成

1. M2：真实指标回包
2. M3：完整策略回包与实机长稳测试

## 8. 最容易踩坑的 5 个问题

1. 把 Vivado 路径写成 `bin1`（应为 `bin`）
2. 忘记设置 `PYTHONPATH=host_side/app`
3. 字节序不一致（必须大端）
4. CRC 校验段范围算错
5. 改了协议却没同步 ICD/数据字典

## 9. 新手协作规则

1. 先跑测试，后提交代码
2. 改协议先改文档，再改代码
3. 每次迭代更新 commit.md

## 10. 下一步怎么学

1. 先读 ICD
2. 再读数据字典
3. 再读 `host_side/app/fpga_protocol.py`
4. 最后看 `fpga_side/rtl/src/m1_protocol_core.v`

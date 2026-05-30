# VS Code 到 Vivado 迁移操作手册（重构目录版）

## 1. 适用范围

本手册适用于当前目录结构：

- `host_side`：上位机
- `fpga_side`：FPGA

目标：在 VS Code 改 RTL，在 Vivado 做仿真/实现/下载。

## 2. 迁移前必查清单

1. Python 回归通过（12/12）
2. `tb_top` 和 `tb_system_mixed` 在 batch 可运行
3. 协议文档与数据字典已确认版本

命令：

```powershell
$env:PYTHONPATH="host_side/app"
python -m unittest -v host_side/tests/test_protocol.py host_side/tests/test_validator.py host_side/tests/test_udp_transport.py host_side/tests/test_run_all_protocol.py host_side/tests/test_contract_snapshot.py host_side/tests/test_mock_fpga_behavior.py

$env:Path="C:\vivado2019\Vivado\2019.1\bin;" + $env:Path
vivado -mode batch -source fpga_side/scripts/vivado/run_xsim.tcl
```

## 3. Vivado 工程导入路径

### 源码

- `fpga_side/rtl/src/*.v`

### 仿真

- `fpga_side/rtl/tb/*.v`

### 约束

- `fpga_side/rtl/constraints/*.xdc`

## 4. 推荐操作顺序

1. 先 Behavioral Simulation
2. 再 Synthesis
3. 再 Implementation
4. 最后 Generate Bitstream

## 5. 与上位机联调步骤

1. 上位机 smoke：

```powershell
$env:PYTHONPATH="host_side/app"
python host_side/app/e2e_runner.py --code 000858 --smoke
```

2. 异常注入：

```powershell
$env:PYTHONPATH="host_side/app"
python host_side/app/acceptance_injection.py --host 192.168.1.101 --port 5001 --code 000858SZ
```

3. 持续联调：

```powershell
$env:PYTHONPATH="host_side/app"
python host_side/app/run_all.py 000858 120
```

## 6. ILA 探针建议

1. `frame_accepted`
2. `frame_rejected`
3. `frame_reject_reason`
4. `tx_valid/tx_last`
5. `rx_valid/rx_last`

## 7. 常见问题

### 1) Vivado 报路径过长

缩短工程路径，或用 `subst` 映射盘符。

### 2) 仿真通过但联调失败

优先核对：帧头、长度、CRC、端口。

### 3) 字段偏移错位

按 ICD 的偏移表逐字节对照，不要按结构体猜测。

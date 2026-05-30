# FPGA 侧 RTL 目录说明（中文）

本目录用于存放 FPGA 相关的 RTL 源码、测试文件与仿真资产。

## 目录含义

- `src`：RTL 源码（Verilog）
- `tb`：测试平台（Testbench）
- `constraints`：约束文件（XDC）
- `ip`：IP 相关文件
- `sim`：本地仿真工程输出

## 当前里程碑

1. M1：完成上行解析与 44B 固定回包
2. M1.1：完成可配置占位、拒绝错误码、混合帧压力测试
3. M2（下一步）：将 MA5/MA10 从占位值切换为真实计算值

## 如何运行仿真

请在仓库根目录执行：

```powershell
$env:Path="C:\vivado2019\Vivado\2019.1\bin;" + $env:Path
vivado -mode batch -source fpga_side/scripts/vivado/run_xsim.tcl
```

## 通过标准

- `tb_top` 显示 `PASSED`
- `tb_system_mixed` 显示 `PASSED`

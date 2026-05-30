# FPGA Exchange SerDes（小白可上手版）

这是一个“上位机 Python + FPGA RTL”联合工程，目标是通过以太网/光口完成：

1. 上位机发送行情帧（48B）
2. FPGA 解析并处理
3. FPGA 回传结果帧（44B）

## 30 秒看懂当前状态

- 上位机链路：可运行
- FPGA M1/M1.1：可仿真通过
- Vivado batch：可运行
- 目录已重构：按上位机侧/FPGA侧分离

## 目录总览（重构后）

```text
.
├─ host_side/
│  ├─ app/      # 上位机业务代码
│  ├─ tests/    # 上位机测试
│  └─ data/     # 样例输出数据
├─ fpga_side/
│  ├─ rtl/      # Verilog/TB/XDC/仿真工程
│  ├─ docs/     # FPGA 侧成果文档
│  ├─ scripts/  # Vivado 批脚本
│  └─ logs/     # Vivado 运行日志
├─ doc/         # 文档中心
├─ .vscode/     # VS Code 任务与配置
└─ commit.md    # 变更记录
```

## 新手上手（按顺序）

### 第 1 步：准备 Python 环境

```powershell
py -3.10 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install akshare easyquotation requests
```

### 第 2 步：跑上位机回归

```powershell
$env:PYTHONPATH="host_side/app"
python -m unittest -v host_side/tests/test_protocol.py host_side/tests/test_validator.py host_side/tests/test_udp_transport.py host_side/tests/test_run_all_protocol.py host_side/tests/test_contract_snapshot.py host_side/tests/test_mock_fpga_behavior.py
```

通过标准：12/12 通过。

### 第 3 步：跑 FPGA 批仿真

```powershell
$env:Path="C:\vivado2019\Vivado\2019.1\bin;" + $env:Path
vivado -mode batch -source fpga_side/scripts/vivado/run_xsim.tcl
```

通过标准：`tb_top` 与 `tb_system_mixed` 均 PASSED。

## 一键常用命令

### 上位机端到端（自动启动 mock）

```powershell
$env:PYTHONPATH="host_side/app"
python host_side/app/e2e_runner.py --code 000858 --start-mock --limit 20
```

### 异常注入验收

```powershell
$env:PYTHONPATH="host_side/app"
python host_side/app/acceptance_injection.py --host 127.0.0.1 --port 19011 --code 000858SZ --start-mock
```

## 文档导航（小白推荐阅读顺序）

1. 本文件 README
2. doc/MA703FA_FPGA项目小白百科全书.md
3. doc/通信协议接口控制文档 (ICD)/通信协议接口控制文档 (ICD).md
4. doc/数据字典/数据字典.md
5. doc/VSCode到Vivado迁移操作手册.md
6. doc/全链条开发实施计划_v2.md
7. doc/任务与分工总表.md
8. fpga_side/docs/README.md

## 当前已完成能力（简版）

### 上位机侧

- 行情采集、清洗、校验
- 协议编解码（48B/44B）
- UDP 重试、统计、JSONL 日志
- mock FPGA 回环与异常注入验收

### FPGA侧

- M1 协议核：上行校验 + 下行回包
- M1.1：可配置占位（MA5/MA10/RSI）
- 拒绝错误码输出（header/length/crc/size）
- system-level 混合帧压力 TB

## 常见问题（新手高频）

### 1) vivado 命令找不到

原因：PATH 未配置或目录写错。2019.1 默认是 `...\bin`，不是 `...\bin1`。

### 2) Python 测试报找不到模块

原因：重构后代码在 `host_side/app`。先设置：

```powershell
$env:PYTHONPATH="host_side/app"
```

### 3) 仿真能过但上板不通

优先检查：

1. IP/端口配置
2. 帧头与长度字段
3. CRC 校验
4. 网卡绑定和防火墙

## 下一步建议

1. M2：把 MA5/MA10 从占位改为真实计算输出。
2. 增加 FPGA 侧 ILA 触发模板。
3. 增加“实机联调日报模板”。

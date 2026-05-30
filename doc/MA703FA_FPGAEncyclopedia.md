# MA703FA FPGA 项目小白百科全书（2026-05 最新版）

## 0. 这份文档解决什么问题

读完本文档，你可以独立完成四件事：

1. 在自己的电脑上搭建 Python + Vivado 2019 环境
2. 跑通上位机 12 项协议测试（不需要 FPGA 硬件）
3. 在 Vivado 2019 里从零建工程、加文件、跑仿真、看波形
4. 看懂系统闭环，知道改代码该改哪里、改了之后该跑什么回归

---

## 1. 三条红线（先看完再动手）

1. **协议不乱改**：上行 48B、下行 44B、Big-Endian、CRC32。任何字段变动必须先改 ICD 和数据字典。
2. **先验证再改代码**：先跑现有测试确认基线通过，再做修改，最后跑回归。
3. **改接口必须同步文档**：ICD、数据字典、Python/FPGA 协议实现、测试，四个一起更新。

---

## 2. 这个项目在做什么

把 A 股行情数据（open/high/low/close/volume）从 Python 上位机通过 UDP 发送给 FPGA，FPGA 硬件并行计算 MA/RSI/MACD/量比/Bollinger/ATR 等指标并打分，然后把结果打包回传给上位机展示交易信号。

**当前进展（2026-05-31）**：
- 协议闭环稳定（48B 上行 → FPGA 校验 → 44B 下行回包）
- 指标链路完整（MA5/MA20/MA60、RSI、MACD(DIF/DEA)、Bollinger、ATR、量比）
- 评分决策链路接入（0-100 评分 + 0/1/2 买卖决策）
- Python 12/12 测试通过，FPGA 6 个 TB 全部跑通

---

## 3. 目录一览

```text
fpga_exchangeSerdes/
├─ host_side/
│  ├─ app/                # Python 主代码（协议、校验、传输、编排）
│  │   ├─ fpga_protocol.py    ← 协议编解码（最核心）
│  │   ├─ data_validator.py   ← 数据校验
│  │   ├─ udp_transport.py    ← UDP 收发
│  │   ├─ mock_fpga.py        ← 本地模拟 FPGA
│  │   ├─ e2e_runner.py       ← 端到端流程
│  │   ├─ run_all.py          ← 一键执行
│  │   └─ config.py           ← 网络/超时配置
│  ├─ tests/              # Python 测试（6 个文件，12 项）
│  └─ data/               # 样例数据
├─ fpga_side/
│  ├─ rtl/
│  │   ├─ src/            # Verilog 源码（10 个模块）
│  │   │   ├─ top.v           ← 统一顶层
│  │   │   ├─ m1_protocol_core.v ← 协议校验核
│  │   │   ├─ indicator_top.v ← 指标汇聚
│  │   │   ├─ ma_calc.v       ← 均线 MA
│  │   │   ├─ rsi_calc.v      ← 相对强弱 RSI
│  │   │   ├─ macd_calc.v     ← MACD
│  │   │   ├─ vol_ratio_calc.v ← 量比
│  │   │   ├─ score_calc.v    ← 综合评分
│  │   │   └─ udp_result_tx.v ← 结果帧打包发送
│  │   └─ tb/             # 仿真 Testbench（6 个）
│  │       ├─ tb_top.v        ← 协议核专项（模块名 tb_m1_protocol_core）
│  │       ├─ tb_top.sv       ← 顶层联调
│  │       ├─ tb_system_mixed.v ← 好帧/坏帧混合压力
│  │       ├─ tb_indicator_top.sv
│  │       ├─ tb_score_calc.sv
│  │       └─ tb_udp_result_tx.sv
│  ├─ scripts/vivado/    # Vivado TCL 批处理脚本
│  │   ├─ run_single_tb.tcl  ← 单 TB 独立执行（推荐）
│  │   └─ run_xsim.tcl       ← 批量执行所有 TB
│  └─ logs/              # 仿真输出日志
└─ doc/                  # 项目文档（9 份）
    ├─ 产品需求说明书 (PRD).md
    ├─ 通信协议接口控制文档 (ICD).md    ← 协议字段定义（权威来源）
    ├─ 数据字典.md
    ├─ 系统总体架构设计.md
    ├─ FPGA 模块详细设计.md
    ├─ Python 模块详细设计.md
    └─ protocol_contract_v1.json
```

---

## 4. 环境搭建（第一步，必须完成）

### 4.1 Python 环境

```powershell
# 1. 确认 Python 版本 ≥ 3.8
python --version

# 2. 创建虚拟环境（推荐）
py -3.10 -m venv .venv
.\.venv\Scripts\Activate.ps1

# 3. 安装依赖
python -m pip install --upgrade pip
python -m pip install akshare easyquotation requests

# 4. 验证导入
python -c "import akshare; print('AKShare OK')"
python -c "import struct; print('struct OK')"
```

### 4.2 Vivado 2019 环境

**安装要求**：Vivado 2019.1，安装路径 `C:\vivado2019\Vivado\2019.1\`

**验证安装**（打开 PowerShell）：
```powershell
# 添加 Vivado 到 PATH
$env:Path = "C:\vivado2019\Vivado\2019.1\bin;" + $env:Path

# 验证 vivado 命令可用
vivado -version
# 应输出类似: Vivado v2019.1 (64-bit)
```

> **注意**：如果 Vivado 装在别的位置，请替换路径。后续所有命令中 `C:\vivado2019\Vivado\2019.1\bin` 都要替换为你的实际路径。

---

## 5. Python 侧：手把手跑通全部测试

### 5.1 设置环境变量

**每次打开新终端都要先执行这一行**：
```powershell
$env:PYTHONPATH = "host_side/app"
```

> **踩坑提示**：如果忘了设置 PYTHONPATH，会遇到 `ModuleNotFoundError: No module named 'fpga_protocol'`。

### 5.2 跑一个测试试试水

```powershell
python -m unittest -v host_side/tests/test_protocol.py
```

**预期看到**：
```
test_build_upstream_frame ... ok
test_parse_downstream_frame ... ok
test_crc32_consistency ... ok
...
----------------------------------------------------------------------
Ran X tests in 0.XXXs
OK
```

### 5.3 一键跑完所有测试

```powershell
python -m unittest -v host_side/tests/test_protocol.py host_side/tests/test_validator.py host_side/tests/test_udp_transport.py host_side/tests/test_run_all_protocol.py host_side/tests/test_contract_snapshot.py host_side/tests/test_mock_fpga_behavior.py
```

**验收标准**：输出末尾出现 `OK`，且所有测试用例都显示 `ok`（共 12 项）。

### 5.4 每个测试在测什么

| 测试文件 | 验证内容 | 不通过意味着 |
|----------|----------|-------------|
| `test_protocol.py` | 48B 上行帧打包、44B 下行帧解包、CRC32 | 协议实现有 bug |
| `test_validator.py` | 数据校验规则（缺失值、异常值） | 数据过滤逻辑有问题 |
| `test_udp_transport.py` | UDP 收发、超时、重试 | 传输层有问题 |
| `test_run_all_protocol.py` | 主流程协议连通 | 端到端路径不通 |
| `test_contract_snapshot.py` | 协议快照一致性 | 协议契约 JSON 与实现不一致 |
| `test_mock_fpga_behavior.py` | mock FPGA 行为与异常路径 | mock 模拟不准确 |

---

## 6. FPGA 侧：Vivado 2019 仿真手把手教程

FPGA 验证有两条路径：**GUI 手动操作**（适合新人理解流程）和**批处理脚本**（适合回归）。建议先按 GUI 走一遍，之后日常用脚本。

---

### 6.1 方法一：GUI 手动操作（新人必做，理解工程结构）

以下步骤在 Vivado 2019 GUI 中完成。**每个菜单名、按钮名都是准确的，请逐字对照。**

#### 步骤 1：启动 Vivado

```powershell
$env:Path = "C:\vivado2019\Vivado\2019.1\bin;" + $env:Path
vivado
```

Vivado 启动后会显示 Welcome 界面。

#### 步骤 2：创建新工程

1. 在 Welcome 界面点击 **"Create Project"**
2. 弹出向导，点击 **Next >**
3. **Project name**：填 `fpga_exchange_serdes_xsim`（或任意名字）
4. **Project location**：点 `...` 浏览，选到 `fpga_side/rtl/sim/` 目录
5. 勾选 **"Create project subdirectory"** → 点击 **Next >**
6. Project Type：选 **"RTL Project"**，**不要**勾选 "Do not specify sources at this time" → Next >
7. **Add Sources** 页面：点击绿色的 **"+"** 按钮 → **"Add Files"**
   - 浏览到 `fpga_side/rtl/src/`
   - 全选所有 `.v` 文件（共 10 个）
   - 点击 **OK** → 确认 "Copy sources into project" **不勾选**（保持原位引用）
   - 确认 Target language 是 **Verilog**，Simulator language 是 **Mixed**
   - 点击 **Next >**
8. **Add Constraints** 页面：直接 **Next >**（本项目暂不需要约束文件）
9. **Default Part** 页面：
   - 在搜索框输入 `xc7a100tfgg484-2`
   - 选中搜索结果 → 点击 **Next >**
10. 最后点击 **Finish**，等待工程创建完成。

#### 步骤 3：添加仿真源文件（Testbench）

1. 在左侧 **Flow Navigator** 中，找到 **PROJECT MANAGER** 组
2. 点击 **"Add Sources"**（或菜单 File → Add Sources）
3. 选择 **"Add or create simulation sources"** → Next >
4. 点击绿色的 **"+"** → **"Add Files"**
   - 浏览到 `fpga_side/rtl/tb/`
   - 全选所有 `.v` 和 `.sv` 文件（共 6 个）
   - 点击 **OK**
   - 确认 **"Copy sources into project"** 不勾选
5. 点击 **Finish**

#### 步骤 4：选择仿真顶层并启动仿真

以 `tb_m1_protocol_core` 为例（协议核专项测试）：

1. 在左侧 **Flow Navigator** 中，点击 **SIMULATION** 组下的 **"Run Simulation"** → **"Run Behavioral Simulation"**
2. Vivado 会开始编译（elaborate），等待约 1-3 分钟
3. 如果弹出 "No valid simulation top module" 错误：
   - 在 **Sources** 窗口中（左侧 Project Manager 下方），切换到 **"Simulation Sources"** 标签
   - 展开 `sim_1`，找到 `tb_m1_protocol_core`（在 `tb_top.v` 里）
   - 右键点击 → **"Set as Top"**
   - 再次 Run Simulation
4. 编译通过后，仿真窗口自动打开，波形界面出现。

#### 步骤 5：运行仿真

1. 在仿真工具栏（顶部）找到运行控制按钮：
   - **"Run All"**（蓝色三角形 + 竖线）：一直跑到 `$finish` 止
   - **"Run For..."**：指定时长运行
2. 点击 **"Run All"**，等待仿真完成（通常几秒到几十秒）
3. 仿真结束后检查 **Tcl Console**（底部面板）的输出：
   ```
   [CASE] normal
   [CASE] bad_header
   [CASE] bad_length
   [CASE] bad_crc
   [TB] PASSED
   ```
   看到 `[TB] PASSED` 即表示通过。

#### 步骤 6：查看波形（调试用）

1. 在仿真完成后，波形窗口保留所有信号的历史值
2. 在 **Scope** 子窗口（左侧）展开 `dut`（即 UUT/DUT 实例）
3. 将关键信号拖到波形窗口：
   - `rx_valid`, `rx_data`, `rx_last`（上行帧输入）
   - `tx_valid`, `tx_data`, `tx_last`（下行帧输出）
   - `frame_accepted`, `frame_rejected`, `frame_reject_reason`（协议核状态）
4. 用鼠标滚轮缩放时间轴，检查帧时序

#### 步骤 7：更换 Testbench 重跑

1. 关闭当前仿真：File → **"Close Simulation"**
2. 在 **Sources** → **Simulation Sources** → `sim_1` 中找到另一个 TB
   - 例如 `tb_top`（在 `tb_top.sv` 中）或 `tb_system_mixed`（在 `tb_system_mixed.v` 中）
3. 右键 → **"Set as Top"**
4. 重新点击 **"Run Simulation"** → **"Run Behavioral Simulation"**

#### 步骤 8：关闭工程

仿真完成后，File → **"Close Project"**。

---

### 6.2 方法二：TCL 批处理脚本（日常回归，一键跑完）

配置好环境变量后，一行命令跑一个 TB：

```powershell
# 先设置 Vivado 路径
$env:Path = "C:\vivado2019\Vivado\2019.1\bin;" + $env:Path

# 逐个执行（推荐用于排障）
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_m1_protocol_core
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_system_mixed
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_top
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_indicator_top
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_score_calc
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_udp_result_tx
```

每个命令执行完毕后，检查终端输出末尾是否有：
```
single tb done: tb_xxxxx
```

**脚本做了什么**（`run_single_tb.tcl` 每步说明）：
1. 在 `fpga_side/rtl/sim/` 下创建独立工程（工程名带 TB 名后缀）
2. 自动收集 `fpga_side/rtl/src/*.v` 所有源文件
3. 自动收集 `fpga_side/rtl/tb/*.v` 和 `*.sv` 所有 TB 文件
4. 设置你指定的 TB 为仿真顶层
5. 启动 behavioral simulation，编译并运行
6. 仿真结束后关闭工程

---

### 6.3 六个 TB 都在测什么

| TB 文件 | 仿真顶层 | 测试场景 | 期望结果 |
|---------|----------|----------|----------|
| `tb_top.v` | `tb_m1_protocol_core` | 正常帧 + 坏 header + 坏 length + 坏 CRC | `[TB] PASSED` |
| `tb_system_mixed.v` | `tb_system_mixed` | 好帧、坏帧混合压力 | 接受/拒绝计数正常 |
| `tb_top.sv` | `tb_top` | 顶层全链路（指标→评分→打包） | heartbeat=1, score 有值 |
| `tb_indicator_top.sv` | `tb_indicator_top` | 指标汇聚链路输出 | 各指标值非零 |
| `tb_score_calc.sv` | `tb_score_calc` | 评分与决策映射 | score=46, decision=2 |
| `tb_udp_result_tx.sv` | `tb_udp_result_tx` | 打包字节流行为 | valid_bytes=60 |

---

## 7. 闭环数据流（看懂这张图就懂了整个项目）

```mermaid
flowchart LR
  A[Python<br/>AKShare 行情采集] -->|校验| B[data_validator]
  B -->|48B 帧| C[UDP 发送<br/>udp_transport]
  C -->|以太网| D[FPGA<br/>m1_protocol_core]
  D -->|校验通过| E[top 顶层<br/>行情 → 指标]
  E --> F[indicator_top<br/>MA/RSI/MACD/Boll/ATR/量比]
  F --> G[score_calc<br/>0-100 评分]
  G --> H[udp_result_tx<br/>44B 帧打包]
  H -->|UDP| C
  H -->|结果| I[Python<br/>买卖信号展示]
```

关键路径：
1. **上行**：Python 取行情 → 校验 → 协议打包（48B）→ UDP 发送
2. **FPGA 处理**：协议校验（header/length/crc）→ 指标计算 → 评分 → 打包（44B）
3. **下行**：UDP 回传 → Python 解包 → 展示交易信号

---

## 8. 常见踩坑与解决方案

### 坑 1：Vivado 命令找不到
```
vivado : The term 'vivado' is not recognized...
```
**解决**：Vivado 没有在 PATH 中。必须先执行：
```powershell
$env:Path = "C:\vivado2019\Vivado\2019.1\bin;" + $env:Path
```

### 坑 2：Python 模块导入失败
```
ModuleNotFoundError: No module named 'fpga_protocol'
```
**解决**：忘记设置 PYTHONPATH。必须执行：
```powershell
$env:PYTHONPATH = "host_side/app"
```

### 坑 3：Vivado GUI 仿真找不到顶层模块
"No valid simulation top module" 或 "No such module"
**解决**：确认已正确 Set as Top：在 Simulation Sources 中右键 TB 模块名 → "Set as Top"。

### 坑 4：仿真跑到一半就停了，没有 PASS/FAIL
**解决**：默认仿真时间窗口有限（1000ns），某些系统级 TB 可能来不及跑完。在 Tcl Console 中手动输入 `run all` 继续，或修改 TB 中的 `#1000` 延长等待时间。

### 坑 5：协议偏移搞混
**解决**：记住"上行 48B = 0x30，下行 44B = 0x2C"。CRC32 覆盖范围不包括 CRC32 字段本身（上行 [0..43]，下行 [0..39]）。

### 坑 6：改了接口没同步文档
**解决**：改任何协议字段后，必须同步更新 ICD → 数据字典 → Python `fpga_protocol.py` → FPGA `m1_protocol_core.v` → 相关测试。

### 坑 7：Vivado 2019 项目文件太多，Git 很难管理
**解决**：本项目的 TCL 脚本采用"临时创建工程，跑完即删"策略。仿真工程文件在 `fpga_side/rtl/sim/` 下，已在 `.gitignore` 中忽略。

### 坑 8：Windows PowerShell 执行策略阻止脚本
**解决**：以管理员身份运行 PowerShell，执行：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 9. 我要改代码，该怎么做（标准工作流）

### 场景 A：只改 Python 侧（如加一个新指标对比逻辑）

1. 修改 `host_side/app/` 中的对应文件
2. 补充或修改 `host_side/tests/` 中对应测试
3. 运行全部 Python 测试确认通过
4. 提交

### 场景 B：只改 FPGA 侧（如修改 MA 均线周期）

1. 修改 `fpga_side/rtl/src/ma_calc.v`
2. 检查 `fpga_side/rtl/tb/tb_indicator_top.sv` 是否需要更新
3. 用批处理跑 `tb_indicator_top`：
   ```powershell
   vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_indicator_top
   ```
4. 确认 `single tb done` 且无 FAIL 标记
5. 提交

### 场景 C：改协议字段（如增加新字段，需要改 ICD）

这是最危险的操作，必须按顺序：
1. 先改 `doc/通信协议接口控制文档 (ICD).md`
2. 改 `doc/数据字典.md`
3. 改 `doc/protocol_contract_v1.json`
4. 改 `host_side/app/fpga_protocol.py`（打包/解包逻辑）
5. 改 `fpga_side/rtl/src/m1_protocol_core.v`（解析逻辑）
6. 改相关测试
7. 跑 Python 全部测试 + FPGA `tb_m1_protocol_core` + `tb_system_mixed`
8. 全部通过后才能提交

### 场景 D：加一个全新的 FPGA 模块

1. 在 `fpga_side/rtl/src/` 下新建 `.v` 文件
2. 在 `fpga_side/rtl/tb/` 下新建对应 TB 文件
3. 在 `top.v` 中实例化新模块，连线
4. 更新 `fpga_side/rtl/src/top_stub.v`（如需要）
5. 跑新增的 TB 验证
6. 更新 `doc/FPGA 模块详细设计.md`
7. 提交

---

## 10. 文档阅读顺序（新人建议）

按这个顺序读，每读一份就动手操作对应的内容：

| 序号 | 文档 | 对应操作 |
|------|------|----------|
| 1 | `doc/MA703FA_FPGAEncyclopedia.md`（本文档） | 搭建环境 |
| 2 | `doc/README.md` | 了解文档体系 |
| 3 | `doc/产品需求说明书 (PRD).md` | 理解"要做什么" |
| 4 | `doc/通信协议接口控制文档 (ICD).md` | **精读**：帧格式、字段偏移 |
| 5 | `doc/数据字典.md` | 字段类型与取值范围 |
| 6 | `doc/系统总体架构设计.md` | 模块边界与闭环路径 |
| 7 | `doc/Python 模块详细设计.md` | 对照 `host_side/app/` 源码阅读 |
| 8 | `doc/FPGA 模块详细设计.md` | 对照 `fpga_side/rtl/src/` 源码阅读 |

---

## 11. 当前验证结论（2026-05-31）

| 验证项 | 状态 | 证据 |
|--------|------|------|
| Python 回归（12/12） | ✅ 全部通过 | `OK` 结束 |
| `tb_m1_protocol_core` | ✅ 通过 | `[TB] PASSED`，正常/坏帧全覆盖 |
| `tb_system_mixed` | ✅ 通过 | 混合流量统计正常 |
| `tb_top` | ✅ 通过 | heartbeat=1, score=46, decision=2 |
| `tb_indicator_top` | ✅ 通过 | 指标链路输出正常 |
| `tb_score_calc` | ✅ 通过 | 评分决策映射正确 |
| `tb_udp_result_tx` | ✅ 通过 | 字节流打包正常 |

**一句话**：仿真环境下所有链路已跑通，下一阶段需要上板烧录、实机验证、长时稳定性测试。

---

## 12. 快速命令速查表

```powershell
# ====== Python 环境 ======
$env:PYTHONPATH = "host_side/app"                        # 必须每次设置
python -m unittest -v host_side/tests/test_protocol.py   # 单测
# 全量回归（12项）
python -m unittest -v host_side/tests/test_protocol.py host_side/tests/test_validator.py host_side/tests/test_udp_transport.py host_side/tests/test_run_all_protocol.py host_side/tests/test_contract_snapshot.py host_side/tests/test_mock_fpga_behavior.py

# ====== Vivado 环境 ======
$env:Path = "C:\vivado2019\Vivado\2019.1\bin;" + $env:Path  # 必须每次设置
vivado -version                                              # 确认安装

# ====== FPGA 单 TB 批跑（排障用）======
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_m1_protocol_core
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_system_mixed
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_top
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_indicator_top
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_score_calc
vivado -mode batch -source fpga_side/scripts/vivado/run_single_tb.tcl -tclargs tb_udp_result_tx

# ====== Vivado GUI ======
vivado                                                       # 启动 GUI
```

---

> **最后一个建议**：遇到问题时，先看第 8 节的踩坑清单，90% 的问题都在里面。

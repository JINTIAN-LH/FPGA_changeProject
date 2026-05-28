# FPGA_changeProject

基于 Python 的 A 股分钟线与实时行情采集项目，用于 FPGA 高速交易链路联调与数据回放。

当前仓库聚焦上位机侧数据准备：

- 历史 1 分钟 K 线拉取（优先东方财富，含多数据源回退）
- 3 秒级实时行情滑动窗口采集
- 历史 + 实时统一入口运行
- JSON 文件输出，方便 FPGA/其他程序直接读取

## 项目结构

```text
.
├─ config.py                      # 全局配置（股票列表、路径、采样间隔、窗口大小）
├─ fetch_history.py               # 模块一：历史分钟线拉取
├─ feed_real_time.py              # 模块二：实时行情采集（3 秒轮询）
├─ run_all.py                     # 统一入口：先尝试历史，再进入实时
├─ test_modules.py                # 快速测试脚本
├─ fetch_history.bat              # Windows 便捷启动脚本
├─ 000858_daily_minute.json       # 示例输出：历史分钟线
├─ 000858_real_time_window.json   # 示例输出：实时滑动窗口
└─ doc/
   └─ MA703FA_FPGA_股票高速交易项目_小白百科全书.md
```

## 环境要求

- Windows / Linux / macOS
- Python 3.10+（本仓库已验证 3.10.11）

## 快速开始

### 1) 创建并激活虚拟环境

Windows PowerShell:

```powershell
py -3.10 -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### 2) 安装依赖

```powershell
python -m pip install --upgrade pip
python -m pip install akshare easyquotation requests
```

### 3) 修改配置

编辑 `config.py`：

- `STOCK_LIST`: 股票代码列表
- `OUTPUT_DIR`: 输出目录（不存在会回退到当前目录）
- `REAL_TIME_INTERVAL`: 实时采样间隔（秒）
- `MAX_WINDOW_SIZE`: 滑动窗口条数

### 4) 运行

只拉历史分钟线：

```powershell
python fetch_history.py
```

只跑实时窗口采集：

```powershell
python feed_real_time.py
```

统一运行（推荐）：

```powershell
python run_all.py
```

快速自检：

```powershell
python test_modules.py
```

## 输出数据说明

### 历史分钟线

文件名：`{code}_daily_minute.json`

字段示例：

```json
{
  "time": "2026-05-28 09:31:00",
  "open": 123.45,
  "high": 123.88,
  "low": 123.10,
  "close": 123.66,
  "volume": 987654
}
```

### 实时滑动窗口

文件名：`{code}_real_time_window.json`

字段示例：

```json
{
  "stock_code": "000858",
  "time": "2026-05-28 10:12:15",
  "price": 123.56,
  "volume": 1200,
  "high": 124.02,
  "low": 122.95,
  "open": 123.10,
  "change": 0.78
}
```

## 常见问题

- 非交易时段无数据：脚本会等待开盘时段后重试。
- 接口短时失败：内置重试与多源回退。
- `.venv` 失效：若提示解释器路径不存在，删除 `.venv` 后重新创建。

## 后续建议

- 增加 `requirements.txt` 锁定版本
- 增加日志分级与结构化日志输出
- 增加 JSON schema 校验，保证 FPGA 侧解析稳定

## 非FPGA闭环（今日可跑）

新增模块：

- `fpga_protocol.py`：上/下行帧编解码（48B/44B）+ CRC32
- `data_validator.py`：K线字段、数值范围、时间单调性校验
- `udp_transport.py`：UDP 收发、超时重试、统计计数
- `indicators.py`：Python 参考指标（MA/RSI/MACD/ATR/量比）
- `mock_fpga.py`：本地 UDP Mock FPGA 服务
- `e2e_runner.py`：端到端脚本（读取历史 JSON -> 发包 -> 收包）
- `test_protocol.py`：协议单元测试
- `test_validator.py` / `test_udp_transport.py` / `test_run_all_protocol.py` / `test_contract_snapshot.py`：非FPGA闭环回归测试

快速验证：

```powershell
# 1) 协议单测
python -m unittest -v test_protocol.py

# 2) 完整回归测试
python -m unittest -v test_protocol.py test_validator.py test_udp_transport.py test_run_all_protocol.py test_contract_snapshot.py

# 3) 一键端到端（自动启动 mock）
python e2e_runner.py --code 000858 --start-mock --limit 20
```

说明：

- 当前协议实现已按 ICD V1.0 与数据字典 V1.0 对齐：`0xAA55/0x55AA`、`char[8]` 股票代码、`MA5/MA10/RSI6/RSI14`、`trade_signal/signal_strength`。
- 图片/PDF 已转出为可检索 Markdown：
  - `doc/通信协议接口控制文档 (ICD)/通信协议接口控制文档 (ICD).md`
  - `doc/数据字典/数据字典.md`
- 机器可读契约快照：`doc/protocol_contract_v1.json`
- `run_all.py` 已支持可选 FPGA UDP 下发；相关开关在 `config.py`：`ENABLE_FPGA_UDP`、`FPGA_UDP_HOST`、`FPGA_UDP_PORT`、`UDP_TIMEOUT_SECONDS`、`UDP_MAX_RETRIES`。
- 后续如 ICD 版本升级，可优先修改 `fpga_protocol.py` 的字段映射实现，不影响采集和测试脚本调用方式。

## 许可

仅用于学习与项目研究，行情数据以数据源官方条款为准。

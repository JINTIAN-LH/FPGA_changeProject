"""
====================================
 py_fpga高速交易 — 全局配置
====================================

所有股票代码、文件路径、采集参数统一写在这里。
其他模块 import 这个文件，不硬编码任何值。
"""

# ==================== 股票列表 ====================
# 可同时监控多只股票。想加就加：STOCK_LIST = ["000858", "600519", "000001"]
STOCK_LIST = ["000858"]

# ==================== 输出目录（JSON 文件放这里） ====================
# 默认用项目目录，避免在不同工作目录下运行时路径不一致
import os as _os
_OUTPUT_DIR = r"E:\桌面\Desktop\py_fpga高速交易"
OUTPUT_DIR = _OUTPUT_DIR if _os.path.isdir(_OUTPUT_DIR) else "."

# ==================== 实时行情参数 ====================
REAL_TIME_INTERVAL = 3       # 采集间隔（秒）
MAX_WINDOW_SIZE = 20         # 滑动窗口保留条数（20条 ≈ 1分钟）

# ==================== 历史行情参数 ====================
KLINE_PERIOD = "1"           # K线周期："1"=1分钟, "5"=5分钟, "15"=15分钟
MAX_KLINE_LEN = 240          # 最多取多少根K线（1分钟周期一天约240根）

# ==================== 文件名模板 ====================
# 输出格式：{code}_daily_minute.json / {code}_real_time_window.json
# 如果想改路径，把 OUTPUT_DIR 设成 "../data/" 之类即可

# ==================== FPGA UDP 联调参数 ====================
ENABLE_FPGA_UDP = True  # “True”表示启用 FPGA UDP 联调功能（默认 False，避免误连真实硬件）
FPGA_UDP_MODE = "real"  # "mock" | "real"

# ICD defaults for real hardware link.
FPGA_REAL_UDP_HOST = "169.254.0.118"
FPGA_REAL_UDP_PORT = 5001
PC_REAL_BIND_HOST = "192.168.100.104"
PC_REAL_BIND_PORT = 5000

# Local loopback defaults for software-only verification.
FPGA_MOCK_UDP_HOST = "127.0.0.1"
FPGA_MOCK_UDP_PORT = 9001
PC_MOCK_BIND_HOST = ""
PC_MOCK_BIND_PORT = 0

# Backward-compatible active host/port fields.
if FPGA_UDP_MODE == "real":
	FPGA_UDP_HOST = FPGA_REAL_UDP_HOST
	FPGA_UDP_PORT = FPGA_REAL_UDP_PORT
	FPGA_UDP_BIND_HOST = PC_REAL_BIND_HOST
	FPGA_UDP_BIND_PORT = PC_REAL_BIND_PORT
else:
	FPGA_UDP_HOST = FPGA_MOCK_UDP_HOST
	FPGA_UDP_PORT = FPGA_MOCK_UDP_PORT
	FPGA_UDP_BIND_HOST = PC_MOCK_BIND_HOST
	FPGA_UDP_BIND_PORT = PC_MOCK_BIND_PORT

UDP_TIMEOUT_SECONDS = 1.0
UDP_MAX_RETRIES = 3
SAVE_FPGA_RESULTS = True

# ==================== 联调日志 ====================
ENABLE_UDP_JSONL_LOG = True
UDP_JSONL_LOG_PATH = "fpga_link_events.jsonl"

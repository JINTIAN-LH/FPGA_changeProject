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
ENABLE_FPGA_UDP = False
FPGA_UDP_HOST = "127.0.0.1"
FPGA_UDP_PORT = 9001
UDP_TIMEOUT_SECONDS = 1.0
UDP_MAX_RETRIES = 3
SAVE_FPGA_RESULTS = True

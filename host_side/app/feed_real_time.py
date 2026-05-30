"""
============================================
 模块二：实时行情采集（3秒滑动窗口 → JSON）
============================================

功能：
  每 3 秒采集一次实时价格/成交量/时间，
  滑动窗口始终只保留最近 20 条（≈1分钟），
  支持其他程序 / FPGA 边写边读。

输出：
  {股票代码}_real_time_window.json
  - 是一个数组，始终保留最新 20 条
  - FPGA 端可以定读这个文件获取最新快照

用法：
  python feed_real_time.py                  # 监控 config.py 中所有股票
  python feed_real_time.py 600519           # 指定单只
  python feed_real_time.py 000858 600519    # 指定多只

交易时段判定：
  - 09:30-11:30 上午盘
  - 13:00-15:00 下午盘
  - 其他时间不采集（打印日志静待开盘）
"""

import json
import os
import sys
import time
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import STOCK_LIST, OUTPUT_DIR, REAL_TIME_INTERVAL, MAX_WINDOW_SIZE


# ===================== 工具函数 =====================

def save_json(data, filepath):
    """原子写入 JSON"""
    tmp = filepath + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, filepath)


def load_window(filepath):
    """读取已有的滑动窗口数据，文件不存在就返回空列表"""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []


def is_trading_time():
    """
    判断当前是否在 A 股交易时段。
    同时考虑上午 09:30-11:30 和下午 13:00-15:00。
    """
    now = datetime.now()
    # 周末不交易
    if now.weekday() >= 5:
        return False

    t = now.hour * 60 + now.minute
    # 09:30-11:30 或 13:00-15:00
    return (9 * 60 + 30) <= t <= (11 * 60 + 30) or (13 * 60) <= t <= (15 * 60)


# ===================== 实时采集 =====================

def fetch_realtime_sina(stock_code):
    """
    通过新浪接口获取单只股票实时行情。
    返回 dict 或 None（出错时）。
    """
    try:
        import easyquotation
        q = easyquotation.use("sina")
        data = q.real([stock_code])
        if stock_code not in data:
            return None
        d = data[stock_code]
        return {
            "stock_code": stock_code,
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "price": round(float(d["now"]), 2),
            "volume": int(d["volume"]),
            "high": round(float(d.get("high", 0)), 2),
            "low": round(float(d.get("low", 0)), 2),
            "open": round(float(d.get("open", 0)), 2),
            "change": round(float(d.get("涨幅", 0)), 2),
        }
    except Exception as e:
        print(f"  ⚠️ 采集失败 [{stock_code}]: {e}")
        return None


def run_single(stock_code):
    """运行单只股票的实时滑动窗口采集"""
    filepath = os.path.join(OUTPUT_DIR, f"{stock_code}_real_time_window.json")
    count = 0

    print(f"  📡 实时采集启动 [{stock_code}]")
    print(f"     间隔 {REAL_TIME_INTERVAL}s · 窗口 {MAX_WINDOW_SIZE} 条")
    print(f"     按 Ctrl+C 停止\n")

    while True:
        # 非交易时段：降低轮询频率 + 静默等待
        if not is_trading_time():
            time.sleep(10)
            continue

        # 1) 加载已有窗口
        window = load_window(filepath)

        # 2) 采集新数据
        tick = fetch_realtime_sina(stock_code)
        if tick is None:
            time.sleep(REAL_TIME_INTERVAL)
            continue

        # 3) 追加
        window.append(tick)

        # 4) 滑动截断
        if len(window) > MAX_WINDOW_SIZE:
            window = window[-MAX_WINDOW_SIZE:]

        # 5) 保存
        save_json(window, filepath)

        count += 1
        if count % 20 == 0:
            print(f"  [{stock_code}] 已采集 {count} 次，窗口 {len(window)} 条 "
                  f"| 最新: {tick['time']} 价格={tick['price']}")

        time.sleep(REAL_TIME_INTERVAL)


def run(stock_codes=None):
    """启动多只股票的实时采集（单线程轮询）"""
    if stock_codes is None:
        stock_codes = STOCK_LIST

    stocks = [s.strip().zfill(6) for s in stock_codes]
    print(f"🚀 实时行情采集启动")
    print(f"   股票: {', '.join(stocks)}")
    print(f"   间隔: {REAL_TIME_INTERVAL}s · 窗口: {MAX_WINDOW_SIZE} 条")
    print(f"   保存到: {os.path.abspath(OUTPUT_DIR)}\n")

    if not is_trading_time():
        print("⏳ 当前非交易时段，等待开盘...")

    try:
        if len(stocks) == 1:
            run_single(stocks[0])
        else:
            # 多只：轮流采集
            _run_multi(stocks)
    except KeyboardInterrupt:
        print("\n\n🛑 已停止实时采集")


def _run_multi(stocks):
    """多只股票的轮询（轮流采，一轮分时错开防拥堵）"""
    filepaths = {
        s: os.path.join(OUTPUT_DIR, f"{s}_real_time_window.json")
        for s in stocks
    }
    count = 0
    idx = 0

    while True:
        if not is_trading_time():
            time.sleep(10)
            continue

        stock_code = stocks[idx % len(stocks)]
        fp = filepaths[stock_code]

        window = load_window(fp)
        tick = fetch_realtime_sina(stock_code)
        if tick:
            window.append(tick)
            if len(window) > MAX_WINDOW_SIZE:
                window = window[-MAX_WINDOW_SIZE:]
            save_json(window, fp)

        count += 1
        if count % 20 == 0:
            print(f"  [{stock_code}] 采集 {count} 次"
                  f" | 最新价格={tick['price'] if tick else 'N/A'}")

        idx += 1
        # 轮完一轮耗时 ≈ 3s × 股票数，每只 3s 间隔
        time.sleep(REAL_TIME_INTERVAL)


# ===================== 命令行入口 =====================

if __name__ == "__main__":
    args = sys.argv[1:]
    run(args if args else None)

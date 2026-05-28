"""
=========================================
 模块一：历史行情获取（1分钟K线 → JSON）
=========================================

功能：
  获取当日或最近交易日的完整1分钟K线数据，
  输出为 {股票代码}_daily_minute.json。

独立运行，不依赖实时行情模块。
FPGA / 其他程序可以直接读 JSON 文件。

用法：
  python fetch_history.py              # 用 config.py 的 STOCK_LIST
  python fetch_history.py 600519       # 指定单只
  python fetch_history.py 000858 600519  # 指定多只

数据源（按优先级）：
  1. akshare（东方财富 SDK）
  2. HTTP 直连东方财富（纯 requests，不依赖 akshare）
  3. 新浪财经（备选）

策略：
  - 凌晨/非交易时段 -> 智能等待到开盘前 09:20
  - 当天无数据 -> 自动回退到昨天，再往前最多 7 天
  - 所有接口都失败 -> 持续重试直到拿到数据
"""

import json
import sys
import os
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import STOCK_LIST, OUTPUT_DIR, KLINE_PERIOD, MAX_KLINE_LEN

# ===================== 全局参数 =====================
MAX_RETRIES = 120           # 单只最多重试 120 次
RETRY_INTERVAL = 15         # 重试间隔秒数
MAX_LOOKBACK_DAYS = 7       # 最多往前找 7 天


# ===================== 工具函数 =====================

def save_json(data, filepath):
    """原子写入 JSON（写 tmp -> rename，防止其他程序读到半截数据）"""
    tmp = filepath + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, filepath)
    print(f"  -> 保存 -> {filepath}  ({len(data)} 条)", flush=True)


def now_dt():
    return datetime.now()


def today_ymd():
    return now_dt().strftime("%Y-%m-%d")


def past_days(n):
    return (now_dt() - timedelta(days=n)).strftime("%Y-%m-%d")


def is_weekend(date_str):
    dt = datetime.strptime(date_str, "%Y-%m-%d")
    return dt.weekday() >= 5


def is_off_hours():
    """判断是否为凌晨/非数据可获取时段（东方财富在这个时段直接关连接）"""
    now = now_dt()
    # 周末全天不可用
    if now.weekday() >= 5:
        return True
    # 15:30 ~ 09:15 数据接口一般关闭
    minutes = now.hour * 60 + now.minute
    return minutes < 9 * 60 + 15 or minutes >= 15 * 60 + 30


def seconds_until_open():
    """距离下次可尝试时段的秒数（尽量接近 09:20）"""
    now = now_dt()
    target = now.replace(hour=9, minute=20, second=0, microsecond=0)
    if now >= target:
        if now.hour >= 15:
            target = target + timedelta(days=1)
        else:
            return 15
    delta = (target - now).total_seconds()
    return min(delta, 3600)  # 最多等 1 小时再试，避免错过


# ===================== 数据源 1: akshare =====================

def fetch_by_akshare(stock_code, date_str):
    """akshare 获取 1分钟K线。返回 list 或 None"""
    for attempt in range(2):
        try:
            import akshare as ak
            df = ak.stock_zh_a_hist_min_em(
                symbol=stock_code,
                period=KLINE_PERIOD,
                start_date=f"{date_str} 09:30:00",
                end_date=f"{date_str} 15:00:00",
                adjust="qfq",
            )
            if df.empty:
                return []
            result = []
            for _, row in df.iterrows():
                result.append({
                    "time": str(row["时间"]),
                    "open":  round(float(row["开盘"]), 2),
                    "high":  round(float(row["最高"]), 2),
                    "low":   round(float(row["最低"]), 2),
                    "close": round(float(row["收盘"]), 2),
                    "volume": int(row["成交量"]),
                })
            return result
        except ImportError:
            return None
        except Exception as e:
            msg = str(e)
            if "Remote end closed" in msg or "Connection aborted" in msg:
                if attempt == 0:
                    continue
            return None
    return None


# ===================== 数据源 2: 直连东方财富 HTTP =====================

def fetch_em_http(stock_code, date_str):
    """HTTP 直连东方财富分钟K线接口（不依赖 akshare）"""
    import requests as req

    market = "0" if stock_code.startswith("0") or stock_code.startswith("3") else "1"
    secid = f"{market}.{stock_code}"
    url = (
        f"https://push2his.eastmoney.com/api/qt/stock/kline/get"
        f"?secid={secid}"
        f"&fields1=f1,f2,f3,f4,f5,f6"
        f"&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61"
        f"&klt=1"           # 1分钟K线
        f"&fqt=1"           # 前复权
        f"&beg={date_str}093000"
        f"&end={date_str}150000"
        "&lmt=240"
    )
    try:
        resp = req.get(url, timeout=10,
                       headers={"User-Agent": "Mozilla/5.0"})
        resp.raise_for_status()
        body = resp.json()
        klines = body.get("data", {}).get("klines", [])
        if not klines:
            return []
        result = []
        for line in klines:
            parts = line.split(",")
            if len(parts) < 6:
                continue
            result.append({
                "time": parts[0],
                "open":  round(float(parts[1]), 2),
                "close": round(float(parts[2]), 2),
                "high":  round(float(parts[3]), 2),
                "low":   round(float(parts[4]), 2),
                "volume": int(float(parts[5])),
            })
        return result
    except Exception:
        return None


# ===================== 数据源 3: 新浪财经 =====================

def fetch_by_sina(stock_code, date_str):
    """纯 requests 获取新浪财经 K 线"""
    import requests as req
    url = (
        f"http://money.finance.sina.com.cn/quotes_service/api/json_v2.php"
        f"/CN_MarketData.getKLineData?symbol={stock_code}"
        f"&scale=1&ma=no&datalen={MAX_KLINE_LEN}"
    )
    try:
        resp = req.get(url, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        if not data:
            return []
        result = []
        for item in data:
            if item.get("day", "").startswith(date_str):
                result.append({
                    "time": item["day"],
                    "open":  round(float(item["open"]), 2),
                    "high":  round(float(item["high"]), 2),
                    "low":   round(float(item["low"]), 2),
                    "close": round(float(item["close"]), 2),
                    "volume": int(item["volume"]),
                })
        return result
    except Exception as e:
        return []


# ===================== 组合策略 =====================

def get_kline_for_day(stock_code, date_str):
    """依次尝试所有数据源，返回 list"""
    data = fetch_by_akshare(stock_code, date_str)
    if data is not None:
        if len(data) > 0:
            return data
        print("  (akshare 空数据)", flush=True)

    data = fetch_em_http(stock_code, date_str)
    if data is not None:
        if len(data) > 0:
            return data
        print("  (em_http 空数据)", flush=True)

    data = fetch_by_sina(stock_code, date_str)
    if data is not None and len(data) > 0:
        return data
    return []


# ===================== 公开入口 =====================

def get_daily_minute(stock_code, retry=False):
    """
    获取最近一个交易日的1分钟K线数据。
    自动跳过周末，往前最多 7 天。
    返回 (data_list, used_date)
    """
    for day_offset in range(MAX_LOOKBACK_DAYS):
        date_str = past_days(day_offset)
        if is_weekend(date_str):
            continue

        data = get_kline_for_day(stock_code, date_str)
        if data and len(data) > 0:
            label = "当日" if day_offset == 0 else f"回退 {date_str}"
            print(f"  -> {label}: {len(data)} 条K线", flush=True)
            return data, date_str

        status = "当日暂无" if day_offset == 0 else f"{date_str} 无数据"
        print(f"  -> {status}", end="", flush=True)
        if day_offset < MAX_LOOKBACK_DAYS - 1:
            print("，继续往前...", flush=True)
        else:
            print(flush=True)

    if retry:
        return None, None
    return [], past_days(0)


# ===================== 主入口 =====================

def run(stock_codes=None, retry=True):
    """批量获取历史K线，retry=True 持续重试直到成功"""
    if stock_codes is None:
        stock_codes = STOCK_LIST

    codes = [s.strip().zfill(6) for s in stock_codes]

    for code in codes:
        filename = os.path.join(OUTPUT_DIR, f"{code}_daily_minute.json")

        for attempt in range(1, MAX_RETRIES + 1):
            print(f"\n[{code}] 重试 {attempt}/{MAX_RETRIES} ...", flush=True)

            # ---- 智能等待 ----
            if is_off_hours():
                wait = seconds_until_open()
                print(f"  [凌晨时段] 数据接口未开放，等 {wait:.0f} 秒到 ~09:20 再试...", flush=True)
                import time
                time.sleep(wait)
                continue

            # ---- 获取数据 ----
            data, used_date = get_daily_minute(code, retry=retry)

            if data is not None and len(data) > 0:
                save_json(data, filename)
                break

            if attempt < MAX_RETRIES:
                print(f"  ... 无数据，{RETRY_INTERVAL} 秒后重试", flush=True)
                import time
                time.sleep(RETRY_INTERVAL)
            else:
                print(f"  [超时] {MAX_RETRIES} 次后仍未拿到数据，写空文件", flush=True)
                save_json([], filename)

    print(f"\n完成 {len(codes)} 只股票", flush=True)


if __name__ == "__main__":
    args = sys.argv[1:]
    run(args if args else None)

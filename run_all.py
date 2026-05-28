"""
============================================
 统一数据采集入口
============================================

流程：
  1. 先尝试获取今天已开盘的1分钟K线（东方财富接口）
  2. 启动实时3秒采集，滑动窗口20条
  3. 实时采集期间，每过一分钟自动追加一条精确分钟K线到历史文件
     基于该分钟内所有3秒采样点计算：open=第一笔，high=最高，low=最低，close=最后一笔

用法：
  python run_all.py                     # 默认股票，持续运行
  python run_all.py 000858              # 指定股票
  python run_all.py 000858 600519       # 多只
  python run_all.py 000858 120          # 120秒后自动停止
"""

import sys
import os
import json
import time
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import STOCK_LIST, OUTPUT_DIR


# ===================== 工具 =====================

def save_json(data, filepath):
    tmp = filepath + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, filepath)


def load_json(filepath):
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []


def now_str():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


# ===================== STEP 1: 尝试获取历史 =====================

def try_fetch_today_kline(stock_code):
    """尝试获取今天盘中1分钟K线数据（东方财富接口，盘中可能返回空）"""
    today = datetime.now().strftime("%Y-%m-%d")
    now_hm = datetime.now().strftime("%H:%M:%S")

    # akshare
    try:
        import akshare as ak
        df = ak.stock_zh_a_hist_min_em(
            symbol=stock_code, period="1",
            start_date=f"{today} 09:30:00",
            end_date=f"{today} {now_hm}",
            adjust="qfq",
        )
        if not df.empty:
            result = []
            for _, row in df.iterrows():
                result.append({
                    "time": str(row["时间"]),
                    "open": round(float(row["开盘"]), 2),
                    "high": round(float(row["最高"]), 2),
                    "low":  round(float(row["最低"]), 2),
                    "close": round(float(row["收盘"]), 2),
                    "volume": int(row["成交量"]),
                })
            return result
    except Exception:
        pass

    # 东方财富 HTTP 直连
    try:
        import requests as req
        market = "0" if stock_code[0] in ("0", "3") else "1"
        url = (
            f"https://push2his.eastmoney.com/api/qt/stock/kline/get"
            f"?secid={market}.{stock_code}"
            f"&fields1=f1,f2,f3,f4,f5,f6"
            f"&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61"
            f"&klt=1&fqt=1"
            f"&beg={today}093000&end={today}150000&lmt=240"
        )
        resp = req.get(url, timeout=10, headers={"User-Agent": "Mozilla/5.0"})
        resp.raise_for_status()
        klines = resp.json().get("data", {}).get("klines", [])
        if klines:
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
        pass

    return None


# ===================== STEP 2: 实时采集 =====================

def calc_minute_vol(minute_samples):
    """计算该分钟内的成交量：累加所有3秒采样点的vol_delta"""
    total = sum(s.get("volume", 0) for s in minute_samples)
    return total


def commit_minute_kline(history, history_fp, minute_key, now_dt, samples):
    """
    用该分钟内所有3秒采样点，生成一条精确分钟K线，追加到历史文件。
    open=第一笔价格  high=最高价  low=最低价  close=最后一笔价格
    volume = 该分钟所有3秒增量之和
    """
    if not samples:
        return

    open_price = samples[0]["price"]
    high_price = max(s["price"] for s in samples)
    low_price = min(s["price"] for s in samples)
    close_price = samples[-1]["price"]

    ts = now_dt.strftime("%Y-%m-%d %H:") + minute_key.split(":")[1] + ":00"

    # 去重
    if any(x.get("time", "").startswith(ts[:16]) for x in history):
        return

    minute_vol = calc_minute_vol(samples)

    snapshot = {
        "time": ts,
        "open":  round(open_price, 2),
        "high":  round(high_price, 2),
        "low":   round(low_price, 2),
        "close": round(close_price, 2),
        "volume": minute_vol,
    }
    history.append(snapshot)
    save_json(history, history_fp)
    print(f"  [分] {minute_key}  O={snapshot['open']} H={snapshot['high']} L={snapshot['low']} C={close_price} V={minute_vol}")


def start_realtime(stock_code, duration_seconds=0):
    """
    实时3秒采集 + 每分钟精确快照写入历史文件。

    实时文件：{code}_real_time_window.json   — 滑动窗口20条
    历史文件：{code}_daily_minute.json        — 每分钟追加一条精确分钟K线
    """
    import easyquotation
    q = easyquotation.use("sina")

    realtime_fp = os.path.join(OUTPUT_DIR, f"{stock_code}_real_time_window.json")
    history_fp = os.path.join(OUTPUT_DIR, f"{stock_code}_daily_minute.json")

    history = load_json(history_fp)
    realtime_window = []

    save_json([], realtime_fp)

    last_minute_key = ""
    last_cum_volume = None
    count = 0
    start_ts = time.time()

    # 当前分钟的采样点（分钟结束时结算为一条K线）
    curr_minute_samples = []

    label = "持续运行" if duration_seconds == 0 else f"{duration_seconds}秒"
    print(f"\n[实时采集] {stock_code}  每3秒  窗口20条  {label}")
    print(f"           实时 -> {os.path.basename(realtime_fp)}")
    print(f"           分钟快照 -> {os.path.basename(history_fp)}")

    try:
        while True:
            if duration_seconds > 0 and (time.time() - start_ts) >= duration_seconds:
                break

            try:
                res = q.real([stock_code])
                tick = res.get(stock_code)
                if not tick:
                    time.sleep(3)
                    continue

                now = datetime.now()
                price = round(float(tick["now"]), 2)
                cum_vol = int(tick["volume"])

                # 3秒增量
                if last_cum_volume is not None:
                    vol_delta = max(0, cum_vol - last_cum_volume)
                else:
                    vol_delta = 0
                last_cum_volume = cum_vol

                # ---- 实时条目 ----
                entry = {
                    "stock_code": stock_code,
                    "time": now_str(),
                    "price": price,
                    "volume": vol_delta,
                    "cum_volume": cum_vol,
                    "high": round(float(tick.get("high", 0)), 2),
                    "low":  round(float(tick.get("low", 0)), 2),
                    "open": round(float(tick.get("open", 0)), 2),
                }
                realtime_window.append(entry)
                if len(realtime_window) > 20:
                    realtime_window = realtime_window[-20:]
                save_json(realtime_window, realtime_fp)

                # ---- 分钟切换检测 ----
                minute_key = now.strftime("%H:%M")
                if minute_key != last_minute_key:
                    # 跨分钟了：结算上一分钟的快照
                    if last_minute_key != "" and curr_minute_samples:
                        commit_minute_kline(
                            history, history_fp, last_minute_key, now,
                            curr_minute_samples,
                        )
                    # 重置
                    curr_minute_samples = []

                last_minute_key = minute_key

                # 记录该分钟内的采样
                curr_minute_samples.append(entry)

                count += 1
                if count % 5 == 0:
                    remaining = ""
                    if duration_seconds > 0:
                        remaining = f" 剩余{int(duration_seconds - (time.time() - start_ts))}s"
                    print(f"  [{stock_code}] #{count}  {entry['time']}  价格={entry['price']}{remaining}")

            except Exception as e:
                print(f"  [!] 采集异常: {e}")

            time.sleep(3)

    except KeyboardInterrupt:
        print("\n  [停止] 用户中断")

    # 结束时结算最后一分钟
    if curr_minute_samples:
        commit_minute_kline(
            history, history_fp, last_minute_key, datetime.now(),
            curr_minute_samples,
        )

    print(f"\n[实时完成] 共采集 {count} 次")
    print(f"          实时窗口: {len(realtime_window)} 条")
    print(f"          历史累加: {len(history)} 条")
    return realtime_window


# ===================== 主入口 =====================

def run(stock_codes=None, duration_seconds=0):
    if stock_codes is None:
        stock_codes = STOCK_LIST

    codes = [s.strip().zfill(6) for s in stock_codes]

    for code in codes:
        print(f"\n{'='*55}")
        print(f"  {code}  第一步：尝试获取今日历史分钟K线")
        print(f"{'='*55}")

        history = try_fetch_today_kline(code)
        fp = os.path.join(OUTPUT_DIR, f"{code}_daily_minute.json")

        if history and len(history) > 0:
            save_json(history, fp)
            print(f"  -> 获取到今天K线 {len(history)} 条 -> {fp}")
        else:
            print(f"  -> 今日分钟K线暂不可用（收盘后自动补齐）")
            print(f"  -> 实时采集启动后每分钟自动打快照")

        start_realtime(code, duration_seconds=duration_seconds)

    print(f"\n{'='*55}")
    print(f"  全部完成")


if __name__ == "__main__":
    args = sys.argv[1:]
    codes = []
    seconds = 0
    for a in args:
        if a.isdigit():
            seconds = int(a)
        else:
            codes.append(a)
    run(codes if codes else None, duration_seconds=seconds)

"""
============================================
 测试脚本：快速验证两个核心模块
============================================

运行方式（在 py_fpga高速交易 目录下）：
  python test_modules.py

会依次：
  ✅ 测试 fetch_history.py 获取历史K线
  ✅ 测试 feed_real_time.py 单次采集
  ✅ 验证 JSON 输出格式
"""

import sys
import os
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

TEST_CODE = "000858"


def test_fetch_history():
    """快速验证历史行情模块"""
    print("=" * 50)
    print("🧪 [测试 1/3] fetch_history.py — 历史K线获取")
    print("=" * 50)

    from config import OUTPUT_DIR
    from fetch_history import get_daily_minute, save_json

    data, used_date = get_daily_minute(TEST_CODE)

    if not data:
        print("  ⚠️  未获取到数据（非交易日或接口限流），跳过后续")
        return False

    # 验证字段完整性
    required_fields = {"time", "open", "high", "low", "close", "volume"}
    sample = data[0]
    missing = required_fields - set(sample.keys())
    if missing:
        print(f"  ❌ 字段缺失: {missing}")
        return False

    # 验证数据类型
    assert isinstance(sample["time"], str), "time 应该是字符串"
    assert isinstance(sample["open"], float), "open 应该是浮点数"
    assert isinstance(sample["volume"], int), "volume 应该是整数"

    # 保存并验证 JSON 文件
    filename = os.path.join(OUTPUT_DIR, f"{TEST_CODE}_daily_minute.json")
    save_json(data, filename)

    with open(filename, "r", encoding="utf-8") as f:
        reloaded = json.load(f)

    assert len(reloaded) == len(data), "JSON 读写不一致"
    print(f"  ✅ 通过: {len(data)} 条K线，字段完整，JSON可读写")
    return True


def test_feed_real_time():
    """快速验证实时行情模块（只采一次）"""
    print("\n" + "=" * 50)
    print("🧪 [测试 2/3] feed_real_time.py — 实时行情采集（单次）")
    print("=" * 50)

    from feed_real_time import fetch_realtime_sina

    tick = fetch_realtime_sina(TEST_CODE)

    if tick is None:
        print("  ⚠️  实时采集失败（网络或非交易时段）")
        return False

    # 验证字段
    required = {"stock_code", "time", "price", "volume"}
    missing = required - set(tick.keys())
    if missing:
        print(f"  ❌ 字段缺失: {missing}")
        return False

    assert tick["stock_code"] == TEST_CODE
    assert isinstance(tick["price"], float), "price 应为 float"
    assert isinstance(tick["volume"], int), "volume 应为 int"
    print(f"  ✅ 通过: {tick['time']} 价格={tick['price']} 成交量={tick['volume']}")
    return True


def test_config():
    """验证配置完整性"""
    print("\n" + "=" * 50)
    print("🧪 [测试 3/3] config.py — 配置完整性")
    print("=" * 50)

    from config import (
        STOCK_LIST, REAL_TIME_INTERVAL, MAX_WINDOW_SIZE,
        KLINE_PERIOD, OUTPUT_DIR
    )

    assert isinstance(STOCK_LIST, list) and len(STOCK_LIST) > 0, "STOCK_LIST 不能为空"
    assert isinstance(REAL_TIME_INTERVAL, (int, float)), "REAL_TIME_INTERVAL 应为数字"
    assert isinstance(MAX_WINDOW_SIZE, int) and MAX_WINDOW_SIZE > 0, "MAX_WINDOW_SIZE 应为正整数"
    assert isinstance(KLINE_PERIOD, str), "KLINE_PERIOD 应为字符串"
    assert isinstance(OUTPUT_DIR, str), "OUTPUT_DIR 应为字符串"

    print(f"  ✅ 通过")
    print(f"     股票列表: {STOCK_LIST}")
    print(f"     采集间隔: {REAL_TIME_INTERVAL}s")
    print(f"     滑动窗口: {MAX_WINDOW_SIZE} 条")
    print(f"     输出目录: {OUTPUT_DIR}")
    return True


if __name__ == "__main__":
    print("\n🔧 py_fpga高速交易 — 模块测试\n")
    results = {}

    results["config"] = test_config()
    results["history"] = test_fetch_history()
    results["realtime"] = test_feed_real_time()

    print("\n" + "=" * 50)
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    print(f"\n📊 测试结果: {passed}/{total} 通过\n")

    for name, ok in results.items():
        status = "✅" if ok else "⚠️"
        print(f"  {status} {name}")

    # 如果历史模块通过，展示几条数据
    if results.get("history"):
        with open(f"{TEST_CODE}_daily_minute.json", "r", encoding="utf-8") as f:
            data = json.load(f)
        print(f"\n📋 历史K线预览 (前3条 / 共{len(data)}条):")
        for item in data[:3]:
            print(f"    {item['time']}  O={item['open']} H={item['high']} "
                  f"L={item['low']} C={item['close']} V={item['volume']}")

    print()

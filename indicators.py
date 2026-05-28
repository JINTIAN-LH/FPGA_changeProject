"""Reference indicator implementations used by mock FPGA."""

from __future__ import annotations

from typing import Sequence


def _tail(values: Sequence[float], n: int) -> Sequence[float]:
    return values[-n:] if len(values) >= n else values



def sma(values: Sequence[float], period: int) -> float:
    data = _tail(values, period)
    return float(sum(data) / len(data)) if data else 0.0



def ema(values: Sequence[float], period: int) -> float:
    if not values:
        return 0.0
    alpha = 2.0 / (period + 1)
    out = float(values[0])
    for v in values[1:]:
        out = alpha * float(v) + (1.0 - alpha) * out
    return out



def rsi(values: Sequence[float], period: int = 14) -> float:
    if len(values) < 2:
        return 50.0
    gains = []
    losses = []
    start = max(1, len(values) - period)
    for i in range(start, len(values)):
        delta = float(values[i]) - float(values[i - 1])
        gains.append(max(delta, 0.0))
        losses.append(max(-delta, 0.0))
    avg_gain = sum(gains) / len(gains) if gains else 0.0
    avg_loss = sum(losses) / len(losses) if losses else 0.0
    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return 100.0 - 100.0 / (1.0 + rs)



def macd(values: Sequence[float]) -> tuple[float, float]:
    if not values:
        return 0.0, 0.0
    # Build MACD series to derive signal EMA(9).
    macd_series = []
    for i in range(1, len(values) + 1):
        c = values[:i]
        macd_series.append(ema(c, 12) - ema(c, 26))
    line = macd_series[-1]
    signal = ema(macd_series, 9)
    return line, signal



def atr(highs: Sequence[float], lows: Sequence[float], closes: Sequence[float], period: int = 14) -> float:
    n = min(len(highs), len(lows), len(closes))
    if n < 2:
        return 0.0
    trs = []
    start = max(1, n - period)
    for i in range(start, n):
        h = float(highs[i])
        l = float(lows[i])
        prev_close = float(closes[i - 1])
        tr = max(h - l, abs(h - prev_close), abs(l - prev_close))
        trs.append(tr)
    return float(sum(trs) / len(trs)) if trs else 0.0



def volume_ratio(volumes: Sequence[int], period: int = 5) -> float:
    if not volumes:
        return 0.0
    tail = _tail([float(v) for v in volumes], period)
    avg = sum(tail) / len(tail)
    if avg == 0:
        return 0.0
    return float(tail[-1] / avg)



def score_and_decision(close_values: Sequence[float], rsi_value: float, macd_line: float, macd_signal: float, vol_ratio: float) -> tuple[float, int]:
    """Simple reference scoring model.

    decision: 0 strong sell, 1 sell, 2 hold, 3 buy, 4 strong buy
    """
    score = 50.0
    if len(close_values) >= 20:
        ma5 = sma(close_values, 5)
        ma20 = sma(close_values, 20)
        if ma5 > ma20:
            score += 15
        elif ma5 < ma20:
            score -= 15

    if rsi_value < 30:
        score += 10
    elif rsi_value > 70:
        score -= 10

    if macd_line > macd_signal:
        score += 10
    else:
        score -= 10

    if vol_ratio > 1.2:
        score += 10
    elif vol_ratio < 0.8:
        score -= 10

    score = max(0.0, min(100.0, score))
    if score >= 80:
        decision = 4
    elif score >= 60:
        decision = 3
    elif score >= 40:
        decision = 2
    elif score >= 20:
        decision = 1
    else:
        decision = 0
    return score, decision

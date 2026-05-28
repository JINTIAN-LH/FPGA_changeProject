"""Software-side data validation for k-line payloads."""

from __future__ import annotations

from datetime import datetime
from typing import Iterable


class ValidationError(ValueError):
    """Raised when a bar or bar sequence violates the project schema."""


REQUIRED_FIELDS = ("time", "open", "high", "low", "close", "volume")


def validate_kline_bar(bar: dict) -> dict:
    missing = [field for field in REQUIRED_FIELDS if field not in bar]
    if missing:
        raise ValidationError(f"missing fields: {missing}")

    try:
        parsed_time = datetime.strptime(str(bar["time"]), "%Y-%m-%d %H:%M:%S")
    except ValueError as exc:
        raise ValidationError(f"invalid time format: {bar['time']}") from exc

    open_price = float(bar["open"])
    high_price = float(bar["high"])
    low_price = float(bar["low"])
    close_price = float(bar["close"])
    volume = int(bar["volume"])

    if min(open_price, high_price, low_price, close_price) <= 0:
        raise ValidationError("prices must be positive")
    if volume < 0:
        raise ValidationError("volume must be non-negative")
    if high_price < max(open_price, low_price, close_price):
        raise ValidationError("high must be >= open/low/close")
    if low_price > min(open_price, high_price, close_price):
        raise ValidationError("low must be <= open/high/close")

    return {
        "time": parsed_time.strftime("%Y-%m-%d %H:%M:%S"),
        "open": round(open_price, 2),
        "high": round(high_price, 2),
        "low": round(low_price, 2),
        "close": round(close_price, 2),
        "volume": volume,
    }


def validate_kline_sequence(bars: Iterable[dict]) -> list[dict]:
    validated = [validate_kline_bar(bar) for bar in bars]
    previous = None
    for bar in validated:
        current = datetime.strptime(bar["time"], "%Y-%m-%d %H:%M:%S")
        if previous is not None and current <= previous:
            raise ValidationError("k-line timestamps must be strictly increasing")
        previous = current
    return validated
"""Protocol encode/decode utilities for host <-> FPGA UDP frames.

Implemented per ICD V1.0 image tables:
- Upstream total length: 48 bytes
- Downstream total length: 44 bytes
- Big-endian byte order
- CRC32 over all bytes except final CRC field
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
import json
from pathlib import Path
import struct
import zlib

UP_HEADER = 0xAA55
DOWN_HEADER = 0x55AA
UPSTREAM_LEN = 48
DOWNSTREAM_LEN = 44

_UP_NOCRC_FMT = ">HH8sIffffI8s"
_DOWN_NOCRC_FMT = ">HH8sIffffBB6s"

PROTOCOL_CONTRACT = {
    "endianness": "big",
    "crc32_polynomial": "0x04C11DB7",
    "upstream": {
        "header": "0xAA55",
        "length": 48,
        "fields": [
            {"name": "stock_code", "type": "char[8]", "offset": 4, "size": 8},
            {"name": "timestamp", "type": "uint32_t", "offset": 12, "size": 4},
            {"name": "open", "type": "float32", "offset": 16, "size": 4},
            {"name": "high", "type": "float32", "offset": 20, "size": 4},
            {"name": "low", "type": "float32", "offset": 24, "size": 4},
            {"name": "close", "type": "float32", "offset": 28, "size": 4},
            {"name": "volume", "type": "uint32_t", "offset": 32, "size": 4},
            {"name": "reserved", "type": "uint8_t[8]", "offset": 36, "size": 8},
            {"name": "crc32", "type": "uint32_t", "offset": 44, "size": 4},
        ],
    },
    "downstream": {
        "header": "0x55AA",
        "length": 44,
        "fields": [
            {"name": "stock_code", "type": "char[8]", "offset": 4, "size": 8},
            {"name": "timestamp", "type": "uint32_t", "offset": 12, "size": 4},
            {"name": "ma5", "type": "float32", "offset": 16, "size": 4},
            {"name": "ma10", "type": "float32", "offset": 20, "size": 4},
            {"name": "rsi6", "type": "float32", "offset": 24, "size": 4},
            {"name": "rsi14", "type": "float32", "offset": 28, "size": 4},
            {"name": "trade_signal", "type": "uint8_t", "offset": 32, "size": 1},
            {"name": "signal_strength", "type": "uint8_t", "offset": 33, "size": 1},
            {"name": "reserved", "type": "uint8_t[6]", "offset": 34, "size": 6},
            {"name": "crc32", "type": "uint32_t", "offset": 40, "size": 4},
        ],
    },
}


class ProtocolError(ValueError):
    """Raised when a frame cannot be decoded."""


@dataclass
class UpstreamFrame:
    stock_code: str
    timestamp: int
    open: float
    high: float
    low: float
    close: float
    volume: int
    reserved: bytes = b"\x00" * 8


@dataclass
class DownstreamFrame:
    stock_code: str
    timestamp: int
    ma5: float
    ma10: float
    rsi6: float
    rsi14: float
    trade_signal: int
    signal_strength: int
    reserved: bytes = b"\x00" * 6



def minute_to_epoch(text: str) -> int:
    dt = datetime.strptime(text, "%Y-%m-%d %H:%M:%S")
    return int(dt.timestamp())



def _crc32(data: bytes) -> int:
    return zlib.crc32(data) & 0xFFFFFFFF


def export_contract_snapshot(path: str | Path) -> None:
    target = Path(path)
    target.write_text(
        json.dumps(PROTOCOL_CONTRACT, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def to_exchange_code(raw_code: str) -> str:
    """Convert 6-digit stock code to ICD char[8] code with exchange suffix.

    Examples:
    - 600000 -> 600000SH
    - 000001 -> 000001SZ
    """
    code = raw_code.strip().upper()
    if len(code) == 8 and (code.endswith("SH") or code.endswith("SZ")):
        return code
    if len(code) == 6 and code.isdigit():
        suffix = "SH" if code.startswith("6") else "SZ"
        return code + suffix
    raise ProtocolError(f"Invalid stock code for ICD char[8]: {raw_code}")



def pack_upstream(frame: UpstreamFrame) -> bytes:
    stock_code = to_exchange_code(frame.stock_code)
    code = stock_code.encode("ascii", errors="ignore")[:8].ljust(8, b"\x00")
    reserved = frame.reserved[:8].ljust(8, b"\x00")
    body = struct.pack(
        _UP_NOCRC_FMT,
        UP_HEADER,
        UPSTREAM_LEN,
        code,
        int(frame.timestamp) & 0xFFFFFFFF,
        float(frame.open),
        float(frame.high),
        float(frame.low),
        float(frame.close),
        int(frame.volume) & 0xFFFFFFFF,
        reserved,
    )
    crc = _crc32(body)
    packet = body + struct.pack(">I", crc)
    if len(packet) != UPSTREAM_LEN:
        raise ProtocolError(f"Upstream packet len {len(packet)} != {UPSTREAM_LEN}")
    return packet



def unpack_upstream(data: bytes) -> UpstreamFrame:
    if len(data) != UPSTREAM_LEN:
        raise ProtocolError(f"Upstream packet len {len(data)} != {UPSTREAM_LEN}")
    body, recv_crc = data[:-4], data[-4:]
    calc_crc = _crc32(body)
    recv_crc_u32 = struct.unpack(">I", recv_crc)[0]
    if calc_crc != recv_crc_u32:
        raise ProtocolError(f"Upstream CRC mismatch calc={calc_crc} recv={recv_crc_u32}")

    header, total_len, code, ts, op, hi, lo, cl, vol, reserved = struct.unpack(
        _UP_NOCRC_FMT, body
    )
    if header != UP_HEADER:
        raise ProtocolError(f"Invalid upstream header: {header:#06x}")
    if total_len != UPSTREAM_LEN:
        raise ProtocolError(f"Invalid upstream length field: {total_len}")

    return UpstreamFrame(
        stock_code=code.rstrip(b"\x00").decode("ascii", errors="ignore"),
        timestamp=ts,
        open=op,
        high=hi,
        low=lo,
        close=cl,
        volume=vol,
        reserved=reserved,
    )



def pack_downstream(frame: DownstreamFrame) -> bytes:
    stock_code = to_exchange_code(frame.stock_code)
    code = stock_code.encode("ascii", errors="ignore")[:8].ljust(8, b"\x00")
    reserved = frame.reserved[:6].ljust(6, b"\x00")
    body = struct.pack(
        _DOWN_NOCRC_FMT,
        DOWN_HEADER,
        DOWNSTREAM_LEN,
        code,
        int(frame.timestamp) & 0xFFFFFFFF,
        float(frame.ma5),
        float(frame.ma10),
        float(frame.rsi6),
        float(frame.rsi14),
        int(frame.trade_signal) & 0xFF,
        int(frame.signal_strength) & 0xFF,
        reserved,
    )
    crc = _crc32(body)
    packet = body + struct.pack(">I", crc)
    if len(packet) != DOWNSTREAM_LEN:
        raise ProtocolError(f"Downstream packet len {len(packet)} != {DOWNSTREAM_LEN}")
    return packet



def unpack_downstream(data: bytes) -> DownstreamFrame:
    if len(data) != DOWNSTREAM_LEN:
        raise ProtocolError(f"Downstream packet len {len(data)} != {DOWNSTREAM_LEN}")
    body, recv_crc = data[:-4], data[-4:]
    calc_crc = _crc32(body)
    recv_crc_u32 = struct.unpack(">I", recv_crc)[0]
    if calc_crc != recv_crc_u32:
        raise ProtocolError(f"Downstream CRC mismatch calc={calc_crc} recv={recv_crc_u32}")

    (
        header,
        total_len,
        code,
        ts,
        ma5,
        ma10,
        rsi6,
        rsi14,
        trade_signal,
        signal_strength,
        reserved,
    ) = struct.unpack(_DOWN_NOCRC_FMT, body)

    if header != DOWN_HEADER:
        raise ProtocolError(f"Invalid downstream header: {header:#06x}")
    if total_len != DOWNSTREAM_LEN:
        raise ProtocolError(f"Invalid downstream length field: {total_len}")

    return DownstreamFrame(
        stock_code=code.rstrip(b"\x00").decode("ascii", errors="ignore"),
        timestamp=ts,
        ma5=ma5,
        ma10=ma10,
        rsi6=rsi6,
        rsi14=rsi14,
        trade_signal=trade_signal,
        signal_strength=signal_strength,
        reserved=reserved,
    )

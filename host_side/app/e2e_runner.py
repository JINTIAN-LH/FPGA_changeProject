"""Host-side end-to-end runner for non-FPGA prototype.

Usage:
  python e2e_runner.py --code 000858 --limit 30
  python e2e_runner.py --code 000858 --start-mock --limit 30
"""

from __future__ import annotations

import argparse
from pathlib import Path
import json
import socket
import threading
import time
from datetime import datetime

from config import FPGA_UDP_HOST as DEFAULT_HOST
from config import FPGA_UDP_PORT as DEFAULT_PORT
from fpga_protocol import DownstreamFrame, UpstreamFrame, minute_to_epoch, pack_upstream, to_exchange_code, unpack_downstream
from mock_fpga import serve as start_mock_server



def load_bars(code: str) -> list[dict]:
    fp = Path(f"{code}_daily_minute.json")
    if not fp.exists():
        raise FileNotFoundError(f"missing input file: {fp}")
    return json.loads(fp.read_text(encoding="utf-8"))



def run_client(code: str, host: str, port: int, limit: int, timeout: float) -> list[DownstreamFrame]:
    bars = load_bars(code)[:limit]
    if not bars:
        return []

    results = []
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)

    exch_code = to_exchange_code(code)

    for bar in bars:
        req = UpstreamFrame(
            stock_code=exch_code,
            timestamp=minute_to_epoch(bar["time"]),
            open=float(bar["open"]),
            high=float(bar["high"]),
            low=float(bar["low"]),
            close=float(bar["close"]),
            volume=int(bar["volume"]),
        )
        sock.sendto(pack_upstream(req), (host, port))
        raw, _ = sock.recvfrom(2048)
        rsp = unpack_downstream(raw)
        results.append(rsp)
        print(
            f"code={rsp.stock_code} ts={rsp.timestamp} "
            f"ma5={rsp.ma5:6.2f} ma10={rsp.ma10:6.2f} "
            f"rsi6={rsp.rsi6:6.2f} rsi14={rsp.rsi14:6.2f} "
            f"signal={rsp.trade_signal} strength={rsp.signal_strength}"
        )

    sock.close()
    return results


def run_smoke_once(code: str, host: str, port: int, timeout: float) -> DownstreamFrame:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)

    req = UpstreamFrame(
        stock_code=to_exchange_code(code),
        timestamp=int(datetime.now().timestamp()),
        open=10.0,
        high=10.2,
        low=9.9,
        close=10.1,
        volume=100,
    )
    sock.sendto(pack_upstream(req), (host, port))
    raw, _ = sock.recvfrom(2048)
    sock.close()
    return unpack_downstream(raw)



def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--code", default="000858")
    p.add_argument("--host", default=DEFAULT_HOST)
    p.add_argument("--port", type=int, default=DEFAULT_PORT)
    p.add_argument("--limit", type=int, default=20)
    p.add_argument("--timeout", type=float, default=2.0)
    p.add_argument("--start-mock", action="store_true")
    p.add_argument("--smoke", action="store_true", help="send one synthetic frame without reading local JSON")
    args = p.parse_args()

    th = None
    if args.start_mock:
        th = threading.Thread(target=start_mock_server, kwargs={"host": args.host, "port": args.port}, daemon=True)
        th.start()
        time.sleep(0.2)

    if args.smoke:
        rsp = run_smoke_once(args.code, args.host, args.port, args.timeout)
        print(
            f"[smoke] ok code={rsp.stock_code} ts={rsp.timestamp} "
            f"ma5={rsp.ma5:.2f} ma10={rsp.ma10:.2f} "
            f"rsi6={rsp.rsi6:.2f} rsi14={rsp.rsi14:.2f} "
            f"signal={rsp.trade_signal} strength={rsp.signal_strength}"
        )
    else:
        results = run_client(args.code, args.host, args.port, args.limit, args.timeout)
        print(f"\n[e2e] completed, frames={len(results)}")



if __name__ == "__main__":
    main()

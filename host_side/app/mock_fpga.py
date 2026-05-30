"""Mock FPGA UDP service for local protocol integration tests."""

from __future__ import annotations

from collections import defaultdict
from typing import DefaultDict, List
import socket

from fpga_protocol import DownstreamFrame, ProtocolError, UpstreamFrame, pack_downstream, unpack_upstream
from indicators import rsi, sma

HOST = "127.0.0.1"
PORT = 9001



def serve(host: str = HOST, port: int = PORT) -> None:
    state: DefaultDict[str, List[UpstreamFrame]] = defaultdict(list)
    error_count = 0

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((host, port))
    print(f"[mock-fpga] listening on {host}:{port}")

    try:
        while True:
            raw, addr = sock.recvfrom(2048)
            try:
                req = unpack_upstream(raw)
                bars = state[req.stock_code]
                bars.append(req)
                if len(bars) > 300:
                    del bars[:-300]

                closes = [b.close for b in bars]

                ma5 = sma(closes, 5)
                ma10 = sma(closes, 10)
                rsi6 = rsi(closes, 6)
                rsi14 = rsi(closes, 14)

                # Data dictionary signal rules:
                # buy=1, sell=2, none=0.
                if rsi6 < 30 and rsi14 < 30:
                    trade_signal = 1
                    signal_strength = 90
                elif rsi6 < 40 and rsi14 < 40:
                    trade_signal = 1
                    signal_strength = 70
                elif rsi6 > 70 and rsi14 > 70:
                    trade_signal = 2
                    signal_strength = 90
                elif rsi6 > 60 and rsi14 > 60:
                    trade_signal = 2
                    signal_strength = 70
                else:
                    trade_signal = 0
                    signal_strength = 0

                rsp = DownstreamFrame(
                    stock_code=req.stock_code,
                    timestamp=req.timestamp,
                    ma5=ma5,
                    ma10=ma10,
                    rsi6=rsi6,
                    rsi14=rsi14,
                    trade_signal=trade_signal,
                    signal_strength=signal_strength,
                )
            except ProtocolError as exc:
                error_count += 1
                print(f"[mock-fpga] protocol error: {exc}")
                # ICD behavior: silently drop malformed frames.
                continue

            sock.sendto(pack_downstream(rsp), addr)

    except KeyboardInterrupt:
        print("\n[mock-fpga] stopped")
    finally:
        sock.close()



if __name__ == "__main__":
    serve()

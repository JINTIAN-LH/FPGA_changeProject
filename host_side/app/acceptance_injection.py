"""Protocol acceptance script with anomaly injection for FPGA UDP link.

Cases:
- normal           : valid frame should receive valid response
- bad_length       : malformed length should be dropped (no response)
- bad_crc          : CRC-corrupted frame should be dropped (no response)
- bad_header       : invalid header should be dropped (no response)
- timeout_retry    : transport timeout/retry path should trigger expected timeout stats

Usage examples:
  python acceptance_injection.py --host 192.168.1.101 --port 5001
  python acceptance_injection.py --start-mock
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime
import socket
import threading
import time

from fpga_protocol import UpstreamFrame, pack_upstream, unpack_downstream
from mock_fpga import serve as start_mock_server
from udp_transport import TransportTimeoutError, UdpTransport


@dataclass
class CaseResult:
    name: str
    passed: bool
    detail: str


def _build_base_frame(code: str) -> UpstreamFrame:
    return UpstreamFrame(
        stock_code=code,
        timestamp=int(datetime.now().timestamp()),
        open=10.0,
        high=10.2,
        low=9.9,
        close=10.1,
        volume=100,
    )


def _probe_raw_once(host: str, port: int, payload: bytes, timeout: float = 0.8) -> tuple[bool, str]:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    try:
        sock.sendto(payload, (host, port))
        raw, _ = sock.recvfrom(2048)
        _ = unpack_downstream(raw)
        return True, "response_received"
    except socket.timeout:
        return False, "timeout_no_response"
    except Exception as exc:  # pragma: no cover - diagnostic path
        return False, f"recv_error:{exc}"
    finally:
        sock.close()


def case_normal(host: str, port: int, code: str) -> CaseResult:
    payload = pack_upstream(_build_base_frame(code))
    ok, detail = _probe_raw_once(host, port, payload)
    return CaseResult("normal", ok, detail)


def case_bad_length(host: str, port: int, code: str) -> CaseResult:
    payload = pack_upstream(_build_base_frame(code))
    bad = payload[:-1]  # 47 bytes
    ok, detail = _probe_raw_once(host, port, bad)
    return CaseResult("bad_length", not ok, detail)


def case_bad_crc(host: str, port: int, code: str) -> CaseResult:
    payload = bytearray(pack_upstream(_build_base_frame(code)))
    payload[-1] ^= 0x01
    ok, detail = _probe_raw_once(host, port, bytes(payload))
    return CaseResult("bad_crc", not ok, detail)


def case_bad_header(host: str, port: int, code: str) -> CaseResult:
    payload = bytearray(pack_upstream(_build_base_frame(code)))
    payload[0] = 0x12
    payload[1] = 0x34
    ok, detail = _probe_raw_once(host, port, bytes(payload))
    return CaseResult("bad_header", not ok, detail)


def case_timeout_retry(host: str, port: int, code: str, retries: int = 3) -> CaseResult:
    transport = UdpTransport(
        host=host,
        port=port + 1,
        timeout_seconds=0.15,
        max_retries=retries,
    )
    try:
        try:
            transport.request_response(_build_base_frame(code))
            return CaseResult("timeout_retry", False, "unexpected_response")
        except TransportTimeoutError:
            timeout_ok = transport.stats.timeout_count == retries
            sent_ok = transport.stats.sent_count == retries
            if timeout_ok and sent_ok:
                return CaseResult("timeout_retry", True, f"timeouts={transport.stats.timeout_count}")
            return CaseResult(
                "timeout_retry",
                False,
                f"timeouts={transport.stats.timeout_count}, sent={transport.stats.sent_count}",
            )
    finally:
        transport.close()


def run_all(host: str, port: int, code: str) -> list[CaseResult]:
    return [
        case_normal(host, port, code),
        case_bad_length(host, port, code),
        case_bad_crc(host, port, code),
        case_bad_header(host, port, code),
        case_timeout_retry(host, port, code),
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="192.168.1.101")
    parser.add_argument("--port", type=int, default=5001)
    parser.add_argument("--code", default="000858SZ")
    parser.add_argument("--start-mock", action="store_true")
    args = parser.parse_args()

    th = None
    if args.start_mock:
        th = threading.Thread(target=start_mock_server, kwargs={"host": args.host, "port": args.port}, daemon=True)
        th.start()
        time.sleep(0.2)

    results = run_all(args.host, args.port, args.code)

    passed = 0
    print("\n[acceptance] anomaly injection summary")
    for r in results:
        status = "PASS" if r.passed else "FAIL"
        print(f"- {r.name:14s} {status:4s} {r.detail}")
        if r.passed:
            passed += 1

    print(f"\n[acceptance] total: {passed}/{len(results)} passed")


if __name__ == "__main__":
    main()

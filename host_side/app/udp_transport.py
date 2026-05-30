"""UDP transport with retry and lightweight link statistics."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import math
import json
import socket
import time
from typing import Any

from fpga_protocol import DownstreamFrame, ProtocolError, UpstreamFrame, pack_upstream, unpack_downstream


class TransportTimeoutError(TimeoutError):
    """Raised when all UDP retries are exhausted."""


@dataclass
class TransportStats:
    request_count: int = 0
    sent_count: int = 0
    received_count: int = 0
    timeout_count: int = 0
    crc_error_count: int = 0
    protocol_error_count: int = 0
    rtt_samples_ms: list[float] | None = None

    def __post_init__(self) -> None:
        if self.rtt_samples_ms is None:
            self.rtt_samples_ms = []

    def add_rtt(self, rtt_ms: float) -> None:
        if self.rtt_samples_ms is None:
            self.rtt_samples_ms = []
        self.rtt_samples_ms.append(float(rtt_ms))
        # Keep bounded history to avoid unbounded growth in long-running sessions.
        if len(self.rtt_samples_ms) > 5000:
            self.rtt_samples_ms = self.rtt_samples_ms[-5000:]

    def percentile_ms(self, p: float) -> float:
        if not self.rtt_samples_ms:
            return 0.0
        sorted_samples = sorted(self.rtt_samples_ms)
        k = (len(sorted_samples) - 1) * p
        floor_i = int(math.floor(k))
        ceil_i = int(math.ceil(k))
        if floor_i == ceil_i:
            return sorted_samples[floor_i]
        ratio = k - floor_i
        return sorted_samples[floor_i] * (1.0 - ratio) + sorted_samples[ceil_i] * ratio

    def summary(self) -> dict:
        success_count = self.received_count
        success_rate = (success_count / self.sent_count) if self.sent_count else 0.0
        return {
            "request_count": self.request_count,
            "sent_count": self.sent_count,
            "received_count": self.received_count,
            "timeout_count": self.timeout_count,
            "crc_error_count": self.crc_error_count,
            "protocol_error_count": self.protocol_error_count,
            "success_rate": round(success_rate, 6),
            "rtt_count": len(self.rtt_samples_ms or []),
            "rtt_p50_ms": round(self.percentile_ms(0.50), 3),
            "rtt_p95_ms": round(self.percentile_ms(0.95), 3),
            "rtt_p99_ms": round(self.percentile_ms(0.99), 3),
        }


class UdpTransport:
    def __init__(
        self,
        host: str,
        port: int,
        timeout_seconds: float = 1.0,
        max_retries: int = 3,
        bind_host: str = "",
        bind_port: int = 0,
        jsonl_log_path: str | None = None,
    ) -> None:
        self.host = host
        self.port = port
        self.timeout_seconds = timeout_seconds
        self.max_retries = max_retries
        self.jsonl_log_path = jsonl_log_path
        self.stats = TransportStats()
        self._request_seq = 0
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._sock.bind((bind_host, bind_port))
        self._sock.settimeout(timeout_seconds)

    def _next_request_id(self) -> int:
        self._request_seq += 1
        return self._request_seq

    def _append_jsonl(self, payload: dict[str, Any]) -> None:
        if not self.jsonl_log_path:
            return
        line = json.dumps(payload, ensure_ascii=False) + "\n"
        with open(self.jsonl_log_path, "a", encoding="utf-8") as f:
            f.write(line)

    def _log_attempt(
        self,
        request_id: int,
        frame: UpstreamFrame,
        attempt: int,
        status: str,
        error_code: str,
        rtt_ms: float | None,
    ) -> None:
        self._append_jsonl(
            {
                "ts": datetime.now(timezone.utc).isoformat(),
                "request_id": request_id,
                "stock_code": frame.stock_code,
                "timestamp": int(frame.timestamp),
                "attempt": attempt,
                "max_retries": self.max_retries,
                "host": self.host,
                "port": self.port,
                "status": status,
                "error_code": error_code,
                "rtt_ms": None if rtt_ms is None else round(rtt_ms, 3),
                "timeout_seconds": self.timeout_seconds,
            }
        )

    def close(self) -> None:
        self._sock.close()

    def __del__(self) -> None:
        try:
            self.close()
        except OSError:
            pass

    def request_response(self, frame: UpstreamFrame) -> DownstreamFrame:
        self.stats.request_count += 1
        payload = pack_upstream(frame)
        last_timeout: BaseException | None = None
        request_id = self._next_request_id()

        for attempt in range(1, self.max_retries + 1):
            self.stats.sent_count += 1
            t0 = time.perf_counter()
            self._sock.sendto(payload, (self.host, self.port))
            try:
                raw, _ = self._sock.recvfrom(2048)
                try:
                    response = unpack_downstream(raw)
                except ProtocolError as exc:
                    self.stats.protocol_error_count += 1
                    if "CRC mismatch" in str(exc):
                        self.stats.crc_error_count += 1
                        self._log_attempt(
                            request_id=request_id,
                            frame=frame,
                            attempt=attempt,
                            status="error",
                            error_code="RESP_CRC_MISMATCH",
                            rtt_ms=(time.perf_counter() - t0) * 1000.0,
                        )
                    else:
                        self._log_attempt(
                            request_id=request_id,
                            frame=frame,
                            attempt=attempt,
                            status="error",
                            error_code="RESP_PROTOCOL_ERROR",
                            rtt_ms=(time.perf_counter() - t0) * 1000.0,
                        )
                    raise
                elapsed_ms = (time.perf_counter() - t0) * 1000.0
                self.stats.add_rtt(elapsed_ms)
                self.stats.received_count += 1
                self._log_attempt(
                    request_id=request_id,
                    frame=frame,
                    attempt=attempt,
                    status="ok",
                    error_code="OK",
                    rtt_ms=elapsed_ms,
                )
                return response
            except (socket.timeout, ConnectionResetError) as exc:
                self.stats.timeout_count += 1
                last_timeout = exc
                self._log_attempt(
                    request_id=request_id,
                    frame=frame,
                    attempt=attempt,
                    status="error",
                    error_code="TIMEOUT",
                    rtt_ms=(time.perf_counter() - t0) * 1000.0,
                )

        raise TransportTimeoutError(
            f"timeout after {self.max_retries} attempts to {self.host}:{self.port}"
        ) from last_timeout
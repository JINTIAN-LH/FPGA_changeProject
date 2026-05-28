"""UDP transport with retry and lightweight link statistics."""

from __future__ import annotations

from dataclasses import dataclass
import socket

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


class UdpTransport:
    def __init__(
        self,
        host: str,
        port: int,
        timeout_seconds: float = 1.0,
        max_retries: int = 3,
        bind_host: str = "",
        bind_port: int = 0,
    ) -> None:
        self.host = host
        self.port = port
        self.timeout_seconds = timeout_seconds
        self.max_retries = max_retries
        self.stats = TransportStats()
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._sock.bind((bind_host, bind_port))
        self._sock.settimeout(timeout_seconds)

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

        for _ in range(self.max_retries):
            self.stats.sent_count += 1
            self._sock.sendto(payload, (self.host, self.port))
            try:
                raw, _ = self._sock.recvfrom(2048)
                try:
                    response = unpack_downstream(raw)
                except ProtocolError as exc:
                    self.stats.protocol_error_count += 1
                    if "CRC mismatch" in str(exc):
                        self.stats.crc_error_count += 1
                    raise
                self.stats.received_count += 1
                return response
            except (socket.timeout, ConnectionResetError) as exc:
                self.stats.timeout_count += 1
                last_timeout = exc

        raise TransportTimeoutError(
            f"timeout after {self.max_retries} attempts to {self.host}:{self.port}"
        ) from last_timeout
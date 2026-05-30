import socket
import threading
import tempfile
import time
import unittest
import json

from fpga_protocol import DownstreamFrame, UpstreamFrame, pack_downstream


class UdpTransportTests(unittest.TestCase):
    def test_request_response_updates_stats(self):
        from udp_transport import UdpTransport

        host = "127.0.0.1"
        port = 19001

        def server():
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.bind((host, port))
            raw, addr = sock.recvfrom(2048)
            self.assertGreater(len(raw), 0)
            rsp = DownstreamFrame(
                stock_code="000858SZ",
                timestamp=1717000000,
                ma5=10.0,
                ma10=10.1,
                rsi6=35.0,
                rsi14=40.0,
                trade_signal=1,
                signal_strength=70,
            )
            sock.sendto(pack_downstream(rsp), addr)
            sock.close()

        th = threading.Thread(target=server, daemon=True)
        th.start()
        time.sleep(0.05)

        transport = UdpTransport(host=host, port=port, timeout_seconds=0.5, max_retries=2)
        req = UpstreamFrame(
            stock_code="000858SZ",
            timestamp=1717000000,
            open=10.0,
            high=10.2,
            low=9.9,
            close=10.1,
            volume=100,
        )
        try:
            rsp = transport.request_response(req)

            self.assertEqual(rsp.trade_signal, 1)
            self.assertEqual(transport.stats.sent_count, 1)
            self.assertEqual(transport.stats.received_count, 1)
            self.assertEqual(transport.stats.timeout_count, 0)
            summary = transport.stats.summary()
            self.assertEqual(summary["rtt_count"], 1)
            self.assertGreaterEqual(summary["rtt_p50_ms"], 0.0)
            self.assertGreater(summary["success_rate"], 0.0)
        finally:
            transport.close()

    def test_timeout_retries_are_counted(self):
        from udp_transport import TransportTimeoutError, UdpTransport

        transport = UdpTransport(host="127.0.0.1", port=19002, timeout_seconds=0.05, max_retries=2)
        req = UpstreamFrame(
            stock_code="000858SZ",
            timestamp=1717000000,
            open=10.0,
            high=10.2,
            low=9.9,
            close=10.1,
            volume=100,
        )

        try:
            with self.assertRaises(TransportTimeoutError):
                transport.request_response(req)

            self.assertEqual(transport.stats.sent_count, 2)
            self.assertEqual(transport.stats.timeout_count, 2)
        finally:
            transport.close()

    def test_jsonl_log_written_for_timeout_attempts(self):
        from fpga_protocol import UpstreamFrame
        from udp_transport import TransportTimeoutError, UdpTransport

        with tempfile.TemporaryDirectory() as tmp:
            log_path = f"{tmp}\\link.jsonl"
            transport = UdpTransport(
                host="127.0.0.1",
                port=19999,
                timeout_seconds=0.05,
                max_retries=2,
                jsonl_log_path=log_path,
            )
            req = UpstreamFrame(
                stock_code="000858SZ",
                timestamp=1717000000,
                open=10.0,
                high=10.2,
                low=9.9,
                close=10.1,
                volume=100,
            )
            try:
                with self.assertRaises(TransportTimeoutError):
                    transport.request_response(req)
            finally:
                transport.close()

            with open(log_path, "r", encoding="utf-8") as f:
                lines = [json.loads(x) for x in f if x.strip()]

            self.assertEqual(len(lines), 2)
            self.assertEqual(lines[0]["error_code"], "TIMEOUT")
            self.assertEqual(lines[0]["attempt"], 1)
            self.assertEqual(lines[1]["attempt"], 2)

import socket
import threading
import time
import unittest

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

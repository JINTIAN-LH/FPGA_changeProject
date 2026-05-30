import socket
import threading
import time
import unittest

from fpga_protocol import UpstreamFrame, pack_upstream
from mock_fpga import serve


class MockFpgaBehaviorTests(unittest.TestCase):
    def test_mock_drops_malformed_frame(self):
        host = "127.0.0.1"
        port = 19101

        th = threading.Thread(target=serve, kwargs={"host": host, "port": port}, daemon=True)
        th.start()
        time.sleep(0.1)

        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(0.3)
        try:
            frame = UpstreamFrame(
                stock_code="000858SZ",
                timestamp=1717000000,
                open=10.0,
                high=10.2,
                low=9.9,
                close=10.1,
                volume=100,
            )
            bad = bytearray(pack_upstream(frame))
            bad[-1] ^= 0x01
            sock.sendto(bytes(bad), (host, port))

            with self.assertRaises(socket.timeout):
                sock.recvfrom(2048)
        finally:
            sock.close()


if __name__ == "__main__":
    unittest.main()

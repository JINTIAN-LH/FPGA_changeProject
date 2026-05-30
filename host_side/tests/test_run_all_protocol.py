import unittest


class RunAllProtocolTests(unittest.TestCase):
    def test_send_bars_to_fpga_validates_and_sends(self):
        from run_all import send_bars_to_fpga

        class FakeTransport:
            def __init__(self):
                self.sent = []

            def request_response(self, frame):
                self.sent.append(frame)
                return {"ok": True}

        bars = [
            {
                "time": "2026-05-28 09:31:00",
                "open": 10.0,
                "high": 10.2,
                "low": 9.9,
                "close": 10.1,
                "volume": 100,
            },
            {
                "time": "2026-05-28 09:32:00",
                "open": 10.1,
                "high": 10.3,
                "low": 10.0,
                "close": 10.2,
                "volume": 120,
            },
        ]

        transport = FakeTransport()
        results = send_bars_to_fpga("000858", bars, transport)

        self.assertEqual(len(transport.sent), 2)
        self.assertEqual(len(results), 2)
import unittest

from fpga_protocol import (
    DownstreamFrame,
    ProtocolError,
    UpstreamFrame,
    pack_downstream,
    pack_upstream,
    unpack_downstream,
    unpack_upstream,
)


class ProtocolTests(unittest.TestCase):
    def test_upstream_roundtrip(self):
        frame = UpstreamFrame(
            stock_code="000858SZ",
            timestamp=1_717_000_000,
            open=10.1,
            high=10.3,
            low=10.0,
            close=10.2,
            volume=123456,
        )
        raw = pack_upstream(frame)
        decoded = unpack_upstream(raw)
        self.assertEqual(decoded.stock_code, frame.stock_code)
        self.assertEqual(decoded.timestamp, frame.timestamp)
        self.assertEqual(decoded.volume, frame.volume)

    def test_downstream_roundtrip(self):
        frame = DownstreamFrame(
            stock_code="000858SZ",
            timestamp=1_717_000_000,
            ma5=10.2,
            ma10=10.1,
            rsi6=58.0,
            rsi14=62.0,
            trade_signal=1,
            signal_strength=80,
        )
        raw = pack_downstream(frame)
        decoded = unpack_downstream(raw)
        self.assertEqual(decoded.stock_code, frame.stock_code)
        self.assertEqual(decoded.trade_signal, frame.trade_signal)
        self.assertEqual(decoded.signal_strength, frame.signal_strength)

    def test_crc_failure(self):
        frame = UpstreamFrame(
            stock_code="000858SZ",
            timestamp=10,
            open=1.0,
            high=1.1,
            low=0.9,
            close=1.0,
            volume=10,
        )
        raw = bytearray(pack_upstream(frame))
        raw[5] ^= 0x01
        with self.assertRaises(ProtocolError):
            unpack_upstream(bytes(raw))


if __name__ == "__main__":
    unittest.main()

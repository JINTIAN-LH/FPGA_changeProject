import unittest


class ValidatorTests(unittest.TestCase):
    def test_valid_kline_passes(self):
        from data_validator import validate_kline_bar

        bar = {
            "time": "2026-05-28 09:31:00",
            "open": 10.12,
            "high": 10.30,
            "low": 10.01,
            "close": 10.20,
            "volume": 1000,
        }

        validated = validate_kline_bar(bar)
        self.assertEqual(validated["close"], 10.20)

    def test_invalid_price_order_fails(self):
        from data_validator import ValidationError, validate_kline_bar

        bad = {
            "time": "2026-05-28 09:31:00",
            "open": 10.12,
            "high": 9.99,
            "low": 10.01,
            "close": 10.20,
            "volume": 1000,
        }

        with self.assertRaises(ValidationError):
            validate_kline_bar(bad)

    def test_non_monotonic_sequence_fails(self):
        from data_validator import ValidationError, validate_kline_sequence

        bars = [
            {"time": "2026-05-28 09:32:00", "open": 10.1, "high": 10.2, "low": 10.0, "close": 10.1, "volume": 1},
            {"time": "2026-05-28 09:31:00", "open": 10.1, "high": 10.2, "low": 10.0, "close": 10.1, "volume": 1},
        ]

        with self.assertRaises(ValidationError):
            validate_kline_sequence(bars)
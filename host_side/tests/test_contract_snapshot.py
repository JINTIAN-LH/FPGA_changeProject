import json
import tempfile
import unittest
from pathlib import Path


class ContractSnapshotTests(unittest.TestCase):
    def test_contract_snapshot_can_be_exported(self):
        from fpga_protocol import export_contract_snapshot

        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "protocol_contract.json"
            export_contract_snapshot(target)

            payload = json.loads(target.read_text(encoding="utf-8"))
            self.assertEqual(payload["upstream"]["header"], "0xAA55")
            self.assertEqual(payload["upstream"]["length"], 48)
            self.assertEqual(payload["downstream"]["header"], "0x55AA")
            self.assertEqual(payload["downstream"]["fields"][0]["name"], "stock_code")
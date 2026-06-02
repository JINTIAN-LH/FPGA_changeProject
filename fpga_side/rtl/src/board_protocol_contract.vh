// Board-level protocol contract for MA703FA-100T bring-up.
//
// This header documents the interface boundary used by the board wrapper and
// the future real transport blocks.
//
// Host-side protocol facts already fixed in the repo:
// - Upstream frame: 48 bytes, big-endian, CRC32 at bytes 44..47
// - Downstream frame: 44 bytes, big-endian, CRC32 at bytes 40..43
// - ETHA is the first bring-up path; ETHB is expansion only until validated.
// - MA703FA variant used here has no dedicated external reset input; reset is
//   generated internally in RTL after power-up delay.
//
// Board-level signals are intentionally kept byte-oriented so the future MAC/UDP
// implementation can map directly to the existing Python protocol helpers.

// Market-feed ingress (host-fed) contract:
//   market_frame_valid   : host-side market frame is available
//   market_frame_ready   : board can accept the next host-fed frame
//   market_frame_data    : raw host frame bytes, protocol-defined in Python
//   market_frame_last    : end of one logical market frame
//
// Board-to-core mapping:
//   price_valid/open/high/low/close/volume/cfg_* are the decoded OHLCV/config
//   values consumed by `top`.

// Ethernet bridge contract:
//   m1_rx_*  : network-to-core stream (host/PHY -> board -> `m1_protocol_core`)
//   m1_tx_*  : core-to-network stream (`m1_protocol_core` -> board -> host/PHY)
//   eth_mdio/eth_mdc/eth_rst, etha_*, ethb_* : board pins / PHY management.
//
// Bring-up policy:
//   1) Validate ETHA link first.
//   2) Keep ETHB electrically constrained but logically idle until the first path is stable.

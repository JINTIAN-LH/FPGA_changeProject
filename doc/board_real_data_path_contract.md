# Board Real Data Path Contract

This note defines the smallest practical contract for the real board-side data path on MA703FA-100T.

## 1. Reset policy

- The target board variant does not rely on a dedicated external reset button.
- `top_board` uses an internal power-up reset generator.
- The reset released to downstream logic is `sys_rst_n` inside RTL, not a board pin.

## 2. Ingress path goal

The real network path is:

`RGMII PHY -> MAC -> UDP parser -> m1_rx_* -> m1_protocol_core`

The bridge is responsible for converting one valid UDP payload into the byte-stream expected by the current core.

## 3. Required byte-stream contract

### 3.1 Core input stream

- `m1_rx_valid`: byte is valid this cycle.
- `m1_rx_data[7:0]`: current payload byte.
- `m1_rx_last`: asserted on the final byte of one logical core frame.

### 3.2 Core backpressure

- `m1_tx_ready`: downstream accepts transmit bytes.
- `m1_tx_valid`, `m1_tx_data[7:0]`, `m1_tx_last`: core-to-network response stream.

### 3.3 Bridge behavior

- The bridge must not assert `m1_rx_valid` unless the full frame is verified enough to be forwarded.
- Malformed Ethernet, IP, or UDP frames must be dropped silently or counted internally.
- CRC or header failures must not be turned into core input bytes.

## 4. Real UDP payload mapping

### 4.1 Host-fed market ingress

The host-side upstream frame is already fixed in Python as:

- 48 bytes total
- big-endian
- CRC32 at bytes 44..47
- fields: stock code, timestamp, open, high, low, close, volume, reserved

The board ingress module should decode this payload and drive:

- `price_valid`
- `open_price`
- `high_price`
- `low_price`
- `close_price`
- `volume`
- `cfg_strong_buy`
- `cfg_buy`
- `cfg_neutral`
- `cfg_sell`
- `cfg_valid`

### 4.2 Downstream response

The core downstream byte stream through `m1_tx_*` is packaged to Ethernet/IPv4/UDP by `udp_tx_engine` and transmitted through RGMII TX on PHY-A.

## 5. Minimal implementation decomposition

To keep the design manageable, the real board-side transport should be split into these blocks:

1. `board_rgmii_mac_rx`
- Converts RGMII PHY signaling into a clean frame stream.

2. `board_udp_rx_parser`
- Validates UDP payloads and extracts the protocol frame.

3. `board_market_feed_ingress`
- Converts parsed host market frames into the `top` OHLCV/config inputs.

4. `board_m1_stream_bridge`
- Converts `m1_tx_*` / `m1_rx_*` to and from the UDP path.

## 6. Implemented transport blocks

The repository now contains a complete board transport chain:

- `rgmii_rx_sync` captures RGMII DDR RX into GMII-style byte stream.
- `mac_rx` strips preamble/SFD and emits Ethernet frame bytes.
- `ip_udp_parser` extracts UDP payload for configured destination port.
- `cdc_async_fifo` bridges RX payload into `sys_clk_50m` core domain.
- `market_frame_decoder` enforces 48-byte frame structure and CRC32 before `price_valid`.
- `mdio_init_fsm` drives PHY MDIO write sequence and reset release.
- `cdc_async_fifo` bridges `m1_tx_*` into PHY TX clock domain.
- `udp_tx_engine` builds Ethernet/IPv4/UDP response frames from `m1_tx_*`.
- `rgmii_tx_sync` serializes GMII TX bytes onto RGMII DDR TX pins.

## 7. Current implementation status (this repository)

The active end-to-end chain is:

`wire -> PHY-A -> RGMII RX -> MAC RX -> UDP parser -> core ingress`

and

`core egress -> UDP builder -> MAC TX bytes -> RGMII TX -> PHY-A -> wire`

Details:

1. `rgmii_rx_sync`
- Captures ETHA RGMII RX DDR nibbles into a GMII-style 8-bit stream.

2. `mac_rx`
- Forms frame byte stream from GMII RX and strips preamble/SFD before parser stage.

3. `ip_udp_parser`
- Filters IPv4/UDP frames and extracts UDP payload for configured destination port.

4. `board_eth_bridge`
- Routes extracted UDP payload into async FIFO and fans out to both `m1_rx_*` and `board_market_feed_ingress` decoder input in system clock domain.

5. `market_frame_decoder` + `board_market_feed_ingress`
- Decodes only CRC32-verified 48-byte market frame into `price_valid/open/high/low/close/volume` signals.

6. `mdio_init_fsm`
- Performs startup PHY reset and MDIO register-write initialization.

7. `udp_tx_engine` + `rgmii_tx_sync`
- Converts `m1_tx_*` stream into response UDP frames and drives PHY-A RGMII TX.

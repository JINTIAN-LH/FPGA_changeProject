# board_real.xdc
# Pure XDC only. No Tcl procedures or control flow.
# Top-level for programming is top_board.

# Device configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Board clock
set_property PACKAGE_PIN V4 [get_ports sys_clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk_50m]
create_clock -name sys_clk_50m -period 20.000 -waveform {0.000 10.000} [get_ports sys_clk_50m]

# PHY management
set_property PACKAGE_PIN N17 [get_ports eth_mdio]
set_property IOSTANDARD LVCMOS33 [get_ports eth_mdio]
set_property PACKAGE_PIN U18 [get_ports eth_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports eth_mdc]
set_property PACKAGE_PIN U17 [get_ports eth_rst]
set_property IOSTANDARD LVCMOS33 [get_ports eth_rst]

# PHY-A (ETHA)
set_property PACKAGE_PIN W19 [get_ports etha_rxck]
set_property IOSTANDARD LVCMOS33 [get_ports etha_rxck]
create_clock -name etha_rxck -period 8.000 -waveform {0.000 4.000} [get_ports etha_rxck]

set_property PACKAGE_PIN V18 [get_ports etha_rxctl]
set_property IOSTANDARD LVCMOS33 [get_ports etha_rxctl]
set_property PACKAGE_PIN V19 [get_ports etha_rxd0]
set_property IOSTANDARD LVCMOS33 [get_ports etha_rxd0]
set_property PACKAGE_PIN W20 [get_ports etha_rxd1]
set_property IOSTANDARD LVCMOS33 [get_ports etha_rxd1]
set_property PACKAGE_PIN AA20 [get_ports etha_rxd2]
set_property IOSTANDARD LVCMOS33 [get_ports etha_rxd2]
set_property PACKAGE_PIN AA21 [get_ports etha_rxd3]
set_property IOSTANDARD LVCMOS33 [get_ports etha_rxd3]

set_property PACKAGE_PIN AB21 [get_ports etha_txck]
set_property IOSTANDARD LVCMOS33 [get_ports etha_txck]
set_property PACKAGE_PIN AB22 [get_ports etha_txctl]
set_property IOSTANDARD LVCMOS33 [get_ports etha_txctl]
set_property PACKAGE_PIN W21 [get_ports etha_txd0]
set_property IOSTANDARD LVCMOS33 [get_ports etha_txd0]
set_property PACKAGE_PIN W22 [get_ports etha_txd1]
set_property IOSTANDARD LVCMOS33 [get_ports etha_txd1]
set_property PACKAGE_PIN Y21 [get_ports etha_txd2]
set_property IOSTANDARD LVCMOS33 [get_ports etha_txd2]
set_property PACKAGE_PIN Y22 [get_ports etha_txd3]
set_property IOSTANDARD LVCMOS33 [get_ports etha_txd3]

# PHY-B (ETHB)
set_property PACKAGE_PIN Y18 [get_ports ethb_rxck]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_rxck]
create_clock -name ethb_rxck -period 8.000 -waveform {0.000 4.000} [get_ports ethb_rxck]

set_property PACKAGE_PIN P17 [get_ports ethb_rxctl]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_rxctl]
set_property PACKAGE_PIN R18 [get_ports ethb_rxd0]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_rxd0]
set_property PACKAGE_PIN V22 [get_ports ethb_rxd1]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_rxd1]
set_property PACKAGE_PIN U22 [get_ports ethb_rxd2]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_rxd2]
set_property PACKAGE_PIN U21 [get_ports ethb_rxd3]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_rxd3]

set_property PACKAGE_PIN T21 [get_ports ethb_txck]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_txck]
set_property PACKAGE_PIN R19 [get_ports ethb_txctl]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_txctl]
set_property PACKAGE_PIN P19 [get_ports ethb_txd0]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_txd0]
set_property PACKAGE_PIN V20 [get_ports ethb_txd1]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_txd1]
set_property PACKAGE_PIN U20 [get_ports ethb_txd2]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_txd2]
set_property PACKAGE_PIN T18 [get_ports ethb_txd3]
set_property IOSTANDARD LVCMOS33 [get_ports ethb_txd3]

# Separate clock groups for asynchronous domains.
set_clock_groups -asynchronous -group [get_clocks sys_clk_50m] -group [get_clocks etha_rxck]
set_clock_groups -asynchronous -group [get_clocks sys_clk_50m] -group [get_clocks ethb_rxck]

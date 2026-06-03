# MA703FA 板级约束整理表（首版）

> 目标：为 `fpga_side/rtl/constraints/board_real.xdc` 提供可追溯来源。
>
> 说明：本表基于以下 5 份官方 PDF 的文本提取结果，属于“可落地草案”，上板前需对照丝印与原理图再复核一轮。

## 1. 资料来源

1. `A703-100T/01_user_start/01_user_start/03_Vivado程序下载及固化/下载测试及程序固化.pdf`
2. `A703-100T/02_hardware/MA703FA_100T_HW/MA703FA_100T_HW/01_硬件手册/Artix-7 MA703FA-100T 开发板硬件使用手册20190321_V1.0.pdf`
3. `A703-100T/02_hardware/MA703FA_100T_HW/MA703FA_100T_HW/01_硬件手册/Artix-7 MA703FA-100T 核心板硬件使用手册20190321v1.0 .pdf`
4. `A703-100T/02_hardware/MA703FA_100T_HW/MA703FA_100T_HW/02_原理图/MA703FA20190822.pdf`
5. `A703-100T/02_hardware/MA703FA_100T_HW/MA703FA_100T_HW/02_原理图/MA_703CORE20190401.pdf`

补充提取记录：
- `reports/pdf_constraints_extraction_raw.md`
- `reports/pdf_constraints_key_lines.md`
- `reports/manual_page10_qspi.txt`
- `reports/manual_page12_clock.txt`
- `reports/manual_page20_eth.txt`

## 2. 约束信息整理（时钟 / 复位 / PHY / Bank-Pin）

### 2.1 时钟

| 逻辑信号 | FPGA Pin | 约束建议 | 来源 | 置信度 |
|---|---|---|---|---|
| `sys_clk_50m` | `V4` | `create_clock -period 20.000` | 开发板硬件手册，表 5-3-1-1（提取页：手册第 12 页文本） | 高 |
| `FLASH_CLK` | `L12` | 若使用 QSPI 需绑定该管脚 | 开发板硬件手册，表 5-2-2-2（提取页：手册第 10 页文本） | 中 |
| `MGT216_CLK1_P/N` | `F10/E10` | 仅 MGT/高速链路需要 | 开发板硬件手册，表 5-3-2-1（提取页：手册第 12 页文本） | 中 |

### 2.2 复位

| 信号 | FPGA Pin | 约束建议 | 来源 | 置信度 |
|---|---|---|---|---|
| `ETH_RST` | `U17` | 作为 PHY 复位输出管脚约束 | 开发板硬件手册，表 5-9-1/5-9-2；原理图提取页 2/5/6/8 | 高 |
| `sys_rst_n` | 待确认 | 先用占位符，待按板卡按键/系统复位网络复核 | 原理图中出现 `RST_N12`、`RST 9` 等文本，但无法仅靠抽取文本唯一映射到当前顶层端口 | 低 |

### 2.3 千兆以太网 PHY（RTL8211FD）

PHY 型号证据：开发板硬件手册第 19 页（文本提取命中：`RTL8211FD`）。

#### PHY-A（PL_LANA）

| 信号 | FPGA Pin |
|---|---|
| `ETHA_RXCK` | `W19` |
| `ETHA_RXCTL` | `V18` |
| `ETHA_RXD0` | `V19` |
| `ETHA_RXD1` | `W20` |
| `ETHA_RXD2` | `AA20` |
| `ETHA_RXD3` | `AA21` |
| `ETHA_TXCK` | `AB21` |
| `ETHA_TXCTL` | `AB22` |
| `ETHA_TXD0` | `W21` |
| `ETHA_TXD1` | `W22` |
| `ETHA_TXD2` | `Y21` |
| `ETHA_TXD3` | `Y22` |
| `ETH_MDIO` | `N17` |
| `ETH_MDC` | `U18` |
| `ETH_RST` | `U17` |

来源：开发板硬件手册第 20 页（表 5-9-1）。

#### PHY-B（PL_LANB）

| 信号 | FPGA Pin |
|---|---|
| `ETHB_RXCK` | `Y18` |
| `ETHB_RXCTL` | `P17` |
| `ETHB_RXD0` | `R18` |
| `ETHB_RXD1` | `V22` |
| `ETHB_RXD2` | `U22` |
| `ETHB_RXD3` | `U21` |
| `ETHB_TXCK` | `T21` |
| `ETHB_TXCTL` | `R19` |
| `ETHB_TXD0` | `P19` |
| `ETHB_TXD1` | `V20` |
| `ETHB_TXD2` | `U20` |
| `ETHB_TXD3` | `T18` |
| `ETH_MDIO` | `N17` |
| `ETH_MDC` | `U18` |
| `ETH_RST` | `U17` |

来源：开发板硬件手册第 20 页（表 5-9-2）。

### 2.4 Bank / Pin 映射线索

| 信息 | 来源 | 用途 |
|---|---|---|
| `BANK13/14/15/16/0/216` 分布线索 | 核心板原理图 `MA_703CORE20190401.pdf`（提取页 1/3/4/5/6） | 判定管脚电压域与布线分区 |
| 差分命名示例 `B15_L1_P/B15_L1_N` | 原理图 `MA703FA20190822.pdf`（提取页 2） | 校验差分对命名与 bank 对应 |
| `FPGA Pin` 格式示例 `H13` | 原理图 `MA703FA20190822.pdf`（提取页 2） | 核对 XDC `PACKAGE_PIN` 写法 |

## 3. 可直接落地与待复核项

### 3.1 可直接落地

1. `sys_clk_50m -> V4` 及 50MHz 时钟约束。
2. `ETH_MDIO -> N17`、`ETH_MDC -> U18`、`ETH_RST -> U17`。
3. PHY-A/PHY-B 的 RGMII 数据与时钟管脚映射。

### 3.2 待复核（上板前必须）

1. `sys_rst_n` 对应的真实板级复位输入管脚（当前仅有候选文本 `RST_N12`）。
2. 以太网 IO 的 `IOSTANDARD` 仍要按最终 bank/VCCIO 再核对，但现有手册和原理图都指向 3.3V 供电域，当前草案优先按 `LVCMOS33` 处理。
3. 是否启用双网口：文档证明 ETHA/ETHB 都存在，但当前工程建议先只启用 ETHA，ETHB 作为后续扩展，减少首板风险。
4. 当前 `top.v` 以算法/协议信号为主，未直接暴露板级 RGMII 端口；若要直接上板，建议新增 `top_board` 封装统一板级 IO 命名。

## 4. 外部草案筛选结论：保留哪些，丢弃哪些

### 4.1 建议保留

1. `sys_clk_50m -> V4`，必须保留。
2. `ETH_MDIO -> N17`、`ETH_MDC -> U18`、`ETH_RST -> U17`，作为千兆 PHY 公共管理信号保留。
3. PHY-A/PHY-B 的 RGMII 时钟与数据脚位，作为板级 Ethernet bring-up 参考保留；首板优先只接 ETHA。
4. `FLASH_CLK -> L12`，作为 QSPI 固化/配置参考保留。
5. `BANK13/14/15/16/0/216` 的分区结论保留，用于判断 IO 电压域。

### 4.2 建议丢弃或暂不放入当前正式 xdc

1. `LED`、`KEY`、`UART`：当前 `top.v` 没有这些板级端口，直接写进 xdc 会制造“看起来完整、其实不生效”的假象。
2. `DDR3`：必须走 MIG IP 和独立板级封装，不应和当前算法/协议顶层混写。
3. `clk_50m`、`led[0]`、`key[0]`、`uart_txd` 等命名：这是一套不同顶层命名，不能直接套到当前工程，必须先统一端口名。
4. “一份 xdc 覆盖所有模块”的思路：对当前工程不合适。应采用“当前顶层可用约束 + 后续板级封装扩展”的方式。

## 5. 输出文件

- 约束草案：`fpga_side/rtl/constraints/board_real.xdc`

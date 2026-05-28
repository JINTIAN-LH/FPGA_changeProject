# MA703FA FPGA 股票高速交易项目 · 小白百科全书

## 第一章 · MA703FA 开发板全貌

### 1.1 板卡核心参数

| 参数 | 规格 |
|---|---|
| FPGA 芯片 | Xilinx Artix-7 XC7A100T-2FGG484I（100T，逻辑资源约 101K Logic Cells） |
| 光口 | 1 路 SFP 笼子（支持千兆 1.25Gbps / 万兆 10.3125Gbps 光模块） |
| 以太网 | 1 路千兆 RJ45（RTL8211E PHY，走 GMII/RGMII） |
| 内存 | 2 片 DDR3（各 256MB，共 512MB，16bit 位宽） |
| 时钟 | 板上 50MHz 有源晶振 + SFP 专用 125MHz 差分时钟 |
| 配置 | QSPI Flash（用于固化比特流）、JTAG 下载口 |
| USB-UART | CP2102，用于 FPGA 串口调试打印 |
| 扩展 IO | 2.54mm 排针，若干 LED/按键 |

SFP 光口走的是 FPGA 的 GTP（Gigabit Transceiver）高速串行收发器，这是整个项目的硬件核心通路。

### 1.2 为什么选 MA703FA

- GTP 硬核直接驱动 SFP，不需要外挂 PHY 芯片。
- A7 100T 逻辑资源足以容纳 UDP 协议栈 + 多路技术指标并行运算。
- 米联客提供基础例程（千兆以太网、GTP 回环测试等）。
- 价格在毕业设计可承受范围内。

---

## 第二章 · 开发工具链安装清单

### 2.1 必备软件

| 软件 | 版本建议 | 用途 | 安装注意 |
|---|---|---|---|
| Vivado | 2019.1 或 2020.2 | FPGA 综合/实现/下载 | 需 100GB+ 磁盘，安装 Artix-7 器件库 |
| Modelsim | 2020.4 或 Questa 2021+ | 功能仿真 | 独立安装版，需 license |
| VS Code | 最新版 | Verilog/Python 编码 | 安装 Verilog、Python 插件 |
| Python | 3.9+ | 上位机开发 | 安装 akshare、fastapi、numpy、pandas |
| Wireshark | 最新版 | 网络抓包调试 | 调试 UDP 协议格式 |
| 串口助手 | SecureCRT / MobaXterm | 查看 FPGA 调试输出 | - |

### 2.2 Python 依赖

```bash
pip install fastapi uvicorn akshare pandas numpy pyserial requests websockets
```

---

## 第三章 · 系统架构总览

```text
┌─────────────────────────────────────────────────────┐
│                  上位机 (PC/Linux)                  │
│                                                     │
│  akshare ──→ 数据采集 ──→ 清洗/规整 ──→ UDP封包    │
│                                          │          │
│                                    SFP光口网卡      │
│                                          │          │
└──────────────────────────────────────────┼──────────┘
                                           │ 光纤
                                           │
┌──────────────────────────────────────────┼──────────┐
│              MA703FA FPGA 板             │          │
│                                          │          │
│  SFP光口 ──→ GTP RX ──→ MAC解析 ──→ IP/UDP解析     │
│                                          │          │
│                     ┌────────────────────┤          │
│                     ↓                    ↓          │
│            技术指标并行运算        评分/决策逻辑      │
│          (MA/RSI/MACD/BOLL/ATR)         │          │
│                     │                    │          │
│                     └────────┬───────────┘          │
│                              ↓                      │
│                    UDP封包 ──→ GTP TX ──→ SFP光口   │
│                                          │          │
└──────────────────────────────────────────┼──────────┘
                                           │ 光纤
                                           ↓
                                   上位机接收/展示
```

数据流路径：

1. 上位机从 akshare 获取行情 -> 清洗 -> 封包 -> SFP 光口发送。
2. FPGA SFP 光口接收 -> GTP 解串 -> MAC/IP/UDP 协议解包 -> 提取 K 线数据。
3. FPGA 并行计算技术指标 -> 评分决策 -> 结果封包。
4. FPGA SFP 光口回传 -> 上位机接收解析 -> 可视化展示/比对。

---

## 第四章 · 分角色详细技术路线（含学习路线）

### 组员 1 · 上位机数据采集与预处理

你需要掌握：Python 基础 -> FastAPI -> akshare API -> pandas 数据处理

学习路线（2 周）：

1. Python 基础语法速成（列表、字典、函数、类、文件读写）。
2. 阅读 akshare 文档，跑通 `stock_zh_a_hist()` 获取 A 股日 K。
3. pandas DataFrame 操作：`dropna()`、`drop_duplicates()`、`astype()`、`to_dict()`。
4. FastAPI 入门：写一个 `/api/stock/{code}` 的 GET 接口返回 JSON。
5. JWT Token 鉴权：`pip install python-jose`，增加简单 Bearer Token 验证。

核心代码骨架：

```python
# collector.py
import akshare as ak
import pandas as pd


def fetch_stock_data(symbol: str, market: str, start_date: str, end_date: str) -> dict:
    """统一入口：根据品种和市场获取历史K线"""
    if market == "A":
        df = ak.stock_zh_a_hist(symbol=symbol, period="daily",
                                start_date=start_date, end_date=end_date, adjust="qfq")
    elif market == "HK":
        df = ak.stock_hk_hist(symbol=symbol, period="daily",
                              start_date=start_date, end_date=end_date, adjust="qfq")
    elif market == "US":
        df = ak.stock_us_hist(symbol=symbol, period="daily",
                              start_date=start_date, end_date=end_date, adjust="qfq")
    else:
        raise ValueError(f"Unsupported market: {market}")

    df = standardize_columns(df)
    df = df.drop_duplicates(subset=["日期"]).dropna()
    df["日期"] = pd.to_datetime(df["日期"]).dt.strftime("%Y%m%d")

    for col in ["开盘", "最高", "最低", "收盘", "成交量"]:
        df[col] = df[col].astype(float)

    return df.to_dict(orient="records")
```

关键点：

- 输出字段名和数据类型必须与组员 2 的通信协议文档严格一致。
- 建议输出格式：

```json
{"code":"000001", "market":"A", "date":"20250101", "open":10.50, "high":10.80, "low":10.30, "close":10.60, "volume":12345678}
```

### 组员 2 · SFP 光口 UDP 通信协议与封包解包

你需要掌握：Python socket 编程 -> 二进制打包（struct）-> 网络基础

学习路线（2 周）：

1. 计算机网络基础：IP/UDP/以太网帧结构。
2. Python socket：`socket(AF_INET, SOCK_DGRAM)`。
3. Python struct：`pack()` / `unpack()`。
4. 安装 SFP 光口网卡（推荐 Intel X520-DA2 或 Mellanox ConnectX-3）。
5. 配通 PC 光口与 FPGA 光口的二层直连（同网段即可）。

自定义协议格式建议：

```text
┌──────────┬──────────┬──────────┬──────────┬──────────────┬──────────┬──────────┐
│ 帧头     │ 长度     │ 包序号   │ 股票代码 │ K线数据域     │ 校验和   │ 帧尾     │
│ 2 Bytes  │ 2 Bytes  │ 2 Bytes  │ 10 Bytes │ N×4 Bytes     │ 2 Bytes  │ 2 Bytes  │
│ 0xEB90   │          │          │          │              │ CRC16    │ 0x90EB   │
└──────────┴──────────┴──────────┴──────────┴──────────────┴──────────┴──────────┘
```

K 线数据域（固定 8 个字段，每个 4 字节）：

- `open(4B)` + `high(4B)` + `low(4B)` + `close(4B)` + `volume(4B)` + `date(4B uint32)` + `market(4B)` + `reserved(4B)`
- 共 `32 Bytes`

回传数据域：

- `score(4B float)` + `ma5(4B)` + `ma20(4B)` + `rsi(4B)` + `macd(4B)` + `signal(4B float)`
- `upper_band(4B)` + `lower_band(4B)` + `atr(4B)` + `vol_ratio(4B)` + `decision(1B)` + `reserved(3B)`
- 共 `44 Bytes`

核心代码骨架：

```python
# sfp_udp_client.py
import socket
import struct

FRAME_HEADER = 0xEB90
FRAME_FOOTER = 0x90EB
FPGA_IP = "192.168.10.2"
FPGA_PORT = 8888
PC_IP = "192.168.10.1"
PC_PORT = 8889


def pack_kline_data(stock_code: str, kline: dict, seq: int) -> bytes:
    """将一条K线封装成UDP包"""
    code_bytes = stock_code.encode("utf-8").ljust(10, b'\x00')
    payload = struct.pack(
        ">H H H 10s f f f f f I I I",
        FRAME_HEADER,
        0,
        seq,
        code_bytes,
        kline["open"],
        kline["high"],
        kline["low"],
        kline["close"],
        kline["volume"],
        int(kline["date"]),
        0,
        0,
    )

    payload = payload[:2] + struct.pack(">H", len(payload)) + payload[4:]

    crc = crc16(payload[:-4])
    payload = payload[:-4] + struct.pack(">H", crc) + struct.pack(">H", FRAME_FOOTER)
    return payload


def send_to_fpga(data: bytes):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((PC_IP, PC_PORT))
    sock.sendto(data, (FPGA_IP, FPGA_PORT))
    resp, _ = sock.recvfrom(2048)
    return unpack_response(resp)
```

PC 光口网卡配置：

```text
IP: 192.168.10.1
子网掩码: 255.255.255.0
网关: 不填
MTU: 1500
```

### 组员 3 · FPGA 基础工程与 SFP 底层驱动

你需要掌握：Vivado 工程创建 -> Verilog 基础 -> Clock Wizard -> GTP IP 核配置

学习路线（3 周）：

1. Vivado 基本流程：建工程、加源码、综合、实现、生成比特流、烧录。
2. Verilog 基础：模块、端口、`always`、`assign`、`wire/reg`。
3. 阅读 MA703FA 原理图，确认 SFP 到 GTP 引脚映射。
4. Vivado `7 Series FPGAs Transceivers Wizard (GTP)` 配置 SFP。
5. `Clocking Wizard` 配置系统时钟。

MA703FA SFP 引脚映射（关键信息）：

```text
SFP_TX_P  -> GTP_X0Y0 TXP (具体通道号需查原理图)
SFP_TX_N  -> GTP_X0Y0 TXN
SFP_RX_P  -> GTP_X0Y0 RXP
SFP_RX_N  -> GTP_X0Y0 RXN
SFP_TX_DISABLE -> FPGA GPIO
SFP_LOS        -> FPGA GPIO
```

GTP IP 核关键配置参数：

| 参数 | 值 | 说明 |
|---|---|---|
| Line Rate | 1.25 Gbps（千兆） | 与光模块速率匹配 |
| Reference Clock | 125 MHz | 板载差分时钟 |
| Data Width | 16-bit（内部） | GTP 内部位宽 |
| Encoding | 8b/10b | 线路编码 |
| RX Termination | Programmable | 按板卡设计 |

FPGA 顶层模块框架：

```verilog
// top.v
module top(
    input  wire       sys_clk_50m,
    input  wire       sys_rst_n,

    input  wire       sfp_rx_p,
    input  wire       sfp_rx_n,
    output wire       sfp_tx_p,
    output wire       sfp_tx_n,

    output wire       sfp_tx_disable,
    input  wire       sfp_los,

    output wire       uart_txd,
    output wire [3:0] led
);

    wire clk_125m, clk_200m, locked;
    clk_wiz_0 u_clk_wiz (
        .clk_in1 (sys_clk_50m),
        .clk_out1(clk_125m),
        .clk_out2(clk_200m),
        .locked  (locked)
    );

    // GTP 收发器包装层
    // ...

    // 各子模块统一在这里例化
    // ...
endmodule
```

### 组员 4 · FPGA UDP/IP 协议解析模块

你需要掌握：Verilog 状态机 -> 以太网帧格式 -> UDP/IP 协议栈

学习路线（3 周）：

1. 以太网帧格式：前导码 + SFD + MAC 头 + Type + IP 载荷 + CRC。
2. IP 头（20 字节）和 UDP 头（8 字节）字段。
3. 编写逐层剥离头部的状态机。
4. 引入 FIFO 进行跨时钟域传输。

协议解析状态机（简化）：

```verilog
// eth_udp_parser.v
localparam IDLE       = 4'd0;
localparam ETH_HEADER = 4'd1;
localparam IP_HEADER  = 4'd2;
localparam UDP_HEADER = 4'd3;
localparam PAYLOAD    = 4'd4;
localparam CHECK_FCS  = 4'd5;

reg [3:0] state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                // 检测前导码 -> ETH_HEADER
            end
            ETH_HEADER: begin
                // 校验 Type == 0x0800
            end
            IP_HEADER: begin
                // 校验 Protocol == 17 (UDP)
            end
            UDP_HEADER: begin
                // 提取源/目的端口
            end
            PAYLOAD: begin
                // 写下游 FIFO
            end
            CHECK_FCS: begin
                // CRC32 校验
            end
        endcase
    end
end
```

跨时钟域 FIFO（关键点）：

```text
Vivado FIFO Generator:
- Independent Clocks Block RAM
- 写时钟: gtp_clk (125MHz)
- 读时钟: user_clk (200MHz)
- 位宽: 8bit / 16bit
- 深度: 2048
```

### 组员 5 · FPGA 技术指标硬件并行运算

你需要掌握：定点数运算 -> 流水线设计 -> 技术指标公式

学习路线（3 周）：

1. 先用 Python 完整实现并验证每个指标。
2. 设计定点格式：Q16.16。
3. 学习流水线拆分时序关键路径。
4. 用 Verilog 逐项实现指标。

Q16.16 定点说明：

```text
32-bit Q16.16:
[31]    符号位
[30:16] 整数部分
[15:0]  小数部分

float 10.5  -> 10.5 * 65536 = 688128 = 0x000A8000
float -3.25 -> -3.25 * 65536 = -212992 = 0xFFFC_C000

乘法: (a * b) >>> 16
加法: a + b
```

技术指标实现要点：

| 指标 | 核心运算 | FPGA 实现方案 |
|---|---|---|
| MA5/MA20/MA60 | 滑动平均 | 移位寄存器 + 累加器 + 乘倒数 |
| EMA | 指数加权 | `EMA_today = α*Price + (1-α)*EMA_prev` |
| RSI(14) | RS 比值 | 涨跌幅累加 + 除法 |
| MACD | DIF/DEA/BAR | EMA12/EMA26/EMA9 级联 |
| BOLL(20,2) | 均线和方差 | 均值 + 标准差（可用 CORDIC） |
| ATR(14) | TR 极值 | `TR=max(H-L, abs(H-C_prev), abs(L-C_prev))` |
| 成交量比 | Vol/Vol_ma5 | 均线 + 除法 |

流水线示例（MA5）：

```verilog
// ma5_calc.v
reg [31:0] close_buf [0:4];
reg [31:0] sum;
wire [31:0] ma5;
wire [31:0] inv5 = 32'd13107; // 0.2 in Q16.16

always @(posedge clk) begin
    close_buf[4] <= close_buf[3];
    close_buf[3] <= close_buf[2];
    close_buf[2] <= close_buf[1];
    close_buf[1] <= close_buf[0];
    close_buf[0] <= close_in;
end

always @(posedge clk) begin
    sum <= close_buf[0] + close_buf[1] + close_buf[2] + close_buf[3] + close_buf[4];
end

mult_gen_0 u_mult (.A(sum), .B(inv5), .P(ma5_temp));
assign ma5 = ma5_temp[47:16];
```

### 组员 6 · FPGA 评分决策与结果回传

你需要掌握：比较器逻辑 -> 状态机 -> UDP 发送模块

学习路线（2 周）：

1. 完整梳理 Python 评分逻辑分支。
2. 用 Verilog 实现分段打分。
3. UDP 发送模块与接收模块做镜像逆过程。

评分逻辑骨架：

```verilog
// score_calc.v
reg [7:0] score;
reg [2:0] decision;

always @(posedge clk) begin
    score <= 8'd0;

    if (ma5 > ma20 && ma20 > ma60)
        score <= score + 8'd30;
    else if (ma5 < ma20 && ma20 < ma60)
        score <= score + 8'd0;
    else if (ma5 > ma20)
        score <= score + 8'd15;
    else
        score <= score + 8'd10;

    if (rsi >= 30 && rsi <= 70)
        score <= score + 8'd25;
    else if (rsi < 30)
        score <= score + 8'd15;
    else if (rsi > 70)
        score <= score + 8'd5;

    if (dif > dea && dif_prev <= dea_prev)
        score <= score + 8'd25;
    else if (dif < dea && dif_prev >= dea_prev)
        score <= score + 8'd0;
    else if (dif > dea)
        score <= score + 8'd15;
    else
        score <= score + 8'd10;

    if (vol_ratio > 32'd98304)
        score <= score + 8'd20;
    else if (vol_ratio > 32'd65536)
        score <= score + 8'd10;
    else
        score <= score + 8'd5;

    if (score >= 70)
        decision <= 3'd4;
    else if (score >= 55)
        decision <= 3'd3;
    else if (score >= 40)
        decision <= 3'd2;
    else if (score >= 25)
        decision <= 3'd1;
    else
        decision <= 3'd0;
end
```

UDP 发送模块（逆封装过程）：

```verilog
// udp_tx.v
localparam TX_IDLE = 0, TX_PREAMBLE = 1, TX_MAC = 2, TX_IP = 3,
           TX_UDP = 4, TX_PAYLOAD = 5, TX_CRC = 6, TX_IFG = 7;

// 回传包格式：MAC(14B)+IP(20B)+UDP(8B)+数据(44B)+CRC(4B)=90B
```

### 组员 7 · FPGA 顶层整合与全系统联调

你需要掌握：Vivado 高级功能 -> 时序约束 -> ILA 调试

学习路线（3 周）：

1. 深入掌握综合/实现流程。
2. 学习时序约束：`create_clock`、`set_input_delay`、`set_output_delay`、`set_false_path`。
3. 使用 ILA 抓内部关键信号。
4. 阅读时序报告，关注 WNS/TNS。

顶层整合示例：

```verilog
// top_integrated.v
module top_integrated(
    input  wire       sys_clk_50m,
    input  wire       sys_rst_n,
    input  wire       sfp_rx_p, sfp_rx_n,
    output wire       sfp_tx_p, sfp_tx_n,
    output wire       sfp_tx_disable,
    input  wire       sfp_los,
    output wire       uart_txd,
    output wire [3:0] led
);

    wire clk_125m, clk_200m, clk_locked;
    // ...

    wire [15:0] gtp_rx_data, gtp_tx_data;
    wire        gtp_rx_valid, gtp_tx_ready;
    // ...

    wire [31:0] parsed_open, parsed_high, parsed_low, parsed_close, parsed_volume;
    wire        parsed_valid;
    eth_udp_parser u_parser(
        .clk(clk_200m), .rst_n(clk_locked),
        .rx_data(gtp_rx_data), .rx_valid(gtp_rx_valid),
        .open(parsed_open), .high(parsed_high), .low(parsed_low),
        .close(parsed_close), .volume(parsed_volume),
        .data_valid(parsed_valid)
    );

    wire [31:0] ma5, ma20, ma60, rsi, macd_dif, macd_dea;
    wire [31:0] boll_upper, boll_lower, atr_val, vol_ratio;
    indicator_top u_indicator(
        .clk(clk_200m), .rst_n(clk_locked),
        .price_valid(parsed_valid),
        .open(parsed_open), .high(parsed_high),
        .low(parsed_low), .close(parsed_close), .volume(parsed_volume),
        .ma5(ma5), .ma20(ma20), .ma60(ma60), .rsi(rsi),
        .macd_dif(macd_dif), .macd_dea(macd_dea),
        .boll_upper(boll_upper), .boll_lower(boll_lower),
        .atr(atr_val), .vol_ratio(vol_ratio)
    );

    wire [7:0]  score;
    wire [2:0]  decision;
    wire [15:0] tx_udp_data;
    wire        tx_udp_valid;
    score_decision u_score(
        .clk(clk_200m), .rst_n(clk_locked),
        .ma5(ma5), .ma20(ma20), .ma60(ma60), .rsi(rsi),
        .macd_dif(macd_dif), .macd_dea(macd_dea),
        .boll_upper(boll_upper), .boll_lower(boll_lower),
        .vol_ratio(vol_ratio), .atr(atr_val),
        .close(parsed_close),
        .score(score), .decision(decision),
        .tx_data(tx_udp_data), .tx_valid(tx_udp_valid)
    );

endmodule
```

时序约束模板：

```xdc
# top.xdc
create_clock -period 20.000 -name sys_clk_50m [get_ports sys_clk_50m]
create_clock -period 8.000 -name gtp_ref_clk [get_ports sfp_ref_clk_p]

set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks gtp_rx_clk] \
    -group [get_clocks clk_200m]

set_property PACKAGE_PIN xxx [get_ports sfp_rx_p]
set_property IOSTANDARD LVDS_25 [get_ports sfp_rx_p]
```

ILA 建议挂载信号：

- GTP RX data/valid
- 解析后的 K 线数据
- 指标输出（`ma5`、`rsi` 等）
- `score` / `decision`
- GTP TX data

### 组员 8 · 仿真 + 测试 + 可视化 + 文档

你需要掌握：Modelsim -> Testbench -> Python 可视化 -> 文档排版

学习路线（贯穿全程）：

1. Modelsim 工程、编译、仿真、波形查看。
2. Testbench 范式：时钟、激励、比对、断言。
3. Python 可视化（matplotlib/echarts）。
4. Word/LaTeX 排版。

Testbench 示例：

```systemverilog
// tb_eth_udp_parser.sv
`timescale 1ns / 1ps
module tb_eth_udp_parser;

    reg         clk, rst_n;
    reg  [7:0]  rx_byte;
    reg         rx_valid;
    wire [31:0] open, high, low, close, volume;
    wire        parsed_valid;

    eth_udp_parser uut(.*);

    always #4 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0;
        #100 rst_n = 1;

        send_eth_frame();

        #1000;
        if (parsed_valid && close == 32'h000A_8000)
            $display("PASS: close value matched!");
        else
            $error("FAIL: close mismatch, got %h", close);

        #500 $finish;
    end

    task send_eth_frame();
        // 构造完整以太网帧
    endtask

endmodule
```

可视化服务示例：

```python
# visual_server.py
from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI()

@app.get("/dashboard")
async def dashboard():
    return HTMLResponse("""
    <!DOCTYPE html>
    <html>
    <head><title>FPGA Stock Trading Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    </head>
    <body>
        <h1>FPGA 高速交易系统实时监控</h1>
        <div id="charts">
            <canvas id="kline"></canvas>
            <canvas id="indicators"></canvas>
        </div>
        <script>
            setInterval(async () => {
                const resp = await fetch('/api/result');
                const data = await resp.json();
                updateCharts(data);
            }, 1000);
        </script>
    </body>
    </html>
    """)
```

---

## 第五章 · 项目里程碑时间线（建议 16 周）

| 阶段 | 时间 | 目标 |
|---|---|---|
| 第 1-2 周 | 全员工具安装 + Verilog/Python 基础速成 | 每个人能独立跑通自己模块的 Hello World |
| 第 3-4 周 | 组员 2+3 打通 SFP 光口物理链路 | PC ping FPGA 通，上位机收发回环 OK |
| 第 5-6 周 | 组员 1+2 对接数据格式；组员 3+4 打通 UDP 解析 | 上位机发送 -> FPGA 正确解析 K 线数据 |
| 第 7-8 周 | 组员 5 完成第一版技术指标；组员 8 编写 Testbench | 指标仿真与 Python 对比误差 < 1% |
| 第 9-10 周 | 组员 6 完成评分回传；组员 8 开始系统仿真 | 发送 -> 处理 -> 回传闭环仿真通过 |
| 第 11-12 周 | 组员 7 顶层整合 + 时序收敛 + 上板 | 真实硬件全链路跑通 |
| 第 13-14 周 | 组员 7 联调校准；组员 8 性能测试 + 可视化 | FPGA vs Python 对比误差 < 1% |
| 第 15-16 周 | 组员 8 汇编文档 + PPT + 演示视频 | 完成交付 |

---

## 第六章 · 给小白的关键提醒

最容易踩的坑（按严重程度排序）：

1. 时钟域问题：GTP 恢复时钟与用户时钟不同步，必须用异步 FIFO。
2. 定点精度：建议使用舍入（截位前 +0.5 LSB），避免系统性偏差。
3. UDP 丢包：FPGA 处理不过来会直接丢包，需加深 FIFO 并控制发包间隔。
4. GTP 链路不稳定：检查光模块、光纤、TX disable、PLL lock 状态。
5. CRC 校验错误：以太网使用 CRC32（非 CRC16）。
6. MAC 地址冲突：FPGA MAC 可自定义，但不要冲突。

推荐入门资料：

- Verilog 入门：夏宇闻教程 / HDLBits。
- FPGA 实战：米联客 MA703FA 配套教程（优先 GTP 与以太网）。
- 网络协议：《TCP/IP 详解 卷一》相关章节。
- 时序约束：Vivado UG903。
- GTP 配置：Xilinx UG482。

---

## 第七章 · 你可以让我先生成的第一批文件

| 编号 | 可生成内容 | 说明 |
|---|---|---|
| A | 项目目录结构 | 创建整个工程文件夹骨架 |
| B | 上位机 Python 代码 | 组员 1（采集）+ 组员 2（UDP 收发） |
| C | FPGA Verilog 模块 | 组员 4（解析）/ 5（指标）/ 6（评分回传） |
| D | Testbench 仿真代码 | 各模块的 Modelsim 激励 |
| E | 约束文件（XDC） | 管脚约束 + 时序约束 |
| F | 通信协议文档 | 完整数据格式定义表 |
| G | 毕业设计任务书框架 | 可填充模板 |

---

如果你愿意，我下一步可以直接从 A 开始，在当前仓库一次性生成可运行的项目骨架（含 Python、Verilog、仿真、文档四大目录和初始文件）。

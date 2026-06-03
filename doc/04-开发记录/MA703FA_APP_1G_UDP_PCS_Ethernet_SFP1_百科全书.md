# MA703FA_APP_1G_UDP_PCS_Ethernet_SFP1 工程百科全书

## 0. 这份文档是什么

这是一份面向内部参考工程 `A703-100T/MA703FA_APP_1G_UDP_PCS_Ethernet_SFP1` 的工程百科全书。它的目标不是复述所有源代码，而是把这个工程的结构、数据通路、Vivado 资源、调试入口和常见使用方式讲清楚，方便后续阅读、复现和二次开发。

如果你只想快速抓住重点，这个工程可以概括为一句话：

**它是一个基于 Xilinx Artix-7（`xc7a100tfgg484-2`）的 1G SFP UDP/Ethernet 示例工程，核心入口在 `helai_ip/top.v`，底层由 PCS/PMA、GMII、MAC、IP、ARP、UDP 和测试回环几层组成。**

---

## 1. 工程定位

这个工程的作用是演示和验证 1G 以太网链路上的 UDP 协议栈实现。它不是一个只做单一模块验证的实验工程，而是一个“端到端可跑”的参考项目：

1. 通过 `gig_ethernet_pcs_pma_0` 把 SFP 物理层连起来。
2. 把 GMII 数据送入自定义 UDP 协议栈。
3. 由 `udp_ip_protocol_stack` 负责 MAC / ARP / IP / UDP 的协同。
4. 用 `ikun_udp_test` 做默认回环或测速测试。
5. 通过 Vivado 生成 IP、综合、实现并最终下载到板上。

这个工程的典型价值有两点：

1. 它是理解“Vivado IP + 自写协议栈”组合方式的好样例。
2. 它是后续修改以太网、UDP、ARP、CRC 和测试逻辑时最直接的参考对象。

---

## 2. 目录结构总览

工程主要分成两条线：`project_1` 和 `helai_ip`。

```text
A703-100T/MA703FA_APP_1G_UDP_PCS_Ethernet_SFP1/
├─ project_1/                     # Vivado 工程主体
│  ├─ project_1.xpr               # Vivado 工程文件
│  ├─ project_1.srcs/             # 源码与 IP 引用
│  ├─ project_1.runs/             # 综合/实现/生成比特流的运行结果
│  ├─ project_1.cache/            # Vivado 缓存和 IP 派生产物
│  ├─ project_1.ip_user_files/    # IP 生成文件与用户文件
│  ├─ project_1.sim/              # 仿真相关内容
│  └─ project_1.hw/               # 硬件管理/下载相关内容
└─ helai_ip/                      # 作者自写的 UDP / MAC / IP / ARP 逻辑
   ├─ top.v                       # 工程顶层
   ├─ helai_udp_verilog/
   │  ├─ UDP_verilog/             # 协议栈主体
   │  ├─ udp_app_test/            # 回环/测速测试模块
   │  ├─ ip/                      # 部分 IP 资源
   │  └─ common/                  # 公共辅助模块
   └─ ip/                         # 生成或封装的 IP
```

从维护角度看，`project_1` 更像是 Vivado 的工程壳，`helai_ip` 才是这个示例真正的逻辑主体。

---

## 3. 顶层入口

### 3.1 真正的设计入口

工程的顶层模块是 `helai_ip/top.v`，而不是协议栈中的某个中间模块。它直接例化：

1. `clk_wiz_0`：从 50MHz 输入生成内部时钟。
2. `gig_ethernet_pcs_pma_0`：完成 SFP 物理层与 GMII 之间的转换。
3. `ikun_udp_test`：做 UDP 回环或测速控制。
4. `udp_ip_protocol_stack`：承接应用层数据并完成 UDP/IP/ARP/MAC 封装与解封。

### 3.2 顶层参数

`top.v` 里定义了四个关键参数：

1. `LOCAL_PORT_NUM`
2. `LOCAL_IP_ADDRESS`
3. `LOCAL_MAC_ADDRESS`
4. `DST_PORT_NUM`
5. `DST_IP_ADDRESS`

这说明这个工程本质上是一个“定目标 IP / 定目标端口”的 UDP 设备示例，适合和上位机直接联调。

### 3.3 顶层端口

顶层只暴露少量端口：

1. `i_clk_50m`
2. `led`
3. `sfp_ref_clk_p / sfp_ref_clk_n`
4. `sfp_rx_p / sfp_rx_n`
5. `sfp_tx_p / sfp_tx_n`
6. `sfp_tx_dis`

也就是说，这个工程把复杂度都压进了内部协议栈，板级连线保持最小化。

---

## 4. 总体数据通路

这个工程的数据流可以按“接收”和“发送”两条链路理解。

### 4.1 接收链路

SFP RX → `gig_ethernet_pcs_pma_0` → GMII RX → `mac_layer` / `mac_receive` → `receive_buffer` → `ip_layer` / `udp_layer` → 应用层。

更具体一点：

1. 物理层收包后进入 GMII。
2. `mac_receive` 识别前导码、MAC 头、EtherType 和 CRC。
3. `receive_buffer` 根据 `mac_frame_type` 把 IP 帧和 ARP 帧分流。
4. `ip_receive` 处理 IPv4 头和校验。
5. `udp_receive` 把 UDP 数据交给应用层。

### 4.2 发送链路

应用层 → `udp_layer` → `ip_layer` → `send_buffer` → `mac_layer` / `mac_send` → GMII TX → `gig_ethernet_pcs_pma_0` → SFP TX。

更具体一点：

1. 应用层先声明要发什么、发多长。
2. `udp_send` / `ip_send` 完成协议头组帧。
3. `send_buffer` 决定先发 ARP 还是直接发 IP 数据。
4. `mac_send` 完成以太网头、填充、CRC32 和帧间隔控制。

### 4.3 默认测试模式

`ikun_udp_test` 默认启动回环模式，必要时可通过 VIO 切换到测速模式。也就是说，这个工程不仅能做协议联调，也能做吞吐和稳定性测试。

---

## 5. 协议栈分层

这套工程的层次比较清楚，适合按协议栈读。

### 5.1 `udp_ip_protocol_stack.v`

这是整个协议栈的调度中枢。它把 MAC、ARP、IP、UDP、发送仲裁和接收仲裁串起来。

它的职责不是自己解析每个字节，而是：

1. 组织发送顺序。
2. 组织接收分流。
3. 处理 ARP 查表、补 MAC、请求 ARP。
4. 连接应用层和物理层之间的所有子模块。

### 5.2 `mac_layer.v`

MAC 层负责以太网帧级别的封装和解析。它内部包含：

1. `mac_send`
2. `mac_receive`

这里是整个系统里最靠近以太网帧格式的地方，负责：

1. 帧头处理。
2. 目标 MAC / 源 MAC 处理。
3. EtherType 识别。
4. CRC32 生成与校验。
5. PAUSE 流控帧处理。

### 5.3 `arp_layer.v`

ARP 层负责：

1. ARP 请求发送。
2. ARP 应答接收。
3. 把 IP 地址和 MAC 地址做缓存映射。

它内部有一个 `mac_cache`，用于保存 IP → MAC 的对应关系。

### 5.4 `ip_layer.v`

IP 层负责 IPv4 数据包的组包与解包。

它内部包含：

1. `ip_send`
2. `ip_receive`

同时还带了 ICMP 相关逻辑和一个 `echo_data_fifo`，说明这个工程不仅能发 UDP，还具备一定的网络基础协议示例能力。

### 5.5 `udp_layer.v`

UDP 层是应用和 IP 之间的轻量适配层，内部包含：

1. `udp_send`
2. `udp_receive`

它做的事情比较纯粹：

1. 对上给应用提供请求、应答、长度和端口信息。
2. 对下把 UDP 数据交给 IP 层。

---

## 6. 关键子模块职责

### 6.1 `mac_send.v`

这个模块负责真正发以太网帧。它内部能看到几个关键点：

1. 发送 FIFO。
2. 帧长度记录 FIFO。
3. 帧间隔控制。
4. CRC32 生成。
5. PAUSE 帧支持。

它的思路是先把待发数据写入 FIFO，再在 RGMII 时钟域里逐字节吐出帧头、负载、CRC 和空闲间隔。

### 6.2 `mac_receive.v`

这个模块负责收以太网帧。

它会：

1. 等待 SFD。
2. 解析目标 MAC、源 MAC、EtherType。
3. 判断是不是发给本机。
4. 校验 CRC32。
5. 把可接收的数据写入 FIFO。
6. 识别 PAUSE 控制帧。

### 6.3 `send_buffer.v`

这是发送仲裁模块，作用非常关键：

1. 判断当前是发 ARP 还是发 IP。
2. 检查 MAC 缓存是否已有目标地址。
3. 如果没有 MAC，先触发 ARP 请求。
4. 如果已有 MAC，直接发 IP 数据。

换句话说，它是“发包前的总调度器”。

### 6.4 `receive_buffer.v`

这是接收仲裁模块，按 `mac_frame_type` 把数据分成：

1. `IP_TYPE` → `ip_rx_data_valid`
2. `ARP_TYPE` → `arp_rx_data_valid`

它的逻辑比较直接，主要就是分流。

### 6.5 `arp_send.v` / `arp_receive.v`

ARP 的发送和接收模块分别处理 ARP 请求和应答。

它们的目标是让 `send_buffer` 能够通过 MAC 缓存机制找到目标设备的 MAC 地址，否则就主动发 ARP 请求。

### 6.6 `ip_send.v` / `ip_receive.v`

IP 发送和接收模块负责：

1. IPv4 头生成。
2. 头校验和检查。
3. UDP payload 的穿透。
4. ICMP echo 相关处理。

### 6.7 `udp_send.v` / `udp_receive.v`

UDP 层是应用层最直接接触的模块。

它负责：

1. 把应用数据切成协议层可发的格式。
2. 打包源端口、目的端口、长度等字段。
3. 把收到的 UDP payload 恢复成应用数据流。

### 6.8 `CRC32_generation.v` / `CRC32_check.v`

这两个模块分别完成发送侧 CRC32 生成和接收侧 CRC32 校验。

在这个工程里，CRC 并不是“可有可无”的辅助，而是以太网帧可靠性控制的核心部分之一。

### 6.9 `gmii_to_rgmii.v`

这是 GMII 和 RGMII 的转换桥，作用是把协议栈的字节流和物理层的 DDR 双沿接口连接起来。

### 6.10 `ikun_udp_test.v`

这是工程里的测试入口模块。

它的特点是：

1. 默认做数据回环。
2. 通过 VIO 可切换到测速模式。
3. 回环和测速不能同时运行。

这使它非常适合作为“先看通路，再看性能”的验证工具。

---

## 7. Vivado IP 资源

在 `project_1` 里，除了手写 Verilog，还有不少 Vivado 生成 IP。

### 7.1 物理层相关 IP

1. `gig_ethernet_pcs_pma_0`
2. `clk_wiz_0`

前者负责 SFP / Ethernet PCS/PMA，后者负责时钟管理。

### 7.2 数据流和调试相关 IP

1. `udp_packet_fifo`
2. `MAC_send_fifo`
3. `mac_receive_fifo`
4. `mac_frame_length_fifo`
5. `mac_tx_frame_info_fifo`
6. `shift`
7. `shift_ip`
8. `shift_mac`
9. `echo_data_fifo`
10. `rx_8t32_fifo`
11. `vio_0`
12. `dbg_hub`
13. `ila_0`

这些 IP 体现了这个工程的特点：

1. 既有高速链路 IP。
2. 也有 FIFO 和调试逻辑。
3. 说明作者不是只在写 RTL，而是在做一个可以联调的完整工程。

### 7.3 你需要特别记住的点

如果以后想复现这个工程，最容易踩坑的地方通常不是手写 RTL，而是 IP 版本、IP 生成目录、工程路径和综合/实现缓存。

---

## 8. 工程行为怎么理解

### 8.1 默认行为

默认情况下，这个工程是一个 UDP 回环/测试工程。

也就是说：

1. 上位机发入的数据会进入协议栈。
2. FPGA 可以把收到的数据再发回去。
3. 测速模式下，FPGA 还会按固定长度主动发送测试帧。

### 8.2 为什么要有回环

回环的价值是快速验证链路是否通：

1. 物理层通不通。
2. CRC 是否正常。
3. ARP 是否能正常查到 MAC。
4. UDP 发送和接收是否都能闭环。

### 8.3 为什么要有测速

测速的价值是看这个工程在数据持续流动时是否稳定：

1. FIFO 会不会断。
2. 状态机会不会卡住。
3. 发送速率能不能持续。
4. 物理链路是否会掉包。

---

## 9. 推荐的阅读顺序

如果你第一次读这个工程，建议按下面顺序看：

1. `helai_ip/top.v`
2. `helai_ip/helai_udp_verilog/UDP_verilog/udp_ip_protocol_stack.v`
3. `helai_ip/helai_udp_verilog/UDP_verilog/mac_layer.v`
4. `helai_ip/helai_udp_verilog/UDP_verilog/arp_layer.v`
5. `helai_ip/helai_udp_verilog/UDP_verilog/ip_layer.v`
6. `helai_ip/helai_udp_verilog/UDP_verilog/udp_layer.v`
7. `helai_ip/helai_udp_verilog/UDP_verilog/mac_send.v`
8. `helai_ip/helai_udp_verilog/UDP_verilog/mac_receive.v`
9. `helai_ip/helai_udp_verilog/udp_app_test/ikun_udp_test.v`

这个顺序的好处是：先看总入口，再看协议分层，最后看测试入口。

---

## 10. Vivado 使用建议

### 10.1 打开工程

在 Vivado 里直接打开 `project_1/project_1.xpr`。

### 10.2 确认顶层

检查当前 Top Module 是否是 `top`。

### 10.3 检查 IP 状态

如果工程打开后出现 IP 缺失或版本不匹配，优先处理：

1. `gig_ethernet_pcs_pma_0`
2. `clk_wiz_0`
3. `vio_0`
4. FIFO 类 IP

### 10.4 典型调试路径

1. 先看物理层参考时钟是否正常。
2. 再看 GMII 是否有数据流动。
3. 再看 MAC CRC 是否通过。
4. 再看 ARP 缓存是否建立。
5. 最后看 UDP 层是否能收发。

---

## 11. 如果你要改这个工程

### 11.1 改网络参数

优先改这些地方：

1. `top.v` 里的 IP / MAC / Port 参数。
2. 相关上位机配置。

### 11.2 改协议行为

优先看这些模块：

1. `udp_send.v`
2. `udp_receive.v`
3. `ip_send.v`
4. `ip_receive.v`
5. `arp_send.v`
6. `arp_receive.v`
7. `mac_send.v`
8. `mac_receive.v`

### 11.3 改板级链路

优先看：

1. `top.v`
2. `gig_ethernet_pcs_pma_0` 的配置
3. `clk_wiz_0` 的输出时钟设置
4. 板级约束与物理连接

---

## 12. 常见问题

### 12.1 工程能打开，但跑不起来

优先检查：

1. IP 是否全部生成。
2. 器件型号是否匹配 `xc7a100tfgg484-2`。
3. SFP 参考时钟是否正确接入。
4. 顶层是否仍然是 `top`。

### 12.2 只能收不能发

优先检查：

1. `send_buffer` 是否拿到了 `mac_send_ready`。
2. ARP 缓存里是否已有目标 MAC。
3. `mac_send` 是否正确输出 CRC 和帧间隔。

### 12.3 只能发不能收

优先检查：

1. `mac_receive` 是否识别到 SFD。
2. `receive_buffer` 是否正确分流 IP / ARP。
3. `ip_receive` 的头校验是否通过。

### 12.4 测速模式不工作

优先检查：

1. VIO 是否正确驱动 `udp_tx_speed_en`。
2. `ikun_udp_test` 的状态机是否进入 TX 流程。
3. `PACKET_LENGTH` 与 FIFO 数据流是否匹配。

---

## 13. 一句话总结

这个内部工程是一个“从 SFP 物理层一路打通到 UDP 应用层”的完整 1G Ethernet 示例。它最值得记住的不是某个单独模块，而是它把 **PCS/PMA、GMII、MAC、ARP、IP、UDP、测试回环和 Vivado IP** 组合成了一个可上板、可联调、可验证的闭环。

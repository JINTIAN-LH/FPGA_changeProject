# FPGA 网络配置指南

## 概述

本文档说明如何配置 PC 和 FPGA 之间的以太网通信。

## 网络架构

```
┌─────────────────┐         Ethernet Cable         ┌─────────────────┐
│       PC        │◄──────────────────────────────►│      FPGA       │
│                 │                                 │                 │
│  IP: 169.254.0.100                              │  IP: 169.254.0.118
│  MAC: (auto)    │                                 │  MAC: 02:00:00:00:00:01
│                 │                                 │                 │
│  UDP Port: 5000 │                                 │  UDP Port: 5001 │
└─────────────────┘                                 └─────────────────┘
```

## 1. PC 网卡配置

### Windows 设置

1. 打开网络连接
   - 按 `Win + R`，输入 `ncpa.cpl`，回车

2. 找到以太网适配器
   - 找到连接到 FPGA 的以太网适配器
   - 右键点击 → 属性

3. 配置 IPv4
   - 选择 "Internet 协议版本 4 (TCP/IPv4)"
   - 点击 "属性"

4. 设置静态 IP
   ```
   IP 地址:      169.254.0.100
   子网掩码:     255.255.0.0
   默认网关:     (留空)
   首选 DNS:     (留空)
   备用 DNS:     (留空)
   ```

5. 点击 "确定" 保存

### Linux 设置

```bash
# 临时设置（重启后失效）
sudo ifconfig eth0 169.254.0.100 netmask 255.255.0.0 up

# 或使用 ip 命令
sudo ip addr add 169.254.0.100/16 dev eth0
sudo ip link set eth0 up

# 永久设置（Ubuntu/Debian）
# 编辑 /etc/network/interfaces
auto eth0
iface eth0 inet static
    address 169.254.0.100
    netmask 255.255.0.0
```

### macOS 设置

1. 打开系统偏好设置 → 网络
2. 选择以太网适配器
3. 配置 IPv4：手动
4. 设置：
   ```
   IP 地址:      169.254.0.100
   子网掩码:     255.255.0.0
   路由器:       (留空)
   ```

## 2. FPGA 配置

FPGA 的网络参数在 RTL 中硬编码：

### IP 地址
```verilog
// 文件: fpga_side/rtl/src/udp_tx_engine.v
parameter [31:0] SRC_IP = 32'hA9FE0076;  // 169.254.0.118
parameter [31:0] DST_IP = 32'hC0A86468;  // 192.168.100.104 (需要修改!)
```

### MAC 地址
```verilog
// 文件: fpga_side/rtl/src/udp_tx_engine.v
parameter [47:0] SRC_MAC = 48'h02_00_00_00_00_01;
parameter [47:0] DST_MAC = 48'hFF_FF_FF_FF_FF_FF;  // 广播地址
```

### UDP 端口
```verilog
// 文件: fpga_side/rtl/src/udp_tx_engine.v
parameter [15:0] SRC_PORT = 16'd5001;
parameter [15:0] DST_PORT = 16'd5000;

// 文件: fpga_side/rtl/src/board_eth_bridge.v
localparam [15:0] M1_UDP_DST_PORT = 16'd5001;
```

## 3. 网络协议栈

FPGA 实现了以下网络协议：

### ARP 响应器
- 文件: `fpga_side/rtl/src/arp_responder.v`
- 功能: 响应 PC 的 ARP 请求，提供 FPGA 的 MAC 地址
- 这是 PC 能够发送 UDP 包到 FPGA 的关键

### ICMP Ping 响应器
- 文件: `fpga_side/rtl/src/icmp_responder.v`
- 功能: 响应 ping 请求，用于测试网络连通性

### UDP 解析器
- 文件: `fpga_side/rtl/src/ip_udp_parser.v`
- 功能: 解析接收到的 UDP 包，提取 payload

### UDP 发送引擎
- 文件: `fpga_side/rtl/src/udp_tx_engine.v`
- 功能: 构造并发送 UDP 包

### 网络处理器
- 文件: `fpga_side/rtl/src/network_handler.v`
- 功能: 集成 ARP、ICMP、UDP 处理，管理 TX 多路复用

## 4. 测试步骤

### 步骤 1: 检查物理连接

1. 确认以太网线已连接
2. 确认 FPGA 已上电
3. 检查网卡指示灯是否亮起

### 步骤 2: 验证 IP 配置

```bash
# Windows
ipconfig /all

# Linux/macOS
ifconfig
# 或
ip addr show
```

确认以太网适配器的 IP 地址是 `169.254.0.100`

### 步骤 3: 测试 Ping

```bash
ping 169.254.0.118
```

预期结果:
```
Pinging 169.254.0.118 with 32 bytes of data:
Reply from 169.254.0.118: bytes=32 time<1ms TTL=64
Reply from 169.254.0.118: bytes=32 time<1ms TTL=64
Reply from 169.254.0.118: bytes=32 time<1ms TTL=64
Reply from 169.254.0.118: bytes=32 time<1ms TTL=64
```

如果 ping 失败，检查:
- [ ] 以太网线是否连接
- [ ] FPGA 是否上电
- [ ] PC IP 是否配置正确
- [ ] 防火墙是否阻止 ICMP

### 步骤 4: 检查 ARP 表

```bash
# Windows
arp -a

# Linux/macOS
arp -n
```

应该能看到:
```
169.254.0.118     02-00-00-00-00-01     dynamic
```

### 步骤 5: 测试 UDP

使用提供的调试脚本:

```bash
cd host_side/tests
python network_debug.py --udp
```

或者使用 Wireshark 抓包分析:

1. 打开 Wireshark
2. 选择以太网适配器
3. 设置过滤器: `udp port 5001 or udp port 5000 or arp`
4. 运行测试脚本
5. 分析抓包结果

## 5. 常见问题

### Q1: Ping 不通

**可能原因:**
1. PC 不在同一子网
2. FPGA ARP 响应器未工作
3. 防火墙阻止

**解决方法:**
1. 检查 PC IP 配置
2. 使用 Wireshark 抓包查看 ARP 请求/响应
3. 临时关闭防火墙测试

### Q2: Ping 通但 UDP 不通

**可能原因:**
1. UDP 端口配置错误
2. FPGA UDP 解析器未工作
3. FPGA 应用层未处理

**解决方法:**
1. 检查端口配置
2. 使用 Wireshark 抓包查看 UDP 包
3. 检查 FPGA 仿真波形

### Q3: UDP 超时

**可能原因:**
1. FPGA 未发送响应
2. 响应包格式错误
3. PC 未收到响应

**解决方法:**
1. 检查 FPGA UDP 发送引擎
2. 使用 Wireshark 分析响应包
3. 检查 PC 防火墙

## 6. 调试工具

### Wireshark 过滤器

```
# 显示所有相关流量
udp port 5001 or udp port 5000 or arp

# 只显示 ARP
arp

# 只显示 UDP
udp

# 显示特定 IP 的流量
ip.addr == 169.254.0.118
```

### 网络调试脚本

```bash
# 运行所有测试
python host_side/tests/network_debug.py

# 只测试 ping
python host_side/tests/network_debug.py --ping

# 只测试 UDP
python host_side/tests/network_debug.py --udp

# 使用 mock 服务器测试 UDP
python host_side/tests/network_debug.py --udp --mock

# 显示网络配置
python host_side/tests/network_debug.py --config
```

## 7. 修改 FPGA 网络参数

如果需要修改 FPGA 的网络参数，需要修改以下文件:

### 修改 IP 地址

1. **发送 IP** (`udp_tx_engine.v`):
```verilog
parameter [31:0] SRC_IP = 32'hA9FE0076;  // 修改为你想要的 IP
parameter [31:0] DST_IP = 32'hC0A86468;  // 修改为 PC 的 IP
```

2. **接收 IP** (`arp_responder.v`, `icmp_responder.v`, `network_handler.v`):
```verilog
parameter [31:0] LOCAL_IP = 32'hA9FE0076;  // 修改为你想要的 IP
```

### 修改 MAC 地址

1. **发送 MAC** (`udp_tx_engine.v`):
```verilog
parameter [47:0] SRC_MAC = 48'h02_00_00_00_00_01;  // 修改为你想要的 MAC
parameter [47:0] DST_MAC = 48'hFF_FF_FF_FF_FF_FF;  // 修改为 PC 的 MAC
```

2. **本地 MAC** (`arp_responder.v`, `icmp_responder.v`, `network_handler.v`):
```verilog
parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01;  // 修改为你想要的 MAC
```

### 修改 UDP 端口

1. **发送端口** (`udp_tx_engine.v`):
```verilog
parameter [15:0] SRC_PORT = 16'd5001;  // 修改为你想要的端口
parameter [15:0] DST_PORT = 16'd5000;  // 修改为 PC 的监听端口
```

2. **接收端口** (`board_eth_bridge.v`):
```verilog
localparam [15:0] M1_UDP_DST_PORT = 16'd5001;  // 修改为你想要的端口
```

3. **PC 配置** (`host_side/app/config.py`):
```python
FPGA_REAL_UDP_HOST = "169.254.0.118"  # 修改为 FPGA 的 IP
FPGA_REAL_UDP_PORT = 5001             # 修改为 FPGA 的监听端口
PC_REAL_BIND_HOST = "169.254.0.100"   # 修改为 PC 的 IP
PC_REAL_BIND_PORT = 5000              # 修改为 PC 的监听端口
```

## 8. 性能优化建议

### 减少延迟

1. 使用千兆以太网
2. 减少 UDP 包大小
3. 使用硬件加速的 CRC 计算

### 提高可靠性

1. 实现 UDP 重传机制
2. 添加序列号检测丢包
3. 实现流量控制

### 调试建议

1. 使用 ILA (Integrated Logic Analyzer) 抓取 FPGA 内部信号
2. 使用 Wireshark 分析网络流量
3. 记录详细的日志用于问题定位

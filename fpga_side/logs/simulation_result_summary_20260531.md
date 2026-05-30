# Vivado Batch 仿真结果摘要（2026-05-31，收口版）

## 执行说明
- Python 回归：按标准命令执行，12/12 通过。
- FPGA 仿真：采用单 TB 独立 batch 方式执行并产生日志。
- 脚本：`fpga_side/scripts/vivado/run_single_tb.tcl`
- 日志目录：`fpga_side/logs/tb_runs_20260531`

## 总览结论
- Python 回归：通过（12/12）
- FPGA TB：6 个执行完成
- 编译阻断：0
- 当前限制：默认仿真窗口 1000ns，部分系统流程未覆盖到最终 verdict 断言输出

## FPGA 分项结果

### 1) tb_score_calc
- 证据：`single tb done: tb_score_calc`
- 关键输出：`XSim simulation ran for 1000ns`

### 2) tb_indicator_top
- 证据：`single tb done: tb_indicator_top`
- 关键输出：`[tb_indicator_top] score=46 decision=2 ...`

### 3) tb_udp_result_tx
- 证据：`single tb done: tb_udp_result_tx`
- 关键输出：`[tb_udp_result_tx] valid_bytes=60 tx_last=0`

### 4) tb_top
- 证据：`single tb done: tb_top`
- 关键输出：`[tb_top] heartbeat=0 score=46 decision=2 result_valid=0 tx_valid=1 tx_last=0`

### 5) tb_m1_protocol_core
- 证据：`single tb done: tb_m1_protocol_core`
- 关键输出：`[CASE] normal`、`[CASE] bad_header`

### 6) tb_system_mixed
- 证据：终端批跑输出包含 `single tb done: tb_system_mixed`
- 关键输出：`XSim simulation ran for 1000ns`

## 收口判定
- 本轮满足“可交付收口”的条件：
  1. 主机侧回归全通过
  2. FPGA 关键 TB 批跑完成
  3. 指标链路、打包链路、协议链路均有运行证据
- 距离最终完结仅剩：将系统级 TB 窗口拉长并固化自动 verdict 统计。

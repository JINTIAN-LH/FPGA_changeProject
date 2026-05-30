# Commit History

## 2026-05-28

### 1) chore: init project and add complete README

- Commit: 0e16b3a3e44507345525b7064b6590d760c7a17c
- Branch: main
- Scope:
  - 初始化 Git 仓库并创建首个提交
  - 新增 `README.md`，补全项目说明、环境、运行方式与数据格式
  - 新增 `.gitignore`，忽略 `.venv`、缓存与运行期 JSON 产物
  - 配置并推送远端 `origin`

### 2) feat: land non-FPGA protocol mock pipeline

- Commit: 9308fe4c6dde0fe614b5392c8e6fdb58de39c51f
- Branch: main
- Scope:
  - 新增正式 ICD 对齐的协议编解码、机器可读契约快照与 UDP 传输层
  - 新增软件侧 K 线数据校验、Mock FPGA 服务与端到端回环脚本
  - 将 `run_all.py` 接入可选 FPGA UDP 下发链路与结果落盘
  - 新增协议、校验、传输、契约快照、`run_all` 接入等回归测试
  - 补充 `doc` 下 ICD/数据字典 PDF、图片与 Markdown 转写文档
  - 更新 `README.md`，补全非 FPGA 闭环运行与验证说明

### 3) docs: improve README for beginner readability

- Commit: pending
- Branch: main
- Scope:
  - 重构 `README.md` 开篇结构，新增“当前进度 / 最终目标 / 推荐阅读顺序”
  - 新增当前可运行链路与远期目标链路 Mermaid 图，强调从 Mock 到实机的演进路径
  - 修复“项目结构”段落断裂与重复内容，统一目录树展示
  - 强化小白视角导览，明确每个核心文件的作用与阅读建议

### 4) feat: scaffold VS Code Verilog env and Vivado migration docs

- Commit: pending
- Branch: main
- Scope:
  - 新增 `.vscode` 配置（扩展推荐、语言关联、任务入口）
  - 新增 FPGA 开发骨架目录 `hdl/src|tb|constraints|ip|sim` 与最小 RTL/TB 示例
  - 新增 `scripts/vivado/run_xsim.tcl` 作为 xsim 批处理入口
  - 新增 `doc/VSCode到Vivado迁移操作手册.md` 与 `doc/全链条开发实施计划_v2.md`
  - 更新 `README.md` 增补 VS Code Verilog 环境与文档入口

### 5) feat: add M1 FPGA protocol RTL skeleton and protocol testbench cases

- Commit: pending
- Branch: main
- Scope:
  - 新增 `hdl/src/m1_protocol_core.v`：48B 上行帧解析 + 44B 固定回包状态机
  - 解析校验包含：帧头、长度、CRC32；通过后触发下行发送
  - 回包字段包含：下行帧头/长度、股票代码回显、时间戳回显、固定指标占位、CRC32
  - 更新 `hdl/tb/tb_top.v`：覆盖 normal / bad_header / bad_length / bad_crc 四类协议用例
  - 保持上位机 Python 回归测试全绿（12/12）

### 6) feat: implement M1.1 configurable placeholders, reject reason codes, and mixed-frame stress TB

- Commit: pending
- Branch: main
- Scope:
  - 升级 `hdl/src/m1_protocol_core.v`：新增 `MA5/MA10/RSI` 可配置占位参数
  - 新增 `frame_reject_reason[2:0]`（header/length/crc/size）用于 ILA 观测定位
  - 更新 `hdl/tb/tb_top.v`：坏帧用例增加 reject reason 精确断言
  - 新增 `hdl/tb/tb_system_mixed.v`：连续多帧混合压力仿真（好帧+坏帧）
  - 更新 `scripts/vivado/run_xsim.tcl`：批处理顺序执行 `tb_top` 与 `tb_system_mixed`
  - 在本机以 `C:/vivado2019/Vivado/2019.1/bin` 运行 batch 仿真，结果两套 TB 均 PASSED

### 7) chore: split repository into host_side and fpga_side, sync encyclopedia stage summary

- Commit: pending
- Branch: main
- Scope:
  - 目录重构：新增 `host_side`（`app/tests/data`）与 `fpga_side`（`rtl/scripts/logs`）
  - 将上位机 Python 代码、测试、样例数据迁移到 `host_side`
  - 将 FPGA RTL/TB/仿真脚本/日志迁移到 `fpga_side`
  - 更新 `.vscode/tasks.json` 路径与回归命令（含 `PYTHONPATH=host_side/app`）
  - 更新 `fpga_side/scripts/vivado/run_xsim.tcl` 为新目录路径
  - 更新 `README.md` 的目录树与运行命令
  - 更新《小白百科全书》新增第八章阶段性总结与新目录结构
  - 验证结果：Python 12/12 通过；Vivado batch 仿真（`tb_top` + `tb_system_mixed`）通过

### 8) docs: full beginner-friendly documentation overhaul across project

- Commit: pending
- Branch: main
- Scope:
  - 全量重写 `README.md`，新增“30 秒理解 / 新手三步上手 / 常见问题 / 文档导航”
  - 全量重写《小白百科全书》，统一到 `host_side` / `fpga_side` 新目录与可执行命令
  - 重写 `doc/VSCode到Vivado迁移操作手册.md`，更新 Vivado 导入路径与联调步骤
  - 重写 `doc/全链条开发实施计划_v2.md`，按 M1/M1.1/M2/M3 给出执行与验收口径
  - 重写 `doc/通信协议接口控制文档 (ICD)/通信协议接口控制文档 (ICD).md`，补充 M1.1 拒绝错误码说明
  - 重写 `doc/数据字典/数据字典.md`，增加字段速查、代码映射与新手自检清单
  - 重写 `doc/任务与分工总表.md`，统一角色职责、工作流与站会模板
  - 更新 `fpga_side/rtl/README.md` 为新手友好版本，补充批仿真命令与通过标准

### 9) docs: localize fpga rtl readme for Chinese users

- Commit: pending
- Branch: main
- Scope:
  - 将 `fpga_side/rtl/README.md` 从英文改为中文说明
  - 保留原有结构并增强小白可读性（目录解释、里程碑、仿真命令、通过标准）
  - 与现有目录结构 `host_side/fpga_side` 保持一致

### 10) chore: restructure doc directory and full project sync

- Commit: pending
- Branch: main
- Scope:
  - 按最新组织方式重构 `doc` 目录内容与文档命名
  - 同步清理旧版文档派生产物（历史 PDF/PNG）并纳入新版文档入口
  - 将工程结构变更（`host_side` / `fpga_side`）做全量提交落库
  - 保持 README 与文档导航对齐到当前目录结构

### 11) chore: move fpga-side member deliverables into fpga_side/docs

- Commit: pending
- Branch: main
- Scope:
  - 将组员五、组员六的成果 `.docx` 从 `doc/` 移入 `fpga_side/docs/`
  - 为 FPGA 侧成果文档新增按成员分类的目录，便于定位与归档
  - 更新根 `README.md` 的目录树与文档导航，明确 `fpga_side/docs/README.md` 入口

### 12) feat: integrate protocol-indicator top wiring and refresh documentation baseline

- Commit: pending
- Branch: main
- Scope:
  - 完成系统级接线：在 `fpga_side/rtl/src/top.v` 内实连 `m1_protocol_core` 与 `indicator_top` 指标输出
  - 升级 `fpga_side/rtl/src/m1_protocol_core.v` 下行字段映射，按 ICD 回包结构输出指标/信号字段
  - 更新 `fpga_side/rtl/tb/tb_system_mixed.v` 与 `fpga_side/rtl/tb/tb_top.sv` 以匹配新接口并增强映射校验
  - 执行并通过关键闭环仿真：`tb_m1_protocol_core`、`tb_system_mixed`、`tb_top`
  - 全量更新项目文档入口与百科说明，清理临时/过期文档并补齐 `doc/README.md`

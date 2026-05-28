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

- Commit: pending
- Branch: main
- Scope:
  - 新增正式 ICD 对齐的协议编解码、机器可读契约快照与 UDP 传输层
  - 新增软件侧 K 线数据校验、Mock FPGA 服务与端到端回环脚本
  - 将 `run_all.py` 接入可选 FPGA UDP 下发链路与结果落盘
  - 新增协议、校验、传输、契约快照、`run_all` 接入等回归测试
  - 补充 `doc` 下 ICD/数据字典 PDF、图片与 Markdown 转写文档
  - 更新 `README.md`，补全非 FPGA 闭环运行与验证说明

# 硬件对接契约 — 未来接物理蓝牙红绿灯

## 集成点（已冻结）

`~/.agent-status` 是唯一的集成点：

- **hook 只写**：各 agent 的 hook 一律调 `set_status.sh <status> <agent>`，
  不直接碰硬件、不直接写这个文件。
- **显示端只读**：App / 硬件驱动只读这个文件，不回写。
- **格式**：`<status>` 或 `<status>:<agent>`，例如 `working:claude`。
- **取值**：`status` ∈ {`idle`, `working`, `attention`}；单次写入（`printf > file`，近似原子）；UTF-8。
- **多 agent 语义**：`set_status.sh` 已按优先级聚合成单值，
  `attention`（需人工介入）> `working`（工作中）> `idle`（待命），
  同级取最后写入。显示端（App 或硬件）**不需要**自己做聚合，读到什么显示什么。

## 颜色映射（所有显示端统一）

| status      | 含义       | 灯色 |
| ----------- | ---------- | ---- |
| `attention` | 需人工介入 | 红   |
| `working`   | 工作中     | 黄   |
| `idle`      | 待命       | 蓝   |

## 未来硬件驱动方案（待实施）

- **硬件**：Luxafor Bluetooth（Mac 蓝牙直连，无需装驱动）。
- **驱动库**：`busylight-for-humans`（`pip install`，`busylight on red`，带 HTTP API）
  或 `busylight-core`（`light.on((255, 255, 0))`）。实施前以库的官方支持列表为准。
- **驱动进程**：一个常驻小进程，监听 `~/.agent-status` 变化
  （轮询每 0.5 秒，或用 fsevents），按上表把 status 翻译成灯色。
  只读文件，与 `AgentLights.app` 可同时运行、互不干扰。
- **App 侧零改动**：加硬件 = 新增一个"显示驱动"，hook 和 App 都不用动。

## 演进记录

- v1：单文件 last-write-wins（`~/.agent-status` 直接写）。
- v2：按 agent 分文件 `~/.agent-status.d/<agent>` + 优先级聚合，
  对外契约（`~/.agent-status` 格式与语义）保持不变。

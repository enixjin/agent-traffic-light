# Agent 悬浮红绿灯 — Mac 原生版（Swift）

一个 macOS 原生悬浮窗：🔴 需人工介入 / 🟡 工作中 / 🔵 待命。
初期支持 **Claude Code、OpenCode、Qoder** 三家 agent；架构预留了未来接物理蓝牙灯的能力（见 `HARDWARE.md`）。

## 架构（一句话）

```
Claude Code ─┐
Qoder ───────┼─▶ hook ─▶ set_status.sh ─▶ ~/.agent-status ─▶ 显示端（只读）
OpenCode ────┘                                        ├─ 现在：AgentLights.app
                                                      └─ 未来：物理蓝牙灯驱动
```

- hook 只**写**状态（经 `set_status.sh`），显示端只**读** `~/.agent-status`。
- 多 agent 并发时按优先级聚合：attention > working > idle，同级取最后写入。
  聚合逻辑在 `set_status.sh` 里，hook 和 App 都不用关心有几个 agent。

## 文件

| 文件                      | 说明                                              |
| ------------------------- | ------------------------------------------------- |
| `main.swift`              | App 源码（AppKit 单文件，与 agent 无关）          |
| `build.sh`                | 编译脚本，**在 Mac 上运行**                       |
| `set_status.sh`           | 状态聚合写入脚本（v2，多 agent 优先级聚合）       |
| `hooks-claude.json`       | `hooks` 对象 → 合并进 `~/.claude/settings.json`   |
| `hooks-qoder.json`        | `hooks` 对象 → 合并进 `~/.qoder/settings.json`    |
| `opencode-agent-lights.ts`| → `~/.config/opencode/plugins/agent-lights.ts`    |
| `HARDWARE.md`             | 硬件对接契约（未来接物理蓝牙灯看这份）            |
| `README.md` / `README.en.md` | 说明文档（中文 / English）                   |

## 安装步骤（都在 Mac 上做）

### 1. 编译 App

```bash
# zip 包里自带 agent-traffic-light-mac 文件夹，解压后：
cd agent-traffic-light-mac
./build.sh
```

- 需要 Xcode Command Line Tools：没有的话先跑 `xcode-select --install`。
- 需要 macOS 11 及以上（源码里用了一个 macOS 11 引入的圆角 API）。
- 成功后生成 `AgentLights.app`。双击运行；首次弹"无法验证开发者"时右键 → 打开 → 点"打开"（一次即可）。

### 2. 装状态脚本

```bash
mkdir -p ~/.agent-lights
cp set_status.sh ~/.agent-lights/
chmod +x ~/.agent-lights/set_status.sh
```

### 3. 接 Claude Code

把 `hooks-claude.json` 里的 `hooks` 对象合并进 `~/.claude/settings.json`
（已有 `hooks` 的按事件名逐个合并，不要整段覆盖）。

### 4. 接 Qoder

把 `hooks-qoder.json` 里的 `hooks` 对象合并进 `~/.qoder/settings.json`
（Qoder 官方 hooks 文档：https://docs.qoder.com/extensions/hooks）。
注意：官方文档的 hooks 口径是 IDE / JetBrains 插件，CLI 是否支持未明确，装完以实际触发为准。

### 5. 接 OpenCode

```bash
mkdir -p ~/.config/opencode/plugins
cp opencode-agent-lights.ts ~/.config/opencode/plugins/agent-lights.ts
```

然后重启 OpenCode（插件写法依据官方文档，无需装 npm 包）。

### 6. 测试（三灯依次亮就通了）

```bash
~/.agent-lights/set_status.sh working claude      # 黄灯，显示"工作中 · claude"
~/.agent-lights/set_status.sh attention qoder     # 红灯（优先级最高），显示"需处理 · qoder"
~/.agent-lights/set_status.sh idle qoder          # 回到黄灯（claude 还在工作中）
~/.agent-lights/set_status.sh idle claude         # 蓝灯
```

### 7. 开机自启（可选）

系统设置 → 通用 → 登录项 → 点 `+` → 选 `AgentLights.app`。

## 操作

- 左键按住拖动可移动位置（自动记住，下次打开还在原位）。
- 拖动窗口边缘/角落可缩放（等比 84:296，范围 0.5x–2x，大小自动记住）。
- 右键 → Reset Size 恢复默认大小；右键菜单里还有 Theme → Dark / Light 可切换深浅主题，默认 Dark。
- 退出红绿灯：右键 → Quit。
- 无 Dock 图标，不抢焦点，盖在所有窗口上（所有桌面空间都显示）。

## 状态契约（显示端统一口径）

| 值          | 灯色 | 含义       |
| ----------- | ---- | ---------- |
| `attention` | 红   | 需人工介入 |
| `working`   | 黄   | 工作中     |
| `idle`      | 蓝   | 待命       |

`~/.agent-status` 内容格式：`<status>` 或 `<status>:<agent>`（如 `working:claude`）。

## 已知限制

- agent 异常退出没走到 SessionEnd/Stop 时，它的状态文件会残留（灯可能一直显示它在工作）。
  手动清除：`~/.agent-lights/set_status.sh idle <agent名>`。
- Qoder CLI 的 hooks 支持情况官方未明确，按 IDE / JetBrains 插件口径先接。

## 平台支持与 Roadmap

**当前**

- 平台：仅 macOS（AppKit 原生，macOS 11+），暂无 Windows / Linux 版本。
- Agent：仅支持 Claude Code、OpenCode、Qoder 三家。

**Roadmap（不承诺时间表）**

- Windows / Linux 版：状态契约（`~/.agent-status`）与平台无关，
  各平台只需实现一个只读显示端（托盘小程序 / Electron 等均可），
  hooks 与聚合脚本的逻辑可直接复用。
- 更多 agent（如 Codex、Cursor）：架构上接入新 agent 只需要写一份
  调用 `set_status.sh <status> <agent>` 的 hooks，聚合端与显示端零改动。

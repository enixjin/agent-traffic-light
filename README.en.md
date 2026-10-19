# Agent Floating Traffic Light — Native Mac Version (Swift)

A native macOS floating window: 🔴 needs human input / 🟡 working / 🔵 idle.
Supports **Claude Code, OpenCode, and Qoder** out of the box; the architecture
reserves a clean seam for a future physical Bluetooth light (see `HARDWARE.md`).

## Architecture in one picture

```
Claude Code ─┐
Qoder ───────┼─▶ hook ─▶ set_status.sh ─▶ ~/.agent-status ─▶ displays (read-only)
OpenCode ────┘                                        ├─ now: AgentLights.app
                                                      └─ later: physical Bluetooth light driver
```

- Hooks only **write** state (via `set_status.sh`); displays only **read** `~/.agent-status`.
- When several agents run at once, states merge by priority:
  attention > working > idle; ties go to the most recent write.
  The merge logic lives in `set_status.sh` — hooks and the app don't need
  to know how many agents there are.

## Files

| File                      | Description                                           |
| ------------------------- | ----------------------------------------------------- |
| `main.swift`              | App source (single-file AppKit, agent-agnostic)       |
| `build.sh`                | Build script — **run on a Mac**                       |
| `set_status.sh`           | State aggregation writer (v2, multi-agent priority)   |
| `hooks-claude.json`       | `hooks` object → merge into `~/.claude/settings.json` |
| `hooks-qoder.json`        | `hooks` object → merge into `~/.qoder/settings.json`  |
| `opencode-agent-lights.ts`| → `~/.config/opencode/plugins/agent-lights.ts`       |
| `HARDWARE.md`             | Hardware integration contract (for the future Bluetooth light) |
| `README.md`               | This doc in Chinese                                   |

## Install (all on the Mac)

### 1. Build the app

```bash
# the zip contains an agent-traffic-light-mac folder; after unzipping:
cd agent-traffic-light-mac
./build.sh
```

- Requires Xcode Command Line Tools (`xcode-select --install` if missing).
- Requires macOS 11+ (the source uses a rounded-rect API introduced in macOS 11).
- On success you get `AgentLights.app`. Double-click to run; on first launch
  Gatekeeper will block it ("cannot be verified") — right-click → Open → Open
  in the dialog, once, and it won't ask again.

### 2. Install the status script

```bash
mkdir -p ~/.agent-lights
cp set_status.sh ~/.agent-lights/
chmod +x ~/.agent-lights/set_status.sh
```

### 3. Wire up Claude Code

Merge the `hooks` object from `hooks-claude.json` into `~/.claude/settings.json`
(merge per event name if `hooks` already exists — don't overwrite the whole file).

### 4. Wire up Qoder

Merge the `hooks` object from `hooks-qoder.json` into `~/.qoder/settings.json`
(Qoder official hooks docs: https://docs.qoder.com/extensions/hooks).
Note: the official docs cover the IDE / JetBrains plugin; CLI support is
unconfirmed — verify by triggering events after installing.

### 5. Wire up OpenCode

```bash
mkdir -p ~/.config/opencode/plugins
cp opencode-agent-lights.ts ~/.config/opencode/plugins/agent-lights.ts
```

Then restart OpenCode (follows the official plugin docs, no npm packages needed).

### 6. Test (all three lights in order means it works)

```bash
~/.agent-lights/set_status.sh working claude      # yellow, shows "Working · claude"
~/.agent-lights/set_status.sh attention qoder     # red (highest priority), shows "Attention · qoder"
~/.agent-lights/set_status.sh idle qoder          # back to yellow (claude still working)
~/.agent-lights/set_status.sh idle claude         # blue
```

### 7. Launch at login (optional)

System Settings → General → Login Items → `+` → pick `AgentLights.app`.

## Usage

- Drag with the left mouse button to move it (position is remembered).
- Right-click → Quit.
- No Dock icon, never steals focus, floats above all windows on all Spaces.

## Status contract (same for every display)

| Value       | Light  | Meaning           |
| ----------- | ------ | ----------------- |
| `attention` | red    | needs human input |
| `working`   | yellow | working           |
| `idle`      | blue   | idle              |

`~/.agent-status` content format: `<status>` or `<status>:<agent>` (e.g. `working:claude`).

## Known limitations

- If an agent crashes without reaching SessionEnd/Stop, its state file lingers
  (the light may keep showing it as working).
  Clear manually: `~/.agent-lights/set_status.sh idle <agent-name>`.
- Qoder CLI hooks support is unconfirmed by the official docs; wired per the
  IDE / JetBrains plugin spec for now.

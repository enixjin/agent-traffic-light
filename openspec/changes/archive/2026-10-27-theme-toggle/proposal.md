# Proposal

## Why

`AgentLights.app` currently ships with a single dark traffic-light shell. Users who keep a light desktop wallpaper or prefer a light UI have no way to make the floating window match their environment. A simple manual theme toggle makes the app usable in both light and dark contexts without adding complexity.

## What Changes

- Add a manual **Dark / Light** theme toggle to the app's right-click menu.
- Persist the selected theme across launches using `UserDefaults`.
- Default to the existing dark theme on first launch so current behavior is preserved.
- Replace hard-coded shell colors in `main.swift` with a theme-aware palette:
  - Dark mode keeps the current look (dark housing, light label).
  - Light mode uses a near-white housing, light-gray bezel, and dark label.
- The red/yellow/blue lamp colors and the `~/.agent-status` status contract remain unchanged.

No breaking changes. Existing window position/size persistence and behavior stay the same.

## Capabilities

### New Capabilities

- `ui-theme`: User-selectable dark/light appearance for the traffic-light window, persisted across launches.

### Modified Capabilities

None.

## Impact

- `main.swift`: theme enum/palette, `UserDefaults` read/write, menu construction, and drawing code.
- `README.md` / `README.en.md`: document the new theme menu item.
- No changes to hooks, `set_status.sh`, the status contract, or the build process.

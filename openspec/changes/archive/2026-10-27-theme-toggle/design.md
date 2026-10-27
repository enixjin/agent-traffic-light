# Design

## Context

See `proposal.md` for motivation. The app is a single-file AppKit program (`main.swift`) that draws a fixed-shape traffic light. All visual chrome is currently hard-coded to a dark palette. There are no existing preferences or settings; the only user-facing state persisted today is the window frame via `setFrameAutosaveName(_:)`.

## Goals / Non-Goals

**Goals:**
- Let the user switch between dark and light themes from the right-click menu.
- Remember the choice across app launches.
- Keep the default look identical to today (dark mode).
- Keep the implementation in the existing single-file style.

**Non-Goals:**
- Automatic/system appearance detection.
- Per-agent or per-status theme overrides.
- Changing the red/yellow/blue lamp colors.

## Decisions

1. **Storage: `UserDefaults`**
   - The app has no data layer. `UserDefaults.standard` is the lightest durable store and fits a single toggle.
   - Key: `AgentLightsTheme`, values: `"dark"` / `"light"`.
   - Default when missing: `"dark"`.
   - Alternative: write a sidecar file. Rejected — heavier and unnecessary.

2. **Theme representation: a simple Swift enum + palette struct**
   - Introduce a `Theme` enum with `dark` and `light` cases, each exposing `housing`, `bezel`, and `labelText` colors.
   - `LightView` holds a `theme` property and redraws when it changes.
   - Alternative: keep the current `NSColor` literals and branch in `draw(_:)`. Rejected — an enum keeps the palette coherent and makes adding themes easier.

3. **Menu UI: submenu under right-click menu**
   - Add a `Theme` submenu with `Dark` and `Light` items. The active item gets a `state = .on` checkmark.
   - Tapping an item sets the theme, saves it, and marks the view as needing display.
   - Alternative: a single menu item that cycles modes. Rejected — a submenu shows the current state at a glance and matches standard macOS patterns.

4. **Light mode palette**
   - Housing: `NSColor(white: 0.95, alpha: 1)` (near-white)
   - Bezel: `NSColor(white: 0.85, alpha: 1)` (light gray)
   - Label text: `NSColor(white: 0.20, alpha: 1)` (dark gray)
   - The white highlight dot on the active lamp is unchanged; it sits on the colored lamp, not the shell.

## Risks / Trade-offs

- **Light housing may blend with light wallpapers.** → Mitigation: keep the panel shadow enabled and use a slightly gray bezel so the edge is still visible.
- **UserDefaults may be cleared by system or user action.** → Mitigation: missing value falls back to dark, which is safe and matches current behavior.
- **Translation / localization.** → The menu items are added in English only for now, consistent with the existing app UI.

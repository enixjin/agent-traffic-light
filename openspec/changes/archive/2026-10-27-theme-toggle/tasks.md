# Tasks

## 1. Core implementation

- [x] 1.1 Add a `Theme` enum and palette struct to `main.swift` for dark and light modes, plus `UserDefaults` read/write helpers using key `AgentLightsTheme`. Verify the project still compiles with `./build.sh`.
- [x] 1.2 Update `LightView` to draw using the active theme palette instead of hard-coded colors. Add a `Theme` submenu to the right-click context menu with `Dark` and `Light` items and a checkmark for the active theme. Verify the menu appears and selecting an item redraws the window.
- [x] 1.3 Load the saved theme at launch (default to dark) and persist the choice immediately when the user toggles it. Verify that selecting light mode, quitting, and relaunching restores light mode.

## 2. Documentation

- [x] 2.1 Update `README.md` and `README.en.md` to mention the theme submenu under the Usage/Operation section. Verify both files reference `Theme → Dark / Light` and the dark default.

## 3. Integration verification

- [x] 3.1 Run `./build.sh` on macOS, launch `AgentLights.app`, and exercise the full dark → light → dark toggle cycle. Verify both themes render correctly, the checkmark follows the selection, and the app keeps the choice after relaunch.

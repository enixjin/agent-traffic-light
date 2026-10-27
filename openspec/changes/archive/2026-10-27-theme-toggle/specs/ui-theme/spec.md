# Spec Delta

## Purpose

The `ui-theme` capability lets the user choose between a dark and a light appearance for the AgentLights floating window.

## ADDED Requirements

### Requirement: Theme is selectable from the right-click menu
The app SHALL provide a "Theme" submenu in the right-click context menu with "Dark" and "Light" items. The currently active theme SHALL be indicated with a checkmark.

#### Scenario: User opens the context menu
- **WHEN** the user right-clicks the traffic-light window
- **THEN** a "Theme" submenu appears with "Dark" and "Light" entries

#### Scenario: User switches to light mode
- **WHEN** the user selects "Light" from the "Theme" submenu
- **THEN** the window redraws using the light palette and "Light" shows a checkmark

### Requirement: Selected theme persists across launches
The app SHALL store the user's theme choice in `UserDefaults` and apply it on the next launch.

#### Scenario: Relaunch after selecting light mode
- **WHEN** the user selects "Light" and then restarts the app
- **THEN** the app starts in light mode

### Requirement: Default theme is dark
When no theme preference has been saved, the app SHALL use the dark theme so existing behavior is preserved.

#### Scenario: First launch
- **WHEN** the app launches without a saved theme preference
- **THEN** it renders in dark mode

### Requirement: Light theme uses a light shell palette
In light mode the app SHALL draw the traffic-light housing and label using a light palette. The red, yellow, and blue lamp colors SHALL remain unchanged.

#### Scenario: Light mode rendering
- **WHEN** the app is in light mode
- **THEN** the housing is near-white, the bezel is light gray, the label is dark gray, and the attention/working/idle lamps remain red/yellow/blue

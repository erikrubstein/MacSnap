# Lightweight Grid Snap App Roadmap

## Goal

Build a small native macOS menu bar utility that lets a user define a grid, such as `2 x 4`, then snap dragged windows into grid cells by holding a configurable modifier.

The app should stay intentionally lightweight. It should solve one workflow well: drag a window, hold the snap modifier, choose a grid region, and release.

## MVP Scope

- Menu bar app with a minimal settings window.
- Configurable grid rows and columns, defaulting to `2 x 4`.
- Accessibility permission check and prompt.
- Hold the configured snap modifier while dragging a window to activate snapping.
- Show a transparent grid overlay on the active screen.
- Snap the dragged window into the hovered grid cell on mouse release.
- Optionally hold middle mouse while dragging to span multiple grid cells.
- Persist simple settings locally.

## Out Of Scope For V1

- Custom named layouts.
- Layout editor.
- Per-app rules.
- Per-Space layout persistence.
- Window cycling.
- Onboarding videos.
- Auto-updater.
- Licensing, donation, or purchase flows.
- Complex animations or visual effects.

## Proposed Architecture

### `GridSnapApp`

Owns app lifecycle, menu bar item, settings window, and startup wiring.

### `PermissionManager`

Checks Accessibility permission and opens the macOS permission prompt or Settings pane when needed.

### `InputMonitor`

Tracks global mouse down, drag, mouse up, modifier state, and middle-button state.

### `WindowLocator`

Finds the candidate window under the cursor using `CGWindowList`, then maps that window to an `AXUIElement`.

### `GridModel`

Converts rows, columns, screen geometry, mouse location, and optional span state into target rectangles.

### `OverlayWindow`

Displays a transparent, non-focus-stealing grid overlay with the active cell or span highlighted.

### `SnapEngine`

Moves and resizes the target window through Accessibility APIs.

### `SettingsStore`

Persists rows, columns, gap size, modifier choice, and related simple preferences using `UserDefaults`.

## Phase 0: Risk Spike

Prove that the app can control another window.

Implementation lives in `GridSnap/`.

Status: implemented.

### Deliverables

- Throwaway menu bar or basic app target.
- Accessibility permission check.
- Keyboard shortcut that snaps the focused window to left half or right half.

### Acceptance Criteria

- App can move and resize another app's focused window.
- Works with Finder, Safari or Chrome, Terminal, and one Electron app.
- Failure cases are understood before building the full drag workflow.

## Phase 1: App Shell

Create the real lightweight app foundation.

Implementation lives in `GridSnap/`.

Status: implemented.

### Deliverables

- Menu bar icon.
- Minimal settings window.
- Inputs for grid rows and columns.
- Accessibility permission status.
- Quit action.
- Local settings persistence.

### Acceptance Criteria

- App launches quietly as a menu bar utility.
- Grid size survives restart.
- Dock icon is hidden unless intentionally enabled.

## Phase 2: Grid Math

Implement snapping geometry before wiring global drag behavior.

Implementation lives in `GridSnap/Sources/GridSnapCore/GridModel.swift`.

Status: implemented.

### Deliverables

- `GridModel(rows:columns:)`.
- Mouse-to-cell detection.
- Cell-to-screen-rectangle conversion.
- Span rectangle calculation.
- Optional gap or padding support.

### Acceptance Criteria

- `1 x 2`, `2 x 4`, `3 x 3`, and `4 x 4` grids produce correct rectangles.
- Geometry works across multiple monitor coordinate spaces.
- Target rectangles can use either full screen frame or visible frame.

Validation command:

```sh
cd GridSnap
swift run GridSnapGeometryCheck
```

## Phase 3: Overlay

Draw the active grid while snapping is enabled.

Implementation lives in `GridSnap/Sources/GridSnap/GridOverlayController.swift`.

Status: implemented. The app includes a menu-driven overlay preview so this phase can be tested before drag snapping exists.

### Deliverables

- Transparent borderless overlay window.
- Grid lines.
- Highlighted hovered cell.
- Highlighted span region.
- Logic to show, update, move, and hide overlay.

### Acceptance Criteria

- Overlay does not steal focus.
- Overlay appears only while snapping is active.
- Overlay follows the screen under the mouse.
- Overlay disappears cleanly on mouse up or when snapping is canceled.

## Phase 4: Shift Drag Single-Cell Snap

Wire input monitoring, window detection, overlay updates, and snapping.

Implementation lives in `GridSnap/Sources/GridSnap/DragSnapController.swift`.

Status: implemented. The app snaps the targeted window to the highlighted grid cell on mouse up while the configured snap modifier is held.

### Deliverables

- Detect left mouse down and drag.
- Capture candidate dragged window.
- Show overlay while dragging with the snap modifier held.
- Update highlighted cell as the mouse moves.
- Snap to hovered cell on mouse up.

### Acceptance Criteria

- Drag a normal window, hold the snap modifier, release over a grid cell, and the window snaps.
- Releasing without the snap modifier does nothing.
- Works across multiple displays.
- Desktop, menu bar, app overlays, and non-normal windows are ignored where the focused-window capture path can identify a normal resizable window.

## Phase 5: Multi-Cell Span

Add middle-click span behavior.

Implementation lives in `GridSnap/Sources/GridSnap/DragSnapController.swift`.

Status: implemented. Middle click or the optional span modifier during a snap drag anchors the first selected cell and expands the highlighted selection to the current cell.

### Deliverables

- Detect middle mouse state during snap mode.
- Use the first selected cell as the span anchor.
- Expand highlighted selection from anchor cell to current cell.
- Snap to the combined rectangle on mouse up.

### Acceptance Criteria

- A user can span two or more adjacent grid cells.
- Drag direction does not matter.
- Selection remains stable enough to feel intentional.
- Single-cell snapping still works exactly as before.

## Phase 6: Hardening

Make the MVP dependable for daily use.

Implementation lives mostly in `GridSnap/Sources/GridSnap/GridSnapApp.swift` and `GridSnap/Sources/GridSnap/DragSnapController.swift`.

Status: implemented. The app now prefers under-pointer window targeting, falls back to the focused window, clamps snap rectangles to the active screen, and retries failed snaps with a refreshed Accessibility window reference when possible.

### Deliverables

- Safer handling for failed Accessibility calls.
- Better filtering for non-resizable or unsupported windows.
- Retry or refetch target window before snapping.
- Clamp target rectangles to the selected screen.
- Handle monitor rearrangement, disconnects, and resolution changes.
- Optional diagnostics logging toggle.

### Acceptance Criteria

- Failed snaps do not crash the app.
- Unsupported windows fail silently or produce a useful diagnostic log.
- Basic snapping remains reliable after display changes.

## Phase 7: Polish

Add small quality-of-life improvements without expanding the product too much.

Status: implemented for in-app polish options. The app now supports configurable snap modifier, grid gap, visible/full screen frame behavior, reset settings, subtle overlay fade, and Option-as-span for trackpad users. Launch at login remains a packaging task for a future bundled `.app`.

## Post-MVP: Profiles

Status: implemented. Profiles allow multiple named grid presets, each with its own rows, columns, gap, and optional custom switch shortcut. Settings are separated into Profiles, Global, and System sections; profile management uses a table with Add/Edit/Delete and a smaller edit sheet.

### Candidate Features

- Configurable snap modifier.
- Configurable grid gap.
- Toggle between full screen frame and visible screen frame.
- Launch at login.
- Reset settings.
- Subtle overlay fade.
- Alternate span modifier for trackpad users.

## Recommended Build Order

1. Focused-window keyboard snap.
2. Menu bar app and settings.
3. Grid model.
4. Overlay.
5. Modifier-drag single-cell snap.
6. Middle-click span.
7. Multi-monitor and edge-case hardening.

## Complexity Assessment

This should be much simpler than MacsyZones because it avoids custom layouts, onboarding, licensing, update flows, quick snapper UI, and broad settings surfaces.

The hard parts are still real macOS platform issues:

- Accessibility permissions.
- Tracking global input while another app owns focus.
- Identifying the correct dragged window.
- Converting screen coordinates correctly.
- Moving and resizing windows reliably through `AXUIElement`.

Estimated effort:

- Prototype: 1 to 2 focused days.
- Usable MVP: 3 to 5 focused days.
- Polished lightweight utility: 1 to 2 weeks.

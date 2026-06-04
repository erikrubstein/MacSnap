# GridSnap

Lightweight macOS grid snapping utility.

Current implementation:

- Request Accessibility permission.
- Register global hotkeys.
- Find the currently focused window.
- Move and resize that window through `AXUIElement`.
- Run as a menu bar utility.
- Open a minimal settings window.
- Persist named grid profiles locally.
- Convert grid settings into snap target rectangles.
- Preview the grid overlay on the screen under the mouse.
- Snap a dragged focused window to a grid cell while the snap modifier is held.
- Span multiple grid cells with middle click during a snap drag.
- Prefer the window under the pointer when snapping, with focused-window fallback.
- Retry failed snaps with a refreshed Accessibility window reference.
- Configure snap modifier, grid gap, screen frame mode, and Option span behavior.
- Switch between profiles with optional custom shortcuts.

## Run

```sh
swift run
```

The app appears in the menu bar as `GridSnap`.

If Swift asks which executable to run, use:

```sh
swift run GridSnap
```

## Settings

Open the `GridSnap` menu bar item and choose `Settings...`.

The settings window is split into Profile, Global, and System sections.

The Profile section includes:

- Profile table with active profile, name, grid, gap, and shortcut.
- Add, Edit, and Delete buttons.
- A smaller Edit Profile window for name, rows, columns, gap, and shortcut.

The Global section includes:

- Snap modifier, default `Shift`.
- Whether snapping avoids the menu bar and Dock.
- Whether `Option` can be used as a span modifier for trackpads.

The System section includes:

- Accessibility permission status.
- Buttons to refresh permission status and open Accessibility settings.

## Overlay Preview

Open the `GridSnap` menu bar item and choose `Preview Grid Overlay`.

The preview uses your current rows and columns, appears on the screen under the mouse, and highlights the hovered cell. Choose `Hide Grid Overlay` to dismiss it.

## Drag Snap

Run the app, then drag a normal app window while holding the configured snap modifier. The default is `Shift`.

While the modifier is held during the drag, the grid overlay appears on the screen under the mouse and highlights the hovered cell. Release the mouse while the highlight is visible to snap the dragged window into that cell.

To span multiple cells, keep dragging with the snap modifier, press middle click while the first cell is highlighted, move across the grid, then release the left mouse button while the span is highlighted. If enabled in settings, `Option` can also anchor and expand the span for trackpad use.

The app first tries to target the window under the pointer, then falls back to the focused window if needed.

## Profiles

Each profile has its own name, rows, columns, gap, and optional switch shortcut.

Use `Settings...` to add, edit, and delete profiles. Selecting a row makes that profile active. Edit opens a smaller profile window where you can change the profile name, rows, columns, gap, and shortcut. To set a shortcut, click the shortcut control and press the key combination you want. Switching profiles updates the active grid immediately, including overlay preview and future snaps.

## Hotkeys

- `Ctrl + Option + Left`: snap the focused window to the left half of the current screen.
- `Ctrl + Option + Right`: snap the focused window to the right half of the current screen.
- Custom profile shortcuts: switch to profiles that have shortcuts assigned.

## Geometry Checks

Run the Phase 2 geometry checks with:

```sh
swift run GridSnapGeometryCheck
```

This validates grid cell lookup, cell rectangles, span rectangles, common grid sizes, multi-monitor-style coordinate offsets, gap insets, and profile storage.

## Permission

The first run should trigger the macOS Accessibility permission prompt.

If snapping does not work, open:

System Settings -> Privacy & Security -> Accessibility

Then enable the permission for the built executable or Terminal app that launched it.

## Notes

Launch at login and a double-clickable app bundle belong in a packaging pass after this SwiftPM prototype.

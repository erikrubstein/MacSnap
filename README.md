# MacSnap

Lightweight macOS grid snapping utility.

Current implementation:

- Request Accessibility permission.
- Run as a menu bar utility.
- Open a settings window.
- Persist named grid profiles locally.
- Convert grid settings into snap target rectangles.
- Preview the grid overlay on the screen under the mouse.
- Snap a dragged focused window to a grid cell while the snap modifier is held.
- Span multiple grid cells with a configurable span modifier.
- Prefer the window under the pointer when snapping, with focused-window fallback.
- Retry failed snaps with a refreshed Accessibility window reference.
- Configure snap modifier, optional alternate snap modifier, span modifier, optional alternate span modifier, grid gap, screen frame mode, overlay colors, and restore-on-unsnap behavior.
- Switch between profiles with optional custom shortcuts.

## Run

```sh
swift run
```

The app appears in the menu bar as the MacSnap icon.

If Swift asks which executable to run, use:

```sh
swift run MacSnap
```

## Release DMG

Build an unsigned macOS app bundle and disk image locally with:

```sh
scripts/build_dmg.sh
```

The DMG is written to `dist/MacSnap-<version>.dmg`. By default the script builds a universal `arm64` plus `x86_64` app.

GitHub Actions also builds the DMG. Push a version tag to publish it as a release asset:

```sh
git tag v0.1.0
git push origin v0.1.0
```

The app is not Developer ID signed or notarized yet, so macOS Gatekeeper will warn on first launch after download.

## Settings

Open the MacSnap menu bar item and choose `Settings...`.

The settings window is split into Profiles, Global, Appearance, and conditional Permissions sections.

The Profile section includes:

- Profile table with active profile, name, grid, gap, and shortcut.
- Add, Edit, Delete, Up, and Down buttons.
- A smaller Edit Profile window for name, rows, columns, gap, and shortcut.

The Global section includes:

- Snap modifier, default `Shift`.
- Optional alternate snap modifier, default `None`.
- Span modifier, default `Middle Click`.
- Optional alternate span modifier, default `None`.
- Whether snapping avoids the menu bar and Dock.
- Whether dragging a snapped window restores its pre-snap size.

The Appearance section includes:

- Background color.
- Grid line color.
- Selection color.

The Permissions section appears only when Accessibility permission is missing. It includes:

- A brief permission message.
- Buttons to refresh permission status and open Accessibility settings.

## Drag Snap

Run the app, then drag a normal app window while holding the configured snap modifier. The default is `Shift`.

While the modifier is held during the drag, the grid overlay appears on the screen under the mouse and highlights the hovered cell. Release the mouse while the highlight is visible to snap the dragged window into that cell.

To span multiple cells, keep dragging with the snap modifier, press the configured span modifier while the first cell is highlighted, move across the grid, then release the left mouse button while the span is highlighted.

The app first tries to target the window under the pointer, then falls back to the focused window if needed.

## Profiles

Each profile has its own name, rows, columns, gap, and optional switch shortcut.

Use `Settings...` to add, edit, delete, and reorder profiles. Selecting a row makes that profile active. Edit opens a smaller profile window where you can change the profile name, rows, columns, gap, and shortcut. To set a shortcut, click the shortcut control and press the key combination you want. Switching profiles updates the active grid immediately and briefly previews the grid.

## Hotkeys

Custom profile shortcuts switch to profiles that have shortcuts assigned.

## Geometry Checks

Run the Phase 2 geometry checks with:

```sh
swift run MacSnapGeometryCheck
```

This validates grid cell lookup, cell rectangles, span rectangles, common grid sizes, multi-monitor-style coordinate offsets, gap insets, and profile storage.

## Permission

The first run should trigger the macOS Accessibility permission prompt.

If snapping does not work, open:

System Settings -> Privacy & Security -> Accessibility

Then enable the permission for the built executable or Terminal app that launched it.

## Notes

Launch at login and a double-clickable app bundle belong in a packaging pass after this SwiftPM prototype.

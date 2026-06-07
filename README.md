# MacSnap

MacSnap is a small macOS menu bar app for snapping windows into a configurable grid.

I made it because I wanted something like FancyZones on macOS: lightweight, keyboard/mouse friendly, and built around quickly throwing windows into useful regions without managing full layouts by hand.

## Install

Download the latest `.dmg` from the [releases page](https://github.com/erikrubstein/MacSnap/releases/latest), open it, and drag `MacSnap` into `Applications`.

The app is not signed or notarized yet, so macOS may warn on first launch. You may need to right-click `MacSnap` and choose `Open`.

MacSnap needs Accessibility permission to move and resize windows:

```text
System Settings -> Privacy & Security -> Accessibility
```

Enable `MacSnap` there after launching it.

## Use

MacSnap lives in the menu bar.

By default:

- Hold `Shift` while dragging a window to show the grid.
- Release the mouse over a highlighted cell to snap the window there.
- Press the span modifier once during a snap drag to enter span mode.
- Press the span modifier again to return to single-cell snapping.

Open `Settings...` from the menu bar item to configure:

- grid profiles
- rows, columns, and gap
- snap and span modifiers
- profile shortcuts
- overlay colors
- screen frame behavior

## Update

Use `Check for Updates...` from the MacSnap menu bar menu.

You can also download the latest release manually from GitHub.

## Build

Run locally:

```sh
swift run MacSnap
```

Build an unsigned DMG:

```sh
Packaging/build_dmg.sh
```

Run tests:

```sh
swift test
```

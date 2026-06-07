# AGENTS.md

Guidance for coding agents working in this repository.

## Project

MacSnap is a SwiftPM macOS menu bar app. The app target is `MacSnap`; shared model/settings logic lives in `MacSnapCore`.

Important paths:

- `Sources/MacSnap/` - macOS app code.
- `Sources/MacSnapCore/` - grid math and settings storage.
- `Sources/MacSnap/Resources/` - app icons and resources.
- `Tests/MacSnapCoreTests/` - core behavior tests.
- `Packaging/` - DMG and Sparkle appcast scripts.

## Commands

Build:

```sh
swift build
```

Run:

```sh
swift run MacSnap
```

Test:

```sh
swift test
```

Package:

```sh
Packaging/build_dmg.sh
```

Generate Sparkle appcast locally:

```sh
SPARKLE_PRIVATE_KEY="$(cat Packaging/MacSnap.sparkle.private-key)" Packaging/generate_appcast.sh
```

## Notes

- Do not commit `Packaging/*.private-key`.
- The DMG build script ad-hoc signs the app bundle by default. Pass `CODE_SIGN_IDENTITY="Developer ID Application: ..."` to use a stable signing identity.
- Ad-hoc signed updates can lose macOS Accessibility trust because TCC may no longer match the updated app's code identity. Stable code signing is needed for seamless permission preservation across updates.
- The app is not Developer ID signed or notarized yet.
- Keep `appcast.xml` on `main`; the release workflow updates it for tagged releases.
- Prefer small, focused changes and keep README user-facing rather than roadmap-heavy.

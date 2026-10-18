# Developing Trash Flush

Everything you need to build, change and ship Trash Flush. For what the app does, see the [README](../README.md).

- [Build and run](#build-and-run)
- [Releasing a DMG](#releasing-a-dmg)
- [Signing and permissions](#signing-and-permissions)

## Build and run

You need macOS 14 or later and Xcode 16 or later (Swift 6).

### In Xcode

1. Double-click `Package.swift`. Xcode opens it as a project.
2. Choose the **TrashFlush** scheme and **My Mac**, then press **⌘R**.
3. A trash can icon appears in the menu bar. Click it.

Run from Xcode, the app is a bare executable, not a `.app` bundle, so two things work differently:

- macOS treats **Xcode** as the app asking for the Trash. Give *Xcode* Full Disk Access, or use the built app below.
- Launch at login is disabled because it needs a real `.app`.

### As a real app

```sh
scripts/build-app.sh          # builds build/TrashFlush.app (universal, signed)
open build/TrashFlush.app
```

For daily use, move the app to `/Applications` before you grant permissions or turn on launch at login.

| Variable | Effect |
| --- | --- |
| `UNIVERSAL=0` | Build only for this Mac's architecture (faster). |
| `SIGN_IDENTITY="…"` | Pick a signing identity. By default the first *Developer ID Application* or *Apple Development* identity is used, otherwise the app is signed ad hoc. |
| `BUNDLE_ID=com.you.TrashFlush` | Use your own bundle identifier. |
| `VERSION=1.2.0` | The version users see. |

### Tests

```sh
swift test
```

The tests cover everything that doesn't need a screen: flush detection, Trash scanning, Find Junk, sound synthesis and animation math. They run in under a second.

## Releasing a DMG

```sh
scripts/make-dmg.sh
```

This builds a release app and packages it as `build/TrashFlush-<version>.dmg`, the classic drag-to-Applications installer with a background and laid-out icons, plus a `.sha256` checksum. The first run asks to let your terminal control Finder (that's how the window layout is saved). Set `LAYOUT=0` to skip it, or `SKIP_BUILD=1` to package the app you already built.

### Publishing on GitHub

`.github/workflows/release.yml` does it all when you push a version tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions runs the tests, builds `TrashFlush-1.0.0.dmg` and publishes it as a release with generated notes. The README's download links point to the latest release.

### Without an Apple Developer account

You don't need one to ship a DMG. Without a *Developer ID* certificate the app is signed ad hoc and isn't notarized, so the first time someone opens it, macOS says it can't verify the app and they allow it once in *System Settings › Privacy & Security › Open Anyway*. The README walks users through that.

### Notarizing (optional, Apple Developer Program, $99/year)

Notarized apps open with no warning at all. Once you're in the program:

1. In Xcode › Settings › Accounts › Manage Certificates, add a **Developer ID Application** certificate.
2. Create an [app-specific password](https://account.apple.com) and save the credentials for `notarytool` (stored in your keychain):

   ```sh
   xcrun notarytool store-credentials trashflush --apple-id you@example.com --team-id TEAMID
   ```

3. Build, sign, notarize and staple in one go:

   ```sh
   NOTARY_PROFILE=trashflush scripts/make-dmg.sh
   ```

`make-dmg.sh` picks the Developer ID certificate automatically, signs the app with the hardened runtime and a secure timestamp, signs the DMG, waits for Apple's notary service and staples the ticket so the DMG opens cleanly even offline. Then update the README's install section, since the "Open Anyway" step is no longer needed. To notarize in GitHub Actions too, import the certificate and notary credentials from repository secrets before the build step.

## Signing and permissions

macOS ties Full Disk Access and Accessibility to the app's code signature.

- With an *Apple Development* or *Developer ID* certificate, permissions survive rebuilds. A free Apple ID added in *Xcode › Settings › Accounts* is enough for an Apple Development certificate (*Manage Certificates › + › Apple Development*).
- An ad hoc signature normally identifies one exact build, so every rebuild would look like a new app: System Settings would keep showing Trash Flush as allowed while the new build isn't. `build-app.sh` gives ad hoc builds a designated requirement of just the bundle identifier, so permissions survive rebuilds and updates.
- If a permission is on but doesn't work, reset it and grant it again: `tccutil reset Accessibility dev.trashflush.TrashFlush` (or `SystemPolicyAllFiles` for Full Disk Access).

**Why not the App Sandbox?** A sandboxed app can't reach `~/.Trash` at all, not even with Full Disk Access, and the folder is hidden from the open panel. So Trash Flush is a regular, non-sandboxed app with the hardened runtime. That also rules out the Mac App Store; it ships as a direct download.

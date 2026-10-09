# Trash Flush

A tiny macOS menu bar app that plays a toilet-flush animation, with a flush sound, every time you empty the Trash.

<!-- TODO: replace with a real recording: docs/demo.gif (Cmd+Shift+5 → record a portion, then convert with `ffmpeg` or Gifski) -->
<p align="center">
  <img src="docs/demo.gif" alt="Demo: emptying the Trash makes a toilet pop up beside the Dock's Trash, file icons fly into it and get flushed" width="420">
</p>

Empty the Trash the usual way (Finder, ⌘⇧⌫, right-click the Dock icon) and a little toilet pops up beside the Trash in your Dock. Your files fly out of the Trash into the bowl, the handle goes down and they swirl away. Then the app goes back to sleep.

## Features

- **Flush animation**: a toilet springs up next to the Dock's Trash. The real icons of what you deleted (Finder icons, and Quick Look previews for photos and documents) arc one by one from the Trash into the bowl and splash down. The handle tips, the toilet rocks, the water swirls and drains, the files spiral away, and a "Flushed 12 items · 734 MB freed" caption appears before the toilet slides back into the Dock.
- **Flush sound**: generated in code (filtered noise, a vortex wobble, rising bubble chirps). No audio files ship with the app.
- **4 themes**: Classic, Royal (gold), Toxic (green slime) and Black Hole. Each has its own colors and sound.
- **Flush Now** in the menu: empties the Trash with the animation. You click twice to confirm, so there is no modal dialog to get in the way.
- **Stats**: number of flushes, items flushed, space freed and when you last flushed. Right-click the stats to reset them.
- **Doesn't get in your way**: the overlay is click-through, never takes keyboard focus and shows on every Space (full-screen apps included), on the display that has the Dock.
- **Sound toggle**, **launch at login** (`SMAppService`), and **Reduce Motion** support (no flying or spinning, just a fade).
- **Light on resources**: about 0% CPU when idle, an app of a couple of megabytes, and no network access.

## Requirements

- macOS 14 Sonoma or later (Apple silicon or Intel)
- Xcode 16 or later (Swift 6)

## Build and run

### In Xcode (easiest while learning)

1. Double-click `Package.swift`. Xcode opens it as a project.
2. Choose the **TrashFlush** scheme and **My Mac**, then press **⌘R**.
3. A toilet icon appears in the menu bar. Click it.

When you run it from Xcode like this, the app is a bare executable, not a `.app` bundle. Two things work differently:
- macOS treats **Xcode** as the app asking for the Trash. Give *Xcode* Full Disk Access (see [Permissions](#permissions)), or use the built app below.
- Launch at login is disabled because it needs a real `.app`.

### As a real app

```sh
scripts/build-app.sh          # builds build/TrashFlush.app (universal, signed)
open build/TrashFlush.app
```

For daily use, move `TrashFlush.app` to `/Applications` before you grant permissions or turn on launch at login.

Options: `UNIVERSAL=0` builds only for your Mac's architecture (faster). `SIGN_IDENTITY="Apple Development: you@example.com (TEAMID)"` picks a signing identity, and `BUNDLE_ID=com.you.TrashFlush` sets your own bundle identifier.

### Tests

```sh
swift test
```

The tests cover the logic that doesn't need a screen: flush detection, Trash scanning, sound synthesis and animation math. They also run on Linux.

## Permissions

The Trash (`~/.Trash`) is protected by macOS privacy controls. An app can't list it, or even tell whether it's empty, unless you grant it **Full Disk Access**:

1. Open the menu. If access is missing you'll see a **Full Disk Access needed** banner. Click **Open Settings**.
2. In *System Settings › Privacy & Security › Full Disk Access*, turn on **Trash Flush**. If it isn't listed, click **+** (or drag in the app with **Show App**).
3. Back in the menu, click **Check Again**.

What Trash Flush does with that access: it lists the top-level items in `~/.Trash`, measures their size, and deletes them only when you click **Flush Now** (twice). It never reads file contents and makes no network requests.

**Accessibility (optional):** to put the toilet exactly next to the Trash, the app asks the Dock where its Trash icon is, which needs Accessibility access. Without it, the position is estimated from your Dock settings (icon size and how many apps are in it), which is usually within an icon or so. To allow it, click **Allow…** next to *Exact Dock Trash position* in the menu and turn on Trash Flush in *Privacy & Security › Accessibility*. The app only reads the Trash icon's position; it doesn't watch or control anything else.

**Why not the App Sandbox?** A sandboxed app can't reach `~/.Trash` at all, not even with Full Disk Access, and the folder is hidden from the open panel. So Trash Flush is a regular, non-sandboxed app with the hardened runtime. That also means it can't be sold on the Mac App Store. Distribute it as a signed, notarized download instead.

**Signing and permissions:** macOS ties Full Disk Access to the app's code signature. `build-app.sh` uses your *Apple Development* or *Developer ID* certificate if it finds one, and the permission then survives rebuilds. Without a certificate the app is signed ad hoc. That works, but every rebuild looks like a new app, so you have to turn Full Disk Access off and on again. A free Apple ID added in *Xcode › Settings › Accounts* is enough to get an Apple Development certificate (click *Manage Certificates › + › Apple Development*).

## How it works

```
~/.Trash changes ──► DispatchSource (kernel event) ──► wait 350 ms for quiet ──► scan (background)
                                                                                   │
                     FlushDetector: "had items, now has none" ◄────────────────────┘
                                   │
               ┌───────────────────┼─────────────────────┐
               ▼                   ▼                     ▼
        stats += event     OverlayPanel + FlushView   SoundPlayer
                           (4.4 s, then torn down)    (synthesized WAV)
```

- **Detecting an empty Trash** (`TrashMonitor`): a `DispatchSource` file-system object on `~/.Trash` makes the kernel wake the app only when the folder changes. Nothing polls. Finder deletes items one at a time, so changes are debounced and the folder is scanned once things go quiet. `FlushDetector` then decides whether that was an empty: the Trash had items and now has none. A single *Put Back* doesn't count, and a slow empty of a huge Trash still reports the full amount.
- **Scanning**: file I/O runs in a detached background task. Item sizes are cached by name, because things don't change while they sit in the Trash.
- **Finding the Trash** (`DockTrashLocator`): with Accessibility access it reads the frame of the Dock item whose subrole is `AXTrashDockItem`. Otherwise it estimates: the Dock is centered on its edge and the Trash is its last tile. `FlushScene` then places the toilet beside it, on the side facing the middle of the screen, and sizes the window to fit the toilet, the caption and the arc.
- **The animation** (`FlushView`, `ToiletRenderer`): one SwiftUI `Canvas` inside `TimelineView(.animation)`, rendered with Metal through `.drawingGroup()`. The toilet is a few gradient-filled paths. The water is drawn as a unit circle under a squashing transform, so the vortex arms, foam and drain look right in perspective. Files fly along eased Bézier arcs with a short fading trail, and are drawn as pre-resolved Canvas symbols. Their icons come from `FileIconCache`, which grabs each file's Finder icon (`NSWorkspace`) and a Quick Look thumbnail while the file is still in the Trash, because once the Trash is emptied the files are gone. The timing curves, arcs and spiral math live in `TrashFlushCore/Vortex.swift` and are unit-tested. The view is removed when the animation ends, so nothing renders while the app is idle.
- **The window** (`OverlayPanel`): a borderless, non-activating `NSPanel` with `ignoresMouseEvents`, at status-bar level (above the Dock), with `.canJoinAllSpaces` and `.fullScreenAuxiliary`.
- **The sound** (`FlushSynth`): noise through a two-pole low-pass filter whose cutoff sweeps down (water draining), amplitude wobble that speeds up (the vortex), a "handle" click, and sine chirps that rise in pitch (bubbles), clustered toward the final gulp. It renders in a few milliseconds into an in-memory WAV that `AVAudioPlayer` plays.

## Project structure

```
Package.swift                 Swift package: a core library, the app, and tests
Sources/TrashFlushCore/       Plain Swift (Foundation only), unit-tested
  TrashFolder.swift             list / measure / empty a Trash folder
  FlushDetector.swift           snapshots → "Trash was emptied" events
  FlushSynth.swift, WAVEncoder  the flush sound
  Vortex.swift                  animation timing, flight arcs and spiral geometry
  FlushTheme, FlushStats, TrashSnapshot
Sources/TrashFlush/           The macOS app
  TrashFlushApp.swift           @main, MenuBarExtra
  AppModel.swift                app state and actions (@Observable)
  Trash/TrashMonitor.swift      event-driven ~/.Trash watcher
  Trash/FileIconCache.swift     real icons and previews of the trashed files
  Overlay/                      finding the Dock's Trash, the panel, the SwiftUI view, the Canvas renderer, theme colors
  Menu/                         the menu bar window: button, stats, theme picker, access banner
  Effects/SoundPlayer.swift     plays the synthesized sound
  System/                       launch at login, System Settings links
Support/Info.plist            LSUIElement (no Dock icon), bundle info
scripts/build-app.sh          builds, bundles and signs TrashFlush.app
scripts/make-icon.swift       draws the app icon in code
Tests/TrashFlushCoreTests/    Swift Testing tests
```

**Why a Swift package and not an `.xcodeproj`?** `Package.swift` is a short, readable file instead of thousands of generated lines, so there are no project-file merge conflicts. Xcode opens it directly, and CI builds it with the same `swift build` you run locally. The downside is that Xcode's Run button launches a bare binary. That's why `scripts/build-app.sh` exists to make the real `.app`. The same setup is used by [Tendedero](https://github.com/alejandrobujan/tendedero), which inspired this project.

## Limitations

- Only the startup disk's Trash (`~/.Trash`) is watched. Trashes on external drives (`/Volumes/*/.Trashes`) aren't watched.
- If Finder can't delete some items (for example locked files), the Trash never reaches zero, so no flush is shown.

## Learning notes (for Swift beginners)

Things this project uses that are worth reading about, roughly in the order you'll meet them:

- **`MenuBarExtra`** (SwiftUI, macOS 13+): a whole menu bar app in a few lines. `.menuBarExtraStyle(.window)` gives a popover-like panel instead of a plain menu. `LSUIElement` in `Info.plist` hides the Dock icon.
- **`@Observable`** (macOS 14+): mark a class with it and SwiftUI views update automatically when its properties change. Use `@State` to own one and `@Bindable` to make bindings (`$model.theme`) to its properties.
- **`@MainActor` and Swift 6 concurrency**: UI state lives on the main actor. Slow work (file I/O, rendering audio) runs in `Task.detached` and hands back a `Sendable` value, like `TrashSnapshot`, a plain struct. The compiler checks all of this for you in Swift 6 mode.
- **Event-driven instead of polling**: `DispatchSource.makeFileSystemObjectSource` asks the kernel to notify you. That's why the app uses no CPU while it waits.
- **AppKit where SwiftUI stops**: SwiftUI can't make a click-through, focus-less window that floats over full-screen apps, so `OverlayPanel` subclasses `NSPanel` and hosts the SwiftUI view with `NSHostingView`.
- **`Canvas` + `TimelineView`**: the fastest way to draw lots of moving shapes in SwiftUI. You get a drawing context and a time value, and you draw a frame.
- **Keep logic testable**: anything that doesn't need a screen lives in `TrashFlushCore`, and `swift test` checks it in under a second. Try changing the spiral in `Vortex.swift`, or the sound in `FlushTheme.sound`, and run the tests.
- **TCC (privacy permissions)**: macOS remembers permissions per code signature. That explains most "it worked yesterday" permission puzzles.

## License

[MIT](LICENSE). Inspired by [Tendedero](https://github.com/alejandrobujan/tendedero) by Alejandro Buján.

# Trash Flush

A tiny macOS menu bar app that makes your MacBook's notch eat your trash. Every time you empty the Trash, your files fly up out of the Dock and the notch gulps them down.

<!-- TODO: replace with a real recording: docs/demo.gif (Cmd+Shift+5 → record a portion, then convert with `ffmpeg` or Gifski) -->
<p align="center">
  <img src="docs/demo.gif" alt="Demo: emptying the Trash makes the file icons arc up from the Dock into the notch, which swallows them and grows into an island saying how much was freed" width="420">
</p>

Empty the Trash the usual way (Finder, ⌘⇧⌫, right-click the Dock icon). The real icons of what you deleted pop out of the Trash in your Dock and arc up the screen. The notch opens like a mouth and swallows them one by one, then grows into a little island that says "Flushed 12 items · 734 MB freed" as confetti bursts out. Then the app goes back to sleep.

## Features

- **A menu bar Trash that fills up**: the icon fills as your Trash does. Past the size you pick in the menu (5 GB by default), its lid pops open and flies buzz around it until you flush.
- **Notch animation**: the files are the real icons of what you deleted (Finder icons, and Quick Look previews for photos and documents). They climb up out of the Dock's own Trash (or, with the Dock hidden, a stand-in that peeks up from the screen edge, bounces as it throws each one and turns empty after the last). They fan out along springy arcs, stretch as they speed up and shrink into the notch, which opens wider as each one arrives and bounces as it gulps. Past 12 files the rest follow as a quick stream of small icons.
- **Garbage truck animation** (pick it under *Animation* in the menu): a little green truck drives in along the Dock and brakes by the Trash, beacon blinking. Your files hop out of the Trash into its hopper, the door chomps twice, and after a "beep beep" it drives off the other way, puffing exhaust. A receipt pops up over the Trash: "Picked up 12 items · 734 MB freed". It works with the Dock on any edge.
- **Toilet flush animation**: a 🚽 springs up next to the Dock's Trash, bowl turned to face it. Your files arc out of the Trash and drop into the bowl, and the toilet bounces under each one. Then it flushes: water splashes out of the bowl and the toilet rumbles before it shrinks away and the receipt pops up.
- **Works on every setup**: Macs without a notch, and external displays, get a black pill at the top of the screen instead. With an auto-hidden Dock, a stand-in Trash peeks up from the screen edge, throws the files and slides back down. The Dock can be at the bottom, left or right.
- **Gulp sound**: generated in code. Each gulp is a soft water-drop note a step higher on a pentatonic scale, so a big empty plays a little rising melody, finished by a bell chord. No audio files ship with the app.
- **Find Junk**: one click lists what's safe to throw away: installers (DMG, PKG, ZIP, XIP, ISO) in Downloads and screenshots older than a week, Xcode's DerivedData, old device support files and simulator caches, and app caches over 100 MB. Results show up while the scan is still running. Everything starts checked; untick what you want to keep (right-click an item to show it in Finder), move the rest to the Trash, and flush.
- **Flush Now** in the menu: empties the Trash with the animation. You click twice to confirm, so there is no modal dialog to get in the way.
- **Stats**: number of flushes, items flushed, space freed and when you last flushed. Right-click the stats to reset them.
- **Doesn't get in your way**: the overlay is click-through, never takes keyboard focus and shows on every Space (full-screen apps included), on the display that has the Dock.
- **Sound toggle**, **launch at login** (`SMAppService`), and **Reduce Motion** support (no flying files or confetti, only the island).
- **Light on resources**: about 0% CPU when idle and no network access.

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

**Accessibility (optional):** to launch the files from exactly where the Trash is, and to keep following it if the Dock shifts during the animation (say an app opens), the app asks the Dock where its Trash icon is, which needs Accessibility access. Without it, the position is estimated from your Dock settings (icon size and how many apps are in it), which is usually within an icon or so. To allow it, click **Allow…** next to *Exact Dock Trash position* in the menu and turn on Trash Flush in *Privacy & Security › Accessibility*. The app only reads the Trash icon's position; it doesn't watch or control anything else.

**Why not the App Sandbox?** A sandboxed app can't reach `~/.Trash` at all, not even with Full Disk Access, and the folder is hidden from the open panel. So Trash Flush is a regular, non-sandboxed app with the hardened runtime. That also means it can't be sold on the Mac App Store. Distribute it as a signed, notarized download instead.

**Signing and permissions:** macOS ties Full Disk Access to the app's code signature. `build-app.sh` uses your *Apple Development* or *Developer ID* certificate if it finds one, and the permission then survives rebuilds. Without a certificate the app is signed ad hoc. An ad hoc signature normally identifies one exact build, so every rebuild would look like a new app: System Settings keeps showing Trash Flush as allowed while the new build isn't. To avoid that, `build-app.sh` gives ad hoc builds a designated requirement of just the bundle identifier, so Full Disk Access and Accessibility survive rebuilds on your Mac. If you ever see a permission that is on but doesn't work, run `tccutil reset Accessibility dev.trashflush.TrashFlush` (or `SystemPolicyAllFiles` for Full Disk Access) and grant it again. A free Apple ID added in *Xcode › Settings › Accounts* is enough to get an Apple Development certificate (click *Manage Certificates › + › Apple Development*).

## How it works

```
~/.Trash changes ──► DispatchSource (kernel event) ──► wait 350 ms for quiet ──► scan (background)
                                                                                   │
                     FlushDetector: "had items, now has none" ◄────────────────────┘
                                   │
               ┌───────────────────┼─────────────────────┐
               ▼                   ▼                     ▼
        stats += event   OverlayPanel + NotchFlushView   SoundPlayer
                         (~4 s, then torn down)          (synthesized WAV)
                                   └──── same NotchTimeline ────┘
```

- **Detecting an empty Trash** (`TrashMonitor`): a `DispatchSource` file-system object on `~/.Trash` makes the kernel wake the app only when the folder changes. Nothing polls. Finder deletes items one at a time, so changes are debounced and the folder is scanned once things go quiet. `FlushDetector` then decides whether that was an empty: the Trash had items and now has none. A single *Put Back* doesn't count, and a slow empty of a huge Trash still reports the full amount.
- **Scanning**: file I/O runs in a detached background task. Item sizes are cached by name, because things don't change while they sit in the Trash.
- **Finding the Trash** (`DockTrashLocator`): with Accessibility access it reads the frame of the Dock item whose subrole is `AXTrashDockItem`. Otherwise it estimates: the Dock is centered on its edge and the Trash is its last tile. If the Dock is set to hide, it uses the spot where the Trash sits once the Dock slides out.
- **Finding the notch** (`NotchScene`): `NSScreen.safeAreaInsets` gives the notch's height, and `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` (the menu bar on either side) give its width. Screens without one get a pill.
- **The timeline** (`TrashFlushCore/NotchTimeline.swift`): `NotchTimeline` works out when each file launches and lands, and when the island opens and closes. The notch moves on damped springs that get a kick each time it swallows a file. `NotchMotion` computes their state as a pure function of time, by re-running the springs from zero at a fixed step every frame (under a thousand steps), so the renderer holds no mutable state and the motion is unit-tested.
- **The animation** (`NotchFlushView`): one `TimelineView(.animation)`. The files are pre-resolved symbols in a `Canvas` rendered with Metal through `.drawingGroup()`, flying along eased Bézier arcs. The black notch is drawn on top of them, so they vanish as they reach it. Their icons come from `FileIconCache`, which grabs each file's Finder icon (`NSWorkspace`) and a Quick Look thumbnail while the file is still in the Trash, because once the Trash is emptied the files are gone. The confetti is a [Lottie](https://github.com/airbnb/lottie-ios) animation. The view is removed when the animation ends, so nothing renders while the app is idle.
- **The window** (`OverlayPanel`): a borderless, non-activating `NSPanel` covering the screen, with `ignoresMouseEvents`, above the menu bar (so it can draw over the notch), with `.canJoinAllSpaces` and `.fullScreenAuxiliary`.
- **The sound** (`GulpSynth`): rendered from the same timeline, so every note lands on its gulp. Each gulp is a sine that glides up into its pitch in about 20 ms (the shape of a water drop) with a touch of octave, climbing a pentatonic scale. A low thump starts it and a bell arpeggio ends it, with one soft echo. It renders in a few milliseconds into an in-memory WAV that `AVAudioPlayer` plays.
- **The truck** (`TruckTimeline`, `TruckSynth`, `TruckFlushView`): built the same way. `TruckMotion` runs springs for the body's sag, the braking pitch and the hopper door, again as a pure function of time. The truck is drawn in code in its own coordinates and turned to sit on whichever edge the Dock is on. Its sound is an engine hum that idles and revs, a wooden "tok" per file on the same scale an octave lower, two clunks for the chomps, a horn and the bell.
- **The flush** (`ToiletTimeline`, `ToiletSynth`, `ToiletFlushView`): the toilet is Apple's own 🚽 emoji, drawn once from the system emoji font and trimmed to its pixels, then flipped so the bowl faces the Trash. Springs give it its pop, overshoot and squash under each file, and files go behind it for the last part of their arc so they look like they drop into the bowl. Each file lands with a plop that falls in pitch, and the flush is a wobbling, falling gurgle full of bubbles.
- **Find Junk** (`JunkScanner`, `DiskUsage`, `FlushSuggestions`): the four categories are scanned at once and every candidate is measured in its own task, handed to the list the moment it's done. Measuring folders is the slow part, so `DiskUsage` reads each directory with `getattrlistbulk` (names, types and sizes in bulk, no `stat` per file) and walks subfolders in parallel. On a 20 GB caches folder with 60,000 subfolders that takes about 3 seconds, against 17 with `fts` and 19 with `FileManager`. Items go to the Trash with `FileManager.trashItem`, so nothing is deleted until you flush.

## Project structure

```
Package.swift                 Swift package: a core library, the app, and tests
Sources/TrashFlushCore/       Plain Swift (Foundation only), unit-tested
  TrashFolder.swift             list / measure / empty a Trash folder
  FlushDetector.swift           snapshots → "Trash was emptied" events
  NotchTimeline.swift           animation timing, notch springs and flight arcs
  GulpSynth.swift, WAVEncoder   the gulp sound
  TruckTimeline, TruckSynth     the garbage truck's timing, springs and sound
  ToiletTimeline, ToiletSynth   the toilet flush's timing, springs and sound
  TrashFullness.swift           how full the menu bar Trash looks
  JunkScanner, DiskUsage        finding safe junk and measuring folders fast
  FlushStats, TrashSnapshot
Sources/TrashFlush/           The macOS app
  TrashFlushApp.swift           @main, MenuBarExtra
  AppModel.swift                app state and actions (@Observable)
  Trash/TrashMonitor.swift      event-driven ~/.Trash watcher
  Trash/FileIconCache.swift     real icons and previews of the trashed files
  Resources/confetti-burst.json the confetti (Lottie)  Overlay/                      finding the Dock's Trash and the notch, the panel, the SwiftUI view, confetti
  Menu/                         the menu bar window: button, stats, access banner
  Suggestions/                  Find Junk: the scan, the review list
  Effects/SoundPlayer.swift     plays the synthesized sound
  System/                       launch at login, System Settings links
Support/Info.plist            LSUIElement (no Dock icon), bundle info
scripts/build-app.sh          builds, bundles (with Lottie.framework) and signs TrashFlush.app
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
- **`@Observable`** (macOS 14+): mark a class with it and SwiftUI views update automatically when its properties change. Use `@State` to own one and `@Bindable` to make bindings (`$model.soundEnabled`) to its properties.
- **`@MainActor` and Swift 6 concurrency**: UI state lives on the main actor. Slow work (file I/O) runs in `Task.detached` and hands back a `Sendable` value, like `TrashSnapshot`, a plain struct. The compiler checks all of this for you in Swift 6 mode.
- **Event-driven instead of polling**: `DispatchSource.makeFileSystemObjectSource` asks the kernel to notify you. That's why the app uses no CPU while it waits.
- **AppKit where SwiftUI stops**: SwiftUI can't make a click-through, focus-less window that floats over full-screen apps, so `OverlayPanel` subclasses `NSPanel` and hosts the SwiftUI view with `NSHostingView`.
- **`Canvas` + `TimelineView`**: the fastest way to draw lots of moving shapes in SwiftUI. You get a drawing context and a time value, and you draw a frame.
- **Keep logic testable**: anything that doesn't need a screen lives in `TrashFlushCore`, and `swift test` checks it in under a second. Try changing the spring kicks in `NotchMotion`, or the scale in `GulpSynth`, and run the tests.
- **TCC (privacy permissions)**: macOS remembers permissions per code signature. That explains most "it worked yesterday" permission puzzles.

## License

[MIT](LICENSE). Inspired by [Tendedero](https://github.com/alejandrobujan/tendedero) by Alejandro Buján.

The confetti is [Confetti Burst](https://lottiefiles.com/free-animation/confetti-burst-4zag06zOt1) by Ann Sniechowski, under the [Lottie Simple License](https://lottiefiles.com/page/license).
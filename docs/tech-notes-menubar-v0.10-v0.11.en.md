# Tech notes: reading menu bar icons and the bar under the notch (v0.10.0 – v0.11.0, archived)

[English](tech-notes-menubar-v0.10-v0.11.en.md) · [한국어](기술노트_메뉴막대_v0.10-v0.11.md)

Written: 2026-11-24 · Status: **removed from 1.0.** In daily use it was less useful than expected, so 1.0 was built from 0.9.0 (owner's decision).
Where the code is kept (only on the developer's Mac, not published to GitHub): Git branch `archive/menubar-v0.11` (commit `d48b3cf`), tags `v0.10.0`, `v0.10.1`, `v0.11.0`, plus a full-history backup bundle.
To reuse it: `git switch archive/menubar-v0.11` (to look) or take single files with `git checkout archive/menubar-v0.11 -- <file>`.

---

## 1. What was built

| Version | Feature |
|---|---|
| v0.10.0 | A 4th drawer tab, "Menu Bar" (F4). Lists other apps' menu bar icons (hidden / visible); clicking a row opens that app's menu. Apps collapsed behind "≪" are expanded first, then opened |
| v0.10.1 | Separate bundle ID for the development (Debug) build, `local.toptiroir.app.dev`, data folder `TopTiroir-Dev` (developer convenience, unrelated to the menu bar) |
| v0.11.0 | A 28 pt "second bar" right under the notch. Shows only the hidden icons as real captured images; clicking opens that app's menu |

## 2. Techniques used and what we learned

### 2-1. Reading other apps' menu bar icons — Accessibility (AX)
- **How**: `AXUIElementCreateApplication(pid)` → attribute `kAXExtrasMenuBarAttribute` (the app's status items on the right side) → `kAXChildrenAttribute` for the list of items → each item's `kAXPositionAttribute` / `kAXSizeAttribute` (position, size) and `kAXTitle/Description/Help` (label).
- **Permission**: Accessibility. Check with `AXIsProcessTrusted()`; settings URL `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
- **Avoiding hangs**: `AXUIElementSetMessagingTimeout(app, 0.25)` so one unresponsive app can't stall everything. Reading happens off the main thread.
- **Pressing**: `AXUIElementPerformAction(item, kAXPressAction)` → opens that app's menu. Some apps don't respond to it.
- **What doesn't work**: the old approach (finding layer-25 windows in the window list) found nothing on macOS 27.2. **macOS does not let apps move or remove other apps' icons.**
- **Coordinates**: AX coordinates have their origin at the top-left of the main screen (y grows downward); AppKit (NSScreen) uses the bottom-left. Conversion: `MenuBarItems.axTop(primaryHeight:screenMaxY:)`.

### 2-2. Deciding which icons are "hidden" — found after three failed attempts
1. **By position (failed)**: hidden if inside the notch range or off screen → macOS never places icons inside the notch; it pushes them toward the front app's menu titles, so position alone can't tell.
2. **Hit-testing (failed)**: correct in a standalone test app, but inside the app every icon looked hidden, because this app's own band and drawer windows answered the hit test.
3. **End of the front app's menus**: icons to the left of the rightmost edge (`maxX`) of the front app's `kAXMenuBarAttribute` children are covered by its menu titles.
4. **The real cause — icons collapsed with "≪"**: apps hidden with macOS's "hidden menu bar items" button (the ≪ button of MenuBarAgent) **disappear from the AX tree entirely** (read error -25212). So the app **remembers every app whose icons were read at least once**, by bundle ID (setting `menuBarKnown`, JSON); a remembered app that is running but can't be read now is "hidden".
   - Finding the ≪ button: the **leftmost** item of the app with bundle ID `com.apple.MenuBarAgent` (an assumption that may change with macOS updates). Pressing it with `kAXPressAction` toggles expanded/collapsed.
   - Opening a collapsed app: press ≪ to expand, wait up to 3 s, then press that app's icon. It doesn't collapse again automatically (that could close the menu that just opened).
   - Limitation: the memory starts empty, so the user has to expand ≪ once.

### 2-3. Capturing icon images — ScreenCaptureKit
- `SCScreenshotManager.captureImage(in: CGRect)` captures **only one icon cell (the middle 24 pt of the menu bar)**, never the whole screen.
- **Permission**: Screen Recording. Check with `CGPreflightScreenCaptureAccess()` (doesn't prompt), request with `CGRequestScreenCaptureAccess()` (macOS asks only the first time), settings URL `…?Privacy_ScreenCapture`.
- Images live **in memory only** (never written to files or UserDefaults, never logged). Images captured on the notched screen take priority; re-captured after 60 s; discarded when switching dark/light. If capture isn't possible, the app icon (`NSWorkspace`) is shown instead.
- Step-1 test: a temporary "Capture" button in the dev build confirmed 15/15 successful captures on the notched screen, then the test code was removed — a good example of the "try new technology in a small test first" rule.

### 2-4. The bar window under the notch — NSPanel
- `NSPanel(styleMask: [.borderless, .nonactivatingPanel])` — clicking it doesn't bring this app forward (it needs to open another app's menu).
- `level = .statusBar`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`.
- **Hidden in full-screen apps**: simply **leaving out** `.fullScreenAuxiliary` keeps it from appearing over full-screen apps (no extra detection code needed).
- Refresh: a 10 s timer (2 s tolerance) + `NSWorkspace` notifications (app launch/quit, Space change) after 1 s.
- Background: captured images include the menu bar color as their background, so a solid band color looked more natural than glass (Liquid Glass).
- Limitation: it can cover the middle of a maximized window's title bar.

### 2-5. Development build separation (v0.10.1) — worth reusing in 1.0 (and reused)
- In `project.yml`, only Debug uses bundle ID `local.toptiroir.app.dev`, name "TopTiroir Dev", executable `TopTiroirDev`.
- Settings (UserDefaults), permissions, and login items are per bundle ID, so they separate automatically. The data folder is separated in code (`AppIdentity.supportFolderName`) as `TopTiroir-Dev`.
- Because of ad-hoc signing, the dev build may lose its permissions (Accessibility, Screen Recording) after each rebuild.

## 3. Related files (in the archive branch)
```
Core/MenuBarItems.swift      hidden detection, sorting, memory (MenuBarKnown), bar width (pure functions)
Core/AppIdentity.swift       dev vs. installed build (v0.10.1)
System/MenuBarReader.swift   AX reading, pressing, the ≪ button
System/MenuBarSnapshot.swift ScreenCaptureKit single-cell capture
Drawer/MenuBarModel.swift    tab state, periodic refresh
Drawer/MenuBarTabView.swift  Menu Bar tab UI
Screen/HiddenBarPanel.swift  bar window under the notch
TopTiroirTests/V0100Tests.swift, V0110Tests.swift
기획_v0.11.0_두번째막대.md      (design doc, Korean)
```

## 4. If it comes back
- Show the bar only when the mouse is near the notch (fixes covering title bars).
- Needing two permissions (Accessibility and Screen Recording) is the biggest burden; turn them on only when really needed.
- Re-check how the ≪ button is identified after every macOS update.

# TopTiroir Development Log

[English](DEVLOG.en.md) · [한국어](DEVLOG.md)

> English translation of `DEVLOG.md`. The Korean log is the original; if the two differ, the Korean one is correct.
> UI labels are given in English as they appear in the English UI. "Drawer" is the glass panel that drops down from the notch.

## v1.0.0 (build 16) — 2026-11-24 · confirmed by user, committed and tagged v1.0.0
Built on top of v0.9.0 commit `83faa2a`. Topic: **declare the v0.9.0 feature set as 1.0** (owner's decision).
- **Why**: The Menu Bar tab and the bar under the notch (v0.10.0–v0.11.0) turned out to be less useful than expected in daily use. v0.9.0 already contained every feature originally wanted, so it becomes 1.0 and future work builds on it.
- **Archived**: The menu bar code is kept in a local Git branch and tags (not published to GitHub). The techniques used are written up in `docs/tech-notes-menubar-v0.10-v0.11.en.md`.
- **Brought back**: only the development-build separation from v0.10.1 — the Debug build uses bundle ID `local.toptiroir.app.dev`, name "TopTiroir Dev", executable `TopTiroirDev`, and data folder `TopTiroir-Dev` (it never touches the real notes and favorites). Settings › About shows "· dev build".
- **Changed**: version 1.0.0 / build 16 (higher than build 14 of the previously installed 0.10.1). README in English and Korean (menu bar features removed; no special permissions needed), MIT license (`LICENSE`).
- **Existing data**: the notes/favorites file format is the same in 0.9–0.11, so data carries over. If "Menu Bar" was remembered as the last tab, the drawer opens on Notes instead (test added). Settings left by 0.10–0.11 (`menuBarKnown`, etc.) are simply ignored.
- Tests +3 (dev-build detection, data folder, old tab value).

## v0.9.0 (build 12) — 2026-11-24 · confirmed by user, committed and tagged v0.9.0
After v0.8.0 commit `3d53168`. Topic: quick memo shortcut.

### Built
1. **Quick memo shortcut** (default ⌃⌥M, global): from anywhere, opens the drawer on the Notes/To-dos tab with the text cursor at the end of the memo. If the drawer is already open, it doesn't close it — it switches to the Notes tab and places the cursor (unlike the open-drawer key).
2. A "Quick memo" row in the "Drawer" section of the shortcuts window (Settings › View shortcuts…) — changing, resetting to default, and conflict checks work like the open-drawer key (needs ⌘ or ⌃; shows "Couldn't change it" if another app uses the key, "Unavailable" if it can't be registered).
3. Internals: `HotKey` instances are now identified by number (`id`) so several global keys can be registered. Shortcut entries have `isGlobal` (open drawer, quick memo). The memo field takes the cursor when `focusRequest` increases.
- Version 0.9.0 / build 12. 133 tests pass, 0 warnings.

### To check (screen interaction not verified directly)
- [ ] While using another app, ⌃⌥M opens the drawer and typing goes straight into the memo
- [ ] With the drawer open on Favorites or Settings, ⌃⌥M switches to Notes and places the cursor
- [ ] Changing the quick memo key, default, conflict messages in the shortcuts window; F12 still works
- [ ] The changed key survives a relaunch; English UI text

### Known limitations
- If ⌃⌥M conflicts with another app it is not registered and shows "Unavailable" (change the key).

## v0.8.0 (build 11) — 2026-11-24 · confirmed by user, committed and tagged v0.8.0
After v0.7.0 commit `eae2b83`. Topic: "Close drawer after opening" setting.

### Built
1. **Settings › Behavior › "Close drawer after opening"** switch (default off). When on, the drawer (and folder windows) close as soon as an app, file, folder, or web link from Favorites finishes opening. When off, the existing "stay open after launch" behavior remains (closes once the mouse stays outside the drawer for 0.4 s — handy for opening several items in a row).
2. Settings key `closeOnOpen`. 2 English strings added. 132 tests pass.
- Version 0.8.0 / build 11.

### To check
- [ ] Off: after opening an app the drawer stays, then closes when the mouse leaves (as before)
- [ ] On: opening an app/file/link/folder closes the drawer and folder windows immediately
- [ ] Expanding/collapsing a favorites folder never closes it; nothing opens in edit mode
- [ ] English UI text

## v0.7.0 (build 10) — 2026-11-24 · confirmed by user, committed and tagged v0.7.0
After v0.6.0 commit `0bbc848`. Topic: reorder to-dos + auto-scroll while dragging.

### Built
1. **Reorder to-dos**: **drag the row itself** to a new place (no handle — changed from a handle to the whole row after the first test round; double-click editing still works, dragging is disabled while editing; the ✓ and × buttons don't start a drag). The drop position is shown as an orange line above a row (nearest slot boundary); the dragged row is dimmed. While dragging, an empty slot appears at the bottom so items can be moved to the end. Dropping in place does nothing. The new order is saved 0.8 s later, like the memo.
2. **Auto-scroll while dragging**: when the pointer is within 28 pt of the top/bottom edge of the to-do list, it scrolls faster the closer it is (up to 420 pt/s). Ends when the mouse is released (even with no drop target). Reopening the drawer resets the drag state.
3. Logic in Core: `NotesDocument.moveTodo(id:toSlot:)`, `TodoDrag.slot`, `TodoDrag.autoScrollSpeed`. Drag-only type `local.toptiroir.todo` (the memo and favorites don't accept it as text/file; it never leaves the app).
4. Hover help now mentions "Drag to reorder" (Korean and English).
- Version 0.7.0 / build 10. 131 tests pass, 0 compiler warnings.

### To check
- [ ] Dragging a to-do row shows the orange line and reorders on drop
- [ ] Move to top/bottom, drop in place (no change)
- [ ] With ~20 to-dos, dragging to the top/bottom edge scrolls; stopping stops the scroll
- [ ] Dropping outside the list (e.g. on the memo) changes nothing and the row is un-dimmed
- [ ] Order survives closing/reopening the drawer; English help text
- [ ] Checking off, double-click editing, × delete work as before

### Known limitations
- Row height is computed for single-line rows; while a multi-line row is being edited, drop positions below it may be slightly off (dragging is off while editing anyway).
- If the mouse doesn't move during scrolling, the orange line follows the scroll but there is no separate row highlight.

## v0.6.0 (build 9) — 2026-11-24 · awaiting user test
After v0.5.0 commit `ca7988b`. Topic: English UI (String Catalog).

### Built
1. **Language rule**: follows the Mac's system language — **Korean shows Korean, every other language shows English** (`CFBundleDevelopmentRegion=en`, `CFBundleLocalizations=[en, ko]`; unsupported languages like Japanese or French fall back to English — verified fr→en, ja→en, ko→ko).
2. **Translation table** `TopTiroir/Resources/Localizable.xcstrings`: keys are the Korean strings in the code, 241 English translations. The code barely changed.
3. **Plain strings** (tab names, error/notice text, shortcut names, time display — anything used as `String`) are wrapped in `String(localized:)` (~100 places). SwiftUI `Text("…")`, `Button("…")`, `.help("…")` are translated automatically.
4. Build settings: `LOCALIZATION_PREFERS_STRING_CATALOGS`, `SWIFT_EMIT_LOC_STRINGS`.

### Not translated
- Developer logs/debug text, the backup file name (`TopTiroir-백업-date.json`), the sleep-prevention reason, the favorites type description (Info.plist).
- Korean counters after numbers are written as `item(s)` in English (no plural variants).

### To check
- On a Korean Mac everything looks the same as before; switched to English (below), every screen is in English and nothing overflows.
- English check: quit the installed app, then `open -n build/.../TopTiroir.app --args -AppleLanguages "(en)"`.

## v0.5.0 (build 8) — 2026-11-24 · awaiting user test
v0.4.0 committed: `4b51a9a`, tag `v0.4.0`. Topic: proper installation and stabilization.

### Built
1. **Install script `Tools/install.sh`** (Mac Terminal, in the project folder: `./Tools/install.sh`): xcodegen → tests → Release build (signature check) → ask the running app to quit (stops if it doesn't within 10 s) → move the old `/Applications/TopTiroir.app` to the Trash (`/usr/bin/trash`) → install with `ditto` → refresh the icon with `lsregister` → move the build folder to the Trash → launch. Options `--skip-tests`, `--keep-build`. Paths and bundle ID live in one settings block at the top. No `rm` is used.
2. **Re-register launch at login**: macOS remembers the login item by "the app's location at registration". The location is stored in `loginItemPath` when enabled; at startup, if launch at login is on and the stored location differs from the current one (installed app only), it re-registers once. Development builds (build folder) don't change it. Rules in Core `LoginItemPolicy`, tested. Verified with `sfltool dumpbtm` that after install the login item moved from the build folder to `/Applications/TopTiroir.app`.
3. **Export/import notes and favorites** (Settings › Manage):
   - "Export…": save panel → one file `TopTiroir-백업-YYYY-MM-DD.json` (memo, to-dos, favorites; permissions 600). The save panel notes that the memo text is stored as-is.
   - "Import…": choose file → format check (TopTiroir backup marker and version; files over 20 MB are not read) → a confirmation row in Settings (file date and summary, current summary, checkboxes "Replace notes/to-dos" and "Replace favorites") → nothing changes until "Import" is pressed. The state just before replacing is saved to notes.backup.json / favorites.backup.json, and if that backup fails nothing is replaced. If saving was halted because the original file couldn't be read, import is refused. Favorites folders deeper than 3 levels are pulled up; open folder windows and edit mode are closed.
   - Apps, files, and Finder folders in favorites are stored as bookmark + path → found again on the same Mac. On another Mac, missing paths show dimmed as "Can't find it".
   - Format, validation, and summary are in Core `BackupFile`, tested.
4. **App size**: Release built for arm64 only (`ARCHS: arm64`, Apple silicon only) → 7.8 MB → 4.0 MB.
- Version 0.5.0 / build 8. 124 tests pass, 0 compiler warnings (xcodebuild's "AppIntents metadata skipped" line is a tool message).
- Cleanup: build folder (~312 MB) moved to the Trash. Space is reclaimed only after emptying the Trash.

### First test round fixes — 2026-11-24 (after all checks passed)
1. **Open/save panel position on external displays**: "Export…", "Import…", and "Choose apps, files, folders…" panels appear centered (slightly above) on the screen where the drawer is open (Core `Layout.centeredOrigin`, clamped inside if larger than the screen). If the panel lands at its old position after appearing, it is moved once more. All three use the same helper (`present`).
2. **Choosing an import file closed the drawer**: likely cause — open/save panels are drawn by a separate out-of-process service, so clicks inside them are reported as "clicks in another app" and the outside-click monitor closed the drawer. Favorites selection only happens in edit mode (auto-close off), so it never showed there. → No outside-click closing while a panel is open and for 0.7 s after it closes (`filePanelOpen`). esc, F12, notch click still close.
- 126 tests pass. External displays and real clicks not verified directly — needs user check.

### Known limitations
- The development build (Debug in the build folder) and the installed app share the bundle ID, data, and settings → running both at once overlaps the notch band and shortcuts. Quit the installed app when running the dev build. (Fixed in v0.10.1 / 1.0.0 by a separate dev bundle ID.)
- Import "replaces" (the chosen parts entirely); it does not merge.
- Backup files are not encrypted (memo text is readable).

## v0.4.0 (build 7) — 2026-11-24 · confirmed by user, committed and tagged v0.4.0
v0.3.0 committed: `bb4a470`, tag `v0.3.0`.

### Built (Favorites tab, per mockup "5. Favorites")
1. **List**: rows 24 pt (× text size), a 14 pt line icon on the left (folder = orange folder, dark #F5A623 / light #E08E12; Finder folder = gray folder #7C8090; app = rounded square; web link = globe; file = folded page), name (truncated with …), "›" for folders. A divider and an orange "+ Add…" at the bottom. A centered hint when empty. Scrolls inside the tab when it overflows. The open folder's row is highlighted (dark: white 16%, light: white 85% + soft shadow).
2. **Storage**: `favorites.json` (same folder as notes, 600). Apps, files, and folders store only bookmark data + path (nothing is copied) → still found after moving or renaming (stale bookmarks are refreshed). Missing or trashed items are dimmed; clicking shows "Can't find it". Saved 0.8 s after changes, and immediately when the drawer closes or the app quits. An unreadable file is moved aside, never deleted.
3. **Click**: launch app (NSWorkspace.openApplication), file in its default app, folder in Finder, web link in the default browser → the drawer closes (assumed). Favorites folder → list window. Web links: http/https only (https is added when no scheme; file:, javascript:, and custom schemes are refused). Items open only on click, never automatically.
4. **List window on the right**: a panel attached to the right of the drawer (doesn't steal focus), flipped to the left if it would go off screen. "Name · N items" (11 pt bold) + rows (24 pt, 12 pt text, 12 pt icon) + "+ Add…". Height fits the item count up to 450 pt (scrolls inside beyond that). Width 168 pt × drawer size, padding 6, corner 14, same glass/color/opacity as the drawer. Nested folders open one column further right (max 3 columns; deeper replaces the third column's contents); another folder → replace; the same folder again → close. Closed on drawer close or tab change (`closeAuxiliaryWindows`). esc closes the innermost window first, then the drawer.
5. **Add and organize**: "+ Add…" menu — Choose apps, files, folders… (NSOpenPanel, multiple selection, drawer stays open meanwhile) / Add web link… (inline row in the drawer: name and URL) / New folder… (name). Items are added to the list being viewed. Drag and drop from Finder or a browser (onto a folder row puts it inside; the target gets an orange outline). Right-click, or the "…" shown on hover: Rename / Move up / Move down / Remove from list (the real file is untouched). Folders that contain items ask for confirmation. Duplicates in the same list show "Already there". One `favorites.backup.json` with the state just before delete/rename.
- Logic (list model, duplicates, URL validation, window height/position, depth, click action, kind detection, file reading) in Core; opening goes through the `FavoriteOpening` protocol. 98 tests pass, 0 build warnings.
- Store tests (temp folder, fake opener): kind detection, duplicate notice, URL rejection, finding a moved file via bookmark, trashed file "Can't find it", backup file and permission 600, re-read. No real apps/files/browsers were opened.
- A test harness (same code) captured 2 list-window columns and 16-item scrolling. The favorites.json made for capture was moved to the Trash so no test data remained in user data.

### First test round fixes — 2026-11-24
1. **Edit mode**: an "Add" button at the top of the list (renamed "Edit" in round 2; the "+ Add…" row at the bottom removed) → edit mode. One shared state whether started from the drawer or a folder window. While editing: "✎ Editing" + orange "Save" at the top, below it custom buttons "Choose in Finder…" (NSOpenPanel), "Web link", "New folder", and a "≡" on each row. Clicking outside doesn't close the drawer (so you can drag from Finder). Clicking an item doesn't open apps/files/links (only opens/closes folder windows). esc closes the innermost folder window, otherwise does nothing. Closing via F12/notch or switching tabs ends edit mode (changes are saved as they happen). "Save" = finish saving + leave edit mode. Rules tested in Core `FavoritesEditRules` (auto-close, esc, click, state transitions).
2. **Terminology**: "bundle" → "folder" (UI, notices, menus, DEVLOG). File-system folders are called "Finder folder" where the distinction matters (panel hint, delete menu "real files and Finder folders are kept", button "Choose in Finder…"). Icons differ too (favorites folder orange, Finder folder gray).
3. **3 folder levels**: new folders up to level 3 (no folders inside a level-3 folder; apps, files, links, Finder folders are fine). Exceeding shows an in-drawer notice ("Folders can only be 3 levels deep", closes on OK or after 4 s). Moving checks the moved folder's inner depth too; a folder can't be moved into itself. List windows max 3 columns (the old "replace the third column from the fourth" rule removed). On load, folders deeper than 3 levels are backed up to favorites.backup.json and pulled up one level at a time, never deleted — the user's data was empty this time, so 0 folders moved.
4. **Folder window height**: measures title + fixed rows (top buttons, input row) + items (including rename/delete confirmation rows); stops at 450 pt and scrolls only the items (input row and buttons stay pinned). Shrinks again when the input row closes. Flipping left is recalculated every time.
5. **App icons**: app rows show the real app icon (drawer 14 pt, folder window 12 pt; downscaled from 2× and cached). Missing apps show the line icon, dimmed.
6. **Drag to reorder**: in edit mode drag a row (or ≡) to reorder within a list (orange line at the drop position); dropping on a folder row moves it inside; moving between the drawer list and folder windows works. State is backed up before moving. Right-click "Move up/down" remains.
- 107 tests pass (depth, moving, cleanup, edit-mode rules, window height), 0 build warnings. Captured with temp-folder data in the test harness (edit-mode drawer, 3-column folder windows, app icons), then deleted. User data untouched.

### Second test round fixes — 2026-11-24
1. **Dragging a row showed the "http or https…" notice**: cause — row drag data was plain text (NSString "toptiroir-favorite:…"), which can also be read as a URL (it has a scheme), so the "drop from outside" path treated it as a web link and the http/https check rejected it. The notice was also one shared value, so it showed in both the drawer and folder windows. → Drag only with an app-private type (`local.toptiroir.favorite`, declared in Info.plist, visible only inside this app); a drop carrying it is always treated as a move (Core `FavoriteDrop.classify`, tested). The notice shows only in the window where it happened (`noticeLevel`).
2. Edit-mode button "Add" → "Edit" (hint text and tooltip too).
3. The "Choose in Finder" button is icon-only, name in the tooltip.
4. The reorder handle ≡ moved right after the icon (before the name), edit mode only. Only dragging the handle moves the row (pressing the name doesn't start a drag).
5. Removed the "…" button at the row's right (it overlapped the folder "›"). Rename/delete are right-click only.
6–7. The right-click menu has two items, "Rename" and "Remove from Favorites" (Move up/down removed). The confirmation row also says "from Favorites" (the real file is kept).
8. **Apps and Finder folders needed two clicks to open**: likely cause — the drawer is a window that doesn't activate the app, and macOS (cooperative activation since 14) blocks an inactive app from bringing another app or Finder to the front. The first click only sent the open request without bringing it forward; the second worked because the previous click had briefly activated our app (if it were a gesture conflict, folders would have needed two clicks too). → Briefly activate TopTiroir just before opening, then hand off. Not verified with real clicks — needs user check.
9. Separators between the edit-mode add buttons by purpose: [Choose in Finder · Web link] | [New folder] (add items / make folders).
- 109 tests pass, 0 build warnings. Normal and edit modes captured with temp data, then deleted. The user's favorites.json was not touched.

### Third test round fixes — 2026-11-24
1. **Folder windows clipped left/right in edit mode**: the folder window widens to fit its contents while editing (`Layout.listWindowWidth(editing:)`, min 196 pt × size, wider with text size), back to 168 pt afterwards. Position, next column, and left-flip are recalculated when the width changes. Names truncate with ….
2. **Dropping put items into the neighboring folder**: drop zones on a row are now judged by row height (`FavoriteDrop.zone`) — folder rows: top 25% before / middle 50% inside / bottom 25% after; other rows (including separators): top half before / bottom half after. Before/after shows an orange insertion line; inside outlines the whole folder row.
3. **Dropping into empty space below the list**: in the drawer tab the whole empty area below the list, in folder windows the margin below the last row, is a drop target → end of the list (insertion line at the bottom). Same for adding from Finder/browser.
4. **Open with one click**: verified — favorites rows have no double-click gesture (rename is right-click). Cause ① (fixed): the hosting views of the drawer, folder windows, and shortcuts window could spend the first click on bringing the window forward → `acceptsFirstMouse = true` (folder windows in particular are separate windows, so the first click likely went to activating them). Cause ② (confirmed by test): macOS cooperative activation — the opening sequence is now ① `NSApp.activate()` ② `NSApp.yieldActivation(toApplicationWithBundleIdentifier:)` (the app itself, or for files/folders/links the default app found with `urlForApplication(toOpen:)`) ③ openApplication / open with `OpenConfiguration.activates = true` ④ close the drawer after the completion callback. The same code, called once from a test harness (an inactive accessory app with Finder in front) on Calculator → "done: success, front app after 1 s = Calculator" (Calculator closed afterwards). Real drawer clicks need user check.
   - **Diagnostic log (only when needed)**: `defaults write local.toptiroir.app debugOpenLog -bool true` writes one line per step to `debug-open.log` in the app support folder — time (ms), kind, target bundle ID, activation state, open call, completion result, drawer close (no paths or URLs, file 600). Turn off with `defaults delete local.toptiroir.app debugOpenLog`. Nothing is written when off.
5. All edit-mode add buttons are icon-only (tooltips: Choose in Finder / Add web link / New folder / Add list separator). The vertical separators from round 2 removed.
6. **List separators**: new kind `separator` (favorites.json; old files still read fine). "Add list separator" → appended to the list being viewed. In normal mode a thin line (~9 pt row), clicking does nothing, excluded from the "Name · N items" count. In edit mode a ≡ handle and small dim text "Separator", draggable (before/after only, also to other lists), right-click "Delete" (no confirmation, backup kept). Not subject to folder depth rules.
- 113 tests pass, 0 build warnings. Edit-mode folder window (no clipping), separators, and app icons captured with temp data, then deleted. User favorites untouched.

### Round 4 — one click (2026-11-24, analysis of the user's diagnostic log)
- Log: every click that was logged opened successfully (CotEditor came forward immediately). Freeform was still launching so it wasn't in front at completion; Tailscale is a windowless menu bar app so it can't be "in front" → logged clicks were fine. The real problem was the first click that was never logged at all (spent on waking the window).
- Likely cause: the drawer and folder windows don't activate the app, so hover isn't tracked when they aren't key, and SwiftUI tap gestures may not receive the first click.
- Fix: ① when the mouse enters the drawer, folder, or shortcuts window, make it the key window immediately (tracking area `.activeAlways`) ② outside edit mode, favorites rows are Buttons so they respond to the first click (edit mode keeps the tap gesture for handle dragging) ③ the diagnostic log adds "front app after 0.6 s".
- Limitation: while the drawer is open, moving the mouse over it moves keyboard focus to the drawer (if you were typing in another app, click that app again).

### Round 5 — root cause of the one-click issue confirmed (2026-11-24)
- **Cause (confirmed)**: in a drawer/folder window that isn't key, the first click never reaches the SwiftUI row action (onTapGesture). In a test harness (same code, fake opener) with the drawer not key, mouse down/up events were sent directly to the window: old approach (tap gesture, no first-mouse) → 0 open requests after five clicks; new approach (rows as Buttons + hosting view `acceptsFirstMouse`) → 1 open request on the first click.
- Also fixed: when the mouse enters a window, only that window becomes key (no app activation). Row dragging (onDrag) only on the edit-mode ≡ handle (not the whole row; checked in code). 0.3 s after opening, if a regular app isn't frontmost, unhide it and bring it forward once more (`activate(options: .activateAllWindows)`); accessory (menu-bar-only) apps are logged as "windowless app (won't come forward)". The drawer closes only after this check (closing first would hand activation back to the previous app).
- **Extended diagnostic log** (only when `debugOpenLog` is on): "mouse down/up window=drawer / folder window N / shortcuts key=… appActive=… row=app/folder/file/URL/Finder folder/separator/other editing=…" (as soon as it reaches the window), "done …", "windowless app (won't come forward)", "front after 0.3 s=… target running/hidden/kind/shown", "re-activate request=…", "after 1 s …", "close drawer". No paths or URLs.

### Round 6 — opening several items in a row (2026-11-24)
- The user's diagnostic log confirmed one-click opening works (every item opened on one click, and the front app after 0.6 s was correct).
- Opening a favorite no longer closes the drawer immediately — "stay open after launch": while the mouse is inside the drawer / open folder windows (+ shortcuts window) area (6 pt margin, gaps between windows included) it stays; if the mouse stays outside for 0.4 s or more, the drawer and folder windows close (returning within 0.4 s keeps it open). The mouse position is checked every 0.1 s only while staying open; the timer is removed whenever the drawer closes for any reason. No auto-close in edit mode (existing rule). F12, notch, esc, tab change, opening another item work as before.
- The opening sequence (hand off activation → open → completion → re-activate after 0.3 s) is unchanged; only the final "close drawer" became "stay open after launch".
- Logic in Core `Layout.isInside`, `Layout.LeaveTracker` (0.4 s leave detection), tested. 117 tests pass, 0 build warnings.
- Diagnostic log: "stay-open started", "mouse left for 0.4 s → close drawer", "closed directly while staying open".

### Known limitations
- No auto-scroll at list edges while dragging.
- Changes are saved 0.8 s later even before "Save" ("Save" is the button that ends edit mode).
- The Favorites tab itself couldn't be captured in the real app (the test harness had different settings so the drawer width didn't match) — needs user check.
- When the "Choose apps, files, folders…" panel opens, TopTiroir briefly comes forward and takes focus from the app you were using.
- Dragging a URL from a browser adds it with the site name (e.g. apple.com) instead of the page title.

## v0.3.0 (build 6) — 2026-11-24 · confirmed by user, committed and tagged v0.3.0
v0.2.3 committed: `9fae242`, tag `v0.2.3`.

### Built
1. **Keep screen awake** (first row of Settings › Behavior): "Choose…" → Indefinitely / For a time (11 options, 5 min–5 h) / Until a time (hour:minute field, NSDatePicker). "Start" → starts and closes the drawer. While on: "1:24 left" ("Indefinitely" when unlimited) + "Stop". Remaining time is refreshed each time the drawer opens.
   - Implementation: `IOPMAssertionCreateWithName(PreventUserIdleDisplaySleep, name "TopTiroir 화면 켜 두기")`. Released when time runs out, on stop, on auto-off, and on quit. No permissions needed. The on state is not saved (off after relaunch); only the last mode, duration, and time are saved.
   - Indefinitely: only while charging (on battery the menu shows "Indefinitely (while charging only)" and Start is dimmed). Until a time: handles crossing midnight; more than 5 h away shows "Only times within 5 hours"; a past time shows "That time has already passed" and doesn't start.
2. **Turn off automatically** (below the keep-awake row): when the keyboard or mouse is used (default off, 5 s grace after start; uses only the elapsed time from `CGEventSource.secondsSinceLastEventType` — no permission) / when switching to battery (default on) / when the battery is at or below N% (default on, 20%, 5–50% in steps of 5). "Indefinitely" always turns off when unplugged. Power changes are detected immediately via `IOPSNotificationCreateRunLoopSource` (monitored only while keeping awake). After an automatic stop, the reason is shown in one line at the top the next time the drawer opens (disappears on click or when the drawer closes).
3. **On indicator** (moved to the "Keep screen awake" section in round 1): remaining-time bar (default, 3 pt just below the menu bar, shrinks from the right, faint track, full and softly glowing when indefinite) / breathing neon edge (menu bar border, 4 s cycle) / notch handle glow (46×4 under the notch, centered on screens without a notch). Color swatch (default #F5A623; the color panel is always opaque and values never mix between swatches). On every display, click-through, just below the notch band, re-laid out on display changes, no motion with "Reduce motion". Motion via Core Animation, bar length updated once per second. When off, indicator windows, timers, and power monitoring are all removed. Redrawn only when the style, color, or number of displays changes.
- Logic (end time, remaining time, bar ratio, auto-off decisions, indicator position) in Core `KeepAwake`; the assertion behind the `DisplaySleepBlocking` protocol, session tested with a fake. 78 tests pass, 0 build warnings.
- Real assertion test (separate harness, same code): while active, `pmset -g assertions` shows PreventUserIdleDisplaySleep 1, after release 0. After relaunching the app, 0 TopTiroir assertions.
- All three indicators shown in a harness and captured (bar at 60%, edge, notch glow).

### First test round fixes — 2026-11-24
1. **Settings layout**: a "Keep screen awake" section at the top (duration — left [mode], right [duration/time][Start] / on indicator — right [effect][color] / turn off when keyboard or mouse is used / turn off on battery / turn off when battery is low) → divider → Display → Behavior → Manage. When narrow, the right group wraps to the next line, right-aligned. The indicator row was removed from the Display section.
2. **Keyboard/mouse turning off after one input**: cause — the rule was "last input later than start + 5 s", so a single input should have turned it off, but with a 1 s check interval and a 5 s grace, any input in the first seconds was ignored → the one or two moves right after the drawer closed didn't count, and it only turned off on the next input (the input API itself was verified correct). → Grace reduced to 2 s; 0.25 s checks only when this condition is on (otherwise 1 s); the minimum elapsed time across several input types (any input, mouse move, click, drag, scroll, key, modifier); checks also run while menus are open (.common mode). Power state read every second and on notification; remaining time and bar once per second.
3. **Turn-off reason notice**: if it's shown while the drawer is open, it disappears after 5 s (also disappears and doesn't return if the drawer closes within 5 s). Clicking dismisses it immediately.
4. **Indicator polish**: "Notch handle glow" removed (saved values become the bar). Shape symbols in the picker.
   - Remaining-time bar: 2 pt with round ends, color → lighter shade (computed from the same color) gradient, two layers of glow spreading downward, a slow highlight passing once every 7 s, line and glow shrink together over 1 s for a smooth end. When indefinite, only a 6 s brightness breath.
   - Breathing neon edge → a faint halo spreading 16 pt down from the menu bar's bottom edge + a 1 pt edge line, both ends fade out, 6 s cycle (restrained brightness).
5. App development region set to Korean (`CFBundleDevelopmentRegion: ko`) so the time field shows Korean format instead of "5:40 AM", and system panels like the color panel are in Korean too. (Changed back to `en` in v0.6.0 for the English UI.)
- 80 tests pass (single input, ignoring input during grace, notch-glow conversion, lighter-color calculation), 0 build warnings.

### Round 2 feedback — 7 indicators (2026-11-24)
- Breathing neon edge 1.1× brighter: halo top/middle opacity 0.32→0.352, 0.10→0.11, edge line 0.85→0.935, breathing range 0.35–0.8 → 0.385–0.88 (6 s cycle unchanged).
- 5 new effects (picker symbol + name):
  - Soft halo: fainter than the neon edge, no motion (static effect).
  - Light stream: the same line as the remaining-time bar (length = time left), a bright streak passes over 3.5 s, then rests 2 s.
  - Aurora edge: a halo of three colors (chosen color ±28° on the hue wheel) cycling once every 10 s (faint, soft ends).
  - Dot clock: 10 dots under the notch (centered without one), lit from the left in proportion to time left and turning off from the right (off dots keep 15%), the boundary dot dimmed by the remainder. When indefinite, all lit and breathing alternately.
  - Notch halo: glow around the notch (200 pt in the middle of the menu bar on screens without a notch), 6 s breath, no remaining time.
- Static effects and "Reduce motion" create no animation; only the bar, light stream, and dot clock update remaining time. Unknown saved values become the bar.
- Tests for the calculations (dot brightness, aurora colors, hue shift, window position) and saved-value conversion; 86 tests pass, 0 build warnings. All 7 shown in a harness and captured.
- Five other ideas in the first report (hourglass dots, aurora gradient, firefly dots, corner glow, last-5-minutes alert) are not part of this list — can be done separately if wanted.

### Known limitations
- `pmset -g assertions` shows the Korean name as `named: ""` (the name is set correctly — verified in the assertion properties). Look for the "PreventUserIdleDisplaySleep" line and the TopTiroir pid.
- In full-screen apps the indicator is hidden entirely (it doesn't appear even when the menu bar is revealed with the mouse).
- Start/stop/auto-off behavior and the settings row layout couldn't be clicked in the app directly — needs user check.
- It doesn't prevent the Mac from sleeping (e.g. closing the lid); it only prevents the display from turning off by itself.

## v0.2.3 (build 5) — 2026-11-24 · confirmed by user, committed and tagged v0.2.3
v0.2.2 committed: `6579613`, tag `v0.2.2`.

### Built
1. **One drawer height**: all tabs use the same height value (`notesHeight`). The bottom handle can be dragged on every tab; long content scrolls inside the tab (Settings, Favorites). Max = min(half the screen, 900 pt), unchanged. The shortcuts window follows the drawer height.
2. **Switching tabs closes auxiliary windows**: going to any tab other than Settings (by bookmark or shortcut) closes the shortcuts window and color panels (band color, drawer color). They don't reopen on return. Everything closes in one place, `closeAuxiliaryWindows()`, so v0.4 favorites folder windows can be added there.
3. **Tab shortcuts default to F1·F2·F3** (key codes 122·120·99), working even with a text cursor. Rule: function keys and ⌘/⌃ combos always; single letter/number keys only when there is no cursor. A note about this in the shortcuts window. If the saved values are still the old defaults (1·2·3) they migrate to the new defaults; custom values are kept. Reset / Reset all also use F1–F3. Conflict check with F12 (open drawer) verified.
4. Removed the "Open drawer shortcut" row from Settings › Behavior (shortcuts window only).
5. Settings pickers (open from notch, tab to show on open, close drawer, drawer brightness) and the "View shortcuts…" button sized like the "2 spaces" text (text size 80–95% small / up to 125% regular / above that large). Settings rows grow to fit content (min 21 pt × text size).
6. **Handle between memo and to-dos**: drag up/down to split (memo share 20–80%, default 3:2, saved as a ratio `memoRatio` → kept when the drawer height changes). Double-click = 3:2. Minimum heights: memo 40 pt; to-dos = input row + two rows (input row, split button, and the pending count below always visible). Vertical resize cursor on hover.
- 62 tests pass (new defaults, migration, cursor branching, ratio, min heights, dragging), 0 build warnings.
- (Round 1 feedback) The 4 pickers, "View shortcuts…", band color "Default", indent "+"/"−", "Clear", "Show", and "Quit" in Settings use the same size as "Delete completed": one shared value `DrawerFont.control` (11 pt × text size); pickers can't set a font directly, so they use the closest size step (small = 11 pt). When a row doesn't fit on one line (e.g. text 140% with drawer 80%), the control moves to the next line, right-aligned (the "Drawer & window color" row becomes two lines); percentage text no longer wraps.

### Known limitations
- Pickers only have size steps, so at 130–140% text size they're slightly smaller (13 pt) than button text (15 pt).
- "Reset"/"Reset all" and confirmation-row buttons in the shortcuts window unchanged (out of scope).
- The memo/to-do handle was checked only visually by screen capture; dragging and double-click need user check.

## v0.2.2 (build 4) — 2026-11-24 · confirmed by user, committed and tagged v0.2.2
v0.2.1 committed: `4b45913`, tag `v0.2.1`.

### Built
1. **Shortcuts window**: "View shortcuts…" on the "Shortcuts" row at the bottom of Settings › Behavior ("Close shortcuts" when open). A glass window to the right of the drawer with the same height (follows drawer color, opacity, text size), placed to the left if it would go off the right edge. Scrolls inside when long. Closed by its ✕, "Close shortcuts", or closing the drawer (clicking elsewhere in the drawer keeps it).
   - Sections: Drawer (open/close F12 / esc view-only / quit ⌘Q), Switch tabs (1·2·3), Editing notes and to-dos (⌘Z·⇧⌘Z·⌘X·⌘C·⌘V·⌘A·Tab·⇧Tab·↩·double-click — dimmed, not changeable).
   - Changing: click a key button → "Press a new key…"; esc or clicking again cancels. A "Reset" per row when different from default, "Reset all" at the bottom. Global shortcuts are suspended while recording (so pressing F12 etc. doesn't close the drawer).
   - Validation (Core `ShortcutSet.check`): open drawer = a function key alone or a ⌘/⌃ combo; quit = a ⌘ combo; tab switching = single keys allowed. Keys already used by another entry or a view-only key are refused with "Already used for …". Keypad digits count as the same keys as the top-row digits.
   - The Settings tab's "Open drawer shortcut" row stays and shares the same value (changing one updates the other).
   - Storage: open drawer uses the existing `hotKeyCode`/`hotKeyModifiers`; the rest use `shortcut.<entry>` (key code + modifiers packed into one number).
2. **Tab shortcuts**: with the drawer open and no text cursor, 1 = Notes/To-dos, 2 = Favorites, 3 = Settings (top row and keypad). Judged by key position (key code), so it works with Korean input too. With a cursor in a field, digits are typed as text.
   - Cursor on open: since v0.2.1 no field gets the cursor when the drawer opens → 1·2·3 work right away.
   - Removing the cursor: clicking anything in the drawer that isn't a text field (empty space, text, buttons) removes the cursor (new).
3. Quit (⌘Q) is now a changeable entry and follows the setting instead of a fixed ⌘Q handler (works even with a cursor).
- 57 tests pass (defaults, tab switching, cursor branching, keypad, validation, conflicts, storage, side-window position). 0 build warnings.

### Known limitations
- The shortcuts window's look and clicks were verified only by build and tests (the button that opens it couldn't be clicked directly, so no capture).
- Clicking a non-field button also removes the cursor (e.g. clicking a check button while typing a new to-do removes the cursor from the input).
- The shortcuts window follows the drawer's color and opacity but has no height handle.

## v0.2.1 (build 3) — 2026-11-24 · confirmed by user, committed and tagged v0.2.1
v0.2.0 committed: `288022a`, tag `v0.2.0`.

### Built
1. **To-do split button**: "Delete completed | ▾" to the right of the input row. Main part = delete only checked to-dos (dimmed and inert when there are none); ▾ = "Clear to-dos…" (dimmed when empty). Clearing goes through a confirmation row below the input (count + can't be undone, Clear/Cancel) and leaves `notes.backup.json`. The "Clear to-dos" row in Settings › Manage removed ("Clear memo" stays).
2. **Indent width** (Settings › Behavior): "+ [ 4 spaces ] −", 1–8, default 4. You can type the number; out-of-range values snap to the nearest. Used as the **memo's Tab width**: Tab = N spaces (selected text is replaced by spaces), Shift+Tab = remove up to N leading spaces from every line the cursor/selection touches (undoable with ⌘Z). For this the memo field changed from SwiftUI TextEditor to NSTextView (TextEditor can't remap Tab).
3. **Drawer & window color** (Settings › Display, below band color): either (● Default [Light/Dark/System]) or (○ Color [swatch]). Default = the current glass background, with only the drawer in that appearance (the Mac's appearance unchanged; System is the default). Color = the chosen color as background (together with the opacity setting); text switches light/dark automatically by background luminance (WCAG contrast). Default color #2E3240. Shares the color panel with band color but remembers which swatch opened it so values never mix; always opaque.
- No text field gets the cursor when the drawer opens (the cursor used to land in the indent number field).
- Added missing default registrations for text size and text opacity (no behavior change).
- 46 tests pass (indent range, removing leading spaces, automatic text color, brightness per color mode). 0 build warnings.

### First test round fixes — 2026-11-24
1. **Editing shortcuts ⌘Z·⇧⌘Z·⌘A·⌘C·⌘V·⌘X**: cause — this app has no Dock or menu bar presence (LSUIElement), so it has no "Edit" menu, and macOS delivers these shortcuts to text fields through Edit menu items, so the keys never reached the field (the drawer panel did receive key input — that's why esc worked). → The drawer's key monitor sends undo:/redo:/cut:/copy:/paste:/selectAll: directly to the field with the cursor (first responder) when it sees these 6 keys. If no field can take it, the key passes through. Applies to the memo, new to-do field, to-do edit field, and indent number field. No conflict with ⌘Q. Undo uses the drawer window's undoManager (typing, paste, Tab spaces, and Shift+Tab are all undoable).
   - Why not a hidden Edit menu: there's no guarantee menu shortcuts are handled while the app is inactive (the drawer doesn't activate the app). The key monitor already handles esc and ⌘Q reliably on the same path.
2. **The ▾ list went outside the drawer**: the system menu (SwiftUI Menu) opened from the arrow's left edge to the right and went outside the drawer. → The split button and its list are drawn inside the drawer: the list's right edge = the button's right edge, directly below the button. Closes when the main part or an item is clicked, or ▾ is clicked again.
- (Round 2) **Editing shortcuts didn't work with Korean input**: cause — keys were identified by character (`charactersIgnoringModifiers`), and with Korean input ⌘A arrives as "ㅁ" and ⌘C as "ㅊ", which didn't match a/c. → Identify by key position (key codes A=0, Z=6, X=7, C=8, V=9), logic split into Core `EditCommand` (only when ⌘ alone is held; ⇧ only for Z; ignored with ⌃ or ⌥). If Korean composition is in progress (underlined text), the composition is committed (`unmarkText`) before the command. ⌘Q (key code 12) and esc (53) were key-code based from the start, unaffected. The global open-drawer shortcut (Carbon) is a separate path, unaffected. 48 tests.
- NSTextView undo was verified separately with a temporary window and a temporary, uniquely named pasteboard (the real memo and clipboard were not used).

### Known limitations
- Version number: as a new feature it should have been 0.3.0 under the versioning rule, but 0.2.1 was used to keep v0.3 for "Keep screen awake" (needed user confirmation).
- The open ▾ list doesn't close when clicking elsewhere in the drawer (closes via ▾, the main part, an item, or reopening the drawer).
- In "Color" mode, translucent colors for tabs and dividers use only two values (light/dark), so tabs may look less fitting on very saturated backgrounds.

## v0.2.0 (build 2) — 2026-11-24 · confirmed by user, committed and tagged v0.2.0

### Built
- **Notes/To-dos tab** (first bookmark): memo on top : to-dos below = 3:2, each scrolling separately. The memo field is darker than its surroundings with an inner shadow. To-do rows 22 pt — add with ↩, check with the circle, remove from the list with the ✕ shown on hover. Pending count shown (e.g. 2/5).
- **Storage**: `~/Library/Application Support/TopTiroir/notes.json` (folder 700, file 600, current user only). Written once 0.8 s after typing stops, and immediately when the drawer closes or the app quits. Nothing is sent over the network. If the file is corrupt and can't be read, it is not deleted but moved to `notes-읽기실패-<time>.json` ("read failed") and the app starts empty (if even moving fails, saving stops to protect the original).
- **Drawer height**: drag the handle at the bottom of the Notes/To-dos tab up/down. Min 160 pt, max = min(half the screen height, 900 pt). Saved on release and kept next time. The handle turns orange while dragging.
- **Tab to show on open** (Settings › Behavior): last viewed tab (default) / Notes/To-dos / Favorites.
- **Changing the shortcut**: clicking the "Open drawer shortcut" button shows "Press a new key…" → the pressed key is registered. esc, clicking the button again, or closing the drawer cancels. F1–F20 alone; letter/number keys with ⌘ or ⌃ (⌥/⇧ alone are blocked by macOS). On registration failure a notice is shown and the previous key is kept. A "Back to F12" button when not default.
- **Drawer & window opacity** (Settings › Display, right below size): 50–100% in 5% steps. Live preview while dragging; saved on release or after a 0.4 s pause. Applies to the drawer and the band color panel.
- The drawer & window size slider was already wired up in v0.1, unchanged.
- Version 0.2.0, build 2. 37 tests (16 new: notes data, height, 3:2, opacity, key names, key validation, tab on open) pass, 0 build warnings.

### First test round fixes — 2026-11-24 (after all 12 checks passed)
1. Shortcut "Back to F12" button → "Reset" (same behavior).
2. "Drawer & window size" changes only width, padding, corners, and the handle — not the text.
3. Added a "Text size" slider (80–140%, default 100%) above "Drawer & window size". Text, text row heights (settings rows 21 pt, to-do rows 22 pt, tab height), and switches follow it.
4. "Drawer & window opacity" applies only to the glass background (blur, gradient, border), not the text. Range 20–100% (background only, so text stays readable even lower).
5. Added a "Text opacity" slider (40–100%, default 100%) above "Drawer & window opacity". Order: text size → drawer & window size → text opacity → drawer & window opacity.
6. Only the new to-do input row has a light background (dark: white 14%, light: white 75%) + border, orange border while typing.
7. "Pending N / To-dos N" moved to the bottom left of the drawer (left of the handle). "Delete completed" to the right of the input row (dimmed when none). The handle's drag area is only the middle, so it doesn't overlap the text.
8. "Clear memo" and "Clear to-dos" at the top of Settings › Manage. Clicking shows a confirmation row in place (what will be cleared + can't be undone + backup note) → "Clear" must be pressed again. The state just before clearing is overwritten into a single `notes.backup.json` in the same folder (if the backup fails, nothing is cleared). Buttons dimmed when empty.
- Sliders unified as one `PercentSlider`: the two size sliders save on release; the two opacity sliders preview live and save on release or after a 0.4 s pause.
- 40 tests pass (filtering completed items, both opacity ranges, text size range). Saving and backup verified separately in a temp folder (the real memo was not used).

### Second test round fixes — 2026-11-24
1. **Editing to-dos**: double-click a to-do's text → that row becomes an input field (long text shows fully, up to 6 lines). ↩ saves and ends, esc restores the original text and ends (the drawer stays open). ↩ with empty text keeps the original.
   - If the drawer is closed while editing (F12, notch, outside click — any close except esc) or the app quits (⌘Q, Quit button): if the text equals the saved text it proceeds; if different, an in-drawer confirmation "Save your changes?" (Save / Don't Save / Cancel). Closing is blocked meanwhile and quitting is deferred with `terminateLater`. Cancel keeps editing.
   - Tests added for "is it changed" (`isEditChanged`: ignores leading/trailing spaces; empty text can't be saved so it isn't a change) and for editing text.
2. **The band color panel is always opaque**: reverted the part that followed drawer opacity. Text size and text opacity don't apply either.
3. **"⌘Q" shown next to the Quit button**. ⌘Q is handled by the drawer's key monitor instead of a button shortcut, so it works on any tab while the drawer is open (when the drawer is closed this app doesn't receive keys — it has no Dock or menu bar icon).
4. Removed the backup sentence from the clear confirmation row (backup behavior unchanged).
- 42 tests pass, 0 build warnings.

### Additional limitations
- The system color panel for band color doesn't follow text size or opacity settings (always opaque, round-2 fix).
- "Text opacity" also fades buttons, switches, and the memo field along with the text (applies to all content).
- Only the last backup is kept: clearing the memo and then the to-dos leaves only the state before the second clear (with the memo already empty).
- The light-mode input row color wasn't verified on screen (only dark mode was captured).

### Decisions
- (Changed in round 1) Window opacity 20–100% (background only), text opacity 40–100%.
- Max drawer height min(half the screen, 900) applies to all tabs (the existing half rule + a 900 cap).

### Known limitations
- On a 15-inch built-in display (~956 pt tall) the half-screen rule caps the drawer at ~478 pt. 900 pt is reached only on large external displays.
- Changing shortcuts only works while the drawer is open (while it receives key input).
- To-do text shows one line and truncates with … (full text on hover). Editing and reordering to-dos not yet available.

## v0.1.0 done — 2026-11-24
- All 4 user checks passed → first commit, tag `v0.1.0`.
- Bundle ID kept as `local.toptiroir.app` (owner's decision).
- From the icon concept folder only the original icons and brand guide are committed (zip and preview png excluded via .gitignore).
- No remote repository (nothing pushed).

## v0.1.0 fixes (second test round) — 2026-11-24
- **Clicking the band color swatch did nothing**: the click worked and the color panel did open (present in the window list at layer 26 next to the drawer, but not visible), but the NSPanel default `hidesOnDeactivate = true` hid it immediately (our app never becomes active). → `hidesOnDeactivate = false`.
- **Rounded corners made no visible difference**: the corner pixel in the user's screenshot was (0,0,0), so the corners were drawn but black on the black band. → When notch hiding is on, the top two corners are drawn **just below the band** in the band color, so the screen below the band starts rounded. The bottom two stay black.

## v0.1.0 fixes (first test round) — 2026-11-24
- **Band color didn't change**: the band window was fine (menu bar color in the screenshot ≈ #0B0C10), but SwiftUI ColorPicker couldn't save changes from the drawer panel, which doesn't deactivate other apps (`bandColor` had never been saved). → A swatch button wired directly to the system color panel with target/action (`BandColorPanel`), plus a "Default" button.
- **Rounded screen corners weren't visible**: the 4 windows were created and drawn in place, but at 10 pt in the band color they were nearly invisible (the top ones matched the black band). → Always black, 16 pt, at the screen saver level (.screenSaver).
- **Tabs and drawer per the mockup**: 1:1:1 tabs (gap 3, top corners 7); the selected tab is 2 pt taller with a white background covering the bottom line (no orange); the drawer is glass (blur + gradient) with square top corners and 24 pt rounded bottom corners, a 1 pt border without the top edge, a bottom handle, small orange switches (26×15) and sliders, small gray pop-ups, section titles 10.5 pt bold.
- Shadow uses the system window shadow instead of the mockup values (0, 24, blur 48), to keep the click area equal to the drawer without an outer margin.

## v0.1.0 (build 1) — 2026-11-23 · awaiting user test

### Built
- **Notch hiding (method B)**: a black band window as tall as the menu bar at the top of the built-in notched display, placed just above the desktop icon level. Click-through, fixed on all desktops (Spaces). Recalculated when display settings change. No band on external displays.
- **Rounded screen corners** (default off): 10 pt rounded corner overlays at the four corners of the built-in display (same color as the band, click-through).
- **Drawer**: a Liquid Glass panel. Centered just below the menu bar on the screen with the mouse, width 420 pt × ratio, height fits the content up to half the screen. On a notched display the top corners are square (as if dropping from the notch).
  - Open: click the notch (or hover) · F12 · relaunch the app.
  - Close: outside click · esc (can be set to esc only) · click the notch / F12 again.
  - Three bookmark tabs: Notes/To-dos (v0.2 placeholder) · Favorites (v0.4 placeholder) · Settings (default).
- **Settings tab**: Display (notch hiding, corners, band color, size 80–140%) / Behavior (show F12, open from notch, close drawer) / Manage (show icon for 60 s, launch at login, about, quit ⌘Q).
- 21 unit tests (27 cases with arguments) pass.

### Decisions
- The size slider applies on release (if the drawer resized while dragging, the slider itself would move).
- Corner overlay color follows the band color.
- App Sandbox off (switching to method A might require changing the wallpaper).

### To check / known limitations
- Needs user check that method B actually makes both sides of the notch look black (if macOS doesn't show windows behind the menu bar, switch to method A).
- The band isn't visible in full-screen apps (it lives at the desktop level).
- Launch at login is most reliable when the app is in `/Applications`. Enabling it from the build folder registers that path.
- The `appintentsmetadataprocessor ... no AppIntents.framework` line in the build log is an Xcode tool message (not a code warning).
